#!/bin/bash

# Jackett
echo -e '\nDownloading and replacing file(s) for:  Jackett' >> /var/log/rpi-config_install.log &&
echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Jackett \e[0m" &&
sudo systemctl stop jackett &&
sed -i 's+"BasePathOverride": null,+"BasePathOverride": "/jackett",+' /home/pi/.config/Jackett/ServerConfig.json >> /var/log/rpi-config_install.log 2>&1 &&
sed -i 's+"UpdatePrerelease": false,+"UpdatePrerelease": true,+' /home/pi/.config/Jackett/ServerConfig.json >> /var/log/rpi-config_install.log 2>&1 &&
install -d -m 0755 -o pi -g pi /home/pi/.config/Jackett/Indexers && cd /home/pi/.config/Jackett/Indexers &&
wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/jackett/Indexers/eztv.json &&
wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/jackett/Indexers/rarbg.json &&
wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/jackett/Indexers/thepiratebay.json &&
sudo systemctl start jackett &&
sudo systemctl status jackett >> /var/log/rpi-config_install.log
