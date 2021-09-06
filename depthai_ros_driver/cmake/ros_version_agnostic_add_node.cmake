# Copyright 2021 Open Source Robotics Foundation, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

macro(find_dependent_packages)
  if($ENV{ROS_VERSION} STREQUAL 1)
    find_package(catkin REQUIRED COMPONENTS ${ARGN})
  else()
    find_package(ament_cmake REQUIRED)
    foreach(pkg ${ARGN})
      find_package(${pkg} REQUIRED)
    endforeach()
  endif()
endmacro()

macro(add_ros_node name)
  cmake_parse_arguments(_ARG
    "SKIP_PACKAGE_SEARCH"
    "PROJECT_NAME;COMPONENT_CLASS"
    "SOURCES;ROS1_SOURCES;ROS2_SOURCES;ROS1_COMPONENT_SOURCES;ROS1_EXE_SOURCES;ROS2_EXE_SOURCES;DIRECTORIES;INCLUDE_DIRS;SYSTEM_DEPS;PKG_DEPS;TARGET_DEPS"
    ${ARGN})
  if(_ARG_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR
      "add_ros_node() called with unused arguments: '"
      "${_ARG_UNPARSED_ARGUMENTS}'")
  endif()

  if($ENV{ROS_VERSION} STREQUAL 1)
    message(STATUS "Compiling ${name} as ROS 1")

    if(NOT ${SKIP_PACKAGE_SEARCH})
      find_package(catkin REQUIRED COMPONENTS ${ARGN})
    else()
      message(DEBUG "Skipping package search")
    endif()

    catkin_package (
      INCLUDE_DIRS ${_ARG_INCLUDE_DIRS}
        LIBRARIES ${name}_nodelet
        CATKIN_DEPENDS ${_ARG_PKG_DEPS}
        DEPENDS ${_ARG_SYSTEM_DEPS}
    )

    include_directories(${_ARG_INCLUDE_DIRS})
    include_directories(SYSTEM ${catkin_INCLUDE_DIRS})
    foreach(sys_dep ${_ARG_SYSTEM_DEPS})
      include_directories(SYSTEM ${${sys_dep}_INCLUDE_DIRS})
    endforeach()

    add_library(${name}_lib ${_ARG_SOURCES} ${_ARG_ROS1_SOURCES})
    target_link_libraries(${name}_lib ${catkin_LIBRARIES})
    foreach(sys_dep ${_ARG_SYSTEM_DEPS})
      target_link_libraries(${name}_lib ${${sys_dep}_LIBRARIES})
    endforeach()
    foreach(target_dep ${_ARG_TARGET_DEPS})
      target_link_libraries(${name}_lib ${target_dep})
    endforeach()

    add_dependencies(${name}_lib
      ${${name}_EXPORTED_TARGETS} ${catkin_EXPORTED_TARGETS})

    add_library(${name}_nodelet ${_ARG_ROS1_COMPONENT_SOURCES})
    target_link_libraries(${name}_nodelet ${name}_lib)

    add_executable(${name} ${_ARG_ROS1_EXE_SOURCES})
    target_link_libraries(${name} ${name}_lib)

    install(TARGETS ${name}_lib ${name}_nodelet ${name}
      ARCHIVE DESTINATION ${CATKIN_PACKAGE_LIB_DESTINATION}
      LIBRARY DESTINATION ${CATKIN_PACKAGE_LIB_DESTINATION}
      RUNTIME DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION})

    install(DIRECTORY ${_ARG_DIRECTORIES}
      DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
      USE_SOURCE_PERMISSIONS
    )

    set(${name}_PACKAGE_BIN_DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION})
    set(${name}_PACKAGE_LIB_DESTINATION ${CATKIN_PACKAGE_LIB_DESTINATION})
    set(${name}_PACKAGE_SHARE_DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION})
  else()
    message(STATUS "Compiling ${name} as ROS 2")

    if(NOT ${SKIP_PACKAGE_SEARCH})
      find_package(ament_cmake REQUIRED)
      foreach(pkg ${ARGN})
        find_package(${pkg} REQUIRED)
      endforeach()
    else()
      message(DEBUG "Skipping package search")
    endif()

    add_definitions(-DUSE_ROS2)

    include_directories(${_ARG_INCLUDE_DIRS})

    add_library(${name}_lib SHARED ${_ARG_SOURCES} ${_ARG_ROS2_SOURCES})
    foreach(sys_dep ${_ARG_SYSTEM_DEPS})
      target_link_libraries(${name}_lib PUBLIC ${${sys_dep}_LIBRARIES})
    endforeach()
    foreach(target_dep ${_ARG_TARGET_DEPS})
      target_link_libraries(${name}_lib PUBLIC ${target_dep})
    endforeach()
    ament_target_dependencies(${name}_lib PUBLIC ${_ARG_PKG_DEPS})

    rclcpp_components_register_nodes(${name}_lib ${_ARG_COMPONENT_CLASS})

    add_executable(${name}_node ${_ARG_ROS2_EXE_SOURCES})
    target_link_libraries(${name}_node PUBLIC ${name}_lib)

    install(TARGETS
      ${name}_lib
      ARCHIVE DESTINATION lib
      LIBRARY DESTINATION lib
      RUNTIME DESTINATION bin)

    install(TARGETS
      ${name}_node
      DESTINATION lib/${_ARG_PROJECT_NAME})

    install(DIRECTORY ${_ARG_DIRECTORIES}
      DESTINATION share/${PROJECT_NAME}
      USE_SOURCE_PERMISSIONS
    )

    ament_package()
    set(${name}_PACKAGE_BIN_DESTINATION lib/${PROJECT_NAME})
    set(${name}_PACKAGE_LIB_DESTINATION lib/${PROJECT_NAME})
    set(${name}_PACKAGE_SHARE_DESTINATION share/${PROJECT_NAME})
  endif()
endmacro()
