cmake_minimum_required(VERSION 3.8)
project(edge_reliability_fake_sensor)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(edge_reliability_msgs REQUIRED)

add_executable(fake_sensor_adapter src/fake_sensor_adapter.cpp)
target_compile_features(fake_sensor_adapter PUBLIC cxx_std_17)
ament_target_dependencies(fake_sensor_adapter rclcpp edge_reliability_msgs)

install(TARGETS
  fake_sensor_adapter
  DESTINATION lib/${PROJECT_NAME}
)

install(DIRECTORY launch config
  DESTINATION share/${PROJECT_NAME}
)

ament_package()
