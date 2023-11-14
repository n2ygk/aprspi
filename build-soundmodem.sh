#!/usr/bin/bash
# rebuild soundmodem pkg to incorporate my fixes.
BASEDIR=$(dirname $0)

sudo sed -i -e 's/^#\(deb-src.*\)$/\1/' /etc/apt/sources.list
sudo apt-get update
sudo apt build-dep -y soundmodem
sudo apt-get install -y packaging-dev
mkdir -p ${BASEDIR}/src
(cd ${BASEDIR}/src; apt-get source soundmodem)
# figure out what directory name it's in:
# e.g. soundmodem-0.20
srcdir=`dpkg -s soundmodem|sed -n -e 's/^Source: \(soundmodem\) (\(.*\)-.*$/\1-\2/p'`
cp fix-missing-hid-dinah-gpio.patch ${BASEDIR}/src/${srcdir}/debian/patches/
echo fix-missing-hid-dinah-gpio.patch >${BASEDIR}/src/${srcdir}/debian/patches/series
(
    cd ${BASEDIR}/src/$srcdir
    export EMAIL="n2ygk@weca.org"
    dch -i "hidraw cm119b gpio ptt support"
    debuild -b -uc -us
)

