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
echo -ne "Configuring postgreSQL... \n"
sed -i -e "s/password/${mtf_database_pass}/g" /usr/local/mtf/bin/scout.json

cat > /usr/local/mtf/bin/db-bootstrap.sql <<EOF
CREATE DATABASE mothership;
CREATE DATABASE mothership_test;
CREATE USER mothership_user WITH password '$mtf_database_pass';
ALTER ROLE mothership_user SET client_encoding TO 'utf8';
ALTER ROLE mothership_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE mothership_user SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE mothership to mothership_user;
GRANT ALL PRIVILEGES ON DATABASE mothership_test TO mothership_user;
\connect mothership;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

EOF

sudo -E -u postgres psql -v pass="'${mtf_database_pass}'" -f /usr/local/mtf/bin/db-bootstrap.sql
/usr/local/mtf/bin/ migrate -database postgres://mothership_user:"${mtf_database_pass}"@localhost:5432/mothership -path /usr/local/mtf/bin/migrations up
systemctl stop postgresql.service
echo -ne " Done\n"

# Spin up the mothership and scout.
echo -ne "Creating Measure the Future Service..."
tsleep=$(which sleep)
cat > /lib/systemd/system/mtf-pi-scout.service <<EOF
[Unit]
Description=The Measure the Future scout
After=postgresql.service

[Service]
Environment=LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
WorkingDirectory=/usr/local/mtf/bin
ExecStartPre=$tsleep 10
ExecStart=/usr/local/mtf/bin/scout

[Install]
WantedBy=multi-user.target

EOF

# Enable scout service
ln -s /lib/systemd/system/mtf-pi-scout.service /etc/systemd/system/multi-user.target.wants/mtf-pi-scout.service ||:
echo -ne " Done\n"

echo -ne "*******************\n"
echo -ne "INSTALL SUCCESSFUL!\n"
echo -ne "*******************\n\n"
