set(version 3.21.8)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO protocolbuffers/protobuf
    REF v3.21.8
    SHA512 a9e3ff6fd4b5f4bf86ac58c9b0a35010e7069def08783c0aecc05cc0d6e38f04a1af6b6ad61191c3d3348c1e5e44062f63ce1377141ebbd10f122101ef089088
    HEAD_REF master
    PATCHES
        fix-static-build.patch
        fix-default-proto-file-path.patch
        compile_options.patch
)

string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "dynamic" protobuf_BUILD_SHARED_LIBS)
string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" protobuf_MSVC_STATIC_RUNTIME)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        zlib protobuf_WITH_ZLIB
        codegen protobuf_BUILD_PROTOC_BINARIES
)

if(VCPKG_TARGET_IS_UWP)
    set(protobuf_BUILD_LIBPROTOC OFF)
else()
    set(protobuf_BUILD_LIBPROTOC ON)
endif()

if (VCPKG_DOWNLOAD_MODE)
    # download PKGCONFIG in download mode which is used in `vcpkg_fixup_pkgconfig()` at the end of this script.
    # download it here because `vcpkg_cmake_configure()` halts execution in download mode when running configure process.
    vcpkg_find_acquire_program(PKGCONFIG)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -Dprotobuf_BUILD_SHARED_LIBS=${protobuf_BUILD_SHARED_LIBS}
        -Dprotobuf_MSVC_STATIC_RUNTIME=${protobuf_MSVC_STATIC_RUNTIME}
        -Dprotobuf_BUILD_TESTS=OFF
        -DCMAKE_INSTALL_CMAKEDIR:STRING=share/protobuf
        -Dprotobuf_BUILD_LIBPROTOC=${protobuf_BUILD_LIBPROTOC}
        ${FEATURE_OPTIONS}
)

vcpkg_cmake_install()

# It appears that at this point the build hasn't actually finished. There is probably
# a process spawned by the build, therefore we need to wait a bit.

function(protobuf_try_remove_recurse_wait PATH_TO_REMOVE)
    file(REMOVE_RECURSE ${PATH_TO_REMOVE})
    if (EXISTS "${PATH_TO_REMOVE}")
        execute_process(COMMAND ${CMAKE_COMMAND} -E sleep 5)
        file(REMOVE_RECURSE ${PATH_TO_REMOVE})
    endif()
endfunction()

function(protobuf_fix_protoc_path PROTOC_EXECUTABLE_NAME)
    if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "release")
        vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/protobuf/protobuf-targets-release.cmake"
            "\${_IMPORT_PREFIX}/bin/${PROTOC_EXECUTABLE_NAME}"
            "\${Protobuf_PROTOC_EXECUTABLE}"
        )
    endif()

    if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
        file(READ "${CURRENT_PACKAGES_DIR}/debug/share/protobuf/protobuf-targets-debug.cmake" DEBUG_MODULE)
        string(REPLACE "\${_IMPORT_PREFIX}" "\${_IMPORT_PREFIX}/debug" DEBUG_MODULE "${DEBUG_MODULE}")
        string(REPLACE "\${_IMPORT_PREFIX}/debug/bin/${PROTOC_EXECUTABLE_NAME}" "\${Protobuf_PROTOC_EXECUTABLE}" DEBUG_MODULE "${DEBUG_MODULE}")
        file(WRITE "${CURRENT_PACKAGES_DIR}/share/protobuf/protobuf-targets-debug.cmake" "${DEBUG_MODULE}")
    endif()
endfunction()

protobuf_try_remove_recurse_wait("${CURRENT_PACKAGES_DIR}/debug/include")

if(protobuf_BUILD_PROTOC_BINARIES)
    if(VCPKG_TARGET_IS_WINDOWS)
        vcpkg_copy_tools(TOOL_NAMES protoc AUTO_CLEAN)
        protobuf_fix_protoc_path("protoc.exe")
    else()
        vcpkg_copy_tools(TOOL_NAMES protoc protoc-${version}.0 AUTO_CLEAN)
        protobuf_fix_protoc_path("protoc-${version}.0${EXECUTABLE_SUFFIX}")
    endif()
endif()

protobuf_try_remove_recurse_wait("${CURRENT_PACKAGES_DIR}/debug/share")

vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/${PORT}/protobuf-config.cmake"
    "if(protobuf_MODULE_COMPATIBLE)"
    "if(ON)"
)
if(NOT protobuf_BUILD_LIBPROTOC)
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/${PORT}/protobuf-module.cmake"
        "_protobuf_find_libraries(Protobuf_PROTOC protoc)"
        ""
    )
endif()

if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    protobuf_try_remove_recurse_wait("${CURRENT_PACKAGES_DIR}/bin")
    protobuf_try_remove_recurse_wait("${CURRENT_PACKAGES_DIR}/debug/bin")
endif()

if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/google/protobuf/stubs/platform_macros.h"
        "\#endif  // GOOGLE_PROTOBUF_PLATFORM_MACROS_H_"
        "\#ifndef PROTOBUF_USE_DLLS\n\#define PROTOBUF_USE_DLLS\n\#endif // PROTOBUF_USE_DLLS\n\n\#endif  // GOOGLE_PROTOBUF_PLATFORM_MACROS_H_"
    )
endif()

vcpkg_copy_pdbs()
set(packages protobuf protobuf-lite)
foreach(_package IN LISTS packages)
    set(_file "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/${_package}.pc")
    if(EXISTS "${_file}")
        vcpkg_replace_string(${_file} "-l${_package}" "-l${_package}d")
    endif()
endforeach()

vcpkg_fixup_pkgconfig()

configure_file("${CMAKE_CURRENT_LIST_DIR}/vcpkg-cmake-wrapper.cmake" "${CURRENT_PACKAGES_DIR}/share/${PORT}/vcpkg-cmake-wrapper.cmake" COPYONLY)

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
