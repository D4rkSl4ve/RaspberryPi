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

  # Sonarr
  echo -e '\nDownloading and replacing file(s) for:  Sonarr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Sonarr \e[0m" &&
  sudo systemctl stop sonarr &&
  cd /home/pi/.config/NzbDrone &&
  rm config.xml && rm *.db* &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/sonarr/config.xml -O /home/pi/.config/NzbDrone/config.xml >> /var/log/rpi-config_install.log 2>&1 &&
  sudo chmod 644 /home/pi/.config/NzbDrone/config.xml &&
  sudo chown pi:pi /home/pi/.config/NzbDrone/config.xml &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/sonarr/nzbdrone.db -O /home/pi/.config/NzbDrone/nzbdrone.db >> /var/log/rpi-config_install.log 2>&1 &&
  sudo chmod 644 /home/pi/.config/NzbDrone/nzbdrone.db &&
  sudo chown pi:pi /home/pi/.config/NzbDrone/nzbdrone.db &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/sonarr/nzbdrone.db-journal -O /home/pi/.config/NzbDrone/nzbdrone.db-journal >> /var/log/rpi-config_install.log 2>&1 &&
  sudo chmod 644 /home/pi/.config/NzbDrone/nzbdrone.db-journal &&
  sudo chown pi:pi /home/pi/.config/NzbDrone/nzbdrone.db-journal &&
  sudo systemctl start sonarr &&
  sudo systemctl status sonarr >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> The \e[0;92mAPI Key has to be reset \e[0;96mat Settings/General, generate New API Key\e[0m" &&

  # Radarr
  echo -e '\nDownloading and replacing file(s) for:  Radarr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Radarr \e[0m" &&
  sudo systemctl stop radarr &&
  cd /home/pi/.config/Radarr &&
  rm config.xml && rm *.db* &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/radarr/config.xml -O /home/pi/.config/Radarr/config.xml >> /var/log/rpi-config_install.log 2>&1 &&
  sudo chmod 644 /home/pi/.config/Radarr/config.xml &&
  sudo chown pi:pi /home/pi/.config/Radarr/config.xml &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/radarr/nzbdrone.db -O /home/pi/.config/Radarr/nzbdrone.db >> /var/log/rpi-config_install.log 2>&1 &&
  sudo chmod 644 /home/pi/.config/Radarr/nzbdrone.db &&
  sudo chown pi:pi /home/pi/.config/Radarr/nzbdrone.db &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/radarr/nzbdrone.db-journal -O /home/pi/.config/Radarr/nzbdrone.db-journal >> /var/log/rpi-config_install.log 2>&1 &&
  sudo chmod 644 /home/pi/.config/Radarr/nzbdrone.db-journal &&
  sudo chown pi:pi /home/pi/.config/Radarr/nzbdrone.db-journal &&
  sudo systemctl start radarr &&
  sudo systemctl status radarr >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> The \e[0;92mAPI Key has to be reset \e[0;96mat Settings/General, generate New API Key\e[0m" &&

  # lidarr
  echo -e '\nDownloading and replacing file(s) for:  Lidarr' >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> Downloading and replacing file(s) for:\e[0;92m  Lidarr \e[0m" &&
  sudo systemctl stop lidarr &&
  cd /home/pi/.config/Lidarr &&
  rm config.xml && rm *.db* &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/lidarr/config.xml -O /home/pi/.config/Lidarr/config.xml >> /var/log/rpi-config_install.log 2>&1 &&
  sudo chmod 644 /home/pi/.config/Lidarr/config.xml &&
  sudo chown pi:pi /home/pi/.config/Lidarr/config.xml &&
  wget https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/master/raspi-torbox/lidarr/lidarr.db -O /home/pi/.config/Lidarr/lidarr.db >> /var/log/rpi-config_install.log 2>&1 &&
  sudo chmod 644 /home/pi/.config/Lidarr/lidarr.db &&
  sudo chown pi:pi /home/pi/.config/Lidarr/lidarr.db &&
  sudo systemctl start lidarr &&
  sudo systemctl status lidarr >> /var/log/rpi-config_install.log &&
  echo -e "\e[0;96m> The \e[0;92mAPI Key has to be reset \e[0;96mat Settings/General, generate New API Key\e[0m"

  else
    return 0
fi
}
