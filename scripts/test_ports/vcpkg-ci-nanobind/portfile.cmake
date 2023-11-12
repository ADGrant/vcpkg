set(VCPKG_POLICY_EMPTY_PACKAGE enabled)
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO wjakob/nanobind_example
    REF cc116d7c87d2e19c9c8146464c6ae7ed17620eec
    SHA512 cdb0eb09b1c03c0dea291daf876a85f9d5641f57747786cd2289d0aa4c8e3f34bd2809c351b3231fb80a358615086ee0e687ce23999a9ae012f75b000bdeef10
    HEAD_REF master
)

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")

vcpkg_cmake_build()
