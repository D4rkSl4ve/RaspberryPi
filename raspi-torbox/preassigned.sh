#!/bin/bash
# Part of raspi-config https://github.com/RPi-Distro/raspi-config
#
# See LICENSE file for copyright and license details
# Revised:  8/07/2018

INTERACTIVE=True
ASK_TO_REBOOT=0
BLACKLIST=/etc/modprobe.d/raspi-blacklist.conf
CONFIG=/boot/config.txt

sudo touch /var/log/rpi-config_install.log # Install log file for Raspi-TorBox
sudo chown pi:pi /var/log/rpi-config_install.log # Install log file for Raspi-TorBox

# Execute a command as root (or sudo)
do_with_root() {
    # already root? "Just do it" (tm).
    if [[ `whoami` = 'root' ]]; then
        $*
    elif [[ -x /usr/bin/sudo || -x /bin/sudo ]]; then
        echo "sudo $*"
        sudo $*
    else
        echo "Raspi-Config requires root privileges to install."
        echo "Please run this script as root."
        exit 1
    fi
}

# Deluge
echo -e '\nDownloading and replacing file(s) for:  Deluge' >> /var/log/rpi-config_install.log &&
echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Deluge \e[0m" &&
sudo systemctl stop deluge && do_with_root systemctl stop deluge-web >> /var/log/rpi-config_install.log 2>&1 &&
sudo wget https://github.com/D4rkSl4ve/RaspberryPi/raw/master/raspi-torbox/deluge/WebAPI-0.2.1-py2.7.egg -O /root/.config/deluge/plugins/WebAPI-0.2.1-py2.7.egg >> /var/log/rpi-config_install.log 2>&1 &&
sudo chmod 666 /root/.config/deluge/plugins/WebAPI-0.2.1-py2.7.egg >> /var/log/rpi-config_install.log 2>&1 &&
sudo rm /root/.config/deluge/core.conf >> /var/log/rpi-config_install.log 2>&1 &&
sudo wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/deluge/core.conf -O /root/.config/deluge/core.conf >> /var/log/rpi-config_install.log 2>&1 &&
sudo mv /usr/lib/python2.7/dist-packages/deluge/ui/web/js/deluge-all.js /usr/lib/python2.7/dist-packages/deluge/ui/web/js/deluge-all.js-backup >> /var/log/rpi-config_install.log 2>&1&&
sudo wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/deluge/deluge-all.js -O /usr/lib/python2.7/dist-packages/deluge/ui/web/js/deluge-all.js >> /var/log/rpi-config_install.log 2>&1&&
sudo chmod 644 /usr/lib/python2.7/dist-packages/deluge/ui/web/js/deluge-all.js >> /var/log/rpi-config_install.log 2>&1 &&
sudo mv /usr/lib/python2.7/dist-packages/deluge/ui/web/auth.py /usr/lib/python2.7/dist-packages/deluge/ui/web/auth.py-backup >> /var/log/rpi-config_install.log 2>&1 &&
sudo wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/deluge/auth.py -O /usr/lib/python2.7/dist-packages/deluge/ui/web/auth.py >> /var/log/rpi-config_install.log 2>&1 &&
sudo chmod 644 /usr/lib/python2.7/dist-packages/deluge/ui/web/auth.py >> /var/log/rpi-config_install.log 2>&1 &&
sudo sed -i 's+""show_session_speed": false,+"show_session_speed": true,+' /root/.config/deluge/web.conf >> /var/log/rpi-config_install.log 2>&1 &&
sudo systemctl start deluge && do_with_root systemctl start deluge-web >> /var/log/rpi-config_install.log 2>&1
