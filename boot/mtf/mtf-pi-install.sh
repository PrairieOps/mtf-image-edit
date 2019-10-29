#!/usr/bin/env bash

# Tidy up the Raspbian installation.
echo -ne "Preparing Raspbian... "
sudo apt update -y
sudo apt upgrade -y
sudo apt -y purge --auto-remove gvfs-backends gvfs-fuse &> /dev/null
sudo apt -y install vim &> /dev/null
echo -ne " Done\n"

# Install OpenCV Dependencies
echo -ne "Installing OpenCV Dependencies... "
sudo apt -y install build-essential git cmake pkg-config &> /dev/null
sudo apt -y install libjpeg-dev libtiff5-dev libjasper-dev libpng12-dev &> /dev/null
sudo apt -y install libavcodec-dev libavformat-dev libswscale-dev libv4l-dev &> /dev/null
sudo apt -y install libxvidcore-dev libx264-dev &> /dev/null
sudo apt -y install libatlas-base-dev gfortran &> /dev/null
sudo apt -y install libgtk2.0-dev  &> /dev/null
sudo apt -y install python2.7-dev python3-dev 
sudo apt -y install openjdk-8-jdk &> /dev/null

echo -ne "Begin Measure The Future Installation instructions"
wget https://github.com/MeasureTheFuture/CVBindings/releases/download/3.4.1/cvbindings_3.4.1_armhf.deb &> /dev/null
sudo dpkg -i cvbindings_3.4.1_armhf.deb &> /dev/null

wget https://github.com/MeasureTheFuture/Pi-OpenCV/releases/download/3.4.1/opencv_3.4.1_armhf.deb &> /dev/null
sudo dpkg -i opencv_3.4.1_armhf.deb &> /dev/null
echo -ne " Done\n"

# Install Measure The Future
echo -ne "Installing Measure The Future... "
wget https://github.com/MeasureTheFuture/scout/releases/download/v0.0.24/mtf_0.0.24_armhf.deb &> /dev/null
sudo dpkg -i mtf_0.0.24_armhf.deb &> /dev/null

echo 'export PATH=$PATH:/usr/local/mtf/bin' >> .profile
source .profile
echo -ne " Done\n"

# Bootstrap the Database.
echo -ne "Installing postgreSQL... \n"
sudo apt -y install postgresql &> /dev/null
echo -ne "Create a password for the MTF database: " 
read mtf_database_pass
echo -ne "Configuring postgreSQL... \n"
sudo sed -i -e "s/password/${mtf_database_pass}/g" /usr/local/mtf/bin/scout.json

sudo cat > /usr/local/mtf/bin/db-bootstrap.sql <<EOF
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

sudo -E -u postgres psql -v pass="'${mtf_database_pass}'" -f /usr/local/mtf/bin/db-bootstrap.sql &> /dev/null
migrate -database postgres://mothership_user:"${mtf_database_pass}"@localhost:5432/mothership -path /usr/local/mtf/bin/migrations up &> /dev/null
echo -ne " Done\n"

# Spin up the mothership and scout.
echo -ne "Starting Measure the Future..."
tsleep=$(which sleep)
sudo cat > /lib/systemd/system/mtf-pi-scout.service <<EOF
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

sudo systemctl daemon-reload &> /dev/null
sudo systemctl restart mtf-pi-scout.service &> /dev/null
sudo systemctl enable mtf-pi-scout.service &> /dev/null
echo -ne " Done\n"

echo -ne "*******************\n"
echo -ne "INSTALL SUCCESSFUL!\n"
echo -ne "*******************\n\n"
