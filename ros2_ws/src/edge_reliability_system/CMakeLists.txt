cmake_minimum_required(VERSION 3.8)
project(edge_reliability_system)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(edge_reliability_msgs REQUIRED)

add_executable(system_metrics_node src/system_metrics_node.cpp)
target_compile_features(system_metrics_node PUBLIC cxx_std_17)
target_include_directories(system_metrics_node PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>
)
ament_target_dependencies(system_metrics_node rclcpp edge_reliability_msgs)

install(TARGETS
  system_metrics_node
  DESTINATION lib/${PROJECT_NAME}
)

install(DIRECTORY include/
  DESTINATION include
)

install(DIRECTORY launch config testdata
  DESTINATION share/${PROJECT_NAME}
)

if(BUILD_TESTING)
  find_package(ament_cmake_gtest REQUIRED)

  ament_add_gtest(tegrastats_parser_test
    test/tegrastats_parser_test.cpp
  )
  target_compile_features(tegrastats_parser_test PUBLIC cxx_std_17)
  target_include_directories(tegrastats_parser_test PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  )
endif()

ament_package()
