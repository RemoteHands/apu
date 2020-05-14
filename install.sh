#!/bin/sh
export HOSTNAME=$(cat /etc/hostname)
SCRIPT_PATH=$(readlink -f "$0")
export BASEDIR=$(dirname "$SCRIPT_PATH")
export PATH_PREFIX=$1
. $BASEDIR/config

if [ "$PATH_PREFIX" = "" ]; then
    DRY_RUN=0
    echo "Production 🚨"
    printf "Press Enter to confirm or Strg + C to cancel"
    read ok
else
    echo "Dry-Run 🚨"
    DRY_RUN=1
fi

template() {
    TARGET_FILE=$PATH_PREFIX$2
    TARGET_DIR=$(dirname "$TARGET_FILE")
    echo "Writing $TARGET_FILE"
    mkdir -p "$TARGET_DIR"
    OUTPUT=$(perl -p -i -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' < "$BASEDIR/$1" 2> /dev/null)
    echo "$OUTPUT" > "$TARGET_FILE"
}

if [ $DRY_RUN -eq 0 ]; then
    apt-get install -y libqmi-utils udhcpc bird rsync netplug
fi

# Static Files

if [ $DRY_RUN -eq 0 ]; then
    rsync -av static/ /
fi

template hosts /etc/hosts
template interfaces /etc/network/interfaces
template netplugd.conf /etc/netplug/netplugd.conf
template qmi-network.conf /etc/qmi-network.conf
template bird.conf /etc/bird/bird.conf

if [ ! -d "$PATH_PREFIX/etc/openvpn/client" ]; then
	echo "OpenVPN uninitialized. Configuring client credentials keys/ directory"
	# initial OpenVPN configuration
	apt-get install -y openvpn
	mkdir -p /etc/openvpn/client
	cp "$BASEDIR/credentials/$OPENVPN_CLIENT_NAME.key" "/etc/openvpn/client/"
	cp "$BASEDIR/credentials/$OPENVPN_CLIENT_NAME.crt" "/etc/openvpn/client/"
	cp "$BASEDIR/credentials/ta.key" "/etc/openvpn/client/"
	cp "$BASEDIR/credentials/ca.crt" "/etc/openvpn/client/"

	chown -R root:root /etc/openvpn/client
	chmod -R 550 /etc/openvpn/client
fi	

export OPENVPN_DEV=tap0
export OPENVPN_HOST=$VPN_PRIMARY
template openvpn.conf /etc/openvpn/client-primary.conf
export OPENVPN_DEV=tap1
export OPENVPN_HOST=$VPN_SECONDARY
template openvpn.conf /etc/openvpn/client-secondary.conf

if [ $DRY_RUN -eq 0 ]; then
    # configure and run services
    systemctl enable openvpn@client-primary
    systemctl enable openvpn@client-secondary
    systemctl restart openvpn@client-primary
    systemctl restart openvpn@client-secondary

    systemctl enable bird
    systemctl restart bird

    systemctl disable bird6
    systemctl stop bird6
fi    
