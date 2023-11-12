#!/usr/bin/bash
# needs to run as root and inherit these from the environment:
# all configuration is keyed off the hostname.
MYCALL=`hostname`
PASSCODE=`python tools/passcode.py $MYCALL`
# for a wide digi: ALIASES="RELAY,WIDE,TRACE" and TRACE="--trace TRACE --trace WIDE"
# for a fill-in digi: ALIASES="RELAY,TRACE,WIDE1-1,TRACE1-1"

case $MYCALL in
    n2ygk)
	BEACON='!4116.30N/07355.57W#PHG7300/fill in digipeater n2ygk@weca.org'
	ALIASES="RELAY,TRACE,WIDE1-1,TRACE1-1"
	TRACE=""
	;;
    w2aee)
	BEACON='4048.56N/07357.61W#PHG7430/W-R-T www.w2aee.columbia.edu'
	ALIASES="RELAY,WIDE,TRACE"
	TRACE="--trace TRACE --trace WIDE"
	;;
    wb2zii)
	BEACON='4104.67N/07348.25W#PHG7550/W-R-T www.weca.org'
	ALIASES="RELAY,WIDE,TRACE"
	TRACE="--trace TRACE --trace WIDE"
	;;
    wb2zii-12)
	BEACON='!4054.  N/07349.  W#PHG7300/fill-in digipeater www.weca.org'
	ALIASES="RELAY,TRACE,WIDE1-1,TRACE1-1"
	TRACE=""
	;;
    wb2zii-13)
	BEACON='!4119.  N/07333.  W#PHG7530/ fill-in digipeater www.weca.org'
	ALIASES="RELAY,TRACE,WIDE1-1,TRACE1-1"
	TRACE=""
	;;
    wb2zii-14)
	BEACON='!4118.  N/07353.  W#PHG7300/fill-in digipeater www.weca.org'
	ALIASES="RELAY,TRACE,WIDE1-1,TRACE1-1"
	TRACE=""
	;;
    wb2zii-15)
	BEACON='!4116.  N/07348.  W#PHG7300/fill-in digipeater www.weca.org'
	ALIASES="RELAY,TRACE,WIDE1-1,TRACE1-1"
	TRACE=""
	;;
    *)
	BEACON='aprsdigi not configured de $MYCALL'
	ALIASES="RELAY,TRACE,WIDE1-1,TRACE1-1"
	TRACE=""
	;;
esac

# TODO ALIASES vs. fill-in

RXGAIN=12 # Mic capture volume
TXGAIN=17 # Speaker playback volume

set -x

# Find out which ALSA sound card the DINAH shows up as. This changes based on order of boot/usb hotplug.
#readlink /dev/snd/by-id/usb-C-Media_Electronics_Inc._USB_Audio_Device-00
card=`readlink /dev/snd/by-id/usb-C-Media_Electronics_Inc._USB_Audio_Device* | sed -e 's/^.*\(.\)$/\1/'`
if [ -z "$card" ]; then
    echo must plug in DINAH card before running this script.
fi

apt-get install -y libax25
apt-get install -y ax25-tools
apt-get install -y ax25-apps
# apt-get install -y soundmodem
# have to install my patched version.
if [ -f ../soundmodem_*.deb ]; then
    dpkg -i ../soundmodem_*.deb
else # it's missing so build it
./build-soundmodem.sh
fi
apt-get install -y aprsdigi
apt-get install -y aprx
apt-get install -y emacs

# Have udev make a symlink for the soundcard? NO. Only needed for kissattach to a USB serial port.
#cat >/lib/udev/rules.d/95-myusb.rules <<EOF
#ACTION=="add", ATTRS{idVendor}=="0d8c", ATTRS{idProduct}=="0012", SYMLINK="mytnc", TAG+="systemd"
#EOF

# set the alsamixer levels
sed -e "s/<%= @alsa_speaker_playback_volume %>/$TXGAIN/g" \
    -e "s/<%= @alsa_pcm_capture_volume %>/$RXGAIN/g" \
    < asound.state.erb >/var/lib/alsa/asound.state

cat >/etc/ax25/axports <<EOF
#portname	callsign	speed	paclen	window	description
sm0	$MYCALL	1200	255	2	144.39 MHz (1200 bps)
EOF

cat >/etc/ax25/soundmodem.conf <<EOF
<?xml version="1.0"?>
<modem>
  <configuration name="sm0">
    <chaccess txdelay="150" slottime="100" ppersist="40" fulldup="0" txtail="10"/>
    <audio type="alsa" device="plughw:${card},0" halfdup="0" capturechannelmode="Mono"/>
    <ptt file="/dev/hidraw0" hamlib_model="" hamlib_params="" gpio="2"/>
    <channel name="Channel 0">
      <mod mode="afsk" bps="1200" f0="1200" f1="2200" diffenc="1"/>
      <demod mode="afsk" bps="1200" f0="1200" f1="2200" diffdec="1"/>
      <pkt mode="MKISS" ifname="sm0" hwaddr="$MYCALL" ip="10.0.0.1" netmask="255.255.255.0" broadcast="10.0.0.255"/>
    </channel>
  </configuration>
</modem>
EOF

cat >/etc/ax25/aprsdigi.conf <<EOF
APRSDIGI_CFG="--kill_dupes --kill_loops --subst_mycall --x1j4_xlate --logfile /var/log/aprsdigi.log ${TRACE} --interface ax25:sm0:${ALIASES}"
BEACON_DEST='APRS via WIDE2-2'
BEACON_PORT=sm0
BEACON_TEXT='$BEACON'
EOF

cat >/etc/aprx.conf <<EOF
# stripped down aprx.conf

mycall  $MYCALL

<aprsis>
passcode $PASSCODE
server    rotate.aprs2.net
</aprsis>

<logging>
pidfile /var/run/aprx.pid
rflog /var/log/aprx/aprx-rf.log
aprxlog /var/log/aprx/aprx.log
</logging>

<interface>
   ax25-device   \$mycall
   #tx-ok        false  # transmitter enable defaults to false
   telem-to-is	 false
</interface>
EOF

cp aprsdigi.service aprsbeacon.service /lib/systemd/system/
systemctl daemon-reload
cp logrotate.aprsdigi /etc/logrotate.d

systemctl enable soundmodem
systemctl enable aprsdigi
systemctl enable aprsbeacon

systemctl start soundmodem
systemctl start aprsdigi

