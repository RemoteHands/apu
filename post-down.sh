#!/bin/sh
ALIAS="$1"
INTERFACE="$2"

VPN_PRIMARY=$(getent ahostsv4 vpn-primary | head -n1 | cut -d" " -f1)
VPN_SECONDARY=$(getent ahostsv4 vpn-secondary | head -n1 | cut -d" " -f1)

ip link set dev $INTERFACE alias "$ALIAS"
case $ALIAS in
    "vpn-primary")
	TARGET_IP=$VPN_PRIMARY
	OTHER_IP=$VPN_SECONDARY
	;;
    "vpn-secondary")
	TARGET_IP=$VPN_SECONDARY
	OTHER_IP=$VPN_PRIMARY
	;;
    *)
	exit 1
	;;
esac

# delete existing route to TARGET_IP
if [ "`ip route show $TARGET_IP | wc -l`" -eq 1 ]; then
	ip route delete $TARGET_IP/32;
fi

# blackhole TARGET_IP
ip route add blackhole $TARGET_IP

