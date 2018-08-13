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

  echo -e '\nEditing, Download, Replacing, and Installation of preassgined settings\n'`date` >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;93m> Editing, Download, Replacing, and Installation of preassgined settings \e[0m\n" &&

  # Deluge
  echo -e '\nDownloading and replacing file(s) for:  Deluge' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Deluge \e[0m" &&
  sudo systemctl stop deluge && sudo systemctl stop deluge-web &&
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
  sudo systemctl start deluge && sudo systemctl start deluge-web &&
  sudo systemctl status deluge >> /var/log/rpi-config_install.log &&
  sudo systemctl status deluge-web >> /var/log/rpi-config_install.log &&

  # Jackett
  echo -e '\nDownloading and replacing file(s) for:  Jackett' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Jackett \e[0m" &&
  sudo systemctl stop jackett &&
  sed -i 's+"BasePathOverride": null,+"BasePathOverride": "/jackett",+' /home/pi/.config/Jackett/ServerConfig.json >> /var/log/rpi-config_install.log 2>&1 &&
  sed -i 's+"UpdatePrerelease": false,+"UpdatePrerelease": true,+' /home/pi/.config/Jackett/ServerConfig.json >> /var/log/rpi-config_install.log 2>&1 &&
  sudo systemctl start jackett &&
  sudo systemctl status jackett >> /var/log/rpi-config_install.log
  
      else
        return 0
    fi
    do_reboot_reminder
  }
