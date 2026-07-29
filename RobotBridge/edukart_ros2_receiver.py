#!/usr/bin/env python3
"""
Small EdukARt iPhone -> ROS 2 UDP bridge.

Stable UDP packet format from the app:
    {"type":"drive", "x":0.0, "y":-1.0, "rotation":0.0}
    {"type":"enable"}
    {"type":"stop"}
    {"type":"mecanum"}
    {"type":"offroad"}

The bridge keeps robot-specific ROS wiring in startup arguments. For robots that
accept geometry_msgs/Twist, the iPhone app should not need code changes when
topics or namespaces change.
"""

from __future__ import annotations

import argparse
import json
import socket
import time
from dataclasses import dataclass
from typing import Iterable

import rclpy
from geometry_msgs.msg import Twist
from rclpy.node import Node

try:
    from edu_robot.msg import SetLightingColor
    from edu_robot.srv import SetMode
except ImportError:
    SetLightingColor = None
    SetMode = None


DEFAULT_DRIVE_TOPICS = [
    "/eduard/blue3/cmd_vel",
    "/eduard/blue/autonomous/cmd_vel",
]
DEFAULT_SET_MODE_SERVICES = [
    "/eduard/blue3/set_mode",
    "/eduard/blue/set_mode",
]
DEFAULT_LIGHT_TOPICS = [
    "/eduard/blue3/set_lighting_color",
    "/eduard/blue/set_lighting_color",
]

UDP_PORT = 50505
MODE_AUTONOMOUS = 4


@dataclass(frozen=True)
class DriveConfig:
    max_forward_speed: float
    max_strafe_speed: float
    max_rotation_speed: float
    deadzone: float
    forward_sign: float
    strafe_sign: float
    rotation_sign: float


class LightModeController:
    """Stores reusable Eduard light patterns and publishes them when enabled."""

    MODE_OFF = 0
    MODE_DIM = 1
    MODE_FLASH = 2
    MODE_PULSATION = 3
    MODE_ROTATION = 4
    MODE_RUNNING = 5

    def __init__(self, node: Node, topics: Iterable[str], enabled: bool):
        self.node = node
        self.enabled = enabled and SetLightingColor is not None
        self.publishers = [
            node.create_publisher(SetLightingColor, topic, 10)
            for topic in topics
        ] if self.enabled else []

        if enabled and SetLightingColor is None:
            node.get_logger().warning("edu_robot is not installed; light commands are disabled.")

    def enabled_pattern(self):
        if not self.enabled:
            return

        self._send("all", 0, 255, 0, 100, self.MODE_FLASH)
        self.node.create_timer(0.45, self._enabled_cruise_lights_once)

    def stopped_pattern(self):
        if not self.enabled:
            return

        self._send("all", 255, 0, 0, 100, self.MODE_DIM)

    def _enabled_cruise_lights_once(self):
        self._send("front", 255, 255, 255, 100, self.MODE_DIM)
        self._send("rear", 255, 0, 0, 100, self.MODE_DIM)

    def _send(self, lighting_name: str, r: int, g: int, b: int, brightness: float, mode: int):
        message = SetLightingColor()
        message.lighting_name = lighting_name
        message.r = r
        message.g = g
        message.b = b
        message.brightness.data = brightness
        message.mode = mode

        for publisher in self.publishers:
            publisher.publish(message)


class EdukARTROS2Receiver(Node):
    def __init__(self, args):
        super().__init__("edukart_ros2_receiver")

        self.log_packets = args.log_packets
        self.deadman_timeout = args.deadman_timeout
        self.last_packet_time = time.monotonic()
        self.last_command_was_stop = True
        self.packet_count = 0

        self.drive_config = DriveConfig(
            max_forward_speed=args.max_forward_speed,
            max_strafe_speed=args.max_strafe_speed,
            max_rotation_speed=args.max_rotation_speed,
            deadzone=args.deadzone,
            forward_sign=args.forward_sign,
            strafe_sign=args.strafe_sign,
            rotation_sign=args.rotation_sign,
        )

        self.cmd_vel_publishers = [
            self.create_publisher(Twist, topic, 10)
            for topic in args.drive_topic
        ]
        self.set_mode_clients = self._make_set_mode_clients(args.set_mode_service)
        self.light_modes = LightModeController(self, args.light_topic, args.enable_lights)

        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.setblocking(False)
        self.socket.bind((args.host, args.port))

        self.timer = self.create_timer(0.02, self.poll_socket)

        self.get_logger().info(f"Listening on udp://{args.host}:{args.port}")
        self.get_logger().info(f"Drive topics: {', '.join(args.drive_topic)}")
        if self.set_mode_clients:
            self.get_logger().info(f"SetMode services: {', '.join(args.set_mode_service)}")
        else:
            self.get_logger().info("SetMode disabled; drive commands still publish as Twist.")

    def _make_set_mode_clients(self, services: list[str]):
        if SetMode is None:
            self.get_logger().warning("edu_robot is not installed; SetMode is disabled.")
            return []

        return [self.create_client(SetMode, service) for service in services]

    def poll_socket(self):
        received_packet = False

        while True:
            try:
                data, sender = self.socket.recvfrom(4096)
            except BlockingIOError:
                break

            received_packet = True
            self.packet_count += 1
            self.last_packet_time = time.monotonic()
            self.handle_packet(data, sender)

        if not received_packet and time.monotonic() - self.last_packet_time > self.deadman_timeout:
            self.publish_stop_once()

    def handle_packet(self, data: bytes, sender):
        try:
            packet = json.loads(data.decode("utf-8").strip())
        except json.JSONDecodeError as error:
            self.get_logger().warning(f"Ignoring invalid JSON packet: {error}")
            return

        command_type = packet.get("type")
        if self.log_packets or command_type in ("enable", "stop", "mecanum", "offroad"):
            self.get_logger().info(f"Packet #{self.packet_count} from {sender[0]}:{sender[1]}: {packet}")

        if command_type == "drive":
            self.publish_drive(packet)
        elif command_type == "enable":
            self.enable_robot()
        elif command_type == "stop":
            self.stop_robot()
        elif command_type in ("mecanum", "offroad"):
            self.select_drive_mode(command_type)
        else:
            self.get_logger().warning(f"Ignoring unknown command type: {command_type}")

    def publish_drive(self, packet):
        x = self.apply_deadzone(float(packet.get("x", 0.0)))
        y = self.apply_deadzone(float(packet.get("y", 0.0)))
        rotation = self.apply_deadzone(float(packet.get("rotation", 0.0)))

        message = Twist()
        message.linear.x = self.drive_config.forward_sign * y * self.drive_config.max_forward_speed
        message.linear.y = self.drive_config.strafe_sign * x * self.drive_config.max_strafe_speed
        message.angular.z = self.drive_config.rotation_sign * rotation * self.drive_config.max_rotation_speed

        self.publish_twist(message)
        self.last_command_was_stop = False

    def enable_robot(self):
        self.call_set_mode(MODE_AUTONOMOUS)
        self.light_modes.enabled_pattern()
        self.get_logger().info("Enable requested.")

    def select_drive_mode(self, mode_name: str):
        self.call_set_mode(MODE_AUTONOMOUS)
        self.get_logger().info(f"{mode_name} selected; Twist mapping remains controlled by the iPhone app.")

    def stop_robot(self):
        self.publish_stop_once(force=True)
        self.light_modes.stopped_pattern()
        self.get_logger().info("Stop requested.")

    def publish_stop_once(self, force=False):
        if self.last_command_was_stop and not force:
            return

        self.publish_twist(Twist())
        self.last_command_was_stop = True

    def publish_twist(self, message: Twist):
        for publisher in self.cmd_vel_publishers:
            publisher.publish(message)

    def call_set_mode(self, mode: int):
        for client in self.set_mode_clients:
            if not client.service_is_ready():
                client.wait_for_service(timeout_sec=0.1)

            if not client.service_is_ready():
                self.get_logger().warning(f"SetMode service not ready: {client.srv_name}")
                continue

            request = SetMode.Request()
            request.mode.mode = mode
            future = client.call_async(request)
            future.add_done_callback(self.log_set_mode_result)

    def log_set_mode_result(self, future):
        try:
            response = future.result()
        except Exception as error:
            self.get_logger().warning(f"SetMode failed: {error}")
            return

        self.get_logger().info(f"SetMode response: {response}")

    def apply_deadzone(self, value):
        value = max(min(value, 1.0), -1.0)
        return 0.0 if abs(value) < self.drive_config.deadzone else value


def parse_csv(values: list[str] | None, default_values: list[str]) -> list[str]:
    if not values:
        return default_values

    parsed = []
    for value in values:
        parsed.extend(part.strip() for part in value.split(",") if part.strip())
    return parsed


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=UDP_PORT)
    parser.add_argument("--drive-topic", action="append")
    parser.add_argument("--set-mode-service", action="append")
    parser.add_argument("--light-topic", action="append")
    parser.add_argument("--enable-lights", action="store_true")
    parser.add_argument("--max-forward-speed", type=float, default=0.20)
    parser.add_argument("--max-strafe-speed", type=float, default=0.20)
    parser.add_argument("--max-rotation-speed", type=float, default=1.00)
    parser.add_argument("--deadzone", type=float, default=0.06)
    parser.add_argument("--deadman-timeout", type=float, default=0.30)
    parser.add_argument("--forward-sign", type=float, choices=(-1.0, 1.0), default=-1.0)
    parser.add_argument("--strafe-sign", type=float, choices=(-1.0, 1.0), default=-1.0)
    parser.add_argument("--rotation-sign", type=float, choices=(-1.0, 1.0), default=-1.0)
    parser.add_argument("--log-packets", action="store_true")

    args = parser.parse_args()
    args.drive_topic = parse_csv(args.drive_topic, DEFAULT_DRIVE_TOPICS)
    args.set_mode_service = parse_csv(args.set_mode_service, DEFAULT_SET_MODE_SERVICES)
    args.light_topic = parse_csv(args.light_topic, DEFAULT_LIGHT_TOPICS)
    return args


def main():
    args = parse_args()
    rclpy.init()
    node = EdukARTROS2Receiver(args)

    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.publish_stop_once(force=True)
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
