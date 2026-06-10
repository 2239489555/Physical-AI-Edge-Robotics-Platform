import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    config_file = LaunchConfiguration("config_file")
    default_config = os.path.join(
        get_package_share_directory("edge_reliability_fake_sensor"),
        "config",
        "fake_sensor.yaml",
    )

    return LaunchDescription([
        DeclareLaunchArgument(
            "config_file",
            default_value=default_config,
            description="YAML parameter file for fake_sensor_adapter",
        ),
        Node(
            package="edge_reliability_fake_sensor",
            executable="fake_sensor_adapter",
            name="fake_sensor_adapter",
            output="screen",
            parameters=[config_file],
        ),
    ])
