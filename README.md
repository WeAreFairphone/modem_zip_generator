# Fairphone(-community) modem.zip generator
The `modem.sh` shell script generates a reproducible, flashable ZIP file with the latest proprietary components for the [Fairphone 2](https://shop.fairphone.com).

### Looking for the compiled version?
You can always download the latest modem.zip directly from [here](https://io.pinterjann.is/public/misc/fairphone/modem/modem-latest.zip).

### System requirements
The script is designed to run on GNU/Linux, it should however run on other UNIX systems, too. The following tools are required for the script to run:
`bash curl zip unzip sha256sum`

### Usage
Clone the repository and execute `modem.sh`, it will download and verify the official Fairphone 2 firmware images and extract the proprietary components.

### Misc
See this [forum post](https://forum.fairphone.com/t/pencil2-fp2-modem-firmware/35374) for more information about this script.

### Updates
The newest Fairphone OS versions can be found [here](https://support.fairphone.com/hc/en-us/articles/213290023-Fairphone-OS-downloads-for-Fairphone-2).
