from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    config_file = LaunchConfiguration("config_file")

    return LaunchDescription(
        [
            DeclareLaunchArgument(
                "config_file",
                default_value=PathJoinSubstitution(
                    [
                        FindPackageShare("edge_reliability_health"),
                        "config",
                        "health_monitor.yaml",
                    ]
                ),
                description="YAML parameter file for health_monitor",
            ),
            Node(
                package="edge_reliability_health",
                executable="health_monitor",
                name="health_monitor",
                output="screen",
                parameters=[config_file],
            ),
        ]
    )
