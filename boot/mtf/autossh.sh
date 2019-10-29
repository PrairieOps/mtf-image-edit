#!/usr/bin/env bash

# Get MAC address
mac=$(ip -br link show dev wlan0 | tr -s ' ' | cut -d ' ' -f 3)
# Set hostname based on mac
hostname="lib-mtf-$(printf %s "${mac}" | cut -d ':' -f 4,5,6 --output-delimiter=)"
# set the port based on the last two digits in the mac address
tunnel_port=99"$(printf %s "${mac}" | grep -o "[0-9]" | tr -d '\n'| tail -c 2)"

read -r -d '' \
MTFREMOTESSHCONFIG <<- EOF
Host ${hostname}
  User pi
  HostName 127.0.0.1
  Port ${tunnel_port}
  StrictHostKeyChecking no

EOF

# stage remote ssh config
mkdir -p ~/.remotesshconfig
echo "$MTFREMOTESSHCONFIG"| tee "~/.remotesshconfig/${hostname}" >/dev/null

# send remote ssh config
/usr/bin/ssh mtf_ssh_server 'mkdir -p ~/.ssh/config.d && echo "Include config.d/*">~/.ssh/config'
scp "~/.remotesshconfig/${hostname}" mtf_ssh_server:~/.ssh/config.d/${hostname}

# start tunnel
/usr/bin/ssh -NT -o ExitOnForwardFailure=yes -o ServerAliveInterval=60 -o ServerAliveCountMax=3 mtf_ssh_tunnel
