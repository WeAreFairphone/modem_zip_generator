# Original script by Jannis Pinter (jannispinter)
# Makefile by Roberto M.F. (Roboe)
# https://github.com/WeAreFairphone/flashabe-zip_emojione

SHELL     := /bin/bash

# Version and release
VERSION      := 19.02.1
FLASHABLEZIP := ./build/modem.zip
RELEASENAME  := $(shell date +"modem-$(VERSION)_%Y-%m-%d.zip")
RELEASEZIP   := release/$(RELEASENAME)
RELEASESUM   := $(RELEASEZIP).sha256sum

# Paths
ROOT         := $(shell pwd)
SOURCE       := ./src/
FIRMWARE_DIR := ./src/firmware-update/
EDIFY_BINARY := ./src/META-INF/com/google/android/update-binary
EDIFY_SCRIPT := ./src/META-INF/com/google/android/updater-script
TEMP_DIR     := $(shell mktemp --dry-run -d /tmp/modem.XXXXXXXX)
TEMP_EDIFY_DIR := $(TEMP_DIR)/META-INF/com/google/android/

# Update ZIPs
## OTA update for the Edify interpreter
OTA_FILENAME := 19.02.1-sibon-dc48370a-ota.zip
OTA_FILE     := ./updates/$(OTA_FILENAME)
OTA_URL      := https://storage.googleapis.com/fairphone-updates/5a2d07a7-4402-4e3c-a57b-a6fdd5078c66/$(OTA_FILENAME)
OTA_CHECKSUM := 7a36eb7e722e2f823eb228c9565c1d19febfdf1b3169c9e59b9791063647c045
## Update with desired firmware images (ota or manual)
FWUPDATE_FILENAME := fp2-sibon-$(VERSION)-manual.zip
FWUPDATE_FILE     := ./updates/$(FWUPDATE_FILENAME)
FWUPDATE_URL      := https://storage.googleapis.com/fairphone-updates/5a2d07a7-4402-4e3c-a57b-a6fdd5078c66/$(FWUPDATE_FILENAME)
FWUPDATE_CHECKSUM := b46c4987e41350a144c6c9e188f94169e1cd0b04b6f653ad12c77c3fc9d2a081
### Images directory uses to be 'firmware-update' for OTA ZIPs and 'images' for manual ZIPs
FWUPDATE_IMGSDIR  := images

# Dependencies
CURL      := $(shell command -v curl 2>&1)
ZIP       := $(shell command -v zip 2>&1)
UNZIP     := $(shell command -v unzip 2>&1)
SHA256SUM := $(shell if [[ "$(uname -s)" == "Darwin" ]]; then command -v gsha256sum; else command -v sha256sum; fi)


.PHONY: all build clean release install
all: build


build: $(FLASHABLEZIP)

$(FLASHABLEZIP): $(FIRMWARE_DIR) $(EDIFY_BINARY) $(EDIFY_SCRIPT)
	@mkdir -p "$(TEMP_DIR)"
	@cp -r \
		$(FIRMWARE_DIR) \
		-t "$(TEMP_DIR)"
	@mkdir -p "$(TEMP_EDIFY_DIR)/"
	@cp -r \
		$(EDIFY_BINARY) \
		$(EDIFY_SCRIPT) \
		-t "$(TEMP_EDIFY_DIR)"
	@find "$(TEMP_DIR)" -exec touch -t 197001010000 {} + # Reproducibility
	@echo "Building flashable ZIP..."
	@mkdir -pv "$(@D)"
	@rm -f "$@"
	@cd "$(TEMP_DIR)" && zip -X \
		"$(ROOT)/$@" . \
		--recurse-path
	@rm -rf "$(TEMP_DIR)"
	@echo "Result: $@"

$(FWUPDATE_FILE):
	@echo "Downloading $(FWUPDATE_FILENAME)..."
	@mkdir -pv `dirname $(FWUPDATE_FILE)`
	@$(CURL) --progress-bar "$(FWUPDATE_URL)" -o $(FWUPDATE_FILE)
	@$(SHA256SUM) --check <(echo "$(FWUPDATE_CHECKSUM) $(FWUPDATE_FILE)") || rm -f "$(FWUPDATE_FILE)"

$(OTA_FILE):
	@echo "Downloading $(OTA_FILENAME)..."
	@mkdir -pv "$(@D)"
	@$(CURL) --progress-bar "$(OTA_URL)" -o "$@"
	@$(SHA256SUM) --check <(echo "$(OTA_CHECKSUM) $@") || rm -f "$@"

$(EDIFY_BINARY): $(OTA_FILE)
	@echo "Unpacking Edify interpreter..."
	@rm -rf "$@"
	@$(UNZIP) -j \
		$(OTA_FILE) \
		META-INF/com/google/android/update-binary \
		-d "$(@D)"
	@touch "$@" # Update filedate so Make doesn't unpack it always

$(FIRMWARE_DIR): $(FWUPDATE_FILE)
	@echo "Unpacking firmware files..."
	@rm -rf "$@"
	@$(UNZIP) -j \
		$(FWUPDATE_FILE) \
		$(FWUPDATE_IMGSDIR)/rpm.mbn \
		$(FWUPDATE_IMGSDIR)/emmc_appsboot.mbn \
		$(FWUPDATE_IMGSDIR)/NON-HLOS.bin \
		$(FWUPDATE_IMGSDIR)/tz.mbn \
		$(FWUPDATE_IMGSDIR)/splash.img \
		$(FWUPDATE_IMGSDIR)/sbl1.mbn \
		-d "$@"

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

release: $(RELEASEZIP) $(RELEASESUM)

$(RELEASEZIP): $(FLASHABLEZIP)
	@mkdir -pv "$(@D)"
	@echo -n "Release file: "
	@cp -v "$(FLASHABLEZIP)" "$@"

$(RELEASESUM): $(RELEASEZIP)
	@echo "Release checksum: $@"
	@cd "$(@D)" && $(SHA256SUM) $(RELEASENAME) > $(@F)

install: $(FLASHABLEZIP)
	@echo "Waiting for ADB sideload mode"
	@adb wait-for-sideload
	@adb sideload $(FLASHABLEZIP)
