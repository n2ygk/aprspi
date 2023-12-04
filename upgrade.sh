#!/bin/sh
# upgrade from v1.0 to v1.1

apt-get install -y ufw
ufw allow ssh
ufw enable
 
# block hosts making repeated failed attempts

apt-get install -y fail2ban
# fails to start because it can't find sshd log when backend = auto
sed -i.bak -e s/^backend = auto/backend = systemd/ /etc/fail2ban/jail.conf
# this message doesn't cause a ban with default INFO level logging:
# Connection closed by authenticating user foo 192.168.1.154 port 59027 [preauth]
echo "LogLevel VERBOSE" >/etc/ssh/sshd_config.d/ssh_verbose.conf

systemctl restart fail2ban

 # we don't need to be multicasting who we are
apt-get remove -y avahi-daemon
apt autoremove -y

# enable automatic security updates
apt-get install -y unattended-upgrades
systemctl stop unattended-upgrades
cat >> /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::SyslogEnable "true";
EOF
systemctl enable unattended-upgrades
systemctl start unattended-upgrades
