#!/usr/bin/env bash

apt install -y python-smbus i2c-tools
apt -y remove fake-hwclock
update-rc.d -f fake-hwclock remove
