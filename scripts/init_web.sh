#!/bin/sh
# --------------------------------------------------
# Amazon Linux 2
# --------------------------------------------------
sudo yum update -y
sudo timedatectl set-timezone Asia/Tokyo
sudo hostnamectl set-hostname web
sudo localectl set-locale LANG=ja_JP.utf8

# install nginx web server
sudo amazon-linux-extras install -y nginx1.12
sudo systemctl start nginx.service
sudo systemctl enable nginx.service

# install mysql client
sudo yum install -y http://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm
sudo yum install -y mysql-community-devel mysql-community-client

# install need packages
sudo yum -y install wget curl git
# sudo yum -y install gcc bzip2 make openssl-devel libffi-devel readline-devel zlib-devel

# --------------------------------------------------
# !!! DO NOT WORK !!!!
# --------------------------------------------------
# install anyenv
# if [ ! -d ~/.anyenv ]; then
#   git clone https://github.com/riywo/anyenv ~/.anyenv
#   echo 'export PATH="$HOME/.anyenv/bin:$PATH"' >> ~/.bash_profile
#   echo 'eval "$(anyenv init -)"' >> ~/.bash_profile
#   exec $SHELL -l
#   anyenv install rbenv
#   exec $SHELL -l
# fi