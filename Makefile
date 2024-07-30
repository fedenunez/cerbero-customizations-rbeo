
CERBERO_VERSION=1.24
GITHASH=$(shell git log -1 --pretty=format:"%h") 
BUILD_VERSION=$(CERBERO_VERSION)_$(GITHASH)
C_FOLDER=cerbero-$(CERBERO_VERSION)
RECIPE_FILES := $(wildcard ./recipes/*)  $(wildcard ./packages/*)  
TARGET_FILES := $(patsubst ./%, $(C_FOLDER)/%,$(RECIPE_FILES))  # List of the same files targeted to $(C_FOLDER)/..

usage:
	@echo "make [ios/android]"
	@echo $(TARGET_FILES)

$(C_FOLDER):
	mkdir $(C_FOLDER)

./$(C_FOLDER)/recipes/%: ./recipes/%
	@echo "Linking local recipe $< to $@"
	ln -sr $< $@


./$(C_FOLDER)/packages/%: ./packages/%
	@echo "Linking local package $< to $@"
	ln -sr $< $@


$(C_FOLDER):
	git clone --branch $(CERBERO_VERSION) https://gitlab.freedesktop.org/gstreamer/cerbero $(C_FOLDER)

clean-android:
	cd $(C_FOLDER); \
	./cerbero-uninstalled -c config/cross-android-universal.cbc wipe

clean-ios:
	cd $(C_FOLDER); \
	./cerbero-uninstalled -c config/cross-ios-universal.cbc wipe

clean:
	@echo use make clean-io or make clean-android


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
