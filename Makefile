# Original script by Jannis Pinter (jannispinter)
# Makefile by Roberto M.F. (Roboe)
# https://github.com/WeAreFairphone/flashabe-zip_emojione

SHELL     := /bin/bash

# Version and release
VERSION      := 18.04.1
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

# Update ZIPs
## OTA update for the Edify interpreter
OTA_FILENAME := fp2-sibon-$(VERSION)-ota-userdebug.zip
OTA_FILE     := ./updates/$(OTA_FILENAME)
OTA_URL      := https://storage.googleapis.com/fairphone-updates/6cb84543-9614-425d-9ab4-9e80baca2b8f/$(OTA_FILENAME)
OTA_CHECKSUM := 97b39681b773804c8e12177293171698395c43ad9458c7ba823c85c503f00500
## Update with desired firmware images (ota or manual)
FWUPDATE_FILENAME := $(OTA_FILENAME)
FWUPDATE_FILE     := ./updates/$(FWUPDATE_FILENAME)
FWUPDATE_URL      := $(OTA_URL)
FWUPDATE_CHECKSUM := $(OTA_CHECKSUM)
### Images directory uses to be 'firmware-update' for OTA ZIPs and 'images' for manual ZIPs
FWUPDATE_IMGSDIR  := firmware-update

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
		$(EDIFY_BINARY) \
		$(EDIFY_SCRIPT) \
		-t "$(TEMP_DIR)"
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
