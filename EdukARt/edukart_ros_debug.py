"""Read-only ROS sampling for the in-app remote-control diagnostics."""
import base64
import json
import sys
import time
import uuid

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, DurabilityPolicy
from rosidl_runtime_py.utilities import get_message
from rosidl_runtime_py.convert import message_to_ordereddict


def contains_nonzero(value):
    if isinstance(value, dict):
        return any(contains_nonzero(item) for item in value.values())
    if isinstance(value, (list, tuple)):
        return any(contains_nonzero(item) for item in value)
    return isinstance(value, (int, float)) and not isinstance(value, bool) and abs(value) > 1e-8


def sample(config):
    rclpy.init()
    node = Node("edukart_debug_" + uuid.uuid4().hex[:8])
    namespace = "/" + config["namespace"].strip("/")
    namespace = namespace.rstrip("/")
    topics = {
        "drive": (config["driveTopic"], config["driveType"]),
        "joy": (namespace + "/joy", "sensor_msgs/msg/Joy"),
        "enabled": (namespace + "/enabled", "std_msgs/msg/ByteMultiArray"),
        "rpm": (namespace + "/rpm", "std_msgs/msg/Float32MultiArray"),
    }
    report = {key: {"topic": name, "type": typename, "count": 0, "nonzeroCount": 0}
              for key, (name, typename) in topics.items()}
    subscriptions = []
    qos = QoSProfile(depth=10, reliability=ReliabilityPolicy.BEST_EFFORT,
                     durability=DurabilityPolicy.VOLATILE)

    def receive(key, message):
        value = message_to_ordereddict(message)
        record = report[key]
        record["count"] += 1
        record["last"] = value
        # Ignore stamped-message timestamps when classifying movement.
        movement = value.get("twist", value) if key == "drive" else value
        if key == "drive":
            movement = {field: movement[field] for field in ("linear", "angular") if field in movement}
        if contains_nonzero(movement):
            record["nonzeroCount"] += 1
            record["lastNonzero"] = value

    try:
        for key, (name, typename) in topics.items():
            try:
                subscriptions.append(node.create_subscription(get_message(typename), name,
                    lambda message, key=key: receive(key, message), qos))
            except Exception as error:
                report[key]["error"] = str(error)
        end = time.monotonic() + 12
        while time.monotonic() < end:
            rclpy.spin_once(node, timeout_sec=0.1)
        for key, (name, _) in topics.items():
            def endpoints(items):
                return [{"node": item.node_namespace.rstrip("/") + "/" + item.node_name,
                         "type": item.topic_type, "qos": str(item.qos_profile)} for item in items]
            report[key]["publishers"] = endpoints(node.get_publishers_info_by_topic(name))
            report[key]["subscribers"] = endpoints(node.get_subscriptions_info_by_topic(name))
        report["durationSeconds"] = 12
        report["note"] = "Nur gelesen; keine Fahrbefehle, Services oder Container-Änderungen ausgeführt."
        return report
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    config = json.loads(base64.b64decode(sys.argv[1]))
    print("EDUKART_RESULT=" + json.dumps(sample(config)), flush=True)
