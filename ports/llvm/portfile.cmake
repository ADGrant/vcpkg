set(LLVM_VERSION "14.0.6")

vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO llvm/llvm-project
    REF llvmorg-${LLVM_VERSION}
    SHA512 d64f97754c24f32deb5f284ebbd486b3a467978b7463d622f50d5237fff91108616137b4394f1d1ce836efa59bf7bec675b6dee257a79b241c15be52d4697460
    HEAD_REF main
    PATCHES
        0001-fix-install-tools-path.patch
        0004-fix-dr-1734.patch
        0005-fix-tools-path.patch
        0010-fix-libffi.patch
        0011-fix-install-bolt.patch
        0012-fix-libcxx-path-install.patch
)

vcpkg_check_features(
    OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        tools LLVM_BUILD_TOOLS
        tools LLVM_INCLUDE_TOOLS
        utils LLVM_BUILD_UTILS
        utils LLVM_INCLUDE_UTILS
        utils LLVM_INSTALL_UTILS
        enable-rtti LLVM_ENABLE_RTTI
        enable-ffi LLVM_ENABLE_FFI
        enable-terminfo LLVM_ENABLE_TERMINFO
        enable-threads LLVM_ENABLE_THREADS
        enable-eh LLVM_ENABLE_EH
        enable-bindings LLVM_ENABLE_BINDINGS
)

vcpkg_cmake_get_vars(cmake_vars_file)
include("${cmake_vars_file}")

# LLVM generates CMake error due to Visual Studio version 16.4 is known to miscompile part of LLVM.
# LLVM_TEMPORARILY_ALLOW_OLD_TOOLCHAIN=ON disables this error.
# See https://developercommunity.visualstudio.com/content/problem/845933/miscompile-boolean-condition-deduced-to-be-always.html
# and thread "[llvm-dev] Longstanding failing tests - clang-tidy, MachO, Polly" on llvm-dev Jan 21-23 2020.
list(APPEND FEATURE_OPTIONS
    -DLLVM_TEMPORARILY_ALLOW_OLD_TOOLCHAIN=ON
)

# Force enable or disable external libraries
set(llvm_external_libraries
    zlib
    libxml2
)
foreach(external_library IN LISTS llvm_external_libraries)
    string(TOLOWER "enable-${external_library}" feature_name)
    string(TOUPPER "LLVM_ENABLE_${external_library}" define_name)
    if(feature_name IN_LIST FEATURES)
        list(APPEND FEATURE_OPTIONS
            -D${define_name}=FORCE_ON
        )
    else()
        list(APPEND FEATURE_OPTIONS
            -D${define_name}=OFF
        )
    endif()
endforeach()

# By default assertions are enabled for Debug configuration only.
if("enable-assertions" IN_LIST FEATURES)
    # Force enable assertions for all configurations.
    list(APPEND FEATURE_OPTIONS
        -DLLVM_ENABLE_ASSERTIONS=ON
    )
elseif("disable-assertions" IN_LIST FEATURES)
    # Force disable assertions for all configurations.
    list(APPEND FEATURE_OPTIONS
        -DLLVM_ENABLE_ASSERTIONS=OFF
    )
endif()

# LLVM_ABI_BREAKING_CHECKS can be WITH_ASSERTS (default), FORCE_ON or FORCE_OFF.
# By default in LLVM, abi-breaking checks are enabled if assertions are enabled.
# however, this breaks linking with the debug versions, since the option is
# baked into the header files; thus, we always turn off LLVM_ABI_BREAKING_CHECKS
# unless the user asks for it
if("enable-abi-breaking-checks" IN_LIST FEATURES)
    # Force enable abi-breaking checks.
    list(APPEND FEATURE_OPTIONS
        -DLLVM_ABI_BREAKING_CHECKS=FORCE_ON
    )
else()
    # Force disable abi-breaking checks.
    list(APPEND FEATURE_OPTIONS
        -DLLVM_ABI_BREAKING_CHECKS=FORCE_OFF
    )
endif()

set(LLVM_ENABLE_PROJECTS)
if("bolt" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "bolt")
endif()
if("clang" IN_LIST FEATURES OR "clang-tools-extra" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "clang")
    if("disable-clang-static-analyzer" IN_LIST FEATURES)
        list(APPEND FEATURE_OPTIONS
            # Disable ARCMT
            -DCLANG_ENABLE_ARCMT=OFF
            # Disable static analyzer
            -DCLANG_ENABLE_STATIC_ANALYZER=OFF
        )
    endif()
    if(VCPKG_TARGET_IS_OSX)
        list(APPEND FEATURE_OPTIONS
            -DDEFAULT_SYSROOT:FILEPATH=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
            -DLLVM_CREATE_XCODE_TOOLCHAIN=ON
        )
    endif()
endif()
if("clang-tools-extra" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "clang-tools-extra")
endif()
if("compiler-rt" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "compiler-rt")
endif()
if("flang" IN_LIST FEATURES)
    if(VCPKG_DETECTED_CMAKE_CXX_COMPILER_ID STREQUAL "MSVC" AND VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        message(FATAL_ERROR "Building Flang with MSVC is not supported on x86. Disable it until issues are fixed.")
    endif()
    list(APPEND LLVM_ENABLE_PROJECTS "flang")
    list(APPEND FEATURE_OPTIONS
        # Flang requires C++17
        -DCMAKE_CXX_STANDARD=17
    )
endif()
if("libclc" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "libclc")
endif()
if("lld" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "lld")
endif()
if("lldb" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "lldb")
    list(APPEND FEATURE_OPTIONS
        -DLLDB_ENABLE_CURSES=OFF
    )
endif()
if("mlir" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "mlir")
endif()
if("openmp" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "openmp")
    # Perl is required for the OpenMP run-time
    vcpkg_find_acquire_program(PERL)
    get_filename_component(PERL_PATH ${PERL} DIRECTORY)
    vcpkg_add_to_path(${PERL_PATH})
    # Skip post-build check
    set(VCPKG_POLICY_SKIP_DUMPBIN_CHECKS enabled)
endif()
if("polly" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_PROJECTS "polly")
endif()
if("pstl" IN_LIST FEATURES)
    if(VCPKG_DETECTED_CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        message(FATAL_ERROR "Building pstl with MSVC is not supported. Disable it until issues are fixed.")
    endif()
    list(APPEND LLVM_ENABLE_PROJECTS "pstl")
endif()

set(LLVM_ENABLE_RUNTIMES)
if("libcxx" IN_LIST FEATURES)
    if(VCPKG_DETECTED_CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        message(FATAL_ERROR "Building libcxx with MSVC is not supported, as cl doesn't support the #include_next extension.")
    endif()
    list(APPEND LLVM_ENABLE_RUNTIMES "libcxx")
endif()
if("libcxxabi" IN_LIST FEATURES)
    if(VCPKG_DETECTED_CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        message(FATAL_ERROR "Building libcxxabi with MSVC is not supported. Disable it until issues are fixed.")
    endif()
    list(APPEND LLVM_ENABLE_RUNTIMES "libcxxabi")
endif()
if("libunwind" IN_LIST FEATURES)
    list(APPEND LLVM_ENABLE_RUNTIMES "libunwind")
endif()

# this is for normal targets
set(known_llvm_targets
    AArch64
    AMDGPU
    ARM
    AVR
    BPF
    Hexagon
    Lanai
    Mips
    MSP430
    NVPTX
    PowerPC
    RISCV
    Sparc
    SystemZ
    VE
    WebAssembly
    X86
    XCore
)

set(LLVM_TARGETS_TO_BUILD "")
foreach(llvm_target IN LISTS known_llvm_targets)
    string(TOLOWER "target-${llvm_target}" feature_name)
    if(feature_name IN_LIST FEATURES)
        list(APPEND LLVM_TARGETS_TO_BUILD "${llvm_target}")
    endif()
endforeach()

# this is for experimental targets
set(known_llvm_experimental_targets
    SPRIV
)

set(LLVM_EXPERIMENTAL_TARGETS_TO_BUILD "")
foreach(llvm_target IN LISTS known_llvm_experimental_targets)
    string(TOLOWER "target-${llvm_target}" feature_name)
    if(feature_name IN_LIST FEATURES)
        list(APPEND LLVM_EXPERIMENTAL_TARGETS_TO_BUILD "${llvm_target}")
    endif()
endforeach()

vcpkg_find_acquire_program(PYTHON3)
get_filename_component(PYTHON3_DIR ${PYTHON3} DIRECTORY)
vcpkg_add_to_path(${PYTHON3_DIR})

set(LLVM_LINK_JOBS 1)

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}/llvm
    OPTIONS
        ${FEATURE_OPTIONS}
        -DLLVM_INCLUDE_EXAMPLES=OFF
        -DLLVM_BUILD_EXAMPLES=OFF
        -DLLVM_INCLUDE_TESTS=OFF
        -DLLVM_BUILD_TESTS=OFF
        -DLLVM_INCLUDE_BENCHMARKS=OFF
        -DLLVM_BUILD_BENCHMARKS=OFF
        # Force TableGen to be built with optimization. This will significantly improve build time.
        -DLLVM_OPTIMIZED_TABLEGEN=ON
        "-DLLVM_ENABLE_PROJECTS=${LLVM_ENABLE_PROJECTS}"
        "-DLLVM_ENABLE_RUNTIMES=${LLVM_ENABLE_RUNTIMES}"
        "-DLLVM_TARGETS_TO_BUILD=${LLVM_TARGETS_TO_BUILD}"
        "-DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=${LLVM_EXPERIMENTAL_TARGETS_TO_BUILD}"
        -DPACKAGE_VERSION=${LLVM_VERSION}
        # Limit the maximum number of concurrent link jobs to 1. This should fix low amount of memory issue for link.
        "-DLLVM_PARALLEL_LINK_JOBS=${LLVM_LINK_JOBS}"
        -DLLVM_TOOLS_INSTALL_DIR=tools/llvm/bin
)

vcpkg_cmake_install(ADD_BIN_TO_PATH)

# 'package_name' should be the case of the package used in CMake 'find_package'
# 'FEATURE_NAME' should be the name of the vcpkg port feature
function(llvm_cmake_package_config_fixup package_name)
    cmake_parse_arguments("arg" "DO_NOT_DELETE_PARENT_CONFIG_PATH" "FEATURE_NAME" "" ${ARGN})
    string(TOUPPER "${package_name}" upper_package)
    string(TOLOWER "${package_name}" lower_package)
    if(NOT DEFINED arg_FEATURE_NAME)
        set(arg_FEATURE_NAME ${lower_package})
    endif()
    if("${lower_package}" STREQUAL "${PORT}" OR "${arg_FEATURE_NAME}" IN_LIST FEATURES)
        set(args)
        # Maintains case even if package_name name is case-sensitive
        list(APPEND args PACKAGE_NAME "${lower_package}")
        list(APPEND args TOOLS_PATH "tools/${PORT}/bin")
        # TODO: There is a LLVM_LIBDIR_SUFFIX attached to 'lib' that might make this not work for everyone
        list(APPEND args CONFIG_PATH "lib/cmake/${lower_package}")
        if(arg_DO_NOT_DELETE_PARENT_CONFIG_PATH)
            list(APPEND args "DO_NOT_DELETE_PARENT_CONFIG_PATH")
        endif()
        vcpkg_cmake_config_fixup(${args})
        file(INSTALL "${SOURCE_PATH}/${lower_package}/LICENSE.TXT" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${lower_package}" RENAME copyright)

        # Fixup paths
        vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/${lower_package}/${package_name}Config.cmake" "lib/cmake" "share")
        # Remove last parent directory
        vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/${lower_package}/${package_name}Config.cmake" "get_filename_component(${upper_package}_INSTALL_PREFIX \"\${${upper_package}_INSTALL_PREFIX}\" PATH)\n\n" "\n")

        if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/${lower_package}_usage")
            file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/${lower_package}_usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${lower_package}" RENAME usage)
        endif()
    endif()
endfunction()

llvm_cmake_package_config_fixup("Clang" DO_NOT_DELETE_PARENT_CONFIG_PATH)
llvm_cmake_package_config_fixup("Flang" DO_NOT_DELETE_PARENT_CONFIG_PATH)
llvm_cmake_package_config_fixup("LLD" DO_NOT_DELETE_PARENT_CONFIG_PATH)
llvm_cmake_package_config_fixup("MLIR" DO_NOT_DELETE_PARENT_CONFIG_PATH)
llvm_cmake_package_config_fixup("Polly" DO_NOT_DELETE_PARENT_CONFIG_PATH)
llvm_cmake_package_config_fixup("ParallelSTL" FEATURE_NAME "pstl" DO_NOT_DELETE_PARENT_CONFIG_PATH)
llvm_cmake_package_config_fixup("LLVM")

# Move the clang headers directory so that the built compiler can use the includes
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/tools/llvm/lib")
file(RENAME "${CURRENT_PACKAGES_DIR}/lib/clang" "${CURRENT_PACKAGES_DIR}/tools/llvm/lib/clang")

set(empty_dirs)

if("clang-tools-extra" IN_LIST FEATURES)
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/include/clang-tidy/plugin")
endif()

if("flang" IN_LIST FEATURES)
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/include/flang/Config")
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/include/flang/CMakeFiles")
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/include/flang/Optimizer/CMakeFiles")
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/include/flang/Optimizer/CodeGen/CMakeFiles")
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/include/flang/Optimizer/Dialect/CMakeFiles")
    list(APPEND empty_dirs "${CURRENT_PACKAGES_DIR}/include/flang/Optimizer/Transforms/CMakeFiles")
endif()

if(empty_dirs)
    foreach(empty_dir IN LISTS empty_dirs)
        if(NOT EXISTS "${empty_dir}")
            message(SEND_ERROR "Directory '${empty_dir}' is not exist. Please remove it from the checking.")
        else()
            file(GLOB_RECURSE files_in_dir "${empty_dir}/*")
            if(files_in_dir)
                message(SEND_ERROR "Directory '${empty_dir}' is not empty. Please remove it from the checking.")
            else()
                file(REMOVE_RECURSE "${empty_dir}")
            endif()
        endif()
    endforeach()
endif()

if(NOT DEFINED VCPKG_BUILD_TYPE OR VCPKG_BUILD_TYPE STREQUAL "debug")
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include"
        "${CURRENT_PACKAGES_DIR}/debug/share"
        "${CURRENT_PACKAGES_DIR}/debug/tools"
        "${CURRENT_PACKAGES_DIR}/debug/lib/clang"
    )
endif()

if("mlir" IN_LIST FEATURES)
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/mlir/MLIRConfig.cmake" "set(MLIR_MAIN_SRC_DIR \"${SOURCE_PATH}/mlir\")" "")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/mlir/MLIRConfig.cmake" "${CURRENT_BUILDTREES_DIR}" "\${MLIR_INCLUDE_DIRS}")
endif()

vcpkg_copy_tool_dependencies("${CURRENT_PACKAGES_DIR}/tools/llvm/bin")

# LLVM still generates a few DLLs in the static build:
# * LLVM-C.dll
# * libclang.dll
# * LTO.dll
# * Remarks.dll
set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled)
