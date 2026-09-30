APP_NAME := ClaudeUsageBar
BUILD_DIR = $(shell swift build -c release --show-bin-path)
APP_BUNDLE := build/$(APP_NAME).app
INSTALL_DIR := /Applications

.PHONY: build test icon app run install uninstall clean

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
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	codesign --force --sign - "$(APP_BUNDLE)"

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
