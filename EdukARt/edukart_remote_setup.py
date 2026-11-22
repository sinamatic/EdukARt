"""Discover a ROS runtime and replace this app's single managed bridge.

Runs on the SSH host with Python's standard library. Only the bridge file and
process identified by this app's fixed identity are changed.
"""
import base64
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import socket
import subprocess
import time
import uuid


def run(args, timeout=25):
    result = subprocess.run(args, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, timeout=timeout)
    if result.returncode:
        raise RuntimeError((result.stderr + result.stdout)[-3000:] or str(args[0]) + " failed")
    return result.stdout


def runtime_command(container, command, environment=None):
    if container:
        args = ["docker", "exec"]
        for key, value in (environment or {}).items():
            args += ["-e", key + "=" + value]
        args.append(container)
    else:
        args = ["env"] + [key + "=" + value for key, value in (environment or {}).items()]
    return args + ["bash", "--noprofile", "--norc", "-c", command]


def result_from(output):
    for line in reversed(output.splitlines()):
        if line.startswith("EDUKART_RESULT="):
            return json.loads(line.partition("=")[2])
    raise RuntimeError("ROS analysis returned no result: " + output[-1000:])


def probe(port):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(0.4)
        sock.sendto(b'{"kind":"health","id":"setup"}', ("127.0.0.1", port))
        try:
            return json.loads(sock.recv(60000))
        except (socket.timeout, ValueError, OSError):
            return None


def setup_paths(container):
    # Search existing ROS installations and workspaces without assuming a
    # distro, container name, workspace name, or home directory.
    script = """
import json, os
from pathlib import Path
roots = [Path.home(), Path("/home"), Path("/workspace"), Path("/opt/ros")]
found = set()
for root in roots:
    if not root.is_dir():
        continue
    for base, dirs, files in os.walk(root):
        depth = len(Path(base).relative_to(root).parts)
        dirs[:] = [d for d in dirs if d not in
                   (".git", ".cache", "node_modules", "build", "log") and depth < 6]
        path = Path(base) / "setup.bash"
        if "setup.bash" in files and (
            Path(base).name == "install" or str(path).startswith("/opt/ros/")
        ):
            found.add(str(path))
print(json.dumps(sorted(found)))
"""
    output = run(runtime_command(container, "python3 -c " + shlex.quote(script)), 15)
    return json.loads(output)


def docker_containers():
    if not shutil.which("docker"):
        return []
    try:
        return run(["docker", "ps", "--format", "{{.Names}}"], 10).splitlines()
    except Exception:
        return []


def analyze(payload):
    environment = json.loads(payload["config"]["environment"])
    expected = payload.get("expected", {})
    source = "import base64; exec(base64.b64decode(" + repr(payload["bridge"]) + "))"
    candidates = []
    errors = []
    for container in [""] + docker_containers():
        label = "Host" if not container else "Docker " + container
        try:
            paths = setup_paths(container)
        except Exception as error:
            errors.append(label + ": " + str(error))
            continue
        if not paths:
            errors.append(label + ": kein ROS-Setup gefunden")
        for path in paths[:12]:
            setup = "source " + shlex.quote(path)
            try:
                graph = result_from(run(runtime_command(
                    container, setup + " && python3 -c " + shlex.quote(source)
                    + " --discover", environment), 18))
                topics = graph.get("topics", [])
                services = graph.get("services", [])
                drive = expected.get("drive", {})
                enable = expected.get("enable", {})
                lights = expected.get("lights", {})
                drive_match = any(
                    item.get("name") == drive.get("name")
                    and drive.get("type") in item.get("types", [])
                    and item.get("subscribers", 0) > 0 for item in topics
                )
                mode_match = any(
                    item.get("name") == enable.get("name")
                    and enable.get("type") in item.get("types", [])
                    for item in services
                )
                light_match = any(
                    item.get("name") == lights.get("name")
                    and lights.get("type") in item.get("types", [])
                    and item.get("subscribers", 0) > 0 for item in topics
                )
                workspace = str(Path(path).parent.parent) if Path(path).parent.name == "install" else ""
                identifier = hashlib.sha256((container + "\0" + path).encode()).hexdigest()[:16]
                candidates.append({
                    "id": identifier, "container": container, "setup": setup,
                    "workspace": workspace, "label": label + " · " + path,
                    "matchesEduard": drive_match and mode_match,
                    "matches": [name for name, ok in
                                (("Fahren", drive_match), ("Enable", mode_match),
                                 ("Licht", light_match)) if ok],
                    "installable": bool(container or workspace),
                    "topics": topics, "services": services,
                    "interfaceErrors": {name: value["error"] for name, value
                                        in graph.get("interfaces", {}).items()
                                        if isinstance(value, dict) and "error" in value}
                })
            except Exception as error:
                errors.append(label + " · " + path + ": " + str(error))
    matching = [item for item in candidates if item["matchesEduard"] and item["installable"]]
    selected = matching[0]["id"] if len(matching) == 1 else None
    return {"candidates": candidates, "selected": selected, "errors": errors,
            "message": ("Ein passendes ROS-Ziel gefunden." if selected
                        else "Zielumgebung nicht eindeutig. Befund prüfen und Ziel wählen.")}


def managed_processes(container, paths, identity, stop=False):
    # Match the exact bridge script path and this app's instance ID. No other
    # Python, ROS, driver, workspace, or container process is touched.
    script = """
import json, os, signal, sys
paths = set(json.loads(sys.argv[1]))
identity = sys.argv[2] + ":"
pids = []
for name in os.listdir("/proc"):
    if not name.isdigit() or int(name) == os.getpid():
        continue
    try:
        args = Path("/proc/" + name + "/cmdline").read_bytes().split(b"\\0")
        args = [part.decode(errors="replace") for part in args if part]
        if len(args) < 4 or args[1] not in paths:
            continue
        if "--instance" not in args:
            continue
        index = args.index("--instance")
        if index + 1 >= len(args) or not args[index + 1].startswith(identity):
            continue
        pids.append(int(name))
        if sys.argv[3] == "stop":
            os.kill(int(name), signal.SIGTERM)
    except (OSError, ValueError, IndexError):
        continue
print(json.dumps(pids))
"""
    script = "from pathlib import Path\n" + script
    command = ("python3 -c " + shlex.quote(script) + " "
               + shlex.quote(json.dumps(paths)) + " " + shlex.quote(identity)
               + " " + ("stop" if stop else "list"))
    return json.loads(run(runtime_command(container, command), 10))


def install(payload, analysis):
    identity = str(uuid.UUID(payload["profile"]))
    target_id = payload.get("target") or analysis["selected"]
    matches = [item for item in analysis["candidates"] if item["id"] == target_id]
    if len(matches) != 1 or not matches[0]["installable"]:
        raise RuntimeError("Zielumgebung fehlt oder wurde nicht erneut erkannt. ROS analysieren und Ziel wählen.")
    target = matches[0]
    container = target["container"]
    setup = target["setup"]
    environment = json.loads(payload["config"]["environment"])
    bridge = base64.b64decode(payload["bridge"])
    port = int(payload["config"]["udpPort"])
    instance = identity + ":" + hashlib.sha256(bridge).hexdigest()[:12]
    old_file = Path.home() / ".local" / "share" / "edukart" / identity / "edukart_bridge_v2.py"
    if container:
        network = run(["docker", "inspect", "--format", "{{.HostConfig.NetworkMode}}", container]).strip()
        if network != "host":
            published = run(["docker", "port", container, str(port) + "/udp"]).strip()
            if not published:
                raise RuntimeError("Docker-Ziel hat weder Host-Netzwerk noch einen veröffentlichten UDP-Port.")
        runtime_file = "/tmp/edukart-bridge-" + identity + ".py"
    else:
        runtime_file = str(Path(target["workspace"]) / ".edukart" / "edukart_bridge_v2.py")
    existing = probe(port)
    if existing and not str(existing.get("instance", "")).startswith(identity + ":"):
        raise RuntimeError("UDP-Port wird von einer anderen Bridge verwendet. Keine fremde Bridge beendet.")
    old_paths = [runtime_file, str(old_file)]
    processes = managed_processes(container, old_paths, identity, stop=True)
    if existing and not processes:
        raise RuntimeError("Alte Bridge antwortet, ihr Prozess konnte aber nicht eindeutig zugeordnet werden.")
    for _ in range(20):
        if not managed_processes(container, old_paths, identity):
            break
        time.sleep(0.1)
    else:
        raise RuntimeError("Alter Bridge-Prozess konnte nicht beendet werden.")
    if container:
        old_file.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        temporary = old_file.with_suffix(".tmp")
        temporary.write_bytes(bridge)
        temporary.chmod(0o644)
        try:
            run(["docker", "cp", str(temporary), container + ":" + runtime_file])
        finally:
            temporary.unlink(missing_ok=True)
            old_file.unlink(missing_ok=True)
    else:
        destination = Path(runtime_file)
        destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        temporary = destination.with_suffix(".tmp")
        temporary.write_bytes(bridge)
        temporary.chmod(0o600)
        temporary.replace(destination)
        if old_file != destination:
            old_file.unlink(missing_ok=True)
    # The same install action starts the updated file and verifies its reply.
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as check:
        check.bind(("0.0.0.0", port))
    logfile = "/tmp/edukart-bridge-" + identity + ".log"
    command = (setup + " && exec python3 " + shlex.quote(runtime_file)
               + " --port " + str(port) + " --instance " + shlex.quote(instance)
               + " >" + shlex.quote(logfile) + " 2>&1")
    args = runtime_command(container, command, environment)
    if container:
        args.insert(2, "-d")
        run(args)
    else:
        subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    for _ in range(25):
        health = probe(port)
        if health and health.get("instance") == instance:
            return {"message": "Bridge aktualisiert und gestartet.", "health": health,
                    "target": target["label"], "path": runtime_file}
        time.sleep(0.2)
    raise RuntimeError("Bridge wurde ersetzt, antwortet aber nicht. Bridge-Log: " + logfile)


def main(payload):
    action = payload["action"]
    if action not in ("discover", "install"):
        raise RuntimeError("Unknown setup action")
    analysis = analyze(payload)
    if action == "discover":
        return analysis
    return install(payload, analysis)


if "PAYLOAD" in globals():
    try:
        result = {"ok": True, "result": main(PAYLOAD)}
    except Exception as error:
        result = {"ok": False, "error": str(error)}
    print("EDUKART_RESULT=" + json.dumps(result), flush=True)
