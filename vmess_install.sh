#!/bin/bash

# Ask if user is registered a domain name
echo "Have you registered a domain name and set the Nameservers? (y/n)"
# Read user input, if yes, continue, if no, exit
read -r DOMAIN_NAME
if [ "$DOMAIN_NAME" = "y" ]; then
    echo "Please enter your domain name with www:"
    read -r DOMAIN_NAME
else
    echo "Please register a domain name first."
    exit 1
fi

apt update && apt upgrade -y
apt install -y jq curl unzip

# Install firewall
apt install -y ufw
# Allow ports 22, 80, 443
ufw allow 22
ufw allow 80
ufw allow 443
# Enable firewall
ufw enable

# Install certbot
apt install -y certbot

# Get cert for domain (* without email address to be notified the 1yr expiration)
sudo certbot certonly --standalone --agree-tos --register-unsafely-without-email -d "$DOMAIN_NAME"
# /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem
# /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem

# Check if certificate and private key exist
if [ ! -f /etc/letsencrypt/live/"$DOMAIN_NAME"/privkey.pem ]; then
    echo -e "\033[31mPrivekey not found!\033[0m"
    exit 1
fi
if [ ! -f /etc/letsencrypt/live/"$DOMAIN_NAME"/fullchain.pem ]; then
    echo -e "\033[31mCertificate not found!\033[0m"
    exit 1
fi

# Generate a random uuid
uuid=$(/usr/bin/uuidgen)

# Download latest release of Xray-core from git
LT_RELEASE_V=$(curl --silent "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | jq -r .tag_name)

# Get machine architecture
ARCH=$(uname -m)
case $ARCH in
'i386' | 'i686')
    MACHINE='32'
    ;;
'amd64' | 'x86_64')
    MACHINE='64'
    ;;
'armv7' | 'armv7l')
    MACHINE='arm32-v7a'
    grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
    ;;
'armv8' | 'aarch64')
    MACHINE='arm64-v8a'
    ;;
*)
    echo "Unsupported architecture."
    exit 1
    ;;
esac

# Download Xray-core
DOWNLOAD_LINK="https://github.com/XTLS/Xray-core/releases/download/$LT_RELEASE_V/Xray-linux-$MACHINE.zip"
curl -L -H "Cache-Control: no-cache" -o "Xray-linux-$MACHINE.zip" "$DOWNLOAD_LINK"

# Unzip Xray-core, install to /usr/bin/xray and remove zip file
unzip "Xray-linux-$MACHINE.zip" -d /usr/bin
rm -f "Xray-linux-$MACHINE.zip"

# Create log directory for v2ray
mkdir -p /var/log/v2ray
LOG_DIR="/var/log/v2ray"
# Create Xray config file
mkdir -p /etc/xray/
cat > /etc/xray/config.json << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "$LOG_DIR/access.log",
    "error": "$LOG_DIR/error.log"
  },

  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "timeout": 60,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "security": "chacha20-poly1305"
          }
        ]
      },
      "streamSettings": {
        "network": "h2",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem",
              "keyFile": "/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF

# Create Xray service file
cat > /etc/systemd/system/xray.service << EOF
[Unit]
Description=Xray - A unified platform for anti-censorship
Documentation=
After=network.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon
systemctl daemon-reload

# enable Xray service
systemctl enable xray

# start Xray service
systemctl start xray

# Check Xray status
systemctl status xray
