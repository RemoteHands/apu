#!/bin/sh
export HOSTNAME=$(cat /etc/hostname)
SCRIPT_PATH=$(readlink -f "$0")
export BASEDIR=$(dirname "$SCRIPT_PATH")
. $BASEDIR/vars

#apt-get install -y libqmi-utils udhcpc bird

template() {
    echo "Configuring $2"
    perl -p -i -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' < "$BASEDIR/$1" 2> /dev/null > "$2"
}

template hosts /etc/hosts
template interfaces /etc/network/interfaces
template qmi-network.conf /etc/qmi-network.conf
template bird.conf /etc/bird/bird.conf

if [ ! -d "/etc/openvpn/client" ]; then
	echo "OpenVPN uninitialized. Configuring client credentials keys/ directory"
	# initial OpenVPN configuration
	apt-get install -y openvpn
	mkdir -p /etc/openvpn/client
	cp "$BASEDIR/credentials/$HOSTNAME.key" "/etc/openvpn/client/"
	cp "$BASEDIR/credentials/$HOSTNAME.crt" "/etc/openvpn/client/"
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

# configure and run services
systemctl enable openvpn@client-primary
systemctl enable openvpn@client-secondary
systemctl start openvpn@client-primary
systemctl start openvpn@client-secondary

systemctl enable bird
systemctl restart bird

systemctl disable bird6
systemctl stop bird6

