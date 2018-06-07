# Original script by Jannis Pinter (jannispinter)
# Makefile by Roberto M.F. (Roboe)
# https://github.com/WeAreFairphone/flashabe-zip_emojione

SHELL     := /bin/bash

# Version and release
VERSION      := 18.04.1
FLASHABLEZIP := ./build/modem.zip
RELEASENAME  := "modem-$(VERSION)_%Y-%m-%d.zip"

# Paths
ROOT         := $(shell pwd)
SOURCE       := ./src/
FIRMWARE_DIR := ./src/firmware-update/
EDIFY_BINARY := ./src/META-INF/com/google/android/update-binary
EDIFY_SCRIPT := ./src/META-INF/com/google/android/updater-script

# Update ZIPs
OTA_FILENAME := fp2-sibon-$(VERSION)-ota-userdebug.zip
OTA_FILE     := ./updates/$(OTA_FILENAME)
OTA_URL      := https://storage.googleapis.com/fairphone-updates/6cb84543-9614-425d-9ab4-9e80baca2b8f/$(OTA_FILENAME)
OTA_CHECKSUM := 97b39681b773804c8e12177293171698395c43ad9458c7ba823c85c503f00500

# Dependencies
CURL      := $(shell command -v curl 2>&1)
ZIP       := $(shell command -v zip 2>&1)
UNZIP     := $(shell command -v unzip 2>&1)
SHA256SUM := $(shell if [[ "$(uname -s)" == "Darwin" ]]; then command -v gsha256sum; else command -v sha256sum; fi)


.PHONY: all build clean release install
all: build

build: $(FLASHABLEZIP)
$(FLASHABLEZIP): $(FIRMWARE_DIR) $(EDIFY_BINARY) $(EDIFY_SCRIPT)
	@echo "Building flashable ZIP..."
	@mkdir -pv `dirname $(FLASHABLEZIP)`
	@rm -f "$(FLASHABLEZIP)"
	@cd "$(SOURCE)" && zip -X \
		"$(ROOT)/$(FLASHABLEZIP)" . \
		--recurse-path
	@echo "Result: $(FLASHABLEZIP)"

$(OTA_FILE):
	@echo "Downloading $(OTA_FILENAME)..."
	@mkdir -pv `dirname $(OTA_FILE)`
	@$(CURL) --progress-bar "$(OTA_URL)" -o $(OTA_FILE)
	@$(SHA256SUM) --check <(echo "$(OTA_CHECKSUM) $(OTA_FILE)") || rm -f "$(OTA_FILE)"

$(EDIFY_BINARY): $(OTA_FILE)
	@echo "Unpacking Edify interpreter..."
	@rm -rf "$(EDIFY_BINARY)"
	@$(UNZIP) -j \
		$(OTA_FILE) \
		META-INF/com/google/android/update-binary \
		-d `dirname $(EDIFY_BINARY)`
	@touch $(EDIFY_BINARY) # Update filedate so Make doesn't unpack it always

$(FIRMWARE_DIR): $(OTA_FILE)
	@echo "Unpacking firmware files..."
	@rm -rf "$(FIRMWARE_DIR)"
	@$(UNZIP) -j \
		$(OTA_FILE) \
		firmware-update/rpm.mbn \
		firmware-update/emmc_appsboot.mbn \
		firmware-update/NON-HLOS.bin \
		firmware-update/tz.mbn \
		firmware-update/splash.img \
		firmware-update/sbl1.mbn \
		-d $(FIRMWARE_DIR)

clean:
	@echo "Removing files..."
	# Build
	rm -f "$(FLASHABLEZIP)"
	@# only remove dir if it's empty:
	@rmdir -p `dirname $(FLASHABLEZIP)` 2>/dev/null || true
	# Firmware images
	rm -rf "$(FIRMWARE_DIR)"
	# Edify binary
	rm -f "$(EDIFY_BINARY)"

release: $(FLASHABLEZIP)
	@echo "Release file location:"
	@mkdir -pv release/
	@cp -v "$(FLASHABLEZIP)" "release/$$(date +$(RELEASENAME))"

install: $(FLASHABLEZIP)
	@echo "Waiting for ADB sideload mode"
	@adb wait-for-sideload
	@adb sideload $(FLASHABLEZIP)
