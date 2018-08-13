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
sudo systemctl stop sonarr &&
cd /home/pi/.config/NzbDrone &&
rm config.xml && rm *.db* &&
wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/sonarr/config.xml -O /home/pi/.config/NzbDrone/config.xml >> /var/log/rpi-config_install.log 2>&1 &&
chmod 644 /home/pi/.config/NzbDrone/config.xml &&
wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/sonarr/nzbdrone.db -O /home/pi/.config/NzbDrone/nzbdrone.db >> /var/log/rpi-config_install.log 2>&1 &&
chmod 644 /home/pi/.config/NzbDrone/nzbdrone.db &&
wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/sonarr/nzbdrone.db-journal -O /home/pi/.config/NzbDrone/nzbdrone.db-journal >> /var/log/rpi-config_install.log 2>&1 &&
chmod 644 /home/pi/.config/NzbDrone/nzbdrone.db-journal &&
sudo systemctl start sonarr
# The API Key has to be reset at Settings/General, Generate New API KEYMAP

# Radarr
echo -e '\nDownloading and replacing file(s) for:  Radarr' >> /var/log/rpi-config_install.log &&
echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Radarr \e[0m" &&
sudo systemctl stop radarr &&
cd /home/pi/.config/Radarr &&
rm config.xml && rm *.db* &&
wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/radarr/config.xml -O /home/pi/.config/Radarr/config.xml >> /var/log/rpi-config_install.log 2>&1 &&
chmod 644 /home/pi/.config/Radarr/config.xml &&
wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/radarr/nzbdrone.db -O /home/pi/.config/Radarr/nzbdrone.db >> /var/log/rpi-config_install.log 2>&1 &&
chmod 644 /home/pi/.config/Radarr/nzbdrone.db &&
wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/radarr/nzbdrone.db-journal -O /home/pi/.config/Radarr/nzbdrone.db-journal >> /var/log/rpi-config_install.log 2>&1 &&
chmod 644 /home/pi/.config/Radarr/nzbdrone.db-journal &&
sudo systemctl start radarr &&
# The API Key has to be reset at Settings/General, Generate New API KEYMAP

# lidarr
echo -e '\nDownloading and replacing file(s) for:  Lidarr' >> /var/log/rpi-config_install.log &&
echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Lidarr \e[0m" &&
sudo systemctl stop lidarr &&
cd /home/pi/.config/Lidarr &&
rm config.xml && rm *.db* &&
wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/lidarr/config.xml -O /home/pi/.config/Lidarr/config.xml >> /var/log/rpi-config_install.log 2>&1 &&
chmod 644 /home/pi/.config/Lidarr/config.xml &&
wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/lidarr/lidarr.db -O /home/pi/.config/Lidarr/lidarr.db >> /var/log/rpi-config_install.log 2>&1 &&
chmod 644 /home/pi/.config/Lidarr/lidarr.db &&
wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/lidarr/nzbdrone.db-journal -O /home/pi/.config/Lidarr/nzbdrone.db-journal >> /var/log/rpi-config_install.log 2>&1 &&
chmod 644 /home/pi/.config/Lidarr/nzbdrone.db-journal &&
sudo systemctl start lidarr #&&
# The API Key has to be reset at Settings/General, Generate New API KEYMAP
