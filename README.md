# Remote Hands Device

IT folks like system administrators and pentesters often need to physically interact with a device or connect to a network. Lockdowns during the early days of the SARS-CoV-2 pandemic have allowed more creative approaches than physically moving to an on-site location, if everything was needed is getting hands on a laptop or network port from that location.

Remote Hands aims to provide a reliable and minimal setup to build such device based on a minimal Debian image.

## Features

### Remote Access

Redundant uplink interfaces can be aggregated to access the device in unreliable or unpredictable network environments. Both LTE/5G modem and `enp1s0` are dynamically configured with only one uplink IP route each, their VPN server. Bird configures OSPF over the two VPN connections (primary and secondary), so that connections can survive changing uplinks.

### KVM

Combined with an [ADDERLink ipeps+](https://www.adder.com/en/kvm-solutions/adderlink-ipeps-plus), the remote hands device exposes a UNIX socket `/var/run/kvm.sock` to access a remote machine via HDMI (passthrough) and virtual USB input. 

Situations where screen access and input are needed in early boot stages, the target device is offline or no additional software should be installed on the system, a remote KVM is a handy workaround instead of physically moving the location.

The KVM device is connected to `enp2s0`, which is hidden in `kvm` network namespace, hence the exposure as UNIX socket instead.

### Target Network

The remaining network ports and WiFi stay down on boot and can be upped on demand. While the uplink network operates on the default network namespace, it is recommendable to isolate network connections to a target network in their own network namespace.

A typical MitM setup in a network namespace would add both ethernet interfaces to a bridge within a network namespace:

```sh
ip netns add mitm
ip netns exec mitm ip link set up lo
ip netns exec mitm ip link add pen0 type bridge
ip netns exec mitm ip link set up dev pen0
ip link set netns mitm up master pen0 dev enp3s0
ip link set netns mitm up master pen0 dev enp4s0
```

## Setup and Configuration

### VPN Server

...

### APU

1. Setup minimal Debian base image
2. Download Remote Hands configuration

```
apt update && apt install -y git
mkdir -p /usr/local/src
git clone https://github.com/RemoteHands/apu /usr/local/src/apu
cd /usr/local/src/apu
```

3. Configure

Copy the credentials to the `credentials/` folder. When the drone is configured over local SSH, the following SCP commands can be handy to copy the credentials between the VPN server and the device to be provisioned.

```sh
DEVICE_HOSTNAME="apu4d4"

for CREDENTIAL_FILE in ta.key pki/ca.crt pki/private/${DEVICE_HOSTNAME}.key pki/issued/${DEVICE_HOSTNAME}.crt; do
  scp -3 \
    root@vpn-server:/etc/openvpn/server/$REMOTE_FILE \
    root@remote-hands-drone:/usr/local/src/apu/credentials/
done
```

Remote addresses and local device names can be configured in `./config`:

```sh
cp config.sample config
vim config
```

4. Dry-run (optional)

Verify the configuration files to be applied, without changing any live configuration or touching service state:

```sh
./install.sh /tmp
```

5. Install

The `install.sh` script without argument installs Debian dependencies, applies configuration and restarts services:

```sh
./install.sh /tmp
```