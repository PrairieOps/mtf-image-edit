#!/usr/bin/env bash

read -r -d '' \
MTFAUTOSSHSVC <<- EOF
[Unit]
Description=SSH tunnel to mtf_ssh host
After=network.target

[Service]
User=pi

ExecStart=/bin/bash /opt/mtf/bin/autossh.sh
  /usr/bin/ssh -NT -o ExitOnForwardFailure=yes -o ServerAliveInterval=60 -o ServerAliveCountMax=3 mtf_ssh_tunnel

RestartSec=5
Restart=always

[Install]
WantedBy=multi-user.target

EOF

if [ -d /boot/mtf ]
then
  # Get MAC address
  mac=$(ip -br link show dev wlan0 | tr -s ' ' | cut -d ' ' -f 3)
  # Set hostname based on mac
  hostname="lib-mtf-$(printf %s "${mac}" | cut -d ':' -f 4,5,6 --output-delimiter=)"
  read -r -d '' \
HOSTS <<- EOF
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters

127.0.1.1       ${hostname}

EOF
  echo "$HOSTS"| tee "/etc/hosts" >/dev/null
  echo "$hostname"| tee "/etc/hostname" >/dev/null
  hostname ${hostname}
  if [ -f /boot/mtf/id_rsa.pub ] && [ -f /boot/mtf/id_rsa ]
  then
      mkdir -p /home/pi/.ssh
      cp /boot/mtf/id_rsa /home/pi/.ssh/
      cp /boot/mtf/id_rsa.pub /home/pi/.ssh/
      cp /boot/mtf/id_rsa.pub /home/pi/.ssh/authorized_keys
      chmod 600 /home/pi/.ssh/*
      chmod 700 /home/pi/.ssh
      chown -R 1000:1000 /home/pi/.ssh
  fi

  if [ -f /boot/mtf/ssh_server ] && [ -f /boot/mtf/autossh.sh ]
  then

    # get the server network name/ip
    mtf_ssh_server=$(head -n 1 /boot/mtf/ssh_server)
    # set the port based on the last two digits in the mac address
    tunnel_port=99"$(printf %s "${mac}" | grep -o "[0-9]" | tr -d '\n'| tail -c 2)"

    # write the ssh config for seamless connections to mtf_ssh_server
    read -r -d '' \
MTFSSHCONFIG <<- EOF
Host mtf_ssh_tunnel
  HostName ${mtf_ssh_server}
  User pi
  IdentityFile ~/.ssh/id_rsa
  RemoteForward ${tunnel_port} 127.0.0.1:22
  StrictHostKeyChecking no

Host mtf_ssh_server
  HostName ${mtf_ssh_server}
  User pi
  IdentityFile ~/.ssh/id_rsa
  StrictHostKeyChecking no

EOF

    # apply local ssh config
    echo "$MTFSSHCONFIG"| tee "/home/pi/.ssh/config" >/dev/null
    chown 1000:1000 /home/pi/.ssh/config

    # Move exec wrapper script for service
    mv /boot/mtf/autossh.sh /opt/mtf/bin/
    # Write service template
    echo "$MTFAUTOSSHSVC"| tee "/etc/systemd/system/autossh.service" >/dev/null
    systemctl enable autossh.service && systemctl start autossh.service &
  fi
  # Set Wifi to auto reconnect if we have the script to do it
  if [ -f /etc/wpa_supplicant/ifupdown.sh ]
  then
    ln -s /etc/wpa_supplicant/ifupdown.sh /etc/ifplugd/action.d/ifupdown
  fi

  # Move mtf installer script
  mv /boot/mtf/mtf-pi-install.sh /opt/mtf/bin/
fi

