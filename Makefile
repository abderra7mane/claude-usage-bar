APP_NAME := ClaudeUsageBar
BUILD_DIR = $(shell swift build -c release --show-bin-path)
APP_BUNDLE := build/$(APP_NAME).app
INSTALL_DIR := /Applications
DMG := build/$(APP_NAME).dmg
SPARKLE_BIN := .build/artifacts/sparkle/Sparkle/bin
SPARKLE_ACCOUNT := claude-usage-bar

.PHONY: build test icon app dist appcast updater-key run install uninstall clean

build:
	swift build -c release

test:
	swift test

icon:
	rm -rf build/AppIcon.iconset
	mkdir -p build
	swift Scripts/generate-icon.swift build/AppIcon.iconset
	iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns

app: build
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources" "$(APP_BUNDLE)/Contents/Frameworks"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	ditto "$(BUILD_DIR)/Sparkle.framework" "$(APP_BUNDLE)/Contents/Frameworks/Sparkle.framework"
	cp Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	$(if $(VERSION),/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" "$(APP_BUNDLE)/Contents/Info.plist")
	$(if $(BUILD_NUMBER),/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" "$(APP_BUNDLE)/Contents/Info.plist")
	$(if $(SPARKLE_PUBLIC_KEY),/usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $(SPARKLE_PUBLIC_KEY)" "$(APP_BUNDLE)/Contents/Info.plist")
	cp Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	codesign --force --sign - "$(APP_BUNDLE)"

dist: app
	rm -rf build/dmg "$(DMG)"
	mkdir -p build/dmg
	cp -R "$(APP_BUNDLE)" build/dmg/
	ln -s /Applications build/dmg/Applications
	hdiutil create -volname "Claude Usage Bar" -srcfolder build/dmg -format UDZO -fs HFS+ "$(DMG)"
	rm -rf build/dmg

# Needs REPO, TAG and SPARKLE_PRIVATE_KEY in the environment.
appcast:
	rm -rf build/appcast
	mkdir -p build/appcast
	cp "$(DMG)" build/appcast/
	printenv SPARKLE_PRIVATE_KEY | "$(SPARKLE_BIN)/generate_appcast" --ed-key-file - \
		--download-url-prefix "https://github.com/$(REPO)/releases/download/$(TAG)/" \
		--full-release-notes-url "https://github.com/$(REPO)/releases/tag/$(TAG)" \
		--link "https://github.com/$(REPO)" \
		build/appcast

updater-key: build
	"$(SPARKLE_BIN)/generate_keys" --account $(SPARKLE_ACCOUNT)

run: app
	open "$(APP_BUNDLE)"

install: app
	-pkill -x "$(APP_NAME)"
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/"
	open "$(INSTALL_DIR)/$(APP_NAME).app"

uninstall:
	-pkill -x "$(APP_NAME)"
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"

clean:
	rm -rf .build build
