#!/bin/sh
# Dependency-free outbound-connection logger for webOS TVs that lack tcpdump.
# Run as root, in the background, over SSH:
#
#   nohup sh netmon.sh >/dev/null 2>&1 &
#
# Then use the TV normally (Live TV, apps, the remote's voice button if it has
# one) and check /tmp/netmon.log afterward. Any line that isn't a "===" timestamp
# header is an active connection to something outside your own LAN at that
# moment -- adjust the grep pattern below to match your own router/LAN subnet.
#
# This only sees established TCP connections at each poll interval, so a very
# short-lived connection between polls can be missed; it's a reasonable signal,
# not a packet capture. Lower the sleep interval for finer resolution at the
# cost of log size.

LAN_PATTERN="127.0.0.1\|192.168.1\."   # <-- change to match your own LAN

while true; do
  echo "=== $(date) ===" >> /tmp/netmon.log
  netstat -tnp 2>/dev/null | grep -v "${LAN_PATTERN}" >> /tmp/netmon.log
  sleep 5
done
