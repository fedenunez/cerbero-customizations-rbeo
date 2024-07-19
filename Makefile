
CERBERO_VERSION=1.24
C_FOLDER=cerbero-$(CERBERO_VERSION)
RECIPE_FILES := $(wildcard ./recipes/*.recipe)  # Variable containing all .recipe files in the ./recipes/ directory
TARGET_FILES := $(patsubst ./recipes/%, $(C_FOLDER)/recipes/%,$(RECIPE_FILES))  # List of the same files targeted to $(C_FOLDER)/recipes/

usage:
	@echo "make [ios/android]"

$(C_FOLDER):
	mkdir $(C_FOLDER)

./$(C_FOLDER)/recipes/%.recipe: ./recipes/%.recipe
	@echo "Converting $< to $@"
	ln -sr $< $@
	# Add your conversion command here, e.g., cp $< $@


$(C_FOLDER):
	git clone --branch $(CERBERO_VERSION) https://gitlab.freedesktop.org/gstreamer/cerbero $(C_FOLDER)

clean-ios:
	cd $(C_FOLDER); \
	./cerbero-uninstalled -c config/cross-ios-universal.cbc wipe


ios: $(C_FOLDER) $(TARGET_FILES) 
	cd $(C_FOLDER) ; \
  ./cerbero-uninstalled -c config/cross-ios-universal.cbc bootstrap; \
  ./cerbero-uninstalled -c config/cross-ios-universal.cbc packages rbeolibs
  

android: $(C_FOLDER) $(TARGET_FILES) 
	cd $(C_FOLDER) ; \
  ./cerbero-uninstalled -c config/cross-android-universal.cbc bootstrap ; \
  ./cerbero-uninstalled -c config/cross-android-universal.cbc packages rbeolibs
