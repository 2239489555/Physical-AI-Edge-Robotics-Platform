cmake_minimum_required(VERSION 3.8)
project(edge_reliability_processor)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(edge_reliability_msgs REQUIRED)

add_executable(sensor_processor src/sensor_processor.cpp)
target_compile_features(sensor_processor PUBLIC cxx_std_17)
target_include_directories(sensor_processor PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>
)
ament_target_dependencies(sensor_processor rclcpp edge_reliability_msgs)

install(TARGETS
  sensor_processor
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

  ament_add_gtest(pipeline_metrics_accumulator_test
    test/pipeline_metrics_accumulator_test.cpp
  )
  target_compile_features(pipeline_metrics_accumulator_test PUBLIC cxx_std_17)
  target_include_directories(pipeline_metrics_accumulator_test PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  )
endif()

ament_package()
