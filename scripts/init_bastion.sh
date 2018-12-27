#!/bin/sh

# --------------------------------------------------
# Amazon Linux
# --------------------------------------------------

# key file
mv /tmp/id_rsa ~/.ssh/
sudo chmod 600 ~/.ssh/id_rsa

# hostname
sudo sed -i 's/^HOSTNAME=[a-zA-Z0-9\.\-]*$/HOSTNAME=bastion/g' /etc/sysconfig/network
sudo hostname 'bastion'

# timezoe
sudo cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
sudo sed -i 's|^ZONE=[a-zA-Z0-9\.\-\"]*$|ZONE="Asia/Tokyo"|g' /etc/sysconfig/clock

# lang
sudo bash -c 'echo "LANG=ja_JP.UTF-8" > /etc/sysconfig/i18n'

# yum
sudo yum update -y