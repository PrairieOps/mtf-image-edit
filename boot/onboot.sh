#!/usr/env bash

if [ -d /boot/mtf ]
then
  # Get MAC address
  mac=$(ip -br link show dev wlan0 | tr -s ' ' | cut -d ' ' -f 3)
  # Set hostname based on mac
  hostname=$("lib-mtf-$(printf %s "${mac}" | cut -d ':' -f 4,5,6 --output-delimiter=)")
HOSTS <<- EOF
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters

127.0.1.1       ${hostname}

EOF
  echo "$HOSTS"| tee "/etc/hosts" >/dev/null
  echo "$hostname"| tee "/etc/hosts" >/dev/null
  if [ -f /boot/mtf/id_rsa.pub ] && [ -f /boot/mtf/id_rsa ]
  then
      mkdir -p /home/pi/.ssh
      cp /boot/mtf/id_rsa /home/pi/.ssh/
      cp /boot/mtf/id_rsa.pub /home/pi/.ssh/
      cp /boot/mtf/id_rsa.pub /home/pi/.ssh/authorized_keys
      chmod 600 /home/pi/.ssh/*
      chmod 700 /home/pi/.ssh
  fi

  if [ -f /boot/mtf/ssh_server ]
  then
    # get the server network name/ip
    mtf_ssh_server=$(head -n 1 /boot/mtf/ssh_server)
    # set the port based on the last two digits in the mac address
    tunnel_port=$(99"$(printf %s "${mac}" | grep -o "[0-9]" | tr -d '\n'| tail -c 2)")
MTFAUTOSSHSVC <<- EOF
[Unit]
Description=SSH tunnel to specified remote host
After=network.target

[Service]
User=pi

ExecStart=/usr/bin/ssh -NT -o ExitOnForwardFailure=yes -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -R${tunnel_port}:127.0.0.1:22 -i /home/pi/.ssh/id_rsa pi@${mtf_ssh_server}

RestartSec=5
Restart=always

[Install]
WantedBy=multi-user.target

EOF
    echo "$MTFAUTOSSHSVC"| tee "/etc/systemd/system/autossh.service" >/dev/null
    systemctl enable autossh.service && systemctl start autossh.service
  fi
  # Set Wifi to auto reconnect if we have the script to do it
  if [ -f /etc/wpa_supplicant/ifupdown.sh ]
  then
    ln -s /etc/wpa_supplicant/ifupdown.sh /etc/ifplugd/action.d/ifupdown
  fi
fi

