import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch_ros.actions import ComposableNodeContainer, Node
from launch_ros.descriptions import ComposableNode


def generate_launch_description():
    share = get_package_share_directory('mirs_pc_viewer')
    params = os.path.join(share, 'config', 'coverage_server.yaml')
    coverage_container = ComposableNodeContainer(
        name='mirs_coverage_container',
        namespace='',
        package='rclcpp_components',
        executable='component_container_isolated',
        composable_node_descriptions=[
            ComposableNode(
                package='opennav_coverage',
                plugin='opennav_coverage::CoverageServer',
                name='coverage_server',
                parameters=[params],
            ),
            ComposableNode(
                package='nav2_lifecycle_manager',
                plugin='nav2_lifecycle_manager::LifecycleManager',
                name='lifecycle_manager_coverage',
                parameters=[{
                    'autostart': True,
                    'node_names': ['coverage_server'],
                    'bond_timeout': 0.0,
                }],
            ),
        ],
        output='screen',
    )
    return LaunchDescription([
        coverage_container,
        Node(
            package='mirs_pc_viewer',
            executable='http_gateway',
            output='screen',
        ),
        Node(
            package='mirs_pc_viewer',
            executable='coverage_preview',
            output='screen',
        ),
        Node(
            package='rviz2',
            executable='rviz2',
            name='coverage_preview_rviz',
            arguments=['-d', os.path.join(share, 'rviz', 'coverage_preview.rviz')],
            output='screen',
        ),
    ])
