#!/bin/bash
set -e

### constants
VERSION="18.01.1"
URL_MANUAL="https://storage.googleapis.com/fairphone-updates/3bdd65b8-33c9-4a10-ab07-7765c2419fe5/FP2-gms-$VERSION-manual.zip"
URL_OTA="https://storage.googleapis.com/fairphone-updates/3bdd65b8-33c9-4a10-ab07-7765c2419fe5/FP2-gms-18.01.1-ota-from-17.12.1.zip"

CHECKSUM_MANUAL="c505adf745f178e2cbef8f7cfd4bf18c37bdd7f1ae525792d0bae762b5d77988"
CHECKSUM_OTA="a4a4f4f856e08f37024c00c7b697d1bbd6b213249c48192141bb8db60bccef51"


### print welcome message
echo "Fairphone modem.zip generator"

### download an official FP2 ota zip that contains the 'update-binary'
mkdir -p /tmp/modem/firmware-update
curl --progress-bar $URL_OTA -o /tmp/ota.zip
echo "$CHECKSUM_OTA /tmp/ota.zip" | sha256sum -c
unzip /tmp/ota.zip META-INF/* -d /tmp/modem/
rm /tmp/ota.zip

### we don't need the updater-script provided by Fairphone
rm /tmp/modem/META-INF/com/google/android/updater-script

### download manual.zip containing the latest proprietary binaries
curl --progress-bar $URL_MANUAL -o /tmp/manual.zip
echo "$CHECKSUM_MANUAL /tmp/manual.zip" | sha256sum -c
unzip -j /tmp/manual.zip images/rpm.mbn images/emmc_appsboot.mbn images/NON-HLOS.bin images/tz.mbn images/splash.img images/sbl1.mbn -d /tmp/modem/firmware-update/
rm /tmp/manual.zip

### write updater-script
cat > /tmp/modem/META-INF/com/google/android/updater-script <<EOF

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
echo "ui_print(\"Flashing successful! You have updated your modem firmware to $VERSION.\");" >> /tmp/modem/META-INF/com/google/android/updater-script
echo "set_progress(1.000000);" >> /tmp/modem/META-INF/com/google/android/updater-script

### zip it
CURRENT_DIR=$(pwd)
pushd /tmp/modem/
zip -r "$CURRENT_DIR/modem-$VERSION.zip" META-INF/* firmware-update/*
popd
rm -r /tmp/modem/

### finish
sha256sum modem-$VERSION.zip
echo "Done!"
