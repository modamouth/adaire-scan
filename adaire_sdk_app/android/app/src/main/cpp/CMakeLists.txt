cmake_minimum_required(VERSION 3.4.1)

add_library(
    debuggercheck
    SHARED
    debuggercheck.c
)

find_library(
    log-lib
    log
)

target_link_libraries(
    debuggercheck
    ${log-lib}
    android
)

