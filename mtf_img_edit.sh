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
  echo "File not specified: Using raspbian-stretch-lite-2019-04-08 download."
  download=2019-04-08-raspbian-stretch-lite
  stat ${download}.zip >/dev/null || curl https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-04-09/${download}.zip -O -J
  stat ${download}.img >/dev/null || unzip ${download}.zip
  image=${download}-mtf.img
  stat ${image} || cp ${download}.img ${download}-mtf.img
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
  boot_device="$(fdisk -l ${image} -o 'device,start,type' | grep 'W95 FAT32 (LBA)' | tr -s ' ' | cut -d ' ' -f 1)"
  root_device="$(fdisk -l ${image} -o 'device,start,type' | grep 'Linux' | cut -d ' ' -f 1)"

  # Check image size
  desired_img_size=3221225000
  starting_img_size=$(stat -c %s "${image}")

  # Extend disk image if needed
  if [ "$desired_img_size" -gt "$starting_img_size" ]
  then
    add_bytes=$(( desired_img_size - starting_img_size ))
    dd if=/dev/zero bs=1M count=$(( add_bytes / 1024 / 1024 )) >> "${image}"
    parted "${image}" resizepart 2 100%
  fi

  # Treat the image as a loopback device
  loopback=$(losetup --find --partscan --show  ${image})

  # Make sure the second partition (root) takes full advantage of the image size
  partx "${loopback}"
  e2fsck -f "${loopback}p2"
  resize2fs "${loopback}p2"

  # Edit the boot partition
  mkdir -p "/mnt/${boot_device}"
  mount "${loopback}p1" -o rw "/mnt/${boot_device}"
  cp -r boot/mtf "/mnt/${boot_device}/"
  cp boot/wpa_supplicant.conf "/mnt/${boot_device}/"
  cp boot/onboot.sh "/mnt/${boot_device}/"
  cp boot/config.txt "/mnt/${boot_device}/"
  touch "/mnt/${boot_device}/ssh"

  # Unmount
  umount "/mnt/${boot_device}"
  rmdir "/mnt/${boot_device}"

  # Edit the root partition
  mkdir -p "/mnt/${root_device}"
  mount "${loopback}p2" -o rw "/mnt/${root_device}"
  sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' "/mnt/${root_device}/etc/ssh/sshd_config"

  # Enable our first boot script.
  echo "$MTFMODSVC"| tee "/mnt/${root_device}/lib/systemd/system/raspberrypi-mtf-onboot.service" >/dev/null
  chroot "/mnt/${root_device}" ln -s /lib/systemd/system/raspberrypi-mtf-onboot.service /etc/systemd/system/multi-user.target.wants/raspberrypi-mtf-onboot.service ||:

  # copy over temp assets for use inside chroot.
  cp tmp/* "/mnt/${root_device}/tmp"

  # copy resolve.conf from host to ensure networking functions within the chroot.
  cp /etc/resolv.conf "/mnt/${root_device}/etc"

  # add policy-rc.d to avoid running daemons in chroot.
  cp usr/sbin/policy-rc.d  "/mnt/${root_device}/usr/sbin"

  # hardware clock setup
  cp lib/udev/hwclock-set "/mnt/${root_device}/lib/udev/"
  chroot "/mnt/${root_device}" /tmp/./rtc-config.sh

  # Install measure the future into the image
  chroot "/mnt/${root_device}" /tmp/./mtf-pi-install.sh mtf

  # Clean apt cache
  chroot "/mnt/${root_device}" apt clean

  # Cleanup /tmp
  rm -rf "/mnt/${root_device}/tmp/*"

  # replace a stock resolv.conf
  cp etc/resolv.conf "/mnt/${root_device}/etc"

  # remove custom policy-rc.d
  rm "/mnt/${root_device}/usr/sbin/policy-rc.d"

  # Delete ssh host keys
  rm -v "/mnt/${root_device}/etc/ssh/ssh_host_"*

  # Unmount and clean up
  umount "/mnt/${root_device}"
  rmdir "/mnt/${root_device}"
  losetup -d ${loopback}
else
  echo "File not found: ${image}."
  exit 1
fi
