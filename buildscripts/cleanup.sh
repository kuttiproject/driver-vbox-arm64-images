#!/bin/sh -eu

if [ "$(id -ur)" -ne "0" ]; then
    echo "$0 can only be run as root. Use sudo."
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# Clean Up
echo "==> Cleaning up"

echo "Removing unneeded software..."
## We do not need the following packages:
##   dkms build-essential linux-headers-$(uname -r)
##   vim-tiny 
##   installation-report
##   perl
apt-get purge -y dkms build-essential linux-headers-$(uname -r) vim-tiny installation-report perl
## We apparently need make for vbox guest service to start on arm64
apt-get install -y make
echo "Done."

## The "laptop" tasksel task seems to be autoselected for whatever reason.
## Remove it while ignoring errors
echo "trying to remove *laptop* tasksel task..."
tasksel remove laptop && echo "Done." || echo "Laptop task could not be removed."

## Apt autoremove for all residual stuff
echo "Autoremoving unneeded software..."
apt-get autoremove -y
echo "Done."
