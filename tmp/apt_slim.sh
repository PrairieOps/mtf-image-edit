#!/usr/bin/env bash
mtf_database_pass="$1"

# If we're in a chroot
if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
  mount -t proc none /proc
fi

# Update mirrors
apt update -y

# Tidy up the Raspbian installation.
apt -y autoremove

# If we're in a chroot
if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
  umount /proc
fi


exit
