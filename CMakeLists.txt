cmake_minimum_required(VERSION 3.17)

# Assuming user runs cmake from a build sub folder
set(CMAKE_INSTALL_PREFIX ..)

# ----------------------- CPM ------------------------
set(CPM_DOWNLOAD_VERSION 0.37.0)

if(CPM_SOURCE_CACHE)
    set(CPM_DOWNLOAD_LOCATION "${CPM_SOURCE_CACHE}/cpm/CPM_${CPM_DOWNLOAD_VERSION}.cmake")
elseif(DEFINED ENV{CPM_SOURCE_CACHE})
    set(CPM_DOWNLOAD_LOCATION "$ENV{CPM_SOURCE_CACHE}/cpm/CPM_${CPM_DOWNLOAD_VERSION}.cmake")
else()
    set(CPM_DOWNLOAD_LOCATION "${CMAKE_BINARY_DIR}/cmake/CPM_${CPM_DOWNLOAD_VERSION}.cmake")
endif()

if(NOT (EXISTS ${CPM_DOWNLOAD_LOCATION}))
    message(STATUS "Downloading CPM.cmake to ${CPM_DOWNLOAD_LOCATION}")
    file(DOWNLOAD
        https://github.com/TheLartians/CPM.cmake/releases/download/v${CPM_DOWNLOAD_VERSION}/CPM.cmake
        ${CPM_DOWNLOAD_LOCATION}
    )
endif()

include(${CPM_DOWNLOAD_LOCATION})

# luv
CPMAddPackage("gh:luvit/luv#1.45.0-0")
install(TARGETS luv LIBRARY DESTINATION lib)

# -------------- video encoding library --------------
option(VIDEO_EXPORT "Compile the library for video export." TRUE)
if(VIDEO_EXPORT)
	project(encode DESCRIPTION "library for encoding video files from lua using ffi")

	find_package(PkgConfig REQUIRED)
	pkg_check_modules(LIBAV REQUIRED IMPORTED_TARGET
	    libavformat
	    libavcodec
	    libswresample
	    libswscale
	    libavutil
	)

	add_library(encode SHARED
		game_handler/video/encode.c
	)
	target_link_libraries(encode
	    PkgConfig::LIBAV
	)

	install(TARGETS encode RUNTIME DESTINATION lib)
endif()


# make a custom target with ALL that depends on the imported targets from CPM in order to actually build them
add_custom_target(oh3 ALL)
add_dependencies(oh3 luv)
