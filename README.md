# Measure the Future Raspbian Image Editor

# Requirements

  - Raspberry Pis with all the necessary hardware to be MTF sensors
  - A routable ssh server that allows the user `pi` to login via key-based authentication.
  - This tool expects to be run on Debian Buster.

## Raspberry pi configuration
Under `boot` you can place:

  - `wpa_supplicant.conf` that will get included in the image and written into the boot partition of the sdcard, meaning you don't have to copy it over to each sd card individually.

## MTF-specific configuration
Under `boot/mtf` there are several files you should create:

  - `id_rsa` and `id_rsa.pub` should contain ssh keys for ssh tunnels. This pubkey should be in the authorized_keys for the user `pi` on the ssh server
  - `ssh_server` should contain the routable hostname or IP address of the ssh server

## Usage

### Creating an image

You can specify an image, or run without arguments to have the tool download a raspbian buster image automatically and then edit it.

`sudo ./mtf_img_edit.sh [image file (optional)]`

You can then write than image to sd cards for use in sensors.

### Connecting to the sensors.

Upon bootup, each sensor will connect to the wifi and start a reverse ssh tunnel on the ssh server. It will then write its own configuration file to enable convenient connections back.
Assuming you correctly configured `wpa_supplicant.conf` and have functional Wifi, you should now be able to connect to your sensors shortly after booting them up.
To do so:
  - connect to your ssh server as the user `pi` using the ssh key you provided earlier
  - see which sensors have contacted the ssh server: `ls .ssh/config.d` you'll have one file per sensor, with names like `lib-mtf-xxxxxx`
  - connect to a sensor: `ssh lib-mtf-xxxxxx`
  - run the mtf setup script: `/opt/mtf/bin/mtf-pi-install.sh`
