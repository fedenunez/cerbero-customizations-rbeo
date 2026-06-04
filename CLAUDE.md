# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A set of **Cerbero customizations** that cross-compile open-source crypto/networking
libraries (gnutls, nettle, gmp, libtasn1, libcurl, libevent, gnustl) into a single
distributable bundle (`rbeolibs`) for **iOS** (Framework / `.pkg`) and **Android**
(`tar.gz`), consumed by the BeoLivingApp mobile app.

[Cerbero](https://gitlab.freedesktop.org/gstreamer/cerbero) is GStreamer's
multi-platform build aggregator. This repo does **not** vendor it — it provides only
the *missing recipes* and the *packaging definitions*, then layers them onto a
checked-out Cerbero tree.

## Build commands

```bash
make ios        # bootstrap + package rbeolibs for iOS (config/cross-ios-universal.cbc)
make android    # runs android-host (bootstrap) then android-target (package)
make clean-ios       # cerbero wipe for the iOS config
make clean-android   # cerbero wipe for the Android config
```

- `make clean` does nothing useful — it only prints a reminder. Use `clean-ios` /
  `clean-android`. **Always run the matching clean when switching target platform.**
- `make <target>` first clones Cerbero (`git clone --branch $(CERBERO_VERSION)
  https://gitlab.freedesktop.org/gstreamer/cerbero cerbero-$(CERBERO_VERSION)`) if the
  `cerbero-1.28/` dir is absent, then symlinks every file in `recipes/` and `packages/`
  into the corresponding folder inside the Cerbero tree, then invokes Cerbero.
- The Cerbero checkout (`cerbero-*/`) is **git-ignored** — it is generated, never edited
  in place for permanent changes. Edits belong in `recipes/` / `packages/` at the repo root.
- `BUILD_VERSION` (`$(CERBERO_VERSION)_$(git short-hash)`) is exported into the package
  step and, if set, overrides the package `version`. Bump `CERBERO_VERSION` in the
  `Makefile` to target a different Cerbero release.

### Working on a single recipe/package

After a `make` has linked the files in, drop into the Cerbero tree and run it directly:

```bash
cd cerbero-1.28
./cerbero-uninstalled -c config/cross-ios-universal.cbc build <recipe>
./cerbero-uninstalled -c config/cross-ios-universal.cbc package rbeolibs
```

## Architecture / how the pieces fit

- **`recipes/*.recipe`** — one Python `class Recipe(recipe.Recipe)` per library. Defines
  source (`url`/`tarball_checksum` or git `remotes`/`commit`), `deps`, `configure_options`,
  `patches`, and `files_*` lists (which built artifacts land in which package category:
  `files_libs`, `files_devel`, `files_bins`, `files_lang`, `files_stl`, ...).
  Per-platform tweaks go in `prepare()` / overridden `configure()`, branching on
  `self.config.target_platform` (`Platform.IOS` / `ANDROID` / `DARWIN` / `WINDOWS`).
  These names (`recipe`, `package`, `Platform`, `License`, `SourceType`, `BuildType`,
  `Architecture`) are injected into the recipe namespace by Cerbero at load time — they
  are not imported, so the files only make sense inside a Cerbero tree.
- **`recipes/<name>/*.patch`** — patches referenced by a recipe's `patches = [...]`,
  applied to upstream source. Mostly cross-compilation / iOS-assembly / NDK fixes.
- **`packages/rbeolibs.package`** — the top-level `SDKPackage`. Sets framework/install
  layout per platform, UUIDs, and lists sub-packages. This is the build target name
  passed to `cerbero ... package rbeolibs`.
- **`packages/rbeolibs-base.package`** — the `Package` that enumerates the actual
  libraries to ship via `files` / `files_devel`, using `recipe:category` selectors
  (e.g. `'glib:libs:lang:bins:schemas'`, `'openssl:libs'`). To add/remove a shipped
  library, edit these lists.

When adding a new library: write `recipes/<name>.recipe` (+ any patches under
`recipes/<name>/`), reference it in `packages/rbeolibs-base.package`'s `files` list, then
`make` — the Makefile's symlink rules pick up new files automatically.

## Our recipes vs. upstream 1.28

Every tracked file in this repo (all authored by fna / `fna@khimo.com`) is a
customization injected on top of stock Cerbero — together they are the complete delta
that produces `rbeolibs`. As of the 1.28 bump, our recipes fall into three buckets, and
the bucket matters when editing or debugging:

- **Self-contained (upstream removed them)** — `gnutls`, `nettle`, `libtasn1`,
  `libevent`. Cerbero 1.28 **deleted** these recipes (GStreamer moved TLS to
  OpenSSL + `glib-networking`). They no longer override anything — they are the *only*
  definition. The symlink step adds them as brand-new files in the Cerbero `recipes/`
  dir, so there is no upstream version to diff against. We own them outright, pinned at
  their last-known-good versions (gnutls 3.6.11.1, nettle 3.4.1, libtasn1 4.13,
  libevent 2.1.12). `libevent`'s `patches` list is fully commented out, so the patch
  files under `recipes/libevent/*/` are currently dead weight.
- **Coexist with a differently-keyed upstream recipe** — `libcurl` and `gmp`. Upstream
  1.28 ships `curl` (CMake-based, v8.x) and a *toolchain-only* `recipes-toolchain/gmp.recipe`
  (v6.3.0). The symlink step adds our `recipes/libcurl.recipe` (name `libcurl`, v7.74)
  and `recipes/gmp.recipe` (name `gmp`, v6.1.2) alongside them. `rbeolibs-base.package`
  references `libcurl`/`gmp`, so it resolves to *ours*. Watch for two things: (1) both
  our `curl`-equivalent and upstream `curl` exist in the tree, and (2) our `gmp` shares
  the name `gmp` with the toolchain recipe — verify no namespace clash if a build errors.
- **Pure upstream (referenced, not shipped as a recipe)** — `libnice`, `glib`,
  `openssl`, `libffi`, `libiconv`, `zlib`, `proxy-libintl`, `pcre2`, plus `gnustl`
  (Android STL helper, custom `SourceType.CUSTOM`). These are pulled in by name via the
  `rbeolibs-base.package` `files` selectors and built from upstream 1.28's recipes.

**Build validity is not guaranteed by the file bump.** The recipe files apply cleanly
onto 1.28 (verified by replaying fna's commits onto the upstream tree — only `Makefile`,
`.gitignore`, `README.md` ever conflicted, never a recipe). But the *self-contained*
recipes are pinned at old versions and were last validated against 1.24's toolchains
(NDK/Xcode) and Cerbero recipe APIs. A first `make ios` / `make android` on 1.28 is the
real test; expect to fix version/API drift in those four recipes before it builds.
