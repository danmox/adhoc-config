#!/usr/bin/env bash

# rename a wireless interface

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
  echo "usage: rename_interface.sh <interface> <name>"
  exit 1
fi
iface=$1
name=$2

ifaces=$(ip a | sed -nE 's/^[0-9]+: ([a-z0-9]+):.*/\1/p' | tr '\n' ' ')
if ! echo "$ifaces" | grep -qw "$iface"; then
  echo "'$iface' not in list of wireless interfaces: $ifaces"
  exit
fi
if echo "$ifaces" | grep -qw "$name"; then
  echo "'$name' already exists!"
  exit
fi

if ! __user_query "rename $iface to $name?"; then
  exit
fi

mac=$(iw dev "$iface" info | sed -nE 's/^.*addr ([a-z0-9:]+)$/\1/p')
if [[ -z "$mac" ]]; then
  echo "failed to fetch MAC address for $iface"
  exit
fi

rules_file=/etc/udev/rules.d/10-network.rules
tmp_file=/tmp/10-network.rules

if [[ -e $rules_file ]]; then
  if grep -qw "$mac" $rules_file; then
    echo "rules already exists for interface $iface with MAC address $mac in $rules_file:"
    grep -w "$mac" $rules_file
    exit
  else
    cp $rules_file $tmp_file
  fi
else
  if [[ -e $tmp_file ]]; then
    rm $tmp_file
    touch $tmp_file
  else
    touch $tmp_file
  fi
fi

echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$mac\", NAME:=\"$name\"" >> $tmp_file
sudo cp $tmp_file $rules_file
rm $tmp_file

sudo udevadm control --reload-rules && sudo udevadm trigger

echo "if you have a USB interface unplug and re-plug it; otherwise, restart your system"
