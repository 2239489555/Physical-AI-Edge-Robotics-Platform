cmake_minimum_required(VERSION 3.8)
project(edge_reliability_tracer)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(std_msgs REQUIRED)

add_executable(tracer_publisher src/tracer_publisher.cpp)
ament_target_dependencies(tracer_publisher rclcpp std_msgs)

add_executable(tracer_subscriber src/tracer_subscriber.cpp)
ament_target_dependencies(tracer_subscriber rclcpp std_msgs)

install(TARGETS
  tracer_publisher
  tracer_subscriber
  DESTINATION lib/${PROJECT_NAME}
)

install(DIRECTORY launch config
  DESTINATION share/${PROJECT_NAME}
)

ament_package()
