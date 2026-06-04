# rbeolibs.cmake
#
# Exposes a prebuilt rbeolibs bundle as a single imported target:
#
#     rbeolibs::rbeolibs
#
# Quick start
# -----------
#     set(RBEOLIBS_ROOT "/path/to/extracted/rbeolibs")   # or pass -DRBEOLIBS_ROOT=...
#     include("/path/to/rbeolibs.cmake")
#     target_link_libraries(myapp PRIVATE rbeolibs::rbeolibs)
#
# RBEOLIBS_ROOT
#   Linux    : the extracted prefix (has lib/, include/, lib/pkgconfig/).
#   Android  : the directory that CONTAINS the per-ABI prefixes
#              (armeabi-v7a/, arm64-v8a/, x86/, x86_64/); the correct one is
#              auto-selected from ${ANDROID_ABI}. If RBEOLIBS_ROOT already points
#              at a single-ABI prefix, that prefix is used as-is.
#   iOS/macOS: the directory that contains Rbeolibs.framework.
#
# RBEOLIBS_MODULES (optional)
#   pkg-config modules to expose. Defaults to the common networking/glib set;
#   override to add more, e.g.:
#       set(RBEOLIBS_MODULES glib-2.0 gio-2.0 nice libcurl libevent gstreamer-1.0)

if(TARGET rbeolibs::rbeolibs)
    return()
endif()

if(NOT DEFINED RBEOLIBS_ROOT)
    set(RBEOLIBS_ROOT "${CMAKE_CURRENT_LIST_DIR}"
        CACHE PATH "Root of the extracted rbeolibs bundle")
endif()

if(NOT DEFINED RBEOLIBS_MODULES)
    set(RBEOLIBS_MODULES glib-2.0 gobject-2.0 gio-2.0 gmodule-2.0 nice libcurl libevent)
endif()

# Resolve the actual prefix (descend into the per-ABI dir on Android).
set(_rbeo_prefix "${RBEOLIBS_ROOT}")
if(ANDROID AND DEFINED ANDROID_ABI AND IS_DIRECTORY "${RBEOLIBS_ROOT}/${ANDROID_ABI}")
    set(_rbeo_prefix "${RBEOLIBS_ROOT}/${ANDROID_ABI}")
endif()

add_library(rbeolibs::rbeolibs INTERFACE IMPORTED)

# --- Apple: the bundle is a single framework ----------------------------------
if(APPLE AND EXISTS "${_rbeo_prefix}/Rbeolibs.framework")
    target_include_directories(rbeolibs::rbeolibs INTERFACE
        "${_rbeo_prefix}/Rbeolibs.framework/Headers")
    target_link_options(rbeolibs::rbeolibs INTERFACE
        "-F${_rbeo_prefix}" "-framework" "Rbeolibs")
    message(STATUS "rbeolibs: using Rbeolibs.framework at ${_rbeo_prefix}")
    return()
endif()

if(NOT IS_DIRECTORY "${_rbeo_prefix}/lib")
    message(FATAL_ERROR
        "rbeolibs: '${_rbeo_prefix}/lib' not found. Point RBEOLIBS_ROOT at the "
        "extracted bundle (on Android, at the directory holding the per-ABI prefixes).")
endif()

# --- Prefer pkg-config: correct transitive cflags/libs ------------------------
# The bundle's .pc files are relocatable (prefix=${pcfiledir}/../..), so they
# resolve wherever the bundle was extracted.
find_package(PkgConfig QUIET)
if(PkgConfig_FOUND AND IS_DIRECTORY "${_rbeo_prefix}/lib/pkgconfig")
    # LIBDIR (not PATH) so it cannot fall back to host .pc files.
    set(ENV{PKG_CONFIG_LIBDIR} "${_rbeo_prefix}/lib/pkgconfig")
    pkg_check_modules(_RBEO QUIET IMPORTED_TARGET ${RBEOLIBS_MODULES})
    if(_RBEO_FOUND)
        target_link_libraries(rbeolibs::rbeolibs INTERFACE PkgConfig::_RBEO)
        message(STATUS "rbeolibs: linked via pkg-config (${RBEOLIBS_MODULES})")
        return()
    endif()
    message(WARNING "rbeolibs: pkg-config could not resolve [${RBEOLIBS_MODULES}]; "
                    "falling back to globbing ${_rbeo_prefix}/lib")
endif()

# --- Fallback: include/ + link every library under lib/ -----------------------
target_include_directories(rbeolibs::rbeolibs INTERFACE "${_rbeo_prefix}/include")
file(GLOB _rbeo_libs
    "${_rbeo_prefix}/lib/*.so" "${_rbeo_prefix}/lib/*.so.*"
    "${_rbeo_prefix}/lib/*.a" "${_rbeo_prefix}/lib/*.dylib")
if(NOT _rbeo_libs)
    message(FATAL_ERROR "rbeolibs: no libraries found under ${_rbeo_prefix}/lib")
endif()
target_link_libraries(rbeolibs::rbeolibs INTERFACE ${_rbeo_libs})
message(STATUS "rbeolibs: linked ${_rbeo_prefix}/lib (glob fallback, no pkg-config)")
