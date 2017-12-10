get_property(IN_TRY_COMPILE GLOBAL PROPERTY IN_TRY_COMPILE)
if(IN_TRY_COMPILE OR ESP8266_ESP8266_TOOLCHAIN_INCLUDED)
	return()
endif()
set(ESP8266_ESP8266_TOOLCHAIN_INCLUDED TRUE)


set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR esp8266)
set(CMAKE_CROSSCOMPILING 1)


set(COMPILER_PREFIX "xtensa-lx106-elf-")

find_program(CMAKE_C_COMPILER NAMES "${COMPILER_PREFIX}gcc")
find_program(CMAKE_ASM_COMPILER NAMES "${COMPILER_PREFIX}gcc")
find_program(CMAKE_CXX_COMPILER NAMES "${COMPILER_PREFIX}g++")

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_definitions("-D__ets__" "-DICACHE_FLASH" "-U__STRICT_ANSI__" "-DLWIP_OPEN_SRC" "-DESP8266")

set(ESP_COMMON_DEFINITIONS "-DF_CPU=${CMAKE_MCU_FREQ}")
string(APPEND ESP_COMMON_DEFINITIONS [[ -Os -g -DARDUINO_ESP8266_WEMOS_D1MINI -DARDUINO_ARCH_ESP8266 -DARDUINO_BOARD=\"ESP8266_WEMOS_D1MINI\"]])

string(APPEND CMAKE_C_FLAGS_INIT   " -w -Wpointer-arith -Wno-implicit-function-declaration -Wl,-EL -fno-inline-functions -nostdlib -mlongcalls -mtext-section-literals -falign-functions=4 -ffunction-sections -fdata-sections ${ESP_COMMON_DEFINITIONS}")
string(APPEND CMAKE_CXX_FLAGS_INIT " -w -mlongcalls -mtext-section-literals -fno-exceptions -fno-rtti -falign-functions=4 -ffunction-sections -fdata-sections ${ESP_COMMON_DEFINITIONS}")
string(APPEND CMAKE_ASM_FLAGS_INIT " -x assembler-with-cpp -mlongcalls ${ESP_COMMON_DEFINITIONS}")

find_path(ESP_SDK_PATH
	NAMES "include/espnow.h" "lwip/include"
	NO_CMAKE_FIND_ROOT_PATH
	)
include_directories("${ESP_SDK_PATH}/include" "${ESP_SDK_PATH}/lwip/include" "${ESP_SDK_PATH}/libc/xtensa-lx106-elf/include")


if(ARDUINO_BOARD STREQUAL "d1_mini") # FIXME: remove fixed values
	set(ESP_FLASH_LD "eagle.flash.4m.ld")
	set(ESP_FLASH_SIZE "4M")
	set(ESP_FLASH_FREQ "40")
	set(ESP_FLASH_MODE "dio")
	set(ESP_UPLOAD_RESETMETHOD "nodemcu")
	set(ESP_BOOTLOADER_FILE "${ARDUINO_BOARD_PATH}/bootloaders/eboot/eboot.elf")
	find_program(CMAKE_PYTHON NAMES "python")
	find_file(ESP_ESPOTA NAMES "espota.py" HINTS "${ESP_SDK_PATH}/..")
else()
	message(FATAL_ERROR)
endif()

string(APPEND CMAKE_EXE_LINKER_FLAGS_INIT " -nostdlib -Wl,--no-check-sections -u call_user_start -u _printf_float -u _scanf_float -Wl,-static  -L${ESP_SDK_PATH}/lib -L${ESP_SDK_PATH}/ld -L${ESP_SDK_PATH}/libc/xtensa-lx106-elf/lib -T${ESP_FLASH_LD} -Wl,--gc-sections -Wl,-wrap,system_restart_local -Wl,-wrap,spi_flash_read")

set(ESP_LIBS "-lhal -lphy -lpp -lnet80211 -llwip_gcc -lwpa -lcrypto -lmain -lwps -laxtls -lespnow -lsmartconfig -lmesh -lwpa2 -lstdc++ -lm -lc -lgcc")
#link_libraries(-lhal -lphy -lpp -lnet80211 -llwip_gcc -lwpa -lcrypto -lmain -lwps -laxtls -lespnow -lsmartconfig -lmesh -lwpa2 -lstdc++ -lm -lc -lgcc)


set(CMAKE_C_LINK_EXECUTABLE "<CMAKE_C_COMPILER> <LINK_FLAGS>  -o <TARGET>  -Wl,--start-group <OBJECTS> <LINK_LIBRARIES> ${ESP_LIBS} -Wl,--end-group")
set(CMAKE_ASM_LINK_EXECUTABLE "<CMAKE_ASM_COMPILER> <LINK_FLAGS>  -o <TARGET>  -Wl,--start-group <OBJECTS> <LINK_LIBRARIES> ${ESP_LIBS} -Wl,--end-group")
set(CMAKE_CXX_LINK_EXECUTABLE "<CMAKE_CXX_COMPILER> <LINK_FLAGS>  -o <TARGET>  -Wl,--start-group <OBJECTS> <LINK_LIBRARIES> ${ESP_LIBS} -Wl,--end-group")


get_filename_component(ESP_XTENSA_BIN_DIR ${CMAKE_C_COMPILER} DIRECTORY)
get_filename_component(ESP_XTENSA_BIN_PARENT_DIR ${ESP_XTENSA_BIN_DIR} DIRECTORY)

#find_path(CMAKE_FIND_ROOT_PATH NAMES "include/xtensa" HINTS "${ESP_XTENSA_BIN_PARENT_DIR}/xtensa-lx106-elf")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)


find_program(CMAKE_OBJDUMP NAMES "${COMPILER_PREFIX}objdump")
find_program(CMAKE_SIZE NAMES "${COMPILER_PREFIX}size")
find_program(CMAKE_ESPTOOL NAMES "esptool")


set(CMAKE_OBJDUMP_FLAGS_LST -h -S -z)


function(target_elf_to_lst ELF_TARGET)
	add_custom_command(TARGET ${ELF_TARGET}
		POST_BUILD COMMAND ${CMAKE_OBJDUMP} ${CMAKE_OBJDUMP_FLAGS_LST} $<TARGET_FILE:${ELF_TARGET}> > "${ELF_TARGET}.lst")
endfunction()


function(target_elf_to_bin ELF_TARGET)
	add_custom_command(TARGET ${ELF_TARGET}
		POST_BUILD COMMAND ${CMAKE_ESPTOOL} -eo ${ESP_BOOTLOADER_FILE} -bo "${ELF_TARGET}.bin" -bm ${ESP_FLASH_MODE} -bf ${ESP_FLASH_FREQ} -bz ${ESP_FLASH_SIZE} -bs .text -bp 4096 -ec -eo $<TARGET_FILE:${ELF_TARGET}> -bs .irom0.text -bs .text -bs .data -bs .rodata -bc -ec)
endfunction()


function(add_upload TARGET)
	add_custom_target(upload-${TARGET}
		${CMAKE_ESPTOOL} -cd ${ESP_UPLOAD_RESETMETHOD} -cb ${CMAKE_UPLOAD_BAUD} -cp ${CMAKE_UPLOAD_PORT} -ca 0x00000 -cf "${TARGET}.bin"
		DEPENDS ${TARGET}
		VERBATIM)
endfunction()


function(add_upload_ota TARGET)
	add_custom_target(upload-ota-${TARGET}
		${CMAKE_PYTHON} ${ESP_ESPOTA} -i ${CMAKE_UPLOAD_IP} -p ${CMAKE_UPLOAD_IP_PORT} --auth=${CMAKE_UPLOAD_AUTH} -f "${TARGET}.bin"
		DEPENDS ${TARGET}
		VERBATIM)
endfunction()
