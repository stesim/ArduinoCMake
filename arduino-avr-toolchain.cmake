get_property(IN_TRY_COMPILE GLOBAL PROPERTY IN_TRY_COMPILE)
if(IN_TRY_COMPILE OR ARDUINO_AVR_TOOLCHAIN_INCLUDED)
	return()
endif()
set(ARDUINO_AVR_TOOLCHAIN_INCLUDED TRUE)


set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arduino)
SET(CMAKE_CROSSCOMPILING 1)


set(COMPILER_PREFIX "avr-")

find_program(CMAKE_C_COMPILER NAMES "${COMPILER_PREFIX}gcc")
find_program(CMAKE_ASM_COMPILER NAMES "${COMPILER_PREFIX}gcc")
find_program(CMAKE_CXX_COMPILER NAMES "${COMPILER_PREFIX}g++")

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS ON)

set(AVR_COMMON_DEFINES "-Os -g -flto -mmcu=${CMAKE_MCU} -DF_CPU=${CMAKE_MCU_FREQ}")

string(APPEND CMAKE_C_FLAGS_INIT   " -ffunction-sections -fdata-sections -fno-fat-lto-objects ${AVR_COMMON_DEFINES}")
string(APPEND CMAKE_CXX_FLAGS_INIT " -fno-exceptions -ffunction-sections -fdata-sections -fno-threadsafe-statics ${AVR_COMMON_DEFINES}")
string(APPEND CMAKE_ASM_FLAGS_INIT " -x assembler-with-cpp ${AVR_COMMON_DEFINES}")
string(APPEND CMAKE_EXE_LINKER_FLAGS_INIT " -fuse-linker-plugin -Wl,--gc-sections")


find_program(CMAKE_AR NAMES "${COMPILER_PREFIX}gcc-ar")
find_program(CMAKE_RANLIB NAMES "${COMPILER_PREFIX}gcc-ranlib")


get_filename_component(AVR_BIN_DIR ${CMAKE_C_COMPILER} DIRECTORY)
get_filename_component(AVR_BIN_PARENT_DIR ${AVR_BIN_DIR} DIRECTORY)

#find_path(CMAKE_FIND_ROOT_PATH NAMES "include/avr" HINTS "${AVR_BIN_PARENT_DIR}/avr")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)


find_program(CMAKE_OBJDUMP NAMES "${COMPILER_PREFIX}objdump")
find_program(CMAKE_OBJCOPY NAMES "${COMPILER_PREFIX}objcopy")
find_program(CMAKE_SIZE NAMES "${COMPILER_PREFIX}size")
find_program(CMAKE_AVRDUDE NAMES "avrdude")

set(CMAKE_OBJDUMP_FLAGS_LST -h -S -z)
set(CMAKE_OBJCOPY_FLAGS_EEP -O ihex -j .eeprom --set-section-flags=.eeprom=alloc,load --no-change-warnings --change-section-lma .eeprom=0)
set(CMAKE_OBJCOPY_FLAGS_FLASH -O ihex -R .eeprom)

set(CMAKE_AVRDUDE_FLAGS -p${CMAKE_MCU} -c${CMAKE_UPLOAD_PROTOCOL} -P${CMAKE_UPLOAD_PORT} -b${CMAKE_UPLOAD_BAUD} -D)


function(target_elf_to_lst ELF_TARGET)
	add_custom_command(TARGET ${ELF_TARGET}
		POST_BUILD COMMAND ${CMAKE_OBJDUMP} ${CMAKE_OBJDUMP_FLAGS_LST} $<TARGET_FILE:${ELF_TARGET}> > "${ELF_TARGET}.lst")
endfunction()


function(target_elf_to_eep ELF_TARGET)
	add_custom_command(TARGET ${ELF_TARGET}
		POST_BUILD COMMAND ${CMAKE_OBJCOPY} ${CMAKE_OBJCOPY_FLAGS_EEP} $<TARGET_FILE:${ELF_TARGET}>  "${ELF_TARGET}.eep")
endfunction()


function(target_elf_to_hex ELF_TARGET)
	add_custom_command(TARGET ${ELF_TARGET}
		POST_BUILD COMMAND ${CMAKE_OBJCOPY} ${CMAKE_OBJCOPY_FLAGS_FLASH} $<TARGET_FILE:${ELF_TARGET}>  "${ELF_TARGET}.hex")
endfunction()


function(add_upload TARGET)
	add_custom_target(upload-${TARGET}
		${CMAKE_AVRDUDE} ${CMAKE_AVRDUDE_FLAGS} "-Uflash:w:${TARGET}.hex:i"
		DEPENDS ${TARGET}
		VERBATIM)
endfunction()
