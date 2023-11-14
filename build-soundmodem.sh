#!/usr/bin/bash
# rebuild soundmodem pkg to incorporate my fixes.

set -x
sudo sed -i -e 's/^#\(deb-src.*\)$/\1/' /etc/apt/sources.list
sudo apt-get update
sudo apt build-dep -y soundmodem
sudo apt-get install -y packaging-dev
cd ..
# apt-get source soundmodem
#src=soundmodem-0.20
git clone https://salsa.debian.org/debian-hamradio-team/soundmodem.git
src=soundmodem
cp aprspi/fix-missing-hid-dinah-gpio.patch $src/debian/patches/
echo fix-missing-hid-dinah-gpio.patch >>$src/debian/patches/series
export EMAIL="n2ygk@weca.org"
cd $src
dch -i "hidraw cm119b gpio ptt support"
debuild -b -uc -us

