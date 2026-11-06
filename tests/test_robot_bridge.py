"""Offline checks for deployment and UDP parsing; ROS calls use doubles."""
import base64
import importlib.util
import json
from pathlib import Path
import socket
import select
import sys
import tempfile
import types
import unittest
from unittest.mock import Mock, patch
import uuid

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


manager = load("manager", ROOT / "EdukARt/edukart_remote_setup.py")


class DeploymentChecks(unittest.TestCase):
    def payload(self, action):
        return {"action": action, "profile": str(uuid.uuid4()),
                "bridge": base64.b64encode(b"print('bridge')").decode(),
                "config": {"container": "driver", "setup": "source /opt/ros/jazzy/setup.bash",
                           "environment": "{}", "udpPort": "50505"}}

    def test_runtime_arguments_do_not_interpret_container_or_environment_as_shell(self):
        args = manager.runtime_command("driver; bad", "echo ok", {"ROS_DOMAIN_ID": "$(bad)"})
        self.assertEqual(args[:5], ["docker", "exec", "-e", "ROS_DOMAIN_ID=$(bad)", "driver; bad"])

    def test_debug_samples_without_installing_or_stopping_containers(self):
        payload = self.payload("debug")
        payload["debugScript"] = base64.b64encode(b"print('sample')").decode()
        payload["debugConfig"] = {"namespace": "autonohm/sml_bot", "driveTopic": "/autonohm/sml_bot/cmd_vel", "driveType": "geometry_msgs/msg/Twist"}
        calls = []
        def fake_run(args, timeout=25):
            calls.append(args)
            if args[:2] == ["docker", "ps"]:
                return "driver: Up\n"
            return 'EDUKART_RESULT={"drive":{"count":20,"nonzeroCount":10},"joy":{"count":0}}'
        with patch.object(manager, "run", fake_run), patch.object(manager.shutil, "which", return_value="docker"):
            result = manager.main(payload)
        self.assertEqual(result["drive"]["nonzeroCount"], 10)
        self.assertTrue(all(args[:2] in (["docker", "exec"], ["docker", "ps"]) for args in calls))
        self.assertFalse(any("stop" in args or "cp" in args or "restart" in args for args in calls))

    def test_discovery_is_read_only_and_returns_visible_drive(self):
        graph = {"topics": [{"name": "/sml/cmd_vel", "types": ["geometry_msgs/msg/Twist"], "subscribers": 1}]}
        calls = []
        def fake_run(args, timeout=25):
            calls.append(args)
            if args[:2] == ["docker", "ps"]:
                return "driver\njoy\n"
            return "EDUKART_RESULT=" + json.dumps(graph)
        with patch.object(manager, "run", fake_run), patch.object(manager.shutil, "which", return_value="docker"):
            result = manager.main(self.payload("discover"))
        self.assertEqual(result["container"], "driver")
        self.assertFalse(any("cp" in args or "-d" in args for args in calls))
        self.assertIn("--discover", calls[-1][-1])

    def test_discovery_falls_back_from_missing_container(self):
        graph = {"topics": [{"types": ["geometry_msgs/msg/Twist"], "subscribers": 1}]}
        def fake_run(args, timeout=25):
            if args[:2] == ["docker", "ps"]:
                return "working\n"
            if "driver" in args:
                raise RuntimeError("No such container")
            return "EDUKART_RESULT=" + json.dumps(graph)
        with patch.object(manager, "run", fake_run), patch.object(manager.shutil, "which", return_value="docker"):
            result = manager.main(self.payload("discover"))
        self.assertEqual(result["container"], "working")
        self.assertTrue(result["warnings"])

    def test_install_stores_exact_bundled_script_without_starting(self):
        payload = self.payload("install")
        calls = []
        def fake_run(args, timeout=25):
            calls.append(args)
            return "host\n" if args[:2] == ["docker", "inspect"] else ""
        with tempfile.TemporaryDirectory() as home, patch.object(manager.Path, "home", return_value=Path(home)), patch.object(manager, "run", fake_run):
            result = manager.main(payload)
            self.assertEqual(Path(result["path"]).read_bytes(), b"print('bridge')")
        self.assertTrue(any(args[:2] == ["docker", "cp"] for args in calls))
        self.assertFalse(any("-d" in args for args in calls))

    def test_start_requires_installation(self):
        with tempfile.TemporaryDirectory() as home, patch.object(manager.Path, "home", return_value=Path(home)), patch.object(manager, "run", return_value="host\n"):
            with self.assertRaisesRegex(RuntimeError, "install ROSbridge"):
                manager.main(self.payload("start"))

    def test_start_is_idempotent_and_rejects_foreign_bridge(self):
        payload = self.payload("install")
        with tempfile.TemporaryDirectory() as home, patch.object(manager.Path, "home", return_value=Path(home)), patch.object(manager, "run", return_value="host\n"):
            manager.main(payload)
            payload["action"] = "start"
            instance = payload["profile"] + ":" + manager.hashlib.sha256(b"print('bridge')").hexdigest()[:12]
            with patch.object(manager, "probe", return_value={"version": 2, "instance": instance}):
                self.assertIn("bereits", manager.main(payload)["message"])
            with patch.object(manager, "probe", return_value={"version": 2, "instance": "other"}):
                with self.assertRaisesRegex(RuntimeError, "andere.*Bridge"):
                    manager.main(payload)

    def test_rejects_non_host_container_network(self):
        with patch.object(manager, "run", return_value="bridge\n"):
            with self.assertRaisesRegex(RuntimeError, "host networking"):
                manager.main(self.payload("install"))

    def test_start_after_container_restart_copies_script_and_checks_health(self):
        payload = self.payload("install")
        calls = []
        def fake_run(args, timeout=25):
            calls.append(args)
            return "host\n" if args[:2] == ["docker", "inspect"] else ""
        with tempfile.TemporaryDirectory() as home, patch.object(manager.Path, "home", return_value=Path(home)), patch.object(manager, "run", fake_run):
            manager.main(payload)
            calls.clear()
            payload["action"] = "start"
            instance = payload["profile"] + ":" + manager.hashlib.sha256(b"print('bridge')").hexdigest()[:12]
            with patch.object(manager, "probe", side_effect=[None, {"instance": instance}]), patch.object(manager.socket, "socket"):
                self.assertIn("gestartet", manager.main(payload)["message"])
        self.assertTrue(any(args[:2] == ["docker", "cp"] for args in calls))
        starts = [args for args in calls if args[:3] == ["docker", "exec", "-d"]]
        self.assertEqual(len(starts), 1)
        self.assertIn("--port 50505", starts[0][-1])
        self.assertFalse(any("restart" in args for args in calls))


class FakeNode:
    def __init__(self, name):
        pass

    def create_timer(self, *args):
        pass


class ProtocolChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        modules = {
            "rclpy": types.ModuleType("rclpy"),
            "rclpy.node": types.SimpleNamespace(Node=FakeNode),
            "rosidl_runtime_py": types.ModuleType("rosidl_runtime_py"),
            "rosidl_runtime_py.utilities": types.SimpleNamespace(get_message=Mock(), get_service=Mock()),
            "rosidl_runtime_py.set_message": types.SimpleNamespace(set_message_fields=Mock()),
            "rosidl_runtime_py.convert": types.SimpleNamespace(message_to_ordereddict=Mock())
        }
        with patch.dict(sys.modules, modules):
            cls.module = load("bridge", ROOT / "EdukARt/edukart_bridge_v2.py")

    def setUp(self):
        self.bridge = self.module.Bridge(0, "check-instance")
        self.client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.client.settimeout(1)
        self.address = ("127.0.0.1", self.bridge.socket.getsockname()[1])

    def tearDown(self):
        self.client.close()
        self.bridge.socket.close()

    def exchange(self, raw):
        self.client.sendto(raw, self.address)
        self.assertTrue(select.select([self.bridge.socket], [], [], 1)[0])
        self.bridge.poll()
        return json.loads(self.client.recv(60000))

    def test_health_has_version_and_instance(self):
        result = self.exchange(b'{"kind":"health","id":"1"}')
        self.assertEqual(result, {"id": "1", "ok": True, "version": 2, "instance": "check-instance"})

    def test_malformed_packets_do_not_kill_bridge(self):
        for raw in (b"not JSON", b"[]", b"null", b'{"kind":"unknown"}', b'{"topic":"missing type"}'):
            self.assertFalse(self.exchange(raw)["ok"])
        self.assertTrue(self.exchange(b'{"kind":"health"}')["ok"])

    def test_health_does_not_publish_or_call_services(self):
        self.exchange(b'{"kind":"health"}')
        self.assertEqual(self.bridge.publishers_by_type, {})
        self.assertEqual(self.bridge.clients_by_type, {})

    def test_generic_publisher_uses_supplied_type_topic_and_fields(self):
        publisher = Mock()
        self.bridge.create_publisher = Mock(return_value=publisher)
        message = object()
        packet = {"id": "publish", "kind": "publish", "topic": "/custom/drive",
                  "messageType": "custom_msgs/msg/Drive", "message": {"speed": 0.4}}
        with patch.object(self.module, "get_message", return_value=lambda: message), patch.object(self.module, "set_message_fields") as fill:
            self.assertTrue(self.exchange(json.dumps(packet).encode())["ok"])
            fill.assert_called_once_with(message, {"speed": 0.4})
        self.bridge.create_publisher.assert_called_once_with(type(message), "/custom/drive", 10)
        publisher.publish.assert_called_once_with(message)


if __name__ == "__main__":
    unittest.main()
