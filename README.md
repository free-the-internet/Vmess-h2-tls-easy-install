# Vmess + H2 + TLS easy install
Easy Setup Of Vmess + H2 + TLS with The Latest Xray

## What do you need?
0. Debian or Ubuntu with a root account.
1. A domain. Go to register one for free on Freenom: https://www.freenom.com, or buy one from any sources you know.
* Select .ml for certain countries that censor blocks the domains based on suffixes.
2. Add the Public Ip Address of your server to your domain while registering on Freenom. You can also add them later on in the DNS records section of domain management.
* For Freenom, add your Public Ip while registering by filling in both IP address fields.
![](1.png)

## Setup your proxy server
0. You may first need to install `curl` (`apt install curl`)

1. Open a Terminal window and run the following.
```
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)"
```
