#!/bin/sh

set -x
WWAN_NIC="wwan0"
VPN_PRIMARY=78.47.99.59

reconnect_mobile() {
    if ping -c2 "$VPN_PRIMARY"; then
        echo "VPN Server can be pinged. No need to reconnect"
	exit 0
    fi
    for _ in $(seq 1 60); do
	echo "Waiting for signal"
        if [ $(/usr/bin/qmicli -d /dev/cdc-wdm0 --nas-get-signal-strength | grep -i -E '(lte|5g|3g)' | wc -l) -gt 1 ]; then
	    echo "Got signal, restarting $WWAN_NIC"
            ifdown $WWAN_NIC || true;
            ifup $WWAN_NIC;
            break;
        fi
	sleep 1
    done
    echo "Not attempting to reconnect due to no signal"
}

if [ $(ip route show "$VPN_PRIMARY" | grep blackhole | wc -l) -gt 0 ]; then
    reconnect_mobile
elif [ $(ip route get "$VPN_PRIMARY" | wc -l) -gt 0 ]; then
    ping -W10 -c3 $VPN_PRIMARY || reconnect_mobile 
fi