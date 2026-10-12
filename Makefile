APP_NAME := ClaudeUsageBar
# arm64, x86_64 or universal; empty builds for this Mac.
ARCH ?=
ARCH_FLAGS = $(if $(filter universal,$(ARCH)),--arch arm64 --arch x86_64,$(if $(ARCH),--arch $(ARCH)))
BUILD_DIR = $(shell swift build -c release $(ARCH_FLAGS) --show-bin-path)
APP_BUNDLE := build/$(APP_NAME).app
INSTALL_DIR := /Applications
DMG = build/$(APP_NAME)$(if $(ARCH),-$(ARCH)).dmg
RELEASE_ARCHS := arm64 x86_64 universal
SPARKLE_BIN := .build/artifacts/sparkle/Sparkle/bin
SPARKLE_ACCOUNT := claude-usage-bar

.PHONY: build test icon app dist release-dmgs appcast updater-key run install uninstall clean

build:
	swift build -c release $(ARCH_FLAGS)

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

release-dmgs:
	for arch in $(RELEASE_ARCHS); do $(MAKE) dist ARCH=$$arch || exit 1; done

# Writes appcast.xml for Apple Silicon and appcast-x86_64.xml for Intel. Universal installs
# update to the build of the architecture they run as. Needs REPO, TAG and SPARKLE_PRIVATE_KEY.
appcast:
	rm -rf build/appcast
	for arch in arm64 x86_64; do \
		mkdir -p build/appcast/$$arch && \
		cp "build/$(APP_NAME)-$$arch.dmg" build/appcast/$$arch/ && \
		printenv SPARKLE_PRIVATE_KEY | "$(SPARKLE_BIN)/generate_appcast" --ed-key-file - \
			--download-url-prefix "https://github.com/$(REPO)/releases/download/$(TAG)/" \
			--full-release-notes-url "https://github.com/$(REPO)/releases/tag/$(TAG)" \
			--link "https://github.com/$(REPO)" \
			build/appcast/$$arch || exit 1; \
	done
	mv build/appcast/arm64/appcast.xml build/appcast/appcast.xml
	mv build/appcast/x86_64/appcast.xml build/appcast/appcast-x86_64.xml

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
