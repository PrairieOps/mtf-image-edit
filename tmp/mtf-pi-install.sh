#!/usr/bin/env bash
mtf_database_pass="$1"

# If we're in a chroot
if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
  mount -t proc none /proc
fi

# Set locale
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

sed -i 's/en_GB.UTF-8 UTF-8/# en_GB.UTF-8 UTF-8/' "/etc/locale.gen"
sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' "/etc/locale.gen"
sed -i 's/en_GB.UTF-8/en_US.UTF-8/' "/etc/default/locale"
locale-gen
update-locale
dpkg-reconfigure --frontend noninteractive locales

# Set timezone
ln -fs /usr/share/zoneinfo/America/Chicago /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

# Install OpenCV Dependencies
echo -ne "Installing OpenCV Dependencies... "
apt -y install build-essential git cmake pkg-config
apt -y install libjpeg-dev libtiff5-dev libjasper-dev libpng12-dev
apt -y install libavcodec-dev libavformat-dev libswscale-dev libv4l-dev
apt -y install libxvidcore-dev libx264-dev
apt -y install libatlas-base-dev gfortran
apt -y install libgtk2.0-dev libgtk-3-0
apt -y install python2.7-dev python3-dev 
apt -y install openjdk-8-jdk

echo -ne "Begin Measure The Future Installation instructions"
dpkg -i /tmp/cvbindings_3.4.1_armhf.deb && rm /tmp/cvbindings_3.4.1_armhf.deb

dpkg -i /tmp/opencv_3.4.1_armhf.deb && rm /tmp/opencv_3.4.1_armhf.deb
echo -ne " Done\n"

# Install Measure The Future
echo -ne "Installing Measure The Future... "
dpkg -i /tmp/mtf_0.0.24_armhf.deb && rm /tmp/mtf_0.0.24_armhf.deb

# Make as much space as possible.
apt -y autoremove

echo 'export PATH=$PATH:/usr/local/mtf/bin' >> /etc/profile.d/mtf.sh
source /etc/profile.d/mtf.sh
echo -ne " Done\n"

# Bootstrap the Database.
echo -ne "Installing postgreSQL... \n"
apt -y install postgresql
echo -ne " Done\n"

# If we're in a chroot
if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
  umount /proc
fi


exit
