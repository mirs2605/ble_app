#!/usr/bin/env python3
import rclpy
from geometry_msgs.msg import PolygonStamped
from nav_msgs.msg import Path
from opennav_coverage_msgs.action import ComputeCoveragePath
from opennav_coverage_msgs.msg import Coordinate, Coordinates
from rclpy.action import ActionClient
from rclpy.node import Node
from std_msgs.msg import String


class CoveragePreview(Node):
    """Convert the app's zone topic to an OpenNav path planning request."""

    def __init__(self):
        super().__init__('mirs_coverage_preview')
        self.declare_parameter('zone_topic', '/cleaning_zone')
        self.declare_parameter('action_name', '/compute_coverage_path')
        self.declare_parameter('path_topic', '/coverage/path')
        self.declare_parameter('state_topic', '/coverage/state')
        self._client = ActionClient(
            self, ComputeCoveragePath, self.get_parameter('action_name').value)
        self._path_pub = self.create_publisher(
            Path, self.get_parameter('path_topic').value, 10)
        self._state_pub = self.create_publisher(
            String, self.get_parameter('state_topic').value, 10)
        self._subscription = self.create_subscription(
            PolygonStamped, self.get_parameter('zone_topic').value,
            self._on_zone, 10)
        self._busy = False

    def _publish_state(self, message):
        state = String()
        state.data = message
        self._state_pub.publish(state)
        self.get_logger().info(message)

    def _on_zone(self, polygon_msg):
        if self._busy:
            self._publish_state('計画要求を処理中です。次の範囲は保留されました。')
            return
        if len(polygon_msg.polygon.points) < 3:
            self._publish_state('清掃範囲に3点以上必要です。')
            return
        if not self._client.wait_for_server(timeout_sec=0.2):
            self._publish_state(
                'OpenNav Coverage action serverが見つかりません '
                '(/compute_coverage_path)。')
            return

        coordinates = Coordinates()
        for point in polygon_msg.polygon.points:
            coordinate = Coordinate()
            coordinate.axis1 = float(point.x)
            coordinate.axis2 = float(point.y)
            coordinates.coordinates.append(coordinate)

        goal = ComputeCoveragePath.Goal()
        goal.polygons = [coordinates]
        goal.frame_id = polygon_msg.header.frame_id or 'map'
        goal.use_gml_file = False
        goal.generate_path = True
        goal.generate_route = True
        goal.generate_headland = True
        self._busy = True
        self._publish_state('範囲を受信しました。カバレッジ経路を計算しています。')
        self._client.send_goal_async(goal).add_done_callback(self._goal_response)

    def _goal_response(self, future):
        try:
            goal_handle = future.result()
            if not goal_handle.accepted:
                self._busy = False
                self._publish_state('OpenNav Coverageが計画要求を拒否しました。')
                return
            goal_handle.get_result_async().add_done_callback(self._result)
        except Exception as error:  # report ROS action transport errors in the UI
            self._busy = False
            self._publish_state(f'計画要求エラー: {error}')

    def _result(self, future):
        self._busy = False
        try:
            result = future.result().result
            if result.error_code != 0 or not result.nav_path.poses:
                self._publish_state(
                    f'経路を計算できませんでした (error_code={result.error_code})。')
                return
            self._path_pub.publish(result.nav_path)
            self._publish_state(
                f'経路を計算しました。点数: {len(result.nav_path.poses)} '
                '(/coverage/path)。')
        except Exception as error:
            self._publish_state(f'計画結果の取得エラー: {error}')


def main(args=None):
    rclpy.init(args=args)
    node = CoveragePreview()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
