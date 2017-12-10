if(CMAKE_HOST_WIN32)
	set(ARDUINO_CONFIG_OS "windows")
elseif(CMAKE_HOST_APPLE)
	set(ARDUINO_CONFIG_OS "macosx")
elseif(CMAKE_HOST_UNIX)
	set(ARDUINO_CONFIG_OS "linux")
endif()


macro(read_arduino_platform_config PLATFORM_FILE)
	file(STRINGS ${PLATFORM_FILE} ARDUINO_PLATFORM_CONFIG REGEX "^ *[^ ]+ *=")
endmacro()


macro(read_arduino_compiler_config PLATFORM_FILE)
	file(STRINGS ${PLATFORM_FILE} ARDUINO_COMPILER_CONFIG REGEX "^ *compiler\\.[^ ]+ *=")
endmacro()


macro(read_arduino_tools_config PLATFORM_FILE)
	file(STRINGS ${PLATFORM_FILE} ARDUINO_TOOLS_CONFIG REGEX "^ *tools\\.[^\\.]+\\.[^ ]+ *=")
endmacro()


function(escape_arduino_property_name_to_regex VAR PROP)
	string(REPLACE "." "\\." RES ${PROP})
	set(${VAR} ${RES} PARENT_SCOPE)
endfunction()


function(read_arduino_property PATTERN VAR CONFIG)
	if("${${CONFIG}}" MATCHES ${PATTERN})
		set(${VAR} ${CMAKE_MATCH_1} PARENT_SCOPE)
	endif()
endfunction()


function(read_arduino_properties PATTERN VAR CONFIG)
	set(${VAR} "")
	foreach(LINE ${${CONFIG}})
		if(LINE MATCHES ${PATTERN})
			list(APPEND ${VAR} ${CMAKE_MATCH_1})
		endif()
	endforeach()
	set(${VAR} ${${VAR}} PARENT_SCOPE)
endfunction()


function(read_arduino_platform_property VAR PROP)
	escape_arduino_property_name_to_regex(ESCAPED_PROP ${PROP})
	read_arduino_property("${PROP} *= *([^;]*)" PROP_VALUE ARDUINO_PLATFORM_CONFIG)
	set(${VAR} ${PROP_VALUE} PARENT_SCOPE)
endfunction()


function(read_arduino_compiler_property VAR PROP)
	escape_arduino_property_name_to_regex(ESCAPED_PROP ${PROP})
	read_arduino_property("compiler\\.${ESCAPED_PROP} *= *([^;]*)" PROP_VALUE ARDUINO_COMPILER_CONFIG)
	set(${VAR} ${PROP_VALUE} PARENT_SCOPE)
endfunction()


function(substitute_arduino_compiler_property_values VAR INPUT)
	set(RES ${INPUT})
	while(RES MATCHES "{(.*)}")
		set(PROP_NAME ${CMAKE_MATCH_1})
		if(PROP_NAME STREQUAL "runtime.platform.path")
			set(PROP_VALUE "${ARDUINO_BOARD_PATH}")
		elseif(PROP_NAME MATCHES "^runtime\\..*\\.path")
			set(PROP_VALUE ".")
		else()
			read_arduino_compiler_property(PROP_VALUE ${PROP_NAME})
			if(PROP_VALUE)
				substitute_arduino_compiler_property_values(PROP_VALUE ${PROP_VALUE})
			endif()
		endif()
		string(REPLACE "{${PROP_NAME}}" "${PROP_VALUE}" RES ${RES})
	endwhile()
	set(${VAR} ${RES} PARENT_SCOPE)
endfunction()


macro(read_arduino_compiler_command VAR LANG)
	read_arduino_compiler_property(${VAR} "${LANG}.cmd")
endmacro()


function(read_arduino_compiler_extra_paths VAR)
	read_arduino_properties("compiler\\.[^\\.]*\\.path *= *([^;]*)" PROP_VALUES ARDUINO_COMPILER_CONFIG)
	set(SUBSTITUTED_VALUES)
	foreach(VAL ${PROP_VALUES})
		substitute_arduino_compiler_property_values(SUB_VAL ${VAL})
		list(APPEND SUBSTITUTED_VALUES ${SUB_VAL})
	endforeach()
	set(${VAR} ${SUBSTITUTED_VALUES} PARENT_SCOPE)
endfunction()


macro(read_arduino_tools VAR)
	read_arduino_properties("tools\\.([^\\.]+)\\.cmd.*=" ${VAR} ARDUINO_TOOLS_CONFIG)
	list(REMOVE_DUPLICATES ${VAR})
endmacro()


macro(read_arduino_upload_tools VAR)
	read_arduino_properties("tools\\.([^\\.]+)\\.upload.pattern *=" ${VAR} ARDUINO_TOOLS_CONFIG)
endmacro()


function(read_arduino_tool_property VAR TOOL PROP)
	escape_arduino_property_name_to_regex(ESCAPED_PROP ${PROP})
	read_arduino_property("tools\\.${TOOL}\\.${ESCAPED_PROP} *= *([^;]*)" PROP_VALUE ARDUINO_TOOLS_CONFIG)
	set(${VAR} ${PROP_VALUE} PARENT_SCOPE)
endfunction()


function(substitute_arduino_tool_property_values VAR TOOL INPUT)
	set(RES ${INPUT})
	while(RES MATCHES "{(.*)}")
		set(PROP_NAME ${CMAKE_MATCH_1})
		if(PROP_NAME MATCHES "^runtime\\..*\\.path")
			set(PROP_VALUE ".")
		else()
			read_arduino_tool_property(PROP_VALUE ${TOOL} ${PROP_NAME})
			if(PROP_VALUE)
				substitute_arduino_tool_property_values(PROP_VALUE ${TOOL} ${PROP_VALUE})
			endif()
		endif()
		string(REPLACE "{${PROP_NAME}}" "${PROP_VALUE}" RES ${RES})
	endwhile()
	set(${VAR} ${RES} PARENT_SCOPE)
endfunction()


function(read_arduino_tool_command VAR TOOL)
	if(ARDUINO_CONFIG_OS)
		read_arduino_properties("tools\\.${TOOL}\\.cmd\\.([^ ]+) *=" OS_ENTRIES ARDUINO_TOOLS_CONFIG)

		list(FIND OS_ENTRIES ${ARDUINO_CONFIG_OS} OS_ENTRY_POS)

		if(NOT OS_ENTRY_POS EQUAL -1)
			read_arduino_tool_property(${VAR} ${TOOL} "cmd.${ARDUINO_CONFIG_OS}")
			set(${VAR} ${${VAR}} PARENT_SCOPE)
		endif()
	endif()

	read_arduino_tool_property(${VAR} ${TOOL} "cmd")

	if(NOT ${VAR})
		read_arduino_tool_property(${VAR} ${TOOL} "cmd.path")
		if(${VAR})
			substitute_arduino_tool_property_values(${VAR} ${TOOL} ${${VAR}})
			get_filename_component(${VAR} ${${VAR}} NAME)
		endif()
	endif()

	if(${VAR})
		set(${VAR} ${${VAR}} PARENT_SCOPE)
	endif()
endfunction()


macro(read_arduino_board_config BOARDS_FILE)
	file(STRINGS ${BOARDS_FILE} ARDUINO_BOARD_CONFIG REGEX "^ *${ARDUINO_BOARD}\\.[^=]+=")
endmacro()


function(read_arduino_board_property VAR PROP)
	escape_arduino_property_name_to_regex(ESCAPED_PROP ${PROP})

	if(${ARGC} GREATER 2)
		set(MENU_OPTION_VAR ${ARGV2})

		string(REGEX MATCH "${ARDUINO_BOARD}\\.menu\\.[^\\.]+\\.${${MENU_OPTION_VAR}}\\.${ESCAPED_PROP} *= *([^;]*)" ${VAR} "${ARDUINO_BOARD_CONFIG}")

		if(CMAKE_MATCH_COUNT GREATER 0)
			set(${VAR} ${CMAKE_MATCH_1} PARENT_SCOPE)
		endif()
	endif()

	if(NOT ${VAR})
		string(REGEX MATCH "${ARDUINO_BOARD}\\.${ESCAPED_PROP} *= *([^;]*)" ${VAR} "${ARDUINO_BOARD_CONFIG}")

		if(CMAKE_MATCH_COUNT GREATER 0)
			set(${VAR} ${CMAKE_MATCH_1} PARENT_SCOPE)
		endif()
	endif()

	if(NOT ${VAR})
		set(MENU_ENTRIES)
		foreach(LINE ${ARDUINO_BOARD_CONFIG})
			string(REGEX MATCH "${ARDUINO_BOARD}\\.menu\\.[^\\.]+\\.([^\\.]+\\.${ESCAPED_PROP}) *=" MENU_ENTRY ${LINE})
			if(CMAKE_MATCH_COUNT GREATER 0)
				list(APPEND MENU_ENTRIES ${CMAKE_MATCH_1})
			endif()
		endforeach()

		if(MENU_ENTRIES)
			string(REPLACE ";" " " MENU_ENTRIES "${MENU_ENTRIES}")
			message(WARNING "Cannot find property '${PROP}' of board '${ARDUINO_BOARD}'. Found multiple subconfigurations: ${MENU_ENTRIES}")
		endif()

		set(${VAR} "" PARENT_SCOPE)
	endif()
endfunction()
