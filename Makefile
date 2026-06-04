
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

./$(C_FOLDER)/recipes/%: ./recipes/%
	@echo "Linking local recipe $< to $@"
	ln -s $(abspath $<) $(abspath $@)


./$(C_FOLDER)/packages/%: ./packages/%
	@echo "Linking local package $< to $@"
	ln -s $(abspath $<) $(abspath $@)


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


ios: $(C_FOLDER) $(TARGET_FILES) 
	cd $(C_FOLDER) ; \
  ./cerbero-uninstalled -c config/cross-ios-universal.cbc bootstrap; \
	BUILD_VERSION=$(BUILD_VERSION)\
  ./cerbero-uninstalled -c config/cross-ios-universal.cbc package rbeolibs
  

android-host: $(C_FOLDER) $(TARGET_FILES) 
	cd $(C_FOLDER) ; \
  ./cerbero-uninstalled -c config/cross-android-universal.cbc bootstrap ; 

android-target: $(C_FOLDER) $(TARGET_FILES) 
	cd $(C_FOLDER) ; \
	BUILD_VERSION=$(BUILD_VERSION) \
  ./cerbero-uninstalled -c config/cross-android-universal.cbc package rbeolibs

android: $(C_FOLDER) $(TARGET_FILES)  android-host android-target

macos: $(C_FOLDER) $(TARGET_FILES)
	cd $(C_FOLDER) ; \
  ./cerbero-uninstalled -c config/cross-macos-universal.cbc bootstrap; \
	BUILD_VERSION=$(BUILD_VERSION) \
  ./cerbero-uninstalled -c config/cross-macos-universal.cbc package rbeolibs

# Linux: native build — must be run on a Linux host (no cross config = host target).
linux: $(C_FOLDER) $(TARGET_FILES)
	cd $(C_FOLDER) ; \
  ./cerbero-uninstalled bootstrap; \
	BUILD_VERSION=$(BUILD_VERSION) \
  ./cerbero-uninstalled package rbeolibs
