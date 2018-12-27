#!/bin/sh
# --------------------------------------------------
# Ubuntu 16.04
# !!! need change HOSTNAME !!!
# --------------------------------------------------
sudo DEBIAN_FRONTEND=noninteractive apt -y update
sudo DEBIAN_FRONTEND=noninteractive apt -y upgrade
sudo apt -y install language-pack-ja
sudo timedatectl set-timezone Asia/Tokyo
sudo hostnamectl set-hostname HOSTNAME
sudo localectl set-locale LANG=ja_JP.utf8

# install need packages 
sudo DEBIAN_FRONTEND=noninteractive apt -y install git wget curl
sudo DEBIAN_FRONTEND=noninteractive apt -y install mysql-client libmysqlclient-dev
# sudo DEBIAN_FRONTEND=noninteractive apt -y install build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libncurses5-dev libncursesw5-dev tk-dev libffi-dev liblzma-dev llvm xz-utils

# --------------------------------------------------
# !!! DO NOT WORK !!!!
# --------------------------------------------------
# install anyenv
# if [ ! -d ~/.anyenv ]; then
#   git clone https://github.com/riywo/anyenv ~/.anyenv
#   echo 'export PATH="$HOME/.anyenv/bin:$PATH"' >> ~/.bashrc
#   echo 'eval "$(anyenv init -)"' >> ~/.bashrc
#   exec $SHELL -l
# fi