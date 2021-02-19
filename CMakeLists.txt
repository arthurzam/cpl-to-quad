cmake_minimum_required(VERSION 3.15)
project(cpq LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)

find_package(FLEX)
find_package(BISON 3.2)

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(BISON_FLAGS "${BISON_FLAGS} -Dparse.trace")
else()
    set(FLEX_FLAGS "${FLEX_FLAGS} --batch --never-interactive --nounistd")
endif()

BISON_TARGET(CPL_Parser parser.yy ${CMAKE_CURRENT_BINARY_DIR}/parser.cpp
    DEFINES_FILE ${CMAKE_CURRENT_BINARY_DIR}/parser.hpp
    VERBOSE ${CMAKE_CURRENT_BINARY_DIR}/parser.report
    COMPILE_FLAGS ${BISON_FLAGS})
FLEX_TARGET(CPL_Scanner lexer.l
    ${CMAKE_CURRENT_BINARY_DIR}/lexer.cpp
    COMPILE_FLAGS ${FLEX_FLAGS})
ADD_FLEX_BISON_DEPENDENCY(CPL_Scanner CPL_Parser)

add_executable(cpq
    cpq.cpp
    driver.h
    driver.cpp
    assembly.cpp
    assembly.h
    optimizer.cpp
    declarations.h
    ${BISON_CPL_Parser_OUTPUTS}
    ${FLEX_CPL_Scanner_OUTPUTS}
)
set_property(TARGET cpq PROPERTY INTERPROCEDURAL_OPTIMIZATION True)
