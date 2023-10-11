# Create OpenVPN server credentials

## 1. Connect to OpenVPN server

```sh
ssh -p <VPN_SERVER_SSH_PORT> root@<VPN_SERVER_IP>
```

## 2. change directory to OpenVPN server configuration

```sh
cd /etc/openvpn/server/
```

## 3. Create new key and sign client certificate

The following will generate an encrypted key for the user, for which the password is propmted during the key generation step.
Signing the users certificate requires the secret CA passphrase, which is noted in 1Password.

```sh
export VPN_USER=my_vpn_user
/usr/share/easy-rsa/easyrsa gen-req "$VPN_USER"
/usr/share/easy-rsa/easyrsa sign-req client "$VPN_USER"
```

## 4. export newly generated credentials to ENV variables

```sh
export CLIENT_KEY=$(cat "pki/private/$VPN_USER.key")
export CLIENT_CERTIFICATE=$(cat "pki/issued/$VPN_USER.crt")
export TA_KEY=$(cat ta.key)
export CA_CERTIFICATE=$(cat pki/ca.crt)
```

## 5. Ensure export directory exists

```sh
mkdir -p clients/
```

## 6. Substitute credentials in client configuration template

```sh
envsubst > "clients/$VPN_USER.ovpn" <<EOF
client
dev tun
proto udp
remote <VPN_SERVER_IP> <VPN_SERVER_PORT>
keepalive 10 40
resolv-retry infinite
nobind
user nobody
group nogroup
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
verb 3
#status /var/log/openvpn/tap0.status
#log-append /var/log/openvpn/tap0.log
<ca>
${CA_CERTIFICATE}
</ca>
key-direction 1
<tls-auth>
${TA_KEY}
</tls-auth>
<cert>
${CLIENT_CERTIFICATE}
</cert>
<key>
${CLIENT_KEY}
</key>
EOF
```

## 7. Download the users OpenVPN configuration

```sh
scp -P <VPN_SERVER_SSH_PORT> root@<VPN_SERVER_IP>:"/etc/openvpn/server/clients/*" .
```
