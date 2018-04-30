#!/bin/bash
set -e

### constants
VERSION="18.04.1"

URL_MANUAL="https://storage.googleapis.com/fairphone-updates/6cb84543-9614-425d-9ab4-9e80baca2b8f/fp2-sibon-18.04.1-manual.zip"
URL_OTA="https://storage.googleapis.com/fairphone-updates/7058d8ad-5694-4a1b-95c3-db9a76218c49/FP2-gms-18.04.1-ota-from-18.03.1.zip"

CHECKSUM_MANUAL="c4f5264f583a50ba1b979a84d8ca8a5c03a87c0798e675981ebeea130e321b97"
CHECKSUM_OTA="b97bce6b0397f303b34b6d33386b5eedfd2261f3f750bd69930a1e31fcef3629"

### check platform
unamestr="$(uname)"
if [[ "$unamestr" == "Darwin" ]]; then
   alias sha256sum='gsha256sum'
fi

function exit_failure() {
    echo >&2 "$*"
    exit 1
}

command -v curl >/dev/null 2>&1		|| exit_failure "curl not found.  Aborting."
command -v zip >/dev/null 2>&1		|| exit_failure "zip not found.  Aborting."
command -v unzip >/dev/null 2>&1	|| exit_failure "unzip not found.  Aborting."
command -v sha256sum >/dev/null 2>&1	|| exit_failure "sha256sum not found.  Aborting."

### print welcome message
echo "Fairphone modem.zip generator"

### download an official FP2 ota zip that contains the 'update-binary'
umask 0077
MODEMDIR="$(mktemp -d /tmp/modem.XXXXXXXX)"

curl --progress-bar "$URL_OTA" -o /tmp/ota.zip
echo "$CHECKSUM_OTA /tmp/ota.zip" | sha256sum -c
unzip /tmp/ota.zip META-INF/* -d "$MODEMDIR"
rm /tmp/ota.zip

### we don't need the updater-script provided by Fairphone
rm "$MODEMDIR"/META-INF/com/google/android/updater-script

### download manual.zip containing the latest proprietary binaries
curl --progress-bar "$URL_MANUAL" -o /tmp/manual.zip
echo "$CHECKSUM_MANUAL /tmp/manual.zip" | sha256sum -c
unzip -j /tmp/manual.zip images/rpm.mbn images/emmc_appsboot.mbn images/NON-HLOS.bin images/tz.mbn images/splash.img images/sbl1.mbn -d "$MODEMDIR"/firmware-update/
rm /tmp/manual.zip

### write updater-script
cat > "$MODEMDIR"/META-INF/com/google/android/updater-script <<EOF

get_device_compatible("FP2") == "OK" || abort("This package is for \"FP2\" devices; this is a \"" + getprop("ro.product.device") + "\".");
set_progress(0.200000);

ui_print("Patching firmware images...");

package_extract_file("firmware-update/tz.mbn", "/dev/block/platform/msm_sdcc.1/by-name/tz");
set_progress(0.300000);

package_extract_file("firmware-update/sbl1.mbn", "/dev/block/platform/msm_sdcc.1/by-name/sbl1");
set_progress(0.400000);

package_extract_file("firmware-update/rpm.mbn", "/dev/block/platform/msm_sdcc.1/by-name/rpm");
set_progress(0.600000);

package_extract_file("firmware-update/emmc_appsboot.mbn", "/dev/block/platform/msm_sdcc.1/by-name/aboot");
msm.boot_update("backup");
msm.boot_update("finalize");
set_progress(0.800000);

package_extract_file("firmware-update/splash.img", "/dev/block/platform/msm_sdcc.1/by-name/splash");
set_progress(0.900000);

package_extract_file("firmware-update/NON-HLOS.bin", "/dev/block/platform/msm_sdcc.1/by-name/modem");

EOF

### inject version number
echo "ui_print(\"Flashing successful! You have updated your modem firmware to "$VERSION".\");" >> "$MODEMDIR"/META-INF/com/google/android/updater-script
echo "set_progress(1.000000);" >> "$MODEMDIR"/META-INF/com/google/android/updater-script

### zip it
CURRENT_DIR="$(pwd)"
pushd "$MODEMDIR"
find "$MODEMDIR" -exec touch -t 201401010000 {} +
zip -X -r "$CURRENT_DIR/modem-$VERSION.zip" META-INF/* firmware-update/*
popd
rm -r "$MODEMDIR"

### finish
sha256sum modem-"$VERSION".zip
echo "Done!"
