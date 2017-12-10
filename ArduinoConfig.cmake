if(NOT ARDUINO_CONFIG_INCLUDED)
set(ARDUINO_CONFIG_INCLUDED TRUE)


set(ARDUINO_CONFIG_PATH ${CMAKE_CURRENT_LIST_DIR})

if(CMAKE_HOST_WIN32)
	include(Platform/WindowsPaths)
elseif(CMAKE_HOST_UNIX)
	include(Platform/UnixPaths)
	list(APPEND CMAKE_PREFIX_PATH "/usr/share")
endif()


function(find_arduino_ide_path)
	find_path(ARDUINO_IDE_PATH
		NAMES "hardware" "libraries"
		PATHS ${ARDUINO_ROOT} $ENV{ARDUINO_ROOT}
		PATH_SUFFIXES "arduino" "Arduino"
		DOC "Arduino IDE path"
		NO_DEFAULT_PATH
		)

	find_path(ARDUINO_IDE_PATH
		NAMES "hardware" "libraries"
		PATH_SUFFIXES "arduino" "Arduino"
		DOC "Arduino IDE path"
		)

	message(STATUS "Arduino IDE path: ${ARDUINO_IDE_PATH}")
endfunction()


function(find_arduino_ide_tool_path TOOL)
	if(NOT ARDUINO_TOOL_${TOOL}_PATH)
		file(GLOB_RECURSE FILES "${ARDUINO_TOOLS_PATH}/*/${TOOL}")
		if(NOT FILES AND CMAKE_HOST_WIN32)
			file(GLOB_RECURSE FILES "${ARDUINO_TOOLS_PATH}/*/${TOOL}.exe")
		endif()

		list(LENGTH FILES NUM_RESULTS)

		if(NUM_RESULTS EQUAL 1)
			get_filename_component(PATH ${FILES} DIRECTORY)
		endif()

		set(ARDUINO_TOOL_${TOOL}_PATH "${PATH}" CACHE PATH "Arduino tool path (${TOOL})")
	endif()
endfunction()


function(find_arduino_ide_compiler_path)
	read_arduino_compiler_command(COMPILER_EXECUTABLE "c")

	if(COMPILER_EXECUTABLE)
		find_arduino_ide_tool_path(${COMPILER_EXECUTABLE})
	endif()

	set(ARDUINO_IDE_COMPILER_PATH ${ARDUINO_TOOL_${COMPILER_EXECUTABLE}_PATH} PARENT_SCOPE)
endfunction()


function(find_arduino_ide_tool_paths)
	read_arduino_tools(TOOLS)

	set(TOOL_PATHS)
	foreach(TOOL ${TOOLS})
		read_arduino_tool_command(TOOL_CMD ${TOOL})
		if(TOOL_CMD)
			find_arduino_ide_tool_path(${TOOL_CMD})
			if(ARDUINO_TOOL_${TOOL_CMD}_PATH)
				list(APPEND TOOL_PATHS ${ARDUINO_TOOL_${TOOL_CMD}_PATH})
			endif()
		endif()
	endforeach()

	set(ARDUINO_IDE_TOOL_PATHS ${TOOL_PATHS} PARENT_SCOPE)
endfunction()


function(find_arduino_sketch_path)
	find_path(ARDUINO_SKETCH_PATH
		NAMES "libraries"
		PATHS "$ENV{HOME}/Arduino" "$ENV{HOMEDRIVE}$ENV{HOMEPATH}/Documents/Arduino"
		DOC "Arduino sketch path"
		NO_DEFAULT_PATH
		)

	message(STATUS "Arduino sketch path: ${ARDUINO_SKETCH_PATH}")
endfunction()


function(find_arduino_package_path)
	find_file(ARDUINO_PACKAGE_PATH
		NAMES "packages"
		PATHS "$ENV{HOME}/.arduino15" "$ENV{LOCALAPPDATA}/Arduino15"
		DOC "Arduino package path"
		NO_DEFAULT_PATH
		)

	message(STATUS "Arduino package path: ${ARDUINO_PACKAGE_PATH}")
endfunction()


function(find_arduino_board_path)
	if(ARDUINO_ARCH)
		set(ARCH_DIR ${ARDUINO_ARCH})
	else()
		set(ARCH_DIR "*")
	endif()

	if(ARDUINO_PACKAGE_VERSION)
		set(VER_DIR ${ARDUINO_PACKAGE_VERSION})
	else()
		set(VER_DIR "*")
	endif()

	if(ARDUINO_BOARD_PATH)
		return()
	elseif(ARDUINO_BOARD_FILE)
		get_filename_component(BOARD_PATH ${ARDUINO_BOARD_FILE} DIRECTORY)
		list(APPEND SEARCH_PATHS ${BOARD_PATH})
	endif()

	if(ARDUINO_PACKAGE_PATH)
		list(APPEND SEARCH_PATHS
			"${ARDUINO_PACKAGE_PATH}/${ARDUINO_PLATFORM}/hardware/${ARCH_DIR}"
			"${ARDUINO_PACKAGE_PATH}/${ARDUINO_PLATFORM}/hardware/${ARCH_DIR}/${VER_DIR}")
	endif()

	if(ARDUINO_IDE_PATH)
		list(APPEND SEARCH_PATHS
			"${ARDUINO_IDE_PATH}/hardware/${ARDUINO_PLATFORM}/${ARCH_DIR}"
			"${ARDUINO_IDE_PATH}/hardware/${ARDUINO_PLATFORM}/${ARCH_DIR}/${VAR_DIR}")
	endif()

	if(ARDUINO_PREFER_IDE_TOOLCHAIN)
		list(REVERSE SEARCH_PATHS)
	endif()

	if(SEARCH_PATHS)
		find_path(ARDUINO_BOARD_PATH
			NAMES "boards.txt" "cores" "libraries"
			HINTS ${SEARCH_PATHS}
			DOC "Arduino board path"
			NO_DEFAULT_PATH
			)
	else()
		set(ARDUINO_BOARD_PATH "" CACHE FILEPATH "Arduino board path")
	endif()

	message(STATUS "Arduino board path: ${ARDUINO_BOARD_PATH}")
endfunction()


function(guess_arduino_arch_from_board_path)
	set(PATTERNS
		"${ARDUINO_PLATFORM}/hardware/([^/]+)"
		"${ARDUINO_PLATFORM}/hardware/([^/]+)/[^/]+"
		"hardware/${ARDUINO_PLATFORM}/([^/]+)"
		"hardware/${ARDUINO_PLATFORM}/([^/]+)/[^/]+"
		)

	get_filename_component(BOARD_DIR ${ARDUINO_BOARD_PATH} ABSOLUTE)

	foreach(PATTERN ${PATTERNS})
		if(BOARD_DIR MATCHES ${PATTERN})
			set(ARCH ${CMAKE_MATCH_1})
			break()
		endif()
	endforeach()

	set(ARDUINO_ARCH "${ARCH}" CACHE STRING "Arduino architecture")

	message(STATUS "Arduino architecture: ${ARDUINO_ARCH}")
endfunction()


function(find_arduino_boards_file)
	if(ARDUINO_BOARDS_FILE)
		return()
	elseif(EXISTS "${ARDUINO_BOARD_PATH}/boards.txt")
		set(PATH "${ARDUINO_BOARD_PATH}/boards.txt")
	endif()
	set(ARDUINO_BOARDS_FILE "${PATH}" CACHE FILEPATH "Arduino boards file")

	message(STATUS "Arduino boards file: ${ARDUINO_BOARDS_FILE}")
endfunction()


function(find_arduino_platform_file)
	if(ARDUINO_PLATFORM_FILE)
		return()
	elseif(EXISTS "${ARDUINO_BOARD_PATH}/platform.txt")
		set(PATH "${ARDUINO_BOARD_PATH}/platform.txt")
	endif()
	set(ARDUINO_PLATFORM_FILE "${PATH}" CACHE FILEPATH "Arduino platform file")

	message(STATUS "Arduino platform file: ${ARDUINO_PLATFORM_FILE}")
endfunction()


function(find_arduino_tools_path)
	if(ARDUINO_PACKAGE_PATH)
		list(APPEND SEARCH_PATHS "${ARDUINO_PACKAGE_PATH}/${ARDUINO_PLATFORM}")
	endif()
	if(ARDUINO_IDE_PATH)
		list(APPEND SEARCH_PATHS "${ARDUINO_IDE_PATH}/hardware")
	endif()

	if(ARDUINO_PREFER_IDE_TOOLCHAIN)
		list(REVERSE SEARCH_PATHS)
	endif()

	if(SEARCH_PATHS)
		find_file(ARDUINO_TOOLS_PATH
			NAMES "tools"
			HINTS ${SEARCH_PATHS}
			DOC "Arduino tools path"
			NO_DEFAULT_PATH
			)
	else()
		set(ARDUINO_TOOLS_PATH "" CACHE PATH "Arduino tools path")
	endif()

	message(STATUS "Arduino tools path: ${ARDUINO_TOOLS_PATH}")
endfunction()


function(find_arduino_core_path)
	if(ARDUINO_BOARD_PATH)
		set(PATH "${ARDUINO_BOARD_PATH}/cores/${ARDUINO_CORE}")
	endif()

	set(ARDUINO_CORE_PATH ${PATH} PARENT_SCOPE)

	message(STATUS "Arduino core path: ${PATH}")
endfunction()


function(find_arduino_variant_path)
	if(ARDUINO_BOARD_PATH)
		set(PATH "${ARDUINO_BOARD_PATH}/variants/${ARDUINO_VARIANT}")
	endif()

	set(ARDUINO_VARIANT_PATH ${PATH} PARENT_SCOPE)

	message(STATUS "Arduino variant path: ${PATH}")
endfunction()


function(find_arduino_toolchain_file)
	find_file(CMAKE_TOOLCHAIN_FILE
		NAMES "${ARDUINO_PLATFORM}-${ARDUINO_ARCH}-toolchain.cmake"
		HINTS ${CMAKE_MODULE_PATH} ${CMAKE_CURRENT_LIST_DIR}
		DOC "Arduino toolchain file"
		NO_DEFAULT_PATH
		)

	message(STATUS "Toolchain file: ${CMAKE_TOOLCHAIN_FILE}")
endfunction()


function(add_arduino_core CORE_TARGET_NAME)
	file(GLOB_RECURSE ARDUINO_CORE_SOURCES "${ARDUINO_CORE_PATH}/*.S" "${ARDUINO_CORE_PATH}/*.c" "${ARDUINO_CORE_PATH}/*.cpp")

	add_library(${CORE_TARGET_NAME} STATIC ${ARDUINO_CORE_SOURCES})
	target_include_directories(${CORE_TARGET_NAME} PUBLIC ${ARDUINO_VARIANT_PATH} ${ARDUINO_CORE_PATH})
endfunction()


function(add_arduino_library LIBRARY)
	if(NOT ARDUINO_LIBRARY_${LIBRARY}_PATH)
		if(ARDUINO_BOARD_PATH)
			list(APPEND SEARCH_PATHS "${ARDUINO_BOARD_PATH}/libraries/${LIBRARY}")
		endif()
		if(ARDUINO_IDE_PATH)
			list(APPEND SEARCH_PATHS "${ARDUINO_IDE_PATH}/libraries/${LIBRARY}")
		endif()

		if(ARDUINO_PREFER_IDE_TOOLCHAIN)
			list(REVERSE SEARCH_PATHS)
		endif()

		if(ARDUINO_SKETCH_PATH)
			list(APPEND SEARCH_PATHS "${ARDUINO_SKETCH_PATH}/libraries/${LIBRARY}")
		endif()

		if(SEARCH_PATHS)
			find_path(ARDUINO_LIBRARY_${LIBRARY}_PATH
				NAMES "${LIBRARY}.h"
				HINTS ${SEARCH_PATHS}
				PATH_SUFFIXES "src"
				DOC "Arduino library path (${LIBRARY})"
				NO_DEFAULT_PATH
				NO_CMAKE_FIND_ROOT_PATH
				)
		else()
			set(ARDUINO_LIBRARY_${LIBRARY}_PATH "" CACHE PATH "Arduino library path (${LIBRARY})")
		endif()
	endif()

	if(NOT ARDUINO_LIBRARY_${LIBRARY}_PATH)
		message(FATAL_ERROR "Cannot find Arduino library: ${LIBRARY}")
	endif()

	file(GLOB_RECURSE ARDUINO_LIBRARY_${LIBRARY}_SOURCES "${ARDUINO_LIBRARY_${LIBRARY}_PATH}/*.S" "${ARDUINO_LIBRARY_${LIBRARY}_PATH}/*.c" "${ARDUINO_LIBRARY_${LIBRARY}_PATH}/*.cpp")

	add_library(${LIBRARY} STATIC ${ARDUINO_LIBRARY_${LIBRARY}_SOURCES})
	target_include_directories(${LIBRARY} PUBLIC ${ARDUINO_LIBRARY_${LIBRARY}_PATH})
	target_link_libraries(${LIBRARY} PUBLIC core)
endfunction()


function(target_sketch TARGET)
	set(INO_CPP "${CMAKE_BINARY_DIR}/${TARGET}.ino.cpp")

	get_target_property(TARGET_SOURCES ${TARGET} SOURCES)
	foreach(SOURCE ${TARGET_SOURCES})
		if(SOURCE MATCHES "\\.ino$")
			set(SKETCH_PATH ${SOURCE})
			get_filename_component(SKETCH_PATH ${SKETCH_PATH} ABSOLUTE)
		endif()
	endforeach()

	if(NOT SKETCH_PATH)
		message(FATAL_ERROR "Sketch not found in sources of target: ${TARGET}")
	endif()

	configure_file("${ARDUINO_CONFIG_PATH}/InoWrapper.cpp" ${INO_CPP})
	target_sources(${TARGET} PRIVATE ${INO_CPP})
endfunction()


include(CMakeParseArguments)
macro(setup_arduino PLATFORM BOARD)
	cmake_parse_arguments(ARGS "NO_CORE" "CPU" "" ${ARGN})

	set(ARDUINO_PLATFORM ${PLATFORM} CACHE STRING "Arduino platform")
	set(ARDUINO_BOARD ${BOARD} CACHE STRING "Arduino board")
	set(ARDUINO_BOARD_CPU ${ARGS_CPU} CACHE STRING "Arduino board CPU")
	set(ARDUINO_PREFER_IDE_TOOLCHAIN ON CACHE BOOL "Prefer build toolchain installed with the IDE")

	message(STATUS "Arduino platform:  ${ARDUINO_PLATFORM}")
	message(STATUS "Arduino board:     ${ARDUINO_BOARD}")
	if(ARDUINO_CPU)
		message(STATUS "Arduino board CPU: ${ARDUINO_BOARD_CPU}")
	endif()

	find_arduino_ide_path()
	find_arduino_sketch_path()
	find_arduino_package_path()
	find_arduino_board_path()
	find_arduino_tools_path()

	guess_arduino_arch_from_board_path()

	find_arduino_toolchain_file()

	find_arduino_boards_file()
	find_arduino_platform_file()

	include(ArduinoPlatformReader)
	read_arduino_board_config(${ARDUINO_BOARDS_FILE})

	read_arduino_board_property(CMAKE_MCU "build.mcu" ARDUINO_BOARD_CPU)
	read_arduino_board_property(CMAKE_MCU_FREQ "build.f_cpu" ARDUINO_BOARD_CPU)
	read_arduino_board_property(ARDUINO_CORE "build.core")
	read_arduino_board_property(ARDUINO_VARIANT "build.variant")
	read_arduino_board_property(CMAKE_UPLOAD_PROTOCOL "upload.protocol" ARDUINO_BOARD_CPU)
	read_arduino_board_property(CMAKE_UPLOAD_BAUD "upload.speed" ARDUINO_BOARD_CPU)

	message(STATUS "MCU:             ${CMAKE_MCU}")
	message(STATUS "Frequency:       ${CMAKE_MCU_FREQ}")
	message(STATUS "Core:            ${ARDUINO_CORE}")
	message(STATUS "Variant:         ${ARDUINO_VARIANT}")
	message(STATUS "Upload protocol: ${CMAKE_UPLOAD_PROTOCOL}")
	message(STATUS "Upload speed:    ${CMAKE_UPLOAD_BAUD}")

	set(CMAKE_UPLOAD_PORT "/dev/ttyUSB0" CACHE STRING "Arduino upload port")
	message(STATUS "Upload port:     ${CMAKE_UPLOAD_PORT}")

	find_arduino_core_path()
	find_arduino_variant_path()

	if(ARDUINO_PREFER_IDE_TOOLCHAIN)
		read_arduino_compiler_config(${ARDUINO_PLATFORM_FILE})
		find_arduino_ide_compiler_path()

		if(ARDUINO_IDE_COMPILER_PATH)
			list(APPEND CMAKE_PROGRAM_PATH ${ARDUINO_IDE_COMPILER_PATH})
		endif()

		if(NOT ARDUINO_COMPILER_EXTRA_PATHS)
			read_arduino_compiler_extra_paths(ARDUINO_COMPILER_EXTRA_PATHS)
			set(ARDUINO_COMPILER_EXTRA_PATHS ${ARDUINO_COMPILER_EXTRA_PATHS} CACHE STRING "Arduino compiler extra paths")

			if(ARDUINO_COMPILER_EXTRA_PATHS)
				list(APPEND CMAKE_PREFIX_PATH ${ARDUINO_COMPILER_EXTRA_PATHS})
			endif()
		endif()

		read_arduino_tools_config(${ARDUINO_PLATFORM_FILE})
		find_arduino_ide_tool_paths()

		if(ARDUINO_IDE_TOOL_PATHS)
			list(APPEND CMAKE_PROGRAM_PATH ${ARDUINO_IDE_TOOL_PATHS})
		endif()
	endif()

	add_definitions("-DARDUINO=10805")

	enable_language(ASM)
	enable_language(C)
	enable_language(CXX)

	if(NOT ARGS_NO_CORE)
		add_arduino_core("core")
	endif()
endmacro()

endif()
