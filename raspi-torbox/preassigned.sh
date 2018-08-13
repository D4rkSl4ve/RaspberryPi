#!/bin/bash
# Part of raspi-config https://github.com/RPi-Distro/raspi-config
#
# See LICENSE file for copyright and license details
# Revised:  8/07/2018

INTERACTIVE=True
ASK_TO_REBOOT=0
BLACKLIST=/etc/modprobe.d/raspi-blacklist.conf
CONFIG=/boot/config.txt

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

# Sonarr
echo -e '\nDownloading and replacing file(s) for:  Sonarr' >> /var/log/rpi-config_install.log &&
echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Sonarr \e[0m" &&
sudo systemctl stop sonarr >> /var/log/rpi-config_install.log 2>&1 &&
#cd /home/pi/.config/NzbDrone >> /var/log/rpi-config_install.log &&
#rm config.xml && rm *.db* >> /var/log/rpi-config_install.log 2>&1 &&
#wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/sonarr/config.xml -O /home/pi/.config/NzbDrone/config.xml >> /var/log/rpi-config_install.log 2>&1 &&
#chmod 644 /home/pi/.config/NzbDrone/config.xml >> /var/log/rpi-config_install.log 2>&1 &&
#wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/sonarr/nzbdrone.db -O /home/pi/.config/NzbDrone/nzbdrone.db >> /var/log/rpi-config_install.log 2>&1 &&
#chmod 644 /home/pi/.config/NzbDrone/nzbdrone.db >> /var/log/rpi-config_install.log 2>&1 &&
#wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/sonarr/nzbdrone.db-journal -O /home/pi/.config/NzbDrone/nzbdrone.db-journal >> /var/log/rpi-config_install.log 2>&1 &&
#chmod 644 /home/pi/.config/NzbDrone/nzbdrone.db-journal >> /var/log/rpi-config_install.log 2>&1 &&
#sudo systemctl start sonarr >> /var/log/rpi-config_install.log 2>&1
# The API Key has to be reset at Settings/General, Generate New API KEYMAP
