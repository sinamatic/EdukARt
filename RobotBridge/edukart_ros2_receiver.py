#!/usr/bin/env python3
"""
Receives EdukARt UDP remote-control packets and publishes ROS 2 drive commands.

Default input:
    UDP JSON packets on 0.0.0.0:50505

Default output:
    geometry_msgs/msg/Twist on /cmd_vel

Optional enable output:
    std_msgs/msg/Bool on the topic configured with --enable-topic
"""

import argparse
import json
import socket
import time

import rclpy
from geometry_msgs.msg import Twist
from rclpy.node import Node
from std_msgs.msg import Bool


class EdukARTROS2Receiver(Node):
    def __init__(self, args):
        super().__init__("edukart_ros2_receiver")

        self.cmd_vel_topic = args.cmd_vel_topic
        self.enable_topic = args.enable_topic
        self.max_linear_speed = args.max_linear_speed
        self.max_angular_speed = args.max_angular_speed
        self.deadman_timeout = args.deadman_timeout
        self.invert_x = args.invert_x
        self.invert_y = args.invert_y
        self.invert_rotation = args.invert_rotation

        self.cmd_vel_publisher = self.create_publisher(Twist, self.cmd_vel_topic, 10)
        self.enable_publisher = None
        if self.enable_topic:
            self.enable_publisher = self.create_publisher(Bool, self.enable_topic, 10)

        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.setblocking(False)
        self.socket.bind((args.host, args.port))

        self.last_packet_time = time.monotonic()
        self.last_command_was_stop = True
        self.timer = self.create_timer(0.02, self.poll_socket)

        self.get_logger().info(
            f"Listening on udp://{args.host}:{args.port}, publishing Twist to {self.cmd_vel_topic}"
        )
        if self.enable_topic:
            self.get_logger().info(f"Publishing enable Bool to {self.enable_topic}")
        else:
            self.get_logger().info("No enable topic configured. Enable packets will only be logged.")

    def poll_socket(self):
        received_packet = False

        while True:
            try:
                data, _ = self.socket.recvfrom(4096)
            except BlockingIOError:
                break

            received_packet = True
            self.last_packet_time = time.monotonic()
            self.handle_packet(data)

        if not received_packet and time.monotonic() - self.last_packet_time > self.deadman_timeout:
            self.publish_stop_once()

    def handle_packet(self, data):
        try:
            packet = json.loads(data.decode("utf-8").strip())
        except json.JSONDecodeError as error:
            self.get_logger().warning(f"Ignoring invalid JSON packet: {error}")
            return

        command_type = packet.get("type")

        if command_type == "drive":
            self.publish_drive(packet)
        elif command_type == "enable":
            self.publish_enable()
        elif command_type == "stop":
            self.publish_stop_once(force=True)
        else:
            self.get_logger().warning(f"Ignoring unknown command type: {command_type}")

    def publish_drive(self, packet):
        x = self.read_axis(packet, "x", self.invert_x)
        y = self.read_axis(packet, "y", self.invert_y)
        rotation = self.read_axis(packet, "rotation", self.invert_rotation)

        message = Twist()
        message.linear.x = float(y * self.max_linear_speed)
        message.linear.y = float(x * self.max_linear_speed)
        message.angular.z = float(rotation * self.max_angular_speed)

        self.cmd_vel_publisher.publish(message)
        self.last_command_was_stop = False

    def publish_enable(self):
        if self.enable_publisher is None:
            self.get_logger().info("Enable received, but no --enable-topic is configured.")
            return

        message = Bool()
        message.data = True
        self.enable_publisher.publish(message)
        self.get_logger().info("Enable published.")

    def publish_stop_once(self, force=False):
        if self.last_command_was_stop and not force:
            return

        self.cmd_vel_publisher.publish(Twist())
        self.last_command_was_stop = True

    @staticmethod
    def read_axis(packet, key, is_inverted):
        value = float(packet.get(key, 0.0))
        value = max(min(value, 1.0), -1.0)
        return -value if is_inverted else value


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=50505)
    parser.add_argument("--cmd-vel-topic", default="/cmd_vel")
    parser.add_argument("--enable-topic", default="")
    parser.add_argument("--max-linear-speed", type=float, default=0.25)
    parser.add_argument("--max-angular-speed", type=float, default=1.2)
    parser.add_argument("--deadman-timeout", type=float, default=0.3)
    parser.add_argument("--invert-x", action="store_true")
    parser.add_argument("--invert-y", action="store_true")
    parser.add_argument("--invert-rotation", action="store_true")
    return parser.parse_args()


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
