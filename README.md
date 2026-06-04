# rbeolibs — native dependency bundle for BeoLivingApp

This repository builds **rbeolibs**, a single distributable bundle of open-source
networking / crypto / multimedia libraries, cross-compiled for **iOS, macOS,
Android and Linux** with [Cerbero](https://gitlab.freedesktop.org/gstreamer/cerbero)
(GStreamer's multi-platform build aggregator).

It does **not** vendor Cerbero — it only provides the *missing recipes* and the
*packaging definitions*, layered on top of a checked-out Cerbero tree (currently
**1.28**, set by `CERBERO_VERSION` in the `Makefile`).

## What's in the bundle

`libnice` (ICE/STUN/TURN + its GStreamer plugin), `glib`, `openssl`, `libcurl`,
`libevent`, `libffi`, `libiconv`, `zlib`, `pcre2`, and `proxy-libintl`
(everywhere except Linux, whose glibc already provides gettext).

## Installing a released bundle

Prebuilt bundles for every platform are published on the
[**Releases page**](https://github.com/fedenunez/cerbero-customizations-rbeo/releases).
Each release ships, per platform, a **runtime** bundle (the libraries) and a
**devel** bundle (headers + static libs / `.pc` files). Replace `<version>`
below with the release you downloaded (e.g. `1.28_5d65e09`).

### iOS

Assets: `ios-framework-<version>-universal.pkg` (runtime),
`rbeolibs-devel-<version>-ios-universal.pkg` (headers + static libs).

The runtime `.pkg` wraps `Rbeolibs.framework`. Either install the `.pkg`
(it deploys to `/Library/Developer/Rbeolibs/iPhone.sdk`) or extract the
framework directly:

```bash
pkgutil --expand-full ios-framework-<version>-universal.pkg out
# framework: out/.../Payload/Rbeolibs.framework
```

In Xcode, drag `Rbeolibs.framework` into your target →
**General → Frameworks, Libraries, and Embedded Content** (or *Build Phases →
Link Binary With Libraries*), and add the headers from the devel package to your
header search path.

> **Note:** the framework is a *fat* universal binary (device `arm64` +
> simulator `x86_64`). That's fine for local builds, but Xcode rejects mixed
> device+simulator slices in App Store archives, and there is no `arm64`
> **simulator** slice (Apple-Silicon Macs). For store distribution or simulator
> runs on Apple Silicon, build an `.xcframework` (Cerbero's `xcframework`
> subcommand) instead.

### macOS

Assets: `rbeolibs-<version>-universal.pkg` (runtime),
`rbeolibs-devel-<version>-universal.pkg` (devel).

Installing the runtime `.pkg` deploys `Rbeolibs.framework` to
`/Library/Frameworks/`. Link it in Xcode (it's on the default framework search
path) or embed it in your app bundle.

### Android

Assets: `rbeolibs-android-universal-<version>-runtime.tar.xz` (shared libs),
`rbeolibs-android-universal-<version>.tar.xz` (full: + headers and static libs).

```bash
tar xf rbeolibs-android-universal-<version>.tar.xz -C rbeolibs-android
```

The extracted tree contains the per-ABI (`armeabi-v7a`, `arm64-v8a`, `x86`,
`x86_64`) shared libraries and headers. Wire it into your NDK build:

- **Gradle / jniLibs:** copy each ABI's `*.so` into `src/main/jniLibs/<abi>/`.
- **CMake (`externalNativeBuild`):** add the bundle's `include/` to your include
  path and link the `.so`/`.a` from its `lib/` dir (or use the shipped
  `lib/pkgconfig/*.pc`).

### Linux (x86_64)

Assets: `rbeolibs-linux-x86_64-<version>.tar.xz` (runtime),
`rbeolibs-linux-x86_64-<version>-devel.tar.xz` (headers + `.pc`).

```bash
tar xf rbeolibs-linux-x86_64-<version>.tar.xz -C "$HOME/rbeolibs"
# build against it via pkg-config:
export PKG_CONFIG_PATH="$HOME/rbeolibs/lib/pkgconfig"
export LD_LIBRARY_PATH="$HOME/rbeolibs/lib:$LD_LIBRARY_PATH"
pkg-config --cflags --libs glib-2.0 libcurl nice
```

## Consuming from CMake

The bundle's pkg-config `.pc` files are **relocatable**
(`prefix=${pcfiledir}/../..`), so they resolve correctly wherever you extract
them — no prefix rewriting needed.

### Linux / Android — pkg-config

```cmake
find_package(PkgConfig REQUIRED)

# RBEOLIBS_ROOT = where you extracted the bundle (the per-ABI dir on Android).
# Use PKG_CONFIG_LIBDIR (not PATH) so it cannot fall back to host .pc files.
set(ENV{PKG_CONFIG_LIBDIR} "${RBEOLIBS_ROOT}/lib/pkgconfig")

pkg_check_modules(RBEO REQUIRED IMPORTED_TARGET
    glib-2.0 gobject-2.0 gio-2.0 nice libcurl libevent)

target_link_libraries(myapp PRIVATE PkgConfig::RBEO)
```

`PkgConfig::RBEO` carries the include dirs, lib dirs and transitive link flags.

### Android NDK

The bundle is **per-ABI**, so select the right prefix with `${ANDROID_ABI}`:

```cmake
set(RBEOLIBS_ROOT "${CMAKE_CURRENT_LIST_DIR}/rbeolibs-android/${ANDROID_ABI}")
```

If `pkg-config` is not available in your NDK toolchain, link with manual imported
targets instead (no pkg-config required):

```cmake
set(RBEO "${CMAKE_CURRENT_LIST_DIR}/rbeolibs-android/${ANDROID_ABI}")
add_library(rbeo::curl SHARED IMPORTED)
set_target_properties(rbeo::curl PROPERTIES
    IMPORTED_LOCATION "${RBEO}/lib/libcurl.so"
    INTERFACE_INCLUDE_DIRECTORIES "${RBEO}/include")
target_link_libraries(myapp PRIVATE rbeo::curl)   # repeat per library
```

The `.so` files must also be packaged into the APK — drop them in
`src/main/jniLibs/<abi>/` (Gradle picks them up automatically) or point
`jniLibs.srcDirs` at the bundle's `lib` dirs.

### iOS / macOS — link the framework

```cmake
find_library(RBEOLIBS Rbeolibs PATHS "${RBEOLIBS_ROOT}" REQUIRED)
target_link_libraries(myapp PRIVATE ${RBEOLIBS})
```

## Building from source

You need the host toolchains (Xcode for iOS/macOS); Cerbero's `bootstrap` step
fetches the rest (e.g. the Android NDK, Rust, CMake/Ninja).

```bash
make ios      # iOS universal framework (.pkg)
make macos    # macOS universal framework (.pkg)
make android  # Android, all ABIs (.tar.xz)
make linux    # Linux x86_64 (.tar.xz) — run on a Linux host
```

- The first run clones Cerbero into `cerbero-<version>/` (git-ignored) and
  symlinks everything in `recipes/` and `packages/` into it, then runs Cerbero.
- **When switching target platform, run the matching clean first:**
  `make clean-ios | clean-macos | clean-android | clean-linux`
  (`make clean` only prints a reminder).
- `BUILD_VERSION` (`<CERBERO_VERSION>_<git-short-hash>`) is stamped into the
  package version. Bump `CERBERO_VERSION` in the `Makefile` to target another
  Cerbero release.

### Working on a single recipe / package

After a `make` has linked the files in, drive Cerbero directly:

```bash
cd cerbero-1.28
./cerbero-uninstalled -c config/cross-ios-universal.cbc build <recipe>
./cerbero-uninstalled -c config/cross-ios-universal.cbc package rbeolibs
```

(macOS: `config/cross-macos-universal.cbc`; Android:
`config/cross-android-universal.cbc`; Linux: no `-c` flag — native host build.)

## Continuous builds & releases

`.github/workflows/build-and-release.yml` builds all four platforms on GitHub
Actions:

- **Push a `v*` tag** → builds every platform and publishes a GitHub **Release**
  with all bundles attached (only when *all four* platforms succeed).
- **Manual "Run workflow"** → builds and uploads the bundles as downloadable
  **artifacts** (no Release).

GitHub Actions (including the macOS runners) is free with unlimited minutes on
public repositories.

## Licensing

The bundled libraries are **LGPL-2.1+ / BSD** and are fine to use in
**closed-source**, commercial App Store / Play Store apps. The one obligation is
LGPL *relinking*: ship the libraries dynamically (framework / `.so`) — or provide
the object files so a user could relink — and include the LGPL attribution
notices. **Your own application source stays private.** GPL / patent-encumbered
plugins are deliberately excluded.

## Extending

Add `recipes/<name>.recipe` (plus any patches under `recipes/<name>/`) and
reference it in `packages/rbeolibs-base.package`'s `files`, then run `make` — the
Makefile's symlink rules pick up new files automatically. See `CLAUDE.md` for the
full architecture and the 1.28 recipe layout.
