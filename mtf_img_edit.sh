#!/usr/bin/env bash

read -r -d '' \
USAGE <<- EOF
  mtf_img_edit.sh builds a Measure the Future sensor disk image from an existing Raspbian image.
  Requires root/sudo
  Usage: mtf_img_edit.sh \$image
  \$image	local path to a raspian disk image (eg. ./2019-09-26-raspbian-buster-lite.img).

EOF

read -r -d '' \
MTFMODSVC <<- EOF
[Unit]
Description=Copy and Execute Measure the Future on onboot script.
ConditionPathExists=/boot/onboot.sh
Before=dhcpcd.service
JobRunningTimeoutSec=60

[Service]
Type=oneshot
RemainAfterExit=yes
TimeoutSec=60
ExecStart=/bin/sh -c "mkdir -p /opt/mtf/bin && mv /boot/onboot.sh /opt/mtf/bin/ && /bin/bash /opt/mtf/bin/onboot.sh"

[Install]
WantedBy=multi-user.target

EOF

if [ -z "$1" ]; then
  echo "${USAGE}"
  echo "File not specified: Using raspbian_lite-2019-09-30 download."
  download=2019-09-26-raspbian-buster-lite
  stat ${download}.zip >/dev/null || curl https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-09-30/${download}.zip -O -J
  stat ${download}.img >/dev/null || unzip ${download}.zip
  image=${download}.img
else
  image=${1}
fi

if [ "$(whoami)" != "root" ]
then
  echo "Please run with sudo or as root."
  exit 1
fi

if [ -f "$image" ]
then
  loopback=$(losetup --find --partscan --show  ${image})
  # Edit the boot partition
  boot_device="$(fdisk -l ${image} -o 'device,start,type' | grep 'W95 FAT32 (LBA)' | tr -s ' ' | cut -d ' ' -f 1)"
  mkdir -p "/mnt/${boot_device}"
  mount "${loopback}p1" -o rw "/mnt/${boot_device}"
  cp -r boot/mtf "/mnt/${boot_device}/"
  cp boot/wpa_supplicant.conf "/mnt/${boot_device}/"
  cp boot/onboot.sh "/mnt/${boot_device}/"
  touch "/mnt/${boot_device}/ssh"
  umount "/mnt/${boot_device}"
  rmdir "/mnt/${boot_device}"

  # Edit the root partition
  root_device="$(fdisk -l ${image} -o 'device,start,type' | grep 'Linux' | cut -d ' ' -f 1)"
  mkdir -p "/mnt/${root_device}"
  mount "${loopback}p2" -o rw "/mnt/${root_device}"
  echo "$MTFMODSVC"| tee "/mnt/${root_device}/lib/systemd/system/raspberrypi-mtf-onboot.service" >/dev/null
  sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' "/mnt/${root_device}/etc/ssh/sshd_config"
  chroot "/mnt/${root_device}" ln -s /lib/systemd/system/raspberrypi-mtf-onboot.service /etc/systemd/system/multi-user.target.wants/raspberrypi-mtf-onboot.service ||:
  umount "/mnt/${root_device}"
  rmdir "/mnt/${root_device}"
  losetup -d ${loopback}
else
  echo "File not found: ${image}."
  exit 1
fi
