#!/usr/bin/env bash

# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt-get install -y \
    python python-pip python-dev libffi-dev libssl-dev \
    python-virtualenv python-setuptools \
    libjpeg-dev zlib1g-dev swig \
    mongodb postgresql libpq-dev \
    virtualbox tcpdump apparmor-utils

# Create cuckoo user and group
sudo adduser --disabled-password --gecos "" cuckoo
sudo groupadd pcap
sudo usermod -a -G pcap cuckoo

# Set permissions for tcpdump
sudo chgrp pcap /usr/sbin/tcpdump
sudo setcap cap_net_raw,cap_net_admin=eip /usr/sbin/tcpdump
sudo aa-disable /usr/sbin/tcpdump

# Install m2crypto
sudo apt-get install -y swig
sudo pip install m2crypto

# Add cuckoo user to vboxusers group
sudo usermod -a -G vboxusers cuckoo

# Set up virtualenv and virtualenvwrapper
sudo apt-get install -y virtualenv virtualenvwrapper python3-pip
echo "source /usr/share/virtualenvwrapper/virtualenvwrapper.sh" >> ~/.bashrc
echo "export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3" >> ~/.bashrc
echo "source ~/.local/bin/virtualenvwrapper.sh" >> ~/.bashrc
export WORKON_HOME=~/.virtualenvs
echo "export WORKON_HOME=~/.virtualenvs" >> ~/.bashrc
echo "export PIP_VIRTUALENV_BASE=~/.virtualenvs" >> ~/.bashrc

# Reload bashrc
source ~/.bashrc

# Set up Cuckoo virtualenv
mkvirtualenv -p python2.7 cuckoo-test
pip install -U pip setuptools cuckoo

# Download Windows 7 ISO and set up VM
sudo wget https://cuckoo.sh/win7ultimate.iso -P /mnt/win7
sudo mkdir /mnt/win7
sudo chown cuckoo:cuckoo /mnt/win7/
sudo mount -o ro,loop /mnt/win7/win7ultimate.iso /mnt/win7
sudo apt-get install -y build-essential libssl-dev libffi-dev python-dev genisoimage
sudo apt-get install -y zlib1g-dev libjpeg-dev
pip install -U vmcloak
vmcloak-vboxnet0
vmcloak init --verbose --win7x64 win7x64base --cpus 2 --ramsize 2048
vmcloak clone win7x64base win7x64cuckoo
vmcloak list deps
vmcloak install win7x64cuckoo ie11
vmcloak snapshot --count 1 win7x64cuckoo 192.168.56.101
vmcloak list vms

# Initialize Cuckoo
cuckoo init
cuckoo community

# Add VM to Cuckoo
while read -r vm ip; do cuckoo machine --add $vm $ip; done < <(vmcloak list vms)

# Enable network forwarding
sudo sysctl -w net.ipv4.conf.vboxnet0.forwarding=1
sudo sysctl -w net.ipv4.conf.<your interface name>.forwarding=1

# Configure iptables
sudo iptables -t nat -A POSTROUTING -o <your interface name> -s 192.168.56.0/24 -j MASQUERADE
sudo iptables -P FORWARD DROP
sudo iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -s 192.168.56.0/24 -j ACCEPT

# Set up Cuckoo rooter
cuckoo rooter --sudo --group opensecure

# Start Cuckoo web interface
cuckoo web --host 127.0.0.1 --port 8080
