#!/bin/sh -eu

if [ "$(id -ur)" -ne "0" ]; then
    echo "$0 can only be run as root. Use sudo."
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# Install VirtualBox Guest Additions
echo "==> Installing VirtualBox guest additions"

apt-get update

## Install build packages
echo "Installing build packages..."
apt-get install -y dkms build-essential "linux-headers-$(uname -r)" libxt6 libxmu6
echo "Done."
   
## Assuming that the Guest Additions CD has been "attached"
echo "Building guest additions..."
mount -r /media/cdrom
BUILDERR=0
sh /media/cdrom/VBoxLinuxAdditions-arm64.run --nox11|| BUILDERR=$? 
if [ "$BUILDERR" != "2" ] && [ "$BUILDERR" != "0" ]; then
    echo 2>&1 "Error while building guest additions: code $BUILDERR"
    exit $BUILDERR
fi
umount /media/cdrom
echo "Done."

# Update GRUB settings
echo "==> Updating GRUB settings"

## Set boot loader timeout to 0
echo "Seting boot loader timeout"
sed -i 's/GRUB_TIMEOUT=\(.*\)/GRUB_TIMEOUT=0/g' /etc/default/grub;
echo "Done."

## Disable Predictable Network Interface names and use eth0

## This script disables "predictable interface names" like enp0s3,
## and restores the use of interface names like eth0.
## This seems to be needed if we use the virtualbox-ovf source,
## otherwise networking does not start on any VM created by the
## exported .ova file. The following issue gave the clue:
##   https://github.com/hashicorp/packer/issues/866
## and the solution was picked up from:
##   https://github.com/chef/bento/blob/master/packer_templates/debian/scripts/networking.sh

echo "Disabling predictable network interface names..."
## This script assumes that the names of all interfaces in
## /etc/network/interfaces will be replaced with eth0. This works
## for us, because we use only one interface connected to a NAT
## network.
sed -i 's/en[[:alnum:]]*/eth0/g' /etc/network/interfaces;
## Add kernel parameter to disable predictable interface names
sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0 \1"/g' /etc/default/grub;
echo "Done."

## Update grub
echo "Updating GRUB..."
update-grub;
echo "Done."

# Add/edit directories and files

echo "==> Adding/editing directories and files..."

## Patch networking
## Adding a 2 sec delay to the interface up, to make the dhclient happy
echo "pre-up sleep 2" >> /etc/network/interfaces

## Set up directory for later copying of kutti interface scripts
mkdir -p /home/kuttiadmin/kutti-installscripts
chown kuttiadmin:kuttiadmin /home/kuttiadmin/kutti-installscripts

## Set up basic motd
echo "Welcome to kutti." > /etc/motd

# Add required system packages
echo "==> Adding required system packages"

echo "Installing bash completion, socat, vim and curl..."
apt-get install -y apt-transport-https bash-completion socat vim curl
echo "Done."

# Add user1
echo "==> Adding user1"
adduser --gecos "User 1" --disabled-password user1
chpasswd <<EOPASSWD
user1:Pass@word1
EOPASSWD
adduser user1 sudo

