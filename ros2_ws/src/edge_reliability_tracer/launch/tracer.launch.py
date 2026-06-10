import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    config_file = LaunchConfiguration("config_file")
    default_config = os.path.join(
        get_package_share_directory("edge_reliability_tracer"),
        "config",
        "tracer.yaml",
    )

    return LaunchDescription([
        DeclareLaunchArgument(
            "config_file",
            default_value=default_config,
            description="YAML parameter file for tracer publisher and subscriber",
        ),
        Node(
            package="edge_reliability_tracer",
            executable="tracer_publisher",
            name="tracer_publisher",
            output="screen",
            parameters=[config_file],
        ),
        Node(
            package="edge_reliability_tracer",
            executable="tracer_subscriber",
            name="tracer_subscriber",
            output="screen",
            parameters=[config_file],
        ),
    ])
