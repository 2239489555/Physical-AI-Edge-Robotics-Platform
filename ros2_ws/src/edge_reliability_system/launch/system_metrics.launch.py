from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    config_file = LaunchConfiguration("config_file")
    sample_file = LaunchConfiguration("sample_file")
    raw_log_path = LaunchConfiguration("raw_log_path")
    disk_path = LaunchConfiguration("disk_path")

    return LaunchDescription(
        [
            DeclareLaunchArgument(
                "config_file",
                default_value=PathJoinSubstitution(
                    [
                        FindPackageShare("edge_reliability_system"),
                        "config",
                        "system_metrics.yaml",
                    ]
                ),
                description="YAML parameter file for system_metrics_node",
            ),
            DeclareLaunchArgument(
                "sample_file",
                default_value=PathJoinSubstitution(
                    [
                        FindPackageShare("edge_reliability_system"),
                        "testdata",
                        "tegrastats_samples.txt",
                    ]
                ),
                description="Saved tegrastats sample file for sample_file input mode",
            ),
            DeclareLaunchArgument(
                "raw_log_path",
                default_value="../runtime/logs/tegrastats/system_metrics_node_raw.log",
                description="Project-local raw tegrastats log path",
            ),
            DeclareLaunchArgument(
                "disk_path",
                default_value="/",
                description="Filesystem path used for disk usage metrics",
            ),
            Node(
                package="edge_reliability_system",
                executable="system_metrics_node",
                name="system_metrics_node",
                output="screen",
                parameters=[
                    config_file,
                    {
                        "sample_file": sample_file,
                        "raw_log_path": raw_log_path,
                        "disk_path": disk_path,
                    },
                ],
            ),
        ]
    )
