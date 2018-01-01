# Fairphone modem.zip generator
The `modem.sh` shell script generates a reproducable, flashable ZIP file with the latest proprietary components for the Fairphone 2.

### System requirements
The script is designed to run on GNU/Linux, it should however run on other UNIX systems, too. The following tools are required for the script to run:
`curl zip unzip sha256sum`

### Usage
Clone the repository and execute `modem.sh`, it will download and verify the official Fairphone 2 firmware images and extract the proprietary components.

### Misc
See this [forum post](https://forum.fairphone.com/t/pencil2-fp2-modem-firmware/35374) for more information about this script.
