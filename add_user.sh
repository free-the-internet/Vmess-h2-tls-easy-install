#!/bin/bash

# Add user to xray config

# Check if jq is installed
if ! command -v jq &> /dev/null
then
    echo ""
    echo -e "\033[31mjq could not be found! Install with 'apt install jq'\033[0m"
    exit
fi

CONFIG_PATH='/etc/xray/config.json'
# Check if config file exists
if [ ! -f $CONFIG_PATH ]; then
    # echo in red
    echo -e "\033[31mXray config file not found in default path!\033[0m"
    echo -e "\033[94mEnter the path to your config file:\033[0m"
    echo -e "\033[94mExample: /etc/xray/config.json\033[0m"
    read -r CONFIG_PATH
    if [ ! -f "$CONFIG_PATH" ]; then
        echo -e "\033[31mConfig file not found in specified path!\033[0m"
        exit 1
    fi
fi

DOMAIN_NAME_F='./domain.name'
DOMAIN_NAME=""
# Check if domian.name file exists, if yes, print the domain name
if [ -f $DOMAIN_NAME_F ]; then
    echo -e "\033[94mDomain name found:\033[0m"
    echo -e "$(cat $DOMAIN_NAME_F)"
    echo -e "\033[94mDo you want to use this domain name? (y/n)\033[0m"
    read -r ANSWER
    if [ "$ANSWER" = "y" ]; then
        DOMAIN_NAME=$(cat $DOMAIN_NAME_F)
    else
        echo -e "\033[94mPlease enter your domain name (* Without www):\033[0m"
        read -r DOMAIN_NAME
        # Save domain name to file
        echo "$DOMAIN_NAME" > $DOMAIN_NAME_F
    fi
else
    echo -e "\033[94mPlease enter your domain name:\033[0m"
    read -r DOMAIN_NAME
    # Save domain name to file
    echo "$DOMAIN_NAME" > $DOMAIN_NAME_F
fi

# Ask the user to input OS name
echo -e "\033[94mPlease select end-user's OS:\033[0m"
echo -e "\033[94m1. Windows\033[0m"
echo -e "\033[94m2. Android\033[0m"
echo -e "\033[94m3. Iphone\033[0m"

# Read user input
read -r OS

# ENC method
ENC="none"
USER_NAME=""

if [ "$OS" == "1" ]; then
    # ENC in aes-128-gcm
    ENC="aes-128-gcm"
elif [ "$OS" == "2" ]; then
    # ENC in chacha20-poly1305
    ENC="chacha20-poly1305"
elif [ "$OS" == "3" ]; then
    # ENC in aes-128-gcm
    ENC="aes-128-gcm"
else
    echo -e "\033[33mPlease select a valid OS.\033[0m"
    exit 1
fi

# Ask the user to input a user name
echo -e "\033[33mPlease enter a name (Use A to Z and 1 to 9):\033[0m"
# Read user input
read -r USER_NAME

# Generate a random uuid
uuid=$(/usr/bin/uuidgen)

# Add to client array of v2ray config
jq '.inbounds[0].settings.clients += [{"id": "'$uuid'", "alterId": 0, "email": "'${USER_NAME}'@v.pn", "security": "'$ENC'"}]' $CONFIG_PATH > "$CONFIG_PATH".tmp
mv "$CONFIG_PATH".tmp $CONFIG_PATH

if jq empty "$CONFIG_PATH"; then
  echo -e "\033[33mSettings is valid\033[0m"
else
  echo -e "\033[94mSettings is invalid\033[0m"
  exit 1
fi

# Restart xray
systemctl restart xray

# Print the user info
echo -e "\033[94mUser info for manual enter\033[0m"
echo "Remarks: ${USER_NAME}"
echo "address: $DOMAIN_NAME"
echo "UUID/id: ${uuid}"
echo "Security/Encryption: ${ENC}"
echo "AlterId: 0"
echo "Network: h2 / tls"
echo "Leave the 'request host' and 'path' empty"
echo "SNI: www.$DOMAIN_NAME (with www.)"
echo "uTLS: chrome"
echo "alpn: h2, http/1.1"
echo "allowlnsecure: false"
# Calculate the base64 of the user info
VMESS=$(cat <<EOF
{"add":"$DOMAIN_NAME","aid":"0","alpn":"h2,http/1.1","host":"","id":"$uuid","net":"h2","path":"","port":"443","ps":"${USER_NAME:0:3}","scy":"$ENC","sni":"www.$DOMAIN_NAME","tls":"tls","type":"","v":"2"}
EOF
)
CC=$(echo $VMESS | base64 -w 0)
# Print a hline
echo -e "\033[94m=============USER INFO=============\033[0m"
echo -e "\033[32mvmess://$CC\033[0m"
echo -e "\033[94m=============USER INFO=============\033[0m"
echo -e "\033[33mDO NOT FORGET TO SET 'uTLS' to 'chrome' or 'firefox' AFTER ADDING THE CONFIG LINE\033[0m"
# Calculate the QR code of the user info
#echo -e "\033[94mQR code:\033[0m"
#echo -e "\033[32m$CC\033[0m" | qrencode -o - -t UTF8
