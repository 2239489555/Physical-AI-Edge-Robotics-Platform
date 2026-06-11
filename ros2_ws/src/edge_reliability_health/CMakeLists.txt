cmake_minimum_required(VERSION 3.8)
project(edge_reliability_health)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(edge_reliability_msgs REQUIRED)

add_executable(health_monitor src/health_monitor.cpp)
target_compile_features(health_monitor PUBLIC cxx_std_17)
target_include_directories(health_monitor PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>
)
ament_target_dependencies(health_monitor rclcpp edge_reliability_msgs)

install(TARGETS
  health_monitor
  DESTINATION lib/${PROJECT_NAME}
)

install(DIRECTORY include/
  DESTINATION include
)

install(DIRECTORY launch config
  DESTINATION share/${PROJECT_NAME}
)

if(BUILD_TESTING)
  find_package(ament_cmake_gtest REQUIRED)

  ament_add_gtest(health_rules_test
    test/health_rules_test.cpp
  )
  target_compile_features(health_rules_test PUBLIC cxx_std_17)
  target_include_directories(health_rules_test PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  )
endif()

ament_package()
