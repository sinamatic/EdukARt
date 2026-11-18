"""Runs on the SSH host with Python's standard library only.

The app injects PAYLOAD (configuration + bundled bridge) before executing this file.
No downloads, package installation, sudo, or changes to the robot driver.
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


def run(args, timeout=25):
    result = subprocess.run(args, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, timeout=timeout)
    if result.returncode:
        raise RuntimeError((result.stderr + result.stdout)[-6000:] or str(args[0]) + " failed")
    return result.stdout


def runtime_command(container, command, environment=None):
    args = []
    if container:
        args = ["docker", "exec"]
        for key, value in (environment or {}).items():
            args += ["-e", key + "=" + value]
        args += [container]
    else:
        args = ["env"] + [key + "=" + value for key, value in (environment or {}).items()]
    return args + ["bash", "--noprofile", "--norc", "-c", command]


def result_from(output):
    for line in reversed(output.splitlines()):
        if line.startswith("EDUKART_RESULT="):
            return json.loads(line.partition("=")[2])
    raise RuntimeError("ROS discovery returned no result: " + output[-2000:])


def probe(port):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(0.4)
        sock.sendto(b'{"kind":"health","id":"setup"}', ("127.0.0.1", port))
        try:
            return json.loads(sock.recv(60000))
        except (socket.timeout, ValueError, OSError):
            return None


def main(payload):
    config = payload["config"]
    action = payload["action"]
    environment = json.loads(config["environment"])
    container = config["container"].strip()
    setup = config["setup"].strip()
    bridge = base64.b64decode(payload["bridge"])
    if action == "debug":
        if not setup:
            raise RuntimeError("ROS-Setup-Befehl fehlt.")
        source = "import base64; exec(base64.b64decode(" + repr(payload["debugScript"]) + "))"
        debug_config = base64.b64encode(json.dumps(payload["debugConfig"]).encode()).decode()
        report = result_from(run(runtime_command(container,
            setup + " && python3 -c " + shlex.quote(source) + " " + shlex.quote(debug_config), environment), 25))
        if shutil.which("docker"):
            try:
                report["containers"] = run(["docker", "ps", "--format", "{{.Names}}: {{.Status}}"], 5).splitlines()
            except Exception as error:
                report["containerError"] = str(error)
        if container:
            try:
                report["driverContainerLogs"] = run(
                    ["docker", "logs", "--tail", "120", container], 5)[-16000:]
            except Exception as error:
                report["driverContainerLogsError"] = str(error)
        return report
    if action == "discover":
        candidates = [container]
        if shutil.which("docker"):
            try:
                candidates += run(["docker", "ps", "--format", "{{.Names}}"], 10).splitlines()
            except Exception:
                pass
        candidates.append("")
        candidates = list(dict.fromkeys(candidates))[:8]
        errors = []
        fallback = None
        for candidate in candidates:
            try:
                candidate_setup = setup
                if not candidate_setup:
                    found = run(runtime_command(candidate,
                        "for f in /opt/ros/*/setup.bash; do [ ! -f \"$f\" ] || printf '%s\\n' \"$f\"; done"))
                    paths = found.splitlines()
                    if len(paths) != 1:
                        raise RuntimeError("ROS setup is ambiguous or absent; enter setup command manually")
                    candidate_setup = "source " + shlex.quote(paths[0])
                source = "import base64; exec(base64.b64decode(" + repr(payload["bridge"]) + "))"
                graph = result_from(run(runtime_command(candidate,
                    candidate_setup + " && python3 -c " + shlex.quote(source) + " --discover", environment), 18))
                graph.update(container=candidate, setup=candidate_setup, candidates=candidates, warnings=errors[:])
                if fallback is None:
                    fallback = graph
                # Prefer a runtime where a real drive subscription is visible.
                if any("geometry_msgs/msg/Twist" in t["types"] and t["subscribers"] > 0
                       for t in graph["topics"]):
                    return graph
            except Exception as error:
                errors.append((candidate or "host") + ": " + str(error))
        if fallback:
            fallback["warnings"] = errors
            return fallback
        raise RuntimeError("No ROS 2 environment found. " + "\n".join(errors))

    if container:
        network = run(["docker", "inspect", "--format", "{{.HostConfig.NetworkMode}}", container]).strip()
        if network != "host":
            raise RuntimeError("Selected container needs host networking for the UDP bridge.")
    if not setup:
        raise RuntimeError("Enter a ROS setup command first.")
    identity = payload["profile"]
    # Profile IDs originate in the app; still reject paths rather than trusting input.
    import uuid
    identity = str(uuid.UUID(identity))
    directory = Path.home() / ".local" / "share" / "edukart" / identity
    host_file = directory / "edukart_bridge_v2.py"
    runtime_file = "/tmp/edukart-bridge-" + identity + ".py" if container else str(host_file)
    port = int(config["udpPort"])
    instance = identity + ":" + hashlib.sha256(bridge).hexdigest()[:12]
    if action == "install":
        run(runtime_command(container, setup + " && python3 -c " + shlex.quote(
            "import rclpy, rosidl_runtime_py; from geometry_msgs.msg import Twist; from std_srvs.srv import SetBool"), environment))
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        temporary = directory / "bridge.tmp"
        temporary.write_bytes(bridge)
        temporary.chmod(0o600)
        temporary.replace(host_file)
        if container:
            # /tmp copy must be readable by the container's non-root user.
            host_file.chmod(0o644)
            run(["docker", "cp", str(host_file), container + ":" + runtime_file])
        return {"message": "Bridge installiert. Noch nicht gestartet.", "path": str(host_file)}
    if action != "start":
        raise RuntimeError("Unknown setup action")
    if not host_file.exists():
        raise RuntimeError("Zuerst 'install ROSbridge on Robot' ausführen.")
    if host_file.read_bytes() != bridge:
        raise RuntimeError("Installierte Bridge ist veraltet. Bitte erneut installieren.")
    existing = probe(port)
    if existing:
        if existing.get("instance") == instance and existing.get("version") == 2:
            return {"message": "Bridge läuft bereits und antwortet.", "health": existing}
        raise RuntimeError("UDP-Port wird von einer anderen Bridge verwendet. Anderen Port wählen oder alte Bridge stoppen.")
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as check:
        check.bind(("0.0.0.0", port))
    if container:
        run(["docker", "cp", str(host_file), container + ":" + runtime_file])
    logfile = "/tmp/edukart-bridge-" + identity + ".log"
    command = setup + " && exec python3 " + shlex.quote(runtime_file)
    command += " --port " + str(port) + " --instance " + shlex.quote(instance)
    command += " >" + shlex.quote(logfile) + " 2>&1"
    args = runtime_command(container, command, environment)
    if container:
        args.insert(2, "-d")
        run(args)
    else:
        subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    for _ in range(15):
        health = probe(port)
        if health and health.get("instance") == instance:
            return {"message": "Bridge gestartet; UDP-Antwort bestätigt.", "health": health}
        time.sleep(0.2)
    logs = run(runtime_command(container, "tail -c 4000 " + shlex.quote(logfile)))
    raise RuntimeError("Bridge antwortet nicht. " + logs)


if "PAYLOAD" in globals():
    try:
        result = {"ok": True, "result": main(PAYLOAD)}
    except Exception as error:
        result = {"ok": False, "error": str(error)}
    print("EDUKART_RESULT=" + json.dumps(result), flush=True)
