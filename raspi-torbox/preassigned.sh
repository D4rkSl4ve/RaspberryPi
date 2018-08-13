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

# Jackett
echo -e '\nDownloading and replacing file(s) for:  Jackett' >> /var/log/rpi-config_install.log &&
echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Jackett \e[0m" &&
sudo systemctl stop jackett >> /var/log/rpi-config_install.log 2>&1 &&
sed -i 's+"BasePathOverride": null,+"BasePathOverride": "/jackett",+' /home/pi/.config/Jackett/ServerConfig.json >> /var/log/rpi-config_install.log 2>&1 &&
sudo systemctl start jackett >> /var/log/rpi-config_install.log 2>&1
