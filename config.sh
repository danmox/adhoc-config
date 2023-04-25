#!/usr/bin/env bash

__error_msg_exit() {
	echo "$1. exiting."
	exit
}

__user_query() {
  while true; do
    echo -n "$1 (Y/n) "
    read -r res

    if [[ "$res" == "y" ]] || [[ "$res" == "Y" ]] || [ -z "$res" ]; then
      return 0
    elif [[ "$res" == "n" ]]; then
      return 1
    fi
  done
}

# parse inputs

if [[ $# -ne 2 ]]; then
	echo "usage: config <interface> <node-id>"
  echo ""
  echo "    interface - the wireless interface to configure in ad-hoc mode (e.g. wlp2s0)"
  echo "    node-id   - a unique number to use as the last digits in the node's IP address"
	exit 1
fi
iface=$1
ip_addr=192.168.0.$2

# check inputs

if [[ "$2" -lt 0 ]] || [[ "$2" -gt 255 ]]; then
  __error_msg_exit "invalid node-id: $2"
fi

ifaces=$(ip a | sed -nE 's/^[0-9]+: ([a-z0-9]+):.*/\1/p' | grep -vE "^wl.*" | tr '\n' ' ')
if ! echo "$ifaces" | grep -qw "$iface"; then
  echo "'$iface' not in list of wireless interfaces: $ifaces"
  exit
fi

# double check that everything looks right with user before installing

if ! __user_query "Configure mid-adhoc network for interface $iface with IP $ip_addr"; then
  exit
fi

# ignore wireless device in network manager

nmignorefile=/etc/NetworkManager/conf.d/99-unmanaged-devices.conf
if [[ -e $nmignorefile ]]; then
  if ! grep -qw "$iface" $nmignorefile; then
    __error_msg_exit "$nmignorefile already exists but not configured for device '$iface'"
    exit
  else
    echo "$nmignorefile already configured to ignore device '$iface'"
  fi
else
  echo "creating $nmignorefile"
  echo "[keyfile]
unmanaged-devices=interface-name:$iface" > /tmp/unmanaged.conf
  sudo mv /tmp/unmanaged.conf $nmignorefile || __error_msg_exit "failed to create $nmignorefile"
  echo "restarting NetworkManager"
  sudo systemctl restart NetworkManager.service || __error_msg_exit "failed to restart NetworkManager.service"
fi

wpa_file=/var/run/wpa_supplicant/$iface
if [[ -e $wpa_file ]]; then
  echo "$wpa_file still exists, setting up adhoc will fail unless it is removed"
  exit
fi

# correct absolute paths in mid-adhoc@.service

rm_path=$(which rm 2>/dev/null) || __error_msg_exit "'rm' not found"
rfkill_path=$(which rfkill 2>/dev/null) || __error_msg_exit "'rfkill' not found"
ip_path=$(which ip 2>/dev/null) || __error_msg_exit "'ip' not found"
wpa_path=$(which wpa_supplicant 2>/dev/null) || __error_msg_exit "'wpa_supplicant' not found"
iw_path=$(which iw 2>/dev/null) || __error_msg_exit "'iw' not found"

if [[ -e mid-adhoc@.service ]]; then
  cp mid-adhoc@.service tmp@.service
else
  echo "mid-adhoc@.service does not exist in the current directory."
  exit
fi

sed -i "s|rm_path|$rm_path|" tmp@.service
sed -i "s|rfkill_path|$rfkill_path|" tmp@.service
sed -i "s|ip_path|$ip_path|" tmp@.service
sed -i "s|wpa_supplicant_path|$wpa_path|" tmp@.service
sed -i "s|iw_path|$iw_path|" tmp@.service

# generate config file

echo "creating 25-mid-adhoc.network"
echo "[Match]
Name=$iface

[Network]
Address=$ip_addr/24" > 25-mid-adhoc.network

# if __user_query "Configure gateway/DNS for mid-adhoc"; then
#   echo "Gateway=192.168.0.101
# DNS=8.8.8.8" >> 25-mid-adhoc.network
# fi

# copy service files to system folder

echo "installing mid-adhoc-open.conf to /etc/wpa_supplicant/"
sudo cp mid-adhoc-open.conf /etc/wpa_supplicant/
echo "installing mid-adhoc@.service to /etc/systemd/system/"
sudo mv tmp@.service /etc/systemd/system/mid-adhoc@.service
echo "installing 25-mid-adhoc.network to /etc/systemd/network/"
sudo mv 25-mid-adhoc.network /etc/systemd/network/

# enable system services

if sudo systemctl is-enabled --quiet mid-adhoc@$iface.service; then
  echo "reloading system daemons"
  sudo systemctl daemon-reload || __error_msg_exit "failed to reload daemon files"
else
  echo "enabling system services"
  sudo systemctl enable mid-adhoc@$iface.service || __error_msg_exit "failed to enable mid-adhoc@$iface.service"
  sudo systemctl enable systemd-networkd.service || __error_msg_exit "failed to enable systemd-networkd.service"
fi
echo "restarting mid-adhoc@$iface.service and systemd-networkd.service"
sudo systemctl restart mid-adhoc@$iface.service || __error_msg_exit "failed to restart mid-adhoc@$iface.service"
sudo systemctl restart systemd-networkd.service || __error_msg_exit "failed to restart systemd-networkd.service"
