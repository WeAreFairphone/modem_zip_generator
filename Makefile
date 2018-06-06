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
## Manual update for firmware images
MANUAL_FILENAME := fp2-sibon-$(VERSION)-manual.zip
MANUAL_FILE     := ./updates/$(MANUAL_FILENAME)
MANUAL_URL      := https://storage.googleapis.com/fairphone-updates/6cb84543-9614-425d-9ab4-9e80baca2b8f/$(MANUAL_FILENAME)
MANUAL_CHECKSUM := c4f5264f583a50ba1b979a84d8ca8a5c03a87c0798e675981ebeea130e321b97
## OTA update for the Edify interpreter
OTA_FILENAME := FP2-gms-18.04.1-ota-from-18.03.1.zip
OTA_FILE     := ./updates/$(OTA_FILENAME)
OTA_URL      := https://storage.googleapis.com/fairphone-updates/7058d8ad-5694-4a1b-95c3-db9a76218c49/$(OTA_FILENAME)
OTA_CHECKSUM := b97bce6b0397f303b34b6d33386b5eedfd2261f3f750bd69930a1e31fcef3629

# Dependencies
CURL      := $(shell command -v curl 2>&1)
ZIP       := $(shell command -v zip 2>&1)
UNZIP     := $(shell command -v unzip 2>&1)
SHA256SUM := $(shell if [[ "$(uname -s)" == "Darwin" ]]; then command -v gsha256sum; else command -v sha256sum; fi)


.PHONY: all build clean release
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

$(MANUAL_FILE):
	@echo "Downloading $(MANUAL_FILENAME)..."
	@mkdir -pv `dirname $(MANUAL_FILE)`
	@$(CURL) --progress-bar "$(MANUAL_URL)" -o $(MANUAL_FILE)
	@$(SHA256SUM) --check <(echo "$(MANUAL_CHECKSUM) $(MANUAL_FILE)") || rm -f "$(MANUAL_FILE)"

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

$(FIRMWARE_DIR): $(MANUAL_FILE)
	@echo "Unpacking firmware files..."
	@rm -rf "$(FIRMWARE_DIR)"
	@$(UNZIP) -j \
		$(MANUAL_FILE) \
		images/rpm.mbn \
		images/emmc_appsboot.mbn \
		images/NON-HLOS.bin \
		images/tz.mbn \
		images/splash.img \
		images/sbl1.mbn \
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
