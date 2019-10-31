#!/usr/bin/env bash
mtf_database_pass="$1"

# Tidy up the Raspbian installation.
echo -ne "Preparing Raspbian... "
apt update -y
apt upgrade -y
apt -y purge --auto-remove gvfs-backends gvfs-fuse
apt -y install vim
echo -ne " Done\n"

# Install OpenCV Dependencies
echo -ne "Installing OpenCV Dependencies... "
apt -y install build-essential git cmake pkg-config
apt -y install libjpeg-dev libtiff5-dev libjasper-dev libpng12-dev
apt -y install libavcodec-dev libavformat-dev libswscale-dev libv4l-dev
apt -y install libxvidcore-dev libx264-dev
apt -y install libatlas-base-dev gfortran
apt -y install libgtk2.0-dev 
apt -y install python2.7-dev python3-dev 
apt -y install openjdk-8-jdk

echo -ne "Begin Measure The Future Installation instructions"
dpkg -i /tmp/cvbindings_3.4.1_armhf.deb

dpkg -i /tmp/opencv_3.4.1_armhf.deb
echo -ne " Done\n"

# Install Measure The Future
echo -ne "Installing Measure The Future... "
dpkg -i /tmp/mtf_0.0.24_armhf.deb

echo 'export PATH=$PATH:/usr/local/mtf/bin' >> .profile
source .profile
echo -ne " Done\n"

# Bootstrap the Database.
echo -ne "Installing postgreSQL... \n"
apt -y install postgresql
echo -ne " Done\n"
