#!/bin/bash

if (whiptail --title "Criteria to use preassigned settings" --yesno --defaultno "
  • Rebooted after running the 'First Time Boot'
  • Installed the 'Requirement Packages'
  • Installed the 'TorBox Programs'
  • Rebooted after installing the 'Required Packages and TorBox Programs'
  • All the services have been started/opened by their respective port numbers
    via a local browser  (ie torboxIP:port - 192.168.0.60:8989)
    - Deluge  (torboxIP:8112)
    - Jackett (torboxIP:9117)
    - Sonarr  (torboxIP:8989)
    - Radarr  (torboxIP:7878)
    - Lidarr  (torboxIP:8686)


                    Has the following criteria been met?
    " 20 85) then

      # Jackett
      echo -e '\nDownloading and replacing file(s) for:  Jackett' >> /var/log/rpi-config_install.log &&
      echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Jackett \e[0m" &&
      sudo systemctl stop jackett &&
      sed -i 's+"BasePathOverride": null,+"BasePathOverride": "/jackett",+' /home/pi/.config/Jackett/ServerConfig.json >> /var/log/rpi-config_install.log 2>&1 &&
      sed -i 's+"UpdatePrerelease": false,+"UpdatePrerelease": true,+' /home/pi/.config/Jackett/ServerConfig.json >> /var/log/rpi-config_install.log 2>&1 &&
      mkdir -m755 Indexers && cd /home/pi/.config/Jackett/Indexers &&
      wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/jackett/Indexers/eztv.json &&
      wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/jackett/Indexers/rarbg.json &&
      wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/jackett/Indexers/thepiratebay.json &&
      sudo systemctl start jackett &&
      sudo systemctl status jackett >> /var/log/rpi-config_install.log &&



  else
    return 0
fi
}
