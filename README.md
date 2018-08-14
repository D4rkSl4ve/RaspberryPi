# RaspberryPi

## Scripts
- raspi-torbox
```
<<<<<<< HEAD
sudo su -c "bash <(wget -qO- https://tinyurl.com/raspi-torbox)" root
```

## To-Do After PreAssigned Settings
- Open browser (Chrome or Firefox)
- For Deluge is your torboxIP:8112, set the folders if differt
- For Jackett is your torboxIP:9117, and copy the API Key (top-right), as it will be needed for the other apps.
- For Sonarr is your torboxIP:8989, go to Settings, General, and reset the API Key by selecting the red recycle button, follow by Save.  Then go to Indexers, select Jackett indexer, and paste the API Key previously copied from Jackett.
- Identical set of instructions for Radarr and Lidarr as above.
=======
sudo su -c "bash <(wget -qO- https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/development/raspi-torbox/raspi-torbox.sh)" root
sudo su -c "bash <(wget -qO- https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/development/raspi-torbox/test1.sh)" root
sudo su -c "bash <(wget -qO- https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/development/raspi-torbox/test2.sh)" root
```
## Notes/Comments
```
>> /var/log/rpi-config_install.log &&
>> /var/log/rpi-config_install.log 2>&1 &&

echo "\nInstalling program:  program" >> /var/log/rpi-config_install.log &&
echo -e "\e[0;96m> Installing program:\e[0;92m  program \e[0m" &&

echo "\nCreating service for:  service" >> /var/log/rpi-config_install.log &&
echo -e "\e[0;96m> Creating service for:\e[0;92m  service \e[0m" &&

do_with_root apt-get install <program> -y >> /var/log/rpi-config_install.log 2>&1 &&

do_torbox_programs_preassgined_settings() {}
```
## To-Do list
- check all preassigned settings
- finish whiptail menu for preassigned Settings
- make menus as checklist, so multiple actions can happen
>>>>>>> development
