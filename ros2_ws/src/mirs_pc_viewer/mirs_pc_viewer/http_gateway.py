#!/usr/bin/env python3
import json
import math
import queue
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread

import rclpy
from geometry_msgs.msg import Point32, PolygonStamped
from rclpy.node import Node


class ZoneHandler(BaseHTTPRequestHandler):
    """HTTP endpoint used by the Android app through `adb reverse`."""

    def do_POST(self):
        if self.path != '/cleaning_zone':
            self._reply(404, {'error': 'unknown endpoint'})
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if length <= 0 or length > 1_000_000:
                raise ValueError('invalid Content-Length')
            payload = json.loads(self.rfile.read(length))
            if payload.get('type') != 'cleaning_zone':
                raise ValueError('type must be cleaning_zone')
            frame_id = payload.get('frame_id', 'map')
            vertices = payload.get('polygon')
            if not isinstance(frame_id, str) or not frame_id:
                raise ValueError('frame_id must be a non-empty string')
            if not isinstance(vertices, list) or len(vertices) < 3 or len(vertices) > 1000:
                raise ValueError('polygon must contain 3 to 1000 points')
            points = []
            for vertex in vertices:
                x, y = float(vertex['x']), float(vertex['y'])
                if not math.isfinite(x) or not math.isfinite(y) or abs(x) > 1000 or abs(y) > 1000:
                    raise ValueError('point coordinates must be finite and within +/-1000 m')
                points.append((x, y))
            self.server.zone_queue.put((frame_id, points))
            self._reply(202, {'status': 'accepted', 'points': len(points)})
        except (ValueError, TypeError, KeyError, json.JSONDecodeError) as error:
            self._reply(400, {'error': str(error)})

    def _reply(self, status, body):
        encoded = json.dumps(body).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, fmt, *args):
        # Route the standard HTTP access log through ROS instead of stderr.
        self.server.node.get_logger().info(fmt % args)


class HttpGateway(Node):
    def __init__(self):
        super().__init__('mirs_http_gateway')
        self.declare_parameter('host', '0.0.0.0')
        self.declare_parameter('port', 8765)
        self.declare_parameter('zone_topic', '/cleaning_zone')
        self._publisher = self.create_publisher(
            PolygonStamped, self.get_parameter('zone_topic').value, 10)
        self._queue = queue.Queue()
        host = self.get_parameter('host').value
        port = int(self.get_parameter('port').value)
        self._server = ThreadingHTTPServer((host, port), ZoneHandler)
        self._server.daemon_threads = True
        self._server.zone_queue = self._queue
        self._server.node = self
        self._thread = Thread(target=self._server.serve_forever, daemon=True)
        self._thread.start()
        self._timer = self.create_timer(0.05, self._publish_pending)
        self.get_logger().info(f'Phone simulation gateway listening on {host}:{port}')

    def _publish_pending(self):
        while True:
            try:
                frame_id, points = self._queue.get_nowait()
            except queue.Empty:
                return
            message = PolygonStamped()
            message.header.stamp = self.get_clock().now().to_msg()
            message.header.frame_id = frame_id
            message.polygon.points = [Point32(x=x, y=y, z=0.0) for x, y in points]
            self._publisher.publish(message)
            self.get_logger().info(f'Published {len(points)} cleaning-zone points to /cleaning_zone')

    def destroy_node(self):
        self._server.shutdown()
        self._server.server_close()
        return super().destroy_node()


def main(args=None):
    rclpy.init(args=args)
    node = HttpGateway()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
