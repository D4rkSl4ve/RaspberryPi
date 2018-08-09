# RaspberryPi

## Scripts
- raspi-torbox
```
sudo su -c "bash <(wget -qO- https://raw.githubusercontent.com/D4rkSl4ve/RaspberryPi/development/raspi-torbox/raspi-torbox.sh)" root
```
## Notes/Comments
```>> /var/log/rpi-config_install.log &&
>> /var/log/rpi-config_install.log 2>&1 &&```

```echo "Installing program:  program" >> /var/log/rpi-config_install.log &&```
```echo -e "\e[0;96m> Installing program:\e[0;92m  program \e[0m" &&```

```echo "Creating service for:  service" >> /var/log/rpi-config_install.log &&```
```echo -e "\e[0;96m> Creating service for:\e[0;92m  service \e[0m" &&```

```do_with_root apt-get install <program> -y >> /var/log/rpi-config_install.log 2>&1 &&```

```do_torbox_programs_preassgined_settings() {}```
