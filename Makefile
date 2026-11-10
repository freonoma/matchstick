APP_NAME := Matchstick
CONFIG   ?= release
BUILD    := build
APP      := $(BUILD)/$(APP_NAME).app
VERSION  := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
BUNDLE_ID := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" Resources/Info.plist)
DMG      := $(BUILD)/$(APP_NAME)_$(VERSION).dmg

# "-" signs ad hoc, which is all a copy for your own Mac needs. To share a
# build, sign it with a Developer ID:
#   make dmg SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
SIGNING_IDENTITY ?= -
ifneq ($(SIGNING_IDENTITY),-)
SIGN_FLAGS := --options runtime --timestamp
endif

# Extra flags for swift build. The dmg target uses them to build for both
# Apple silicon and Intel.
ARCHS ?=

.PHONY: app run debug install icon dmg notarize clean

# Build the binary and wrap it into a signed app bundle. A release build
# loses its debug entries, which name the folder it was built in.
app:
	swift build -c $(CONFIG) $(ARCHS)
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp "$$(swift build -c $(CONFIG) $(ARCHS) --show-bin-path)/$(APP_NAME)" $(APP)/Contents/MacOS/
ifeq ($(CONFIG),release)
	strip -S $(APP)/Contents/MacOS/$(APP_NAME)
endif
	cp Resources/Info.plist $(APP)/Contents/
	cp Resources/AppIcon.icns $(APP)/Contents/Resources/
	codesign --force $(SIGN_FLAGS) --sign "$(SIGNING_IDENTITY)" $(APP)

# Replace any running copy with the fresh build.
run: app
	@pkill -x $(APP_NAME) || true
	open -n $(APP)

# Debug builds add a 1 minute timer for testing.
debug:
	$(MAKE) run CONFIG=debug

install: app
	@pkill -x $(APP_NAME) || true
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP) /Applications/

# Redraw the app icon. It uses the same drawing code as the menu bar icon.
icon:
	mkdir -p $(BUILD)
	swiftc Sources/Matchstick/MatchIcon.swift Scripts/AppIcon/main.swift -o $(BUILD)/appicon
	$(BUILD)/appicon Resources/AppIcon.icns

# A disk image with the app and a shortcut to the Applications folder. The
# old image goes first, so a failed build can't leave it behind as the new one.
dmg:
	rm -rf $(BUILD)/dmg $(DMG) $(DMG).sha256
	$(MAKE) app ARCHS="--arch arm64 --arch x86_64"
	mkdir -p $(BUILD)/dmg
	cp -R $(APP) $(BUILD)/dmg/
	ln -s /Applications $(BUILD)/dmg/Applications
	hdiutil create -volname $(APP_NAME) -srcfolder $(BUILD)/dmg -format UDZO $(DMG)
	rm -rf $(BUILD)/dmg
ifneq ($(SIGNING_IDENTITY),-)
	codesign --force --timestamp --identifier $(BUNDLE_ID).dmg --sign "$(SIGNING_IDENTITY)" $(DMG)
endif

# Have Apple notarize the disk image, attach the ticket and write a checksum.
# Needs a Developer ID signature and a notarytool keychain profile:
#   make notarize SIGNING_IDENTITY="..." NOTARY_PROFILE=your-profile
notarize:
	@test -n "$(SIGNING_IDENTITY)" -a "$(SIGNING_IDENTITY)" != "-" -a -n "$(NOTARY_PROFILE)" || \
		{ echo "notarize needs SIGNING_IDENTITY and NOTARY_PROFILE"; exit 1; }
	$(MAKE) dmg
	xcrun notarytool submit $(DMG) --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple $(DMG)
	cd $(BUILD) && shasum -a 256 $(notdir $(DMG)) > $(notdir $(DMG)).sha256

clean:
	rm -rf .build $(BUILD)
