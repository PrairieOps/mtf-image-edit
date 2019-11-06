#!/usr/bin/env bash

# Set hardware clock
hwclock -w

mtf_database_pass="mtf"
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
/usr/local/mtf/bin/migrate -database postgres://mothership_user:"${mtf_database_pass}"@localhost:5432/mothership -path /usr/local/mtf/bin/migrations up
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
systemctl daemon-reload
systemctl start mtf-pi-scout.service
systemctl enable mtf-pi-scout.service

echo -ne " Done\n"
echo -ne "*******************\n"
echo -ne "INSTALL SUCCESSFUL!\n"
echo -ne "*******************\n\n"
