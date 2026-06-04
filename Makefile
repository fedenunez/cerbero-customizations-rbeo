
CERBERO_VERSION=1.28
GITHASH=$(shell git log -1 --pretty=format:"%h") 
BUILD_VERSION=$(CERBERO_VERSION)_$(GITHASH)
C_FOLDER=cerbero-$(CERBERO_VERSION)
RECIPE_FILES := $(wildcard ./recipes/*)  $(wildcard ./packages/*)  
TARGET_FILES := $(patsubst ./%, $(C_FOLDER)/%,$(RECIPE_FILES))  # List of the same files targeted to $(C_FOLDER)/..

usage:
	@echo "make [ios/android/macos/linux]"
	@echo $(TARGET_FILES)

$(C_FOLDER):
	mkdir $(C_FOLDER)

# Force-symlink every local recipe/package into the Cerbero tree, OVERWRITING any
# upstream file of the same name (ln -sfn). This is what lets our overrides (e.g.
# gst-plugins-bad-1.0) actually shadow the upstream recipe: a plain `ln -s` is
# skipped by make when the freshly-cloned upstream file looks newer, and errors on
# an existing target. Runs every build; ln -sfn is idempotent.
.PHONY: symlinks
symlinks: $(C_FOLDER)
	@for f in $(patsubst ./%,%,$(RECIPE_FILES)); do \
	  echo "Linking $$f -> $(C_FOLDER)/$$f"; \
	  ln -sfn "$(CURDIR)/$$f" "$(CURDIR)/$(C_FOLDER)/$$f"; \
	done


$(C_FOLDER):
	git clone --branch $(CERBERO_VERSION) https://gitlab.freedesktop.org/gstreamer/cerbero $(C_FOLDER)

clean-android:
	cd $(C_FOLDER); \
	./cerbero-uninstalled -c config/cross-android-universal.cbc wipe

clean-ios:
	cd $(C_FOLDER); \
	./cerbero-uninstalled -c config/cross-ios-universal.cbc wipe

clean-macos:
	cd $(C_FOLDER); \
	./cerbero-uninstalled -c config/cross-macos-universal.cbc wipe

# Linux builds natively against the host; run on a Linux host (no cross config).
clean-linux:
	cd $(C_FOLDER); \
	./cerbero-uninstalled wipe

clean:
	@echo use make clean-ios / clean-android / clean-macos / clean-linux


ios: symlinks 
	cd $(C_FOLDER) ; \
  ./cerbero-uninstalled -c config/cross-ios-universal.cbc bootstrap; \
	BUILD_VERSION=$(BUILD_VERSION)\
  ./cerbero-uninstalled -c config/cross-ios-universal.cbc package rbeolibs
  

android-host: symlinks 
	cd $(C_FOLDER) ; \
  ./cerbero-uninstalled -c config/cross-android-universal.cbc bootstrap ; 

android-target: symlinks 
	cd $(C_FOLDER) ; \
	BUILD_VERSION=$(BUILD_VERSION) \
  ./cerbero-uninstalled -c config/cross-android-universal.cbc package rbeolibs

android: symlinks  android-host android-target

macos: symlinks
	cd $(C_FOLDER) ; \
  ./cerbero-uninstalled -c config/cross-macos-universal.cbc bootstrap; \
	BUILD_VERSION=$(BUILD_VERSION) \
  ./cerbero-uninstalled -c config/cross-macos-universal.cbc package rbeolibs

# Linux: native build — must be run on a Linux host (no cross config = host target).
linux: symlinks
	cd $(C_FOLDER) ; \
  ./cerbero-uninstalled bootstrap; \
	BUILD_VERSION=$(BUILD_VERSION) \
  ./cerbero-uninstalled package rbeolibs
