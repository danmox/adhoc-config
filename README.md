# adhoc-config

Scripts for configuring wireless interfaces in IBSS (adhoc) mode in linux

# Installation

## Renaming wireless interface

The network interface names Linux automatically assigns can be rather cryptic. You can rename your adapter to something simpler (e.g. `wifi2`) by executing:

```bash
rename_interface.sh <old-name> <new-name>
```
You will need to unplug/re-plug your USB interface after executing this command or restart your system if it is PCI based.

## Configuration

The `config.sh` script automates the steps required to configure a wireless interface in IBSS (adhoc) mode. To summarize one must:
1. Ensure that the desired interface is not being controlled by NetworkManager (the network configuration utility used in Ubuntu and most systems based on the gnome desktop environment)
2. Install a system service that automatically configures the interface in adhoc mode on system start
3. Generate a config file for systemd-networkd so that it automatically assigns the desired IP address on network creation (and optionally a forwarding address for internet passthrough)
4. Install a config file to be used with wpa_supplicant for network association and maintenance

`config.sh` should be executed as follows:
```bash
config.sh <wireless-interface> <node-id>
```
where `<node-id>` is a unique number that will become the last digits of the IP address assigned to the interface (i.e. `192.168.0.<node-id>`). Note that the user must ensure that `<node-id>` is unique for each node they configure.

## Special Cases

The main system service to be used on adhoc network nodes is `mid-adhoc@.service`. `config.sh` is automatically configured to install this script. There are a few other system services that can be used to handle special cases:
- `mid-adhoc-host@.service`: configures internet passthrough for a "host" node that is connected to the internet via a separate network interface
- `mid-adhoc-host-docker@.service`: configures internet passthrough for a "host" node that is connected to the internet via a separate network interface and is also running docker

Note that additional configuration steps must be executed on the other non-host adhoc nodes in order to take advantage of internet passthrough.

# Next Steps

After executing `config.sh` you will have a functioning adhoc network. Each node will be able to communicate directly with any other node in the network that is within range. In other words, each node employs a direct routing approach by default. In order to perform multi-hop routing, a routing protocol such as [B.A.T.M.A.N](https://www.open-mesh.org/projects/open-mesh/wiki) or [babel](https://www.irif.fr/~jch/software/babel/) must be configured on top of the existing adhoc network.
