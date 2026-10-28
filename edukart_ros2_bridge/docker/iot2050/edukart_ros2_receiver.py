#!/usr/bin/env python3
import importlib
import json
import socket

import rclpy
from rclpy.node import Node

UDP_PORT = 50505
ROBOT_NAME = "blue3"


class EdukARTROS2Receiver(Node):
    def __init__(self, robot_name):
        super().__init__("edukart_ros2_receiver")
        self.namespace = f"/eduard/{robot_name.strip('/')}/"
        self.topic_publishers = {}
        self.service_clients = {}
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.setblocking(False)
        self.socket.bind(("0.0.0.0", UDP_PORT))
        self.timer = self.create_timer(0.02, self.poll_socket)

    def poll_socket(self):
        while True:
            try:
                data, _ = self.socket.recvfrom(4096)
            except BlockingIOError:
                break

            packet = json.loads(data.decode("utf-8").strip())
            try:
                if packet.get("kind") == "service":
                    self.call_service(packet)
                else:
                    self.publish_message(packet)
            except (AttributeError, ImportError, KeyError, ValueError) as error:
                self.get_logger().warning(str(error))

    def publish_message(self, packet):
        topic = self.full_name(packet["topic"])
        message_type = packet["messageType"]
        message = self.make_message(message_type, packet["message"])
        self.get_logger().info(f"Publish {topic}")

        key = (topic, message_type)
        if key not in self.topic_publishers:
            self.topic_publishers[key] = self.create_publisher(type(message), topic, 10)

        self.topic_publishers[key].publish(message)

    def call_service(self, packet):
        service = self.full_name(packet["service"])
        service_type = packet["serviceType"]
        service_class = self.service_class(service_type)

        key = (service, service_type)
        if key not in self.service_clients:
            self.service_clients[key] = self.create_client(service_class, service)

        client = self.service_clients[key]
        if not client.service_is_ready():
            client.wait_for_service(timeout_sec=0.1)

        if not client.service_is_ready():
            self.get_logger().warning(f"Service not ready: {service}")
            return

        request = service_class.Request()
        self.fill_message(request, packet["request"])
        self.get_logger().info(f"Call {service}")
        client.call_async(request)

    def full_name(self, name):
        if name.startswith("/"):
            return name

        return self.namespace + name.strip("/")

    def make_message(self, message_type, values):
        package, _, name = message_type.partition("/msg/")
        module = importlib.import_module(f"{package}.msg")
        message = getattr(module, name)()
        self.fill_message(message, values)
        return message

    def service_class(self, service_type):
        package, _, name = service_type.partition("/srv/")
        module = importlib.import_module(f"{package}.srv")
        return getattr(module, name)

    def fill_message(self, message, values):
        for key, value in values.items():
            current = getattr(message, key)
            if isinstance(value, dict):
                self.fill_message(current, value)
            elif isinstance(current, float):
                setattr(message, key, float(value))
            elif isinstance(current, int):
                setattr(message, key, int(value))
            else:
                setattr(message, key, value)


def main():
    rclpy.init()
    node = EdukARTROS2Receiver(ROBOT_NAME)

    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
