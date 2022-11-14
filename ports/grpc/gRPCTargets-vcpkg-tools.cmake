file(GLOB GRPC_PLUGINS "${_IMPORT_PREFIX}/../${VCPKG_HOST_TRIPLET}/tools/grpc/grpc_*_plugin*")

foreach(PLUGIN ${GRPC_PLUGINS})
  get_filename_component(PLUGIN_NAME "${PLUGIN}" NAME_WE)
  if(NOT TARGET gRPC::${PLUGIN_NAME})
    add_executable(gRPC::${PLUGIN_NAME} IMPORTED)
  endif()
  set_property(TARGET gRPC::${PLUGIN_NAME} APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
  set_target_properties(gRPC::${PLUGIN_NAME} PROPERTIES
    IMPORTED_LOCATION_RELEASE "${PLUGIN}"
  )
endforeach()
