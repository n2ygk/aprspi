#!/usr/bin/bash
# needs to run as root and inherit these from the environment:
# TODO get from env
MYCALL=N2YGK
PASSCODE=XXXXX
BEACON='!4116.30N/07355.57W#PHG7300 testing de N2YGK'
RXGAIN=12 # Mic capture volume
TXGAIN=17 # Speaker playback volume

set -x

# find out which ALSA sound card the DINAH shows up as
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
# configuration for WIDE digipeater
APRSDIGI_CFG="--kill_dupes --kill_loops --subst_mycall  --x1j4_xlate \
 --logfile /var/log/aprsdigi.log --trace TRACE --trace WIDE --interface ax25:sm0:RELAY,WIDE,TRACE,"
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

