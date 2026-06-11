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
                        FindPackageShare("edge_reliability_processor"),
                        "config",
                        "processor.yaml",
                    ]
                ),
            ),
            Node(
                package="edge_reliability_processor",
                executable="sensor_processor",
                name="sensor_processor",
                output="screen",
                parameters=[config_file],
            ),
        ]
    )
