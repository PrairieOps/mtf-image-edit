#!/usr/bin/env bash

# Get MAC address
mac=$(ip -br link show dev wlan0 | tr -s ' ' | cut -d ' ' -f 3)
# Set hostname based on mac
hostname="lib-mtf-$(printf %s "${mac}" | cut -d ':' -f 4,5,6 --output-delimiter=)"
# set the port based on the last digits in the mac address
ssh_tunnel_port=52"$(printf %s "${mac}" | grep -o "[0-9]" | tr -d '\n'| tail -c 3)"

read -r -d '' \
MTFREMOTESSHCONFIG <<- EOF
Host ${hostname}
  User pi
  HostName 127.0.0.1
  Port ${ssh_tunnel_port}
  StrictHostKeyChecking no

EOF

# stage remote ssh config
mkdir -p ~/.remotesshconfig
echo "$MTFREMOTESSHCONFIG"| tee "/home/pi/.remotesshconfig/${hostname}" >/dev/null

# send remote ssh config
/usr/bin/ssh mtf_ssh_server 'mkdir -p ~/.ssh/config.d && echo "Include config.d/*">~/.ssh/config'
scp "/home/pi/.remotesshconfig/${hostname}" "mtf_ssh_server:~/.ssh/config.d/${hostname}"

# start tunnel
/usr/bin/ssh -NT mtf_ssh_tunnel
