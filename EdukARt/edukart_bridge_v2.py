#!/usr/bin/env python3
"""Offline ROS 2 JSON/UDP adapter. No robot-specific topics or interfaces."""
import argparse
import json
import os
import socket
import sys
import time
import uuid

import rclpy
from rclpy.node import Node
from rosidl_runtime_py.utilities import get_message, get_service
from rosidl_runtime_py.set_message import set_message_fields
from rosidl_runtime_py.convert import message_to_ordereddict

VERSION = 2


def discover(node):
    # Discovery takes time even when no ros2 CLI daemon is running.
    end = time.monotonic() + 4
    while time.monotonic() < end:
        rclpy.spin_once(node, timeout_sec=0.2)
    topics = []
    for name, types in node.get_topic_names_and_types():
        subscriptions = node.get_subscriptions_info_by_topic(name)
        topics.append({"name": name, "types": types, "subscribers": len(subscriptions),
                       "qos": [str(item.qos_profile) for item in subscriptions]})
    services = [{"name": name, "types": types}
                for name, types in node.get_service_names_and_types()]
    interfaces = {}
    for item in topics + services:
        for typename in item["types"]:
            try:
                cls = get_service(typename).Request if "/srv/" in typename else get_message(typename)
                interfaces[typename] = {"fields": cls.get_fields_and_field_types(),
                                        "defaults": message_to_ordereddict(cls())}
            except Exception as error:
                interfaces[typename] = {"error": str(error)}
    environment_keys = ("ROS_DOMAIN_ID", "RMW_IMPLEMENTATION", "ROS_LOCALHOST_ONLY",
                        "ROS_AUTOMATIC_DISCOVERY_RANGE", "ROS_STATIC_PEERS", "CYCLONEDDS_URI",
                        "FASTRTPS_DEFAULT_PROFILES_FILE", "FASTDDS_DEFAULT_PROFILES_FILE")
    return {"topics": topics, "services": services, "interfaces": interfaces,
            "environment": {key: os.environ[key] for key in environment_keys if key in os.environ},
            "rosDistribution": os.environ.get("ROS_DISTRO", ""), "python": sys.version,
            "nodes": [namespace.rstrip("/") + "/" + name
                      for name, namespace in node.get_node_names_and_namespaces()]}


class Bridge(Node):
    def __init__(self, port, instance):
        super().__init__("edukart_bridge_" + uuid.uuid4().hex[:8])
        self.instance = instance
        self.publishers_by_type = {}
        self.clients_by_type = {}
        self.pending = {}
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.bind(("0.0.0.0", port))
        self.socket.setblocking(False)
        self.create_timer(0.01, self.poll)
        self.create_timer(1, self.expire_requests)

    def reply(self, address, request_id, **values):
        try:
            self.socket.sendto(json.dumps({"id": request_id, **values}).encode(), address)
        except (OSError, TypeError):
            pass

    def poll(self):
        # Bound each tick so malformed/flooding clients cannot starve the ROS executor.
        for _ in range(64):
            try:
                raw, address = self.socket.recvfrom(60000)
            except BlockingIOError:
                return
            packet = {}
            try:
                packet = json.loads(raw)
                if not isinstance(packet, dict):
                    raise ValueError("Packet must be a JSON object")
                request_id = packet.get("id")
                kind = packet.get("kind", "publish")
                if kind == "health":
                    self.reply(address, request_id, ok=True, version=VERSION, instance=self.instance)
                elif kind == "service":
                    self.service(packet, address)
                elif kind == "publish":
                    key = (packet["topic"], packet["messageType"])
                    message = get_message(key[1])()
                    set_message_fields(message, packet["message"])
                    if key not in self.publishers_by_type:
                        if len(self.publishers_by_type) >= 128:
                            raise ValueError("Publisher limit reached")
                        self.publishers_by_type[key] = self.create_publisher(type(message), key[0], 10)
                    self.publishers_by_type[key].publish(message)
                    if request_id:
                        self.reply(address, request_id, ok=True)
                else:
                    raise ValueError("Unknown packet kind")
            except Exception as error:
                request_id = packet.get("id") if isinstance(packet, dict) else None
                self.reply(address, request_id, ok=False, error=str(error))

    def service(self, packet, address):
        if len(self.pending) >= 32:
            raise ValueError("Too many pending service calls")
        key = (packet["service"], packet["serviceType"])
        cls = get_service(key[1])
        request = cls.Request()
        set_message_fields(request, packet["request"])
        if key not in self.clients_by_type:
            if len(self.clients_by_type) >= 128:
                raise ValueError("Service client limit reached")
            self.clients_by_type[key] = self.create_client(cls, key[0])
        client = self.clients_by_type[key]
        if not client.service_is_ready():
            client.wait_for_service(timeout_sec=0.2)
        if not client.service_is_ready():
            raise ValueError("Service not ready: " + key[0])
        future = client.call_async(request)
        self.pending[future] = (time.monotonic() + 5, client, address, packet.get("id"))
        future.add_done_callback(self.service_done)

    def service_done(self, future):
        item = self.pending.pop(future, None)
        if item is None:
            return
        _, _, address, request_id = item
        try:
            self.reply(address, request_id, ok=True, response=message_to_ordereddict(future.result()))
        except Exception as error:
            self.reply(address, request_id, ok=False, error=str(error))

    def expire_requests(self):
        for future, item in list(self.pending.items()):
            deadline, client, address, request_id = item
            if time.monotonic() > deadline:
                self.pending.pop(future, None)
                client.remove_pending_request(future)
                self.reply(address, request_id, ok=False, error="Service response timeout")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--discover", action="store_true")
    parser.add_argument("--port", type=int, default=50505)
    parser.add_argument("--instance", default="edukart")
    args = parser.parse_args()
    rclpy.init()
    node = None
    try:
        if args.discover:
            node = Node("edukart_discovery_" + uuid.uuid4().hex[:8])
            print("EDUKART_RESULT=" + json.dumps(discover(node)), flush=True)
        else:
            node = Bridge(args.port, args.instance)
            rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        if isinstance(node, Bridge):
            node.socket.close()
        if node is not None:
            node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
