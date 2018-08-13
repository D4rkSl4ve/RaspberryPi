#!/bin/bash

# Jackett:  program
echo -e '\nDownloading and installing program:  Jackett' >> /var/log/rpi-config_install.log &&
echo -e "\e[0;96m> Downloading and installing program:\e[0;92m  Jackett \e[0m" &&
cd /home/pi/Downloads
wget https://github.com/Jackett/Jackett/releases/download/v0.9.41/Jackett.Binaries.Mono.tar.gz >> /var/log/rpi-config_install.log 2>&1 &&
do_with_root tar -zxf Jackett.Binaries.Mono.tar.gz --directory /opt/ >> /var/log/rpi-config_install.log 2>&1 &&
do_with_root chown -Rh pi:pi /opt/Jackett &&

# Jackett:  service
echo -e '\nCreating service for:  Jackett' >> /var/log/rpi-config_install.log &&
echo -e "\e[0;96m> Creating service for:\e[0;92m  Jackett \e[0m" &&
cd /home/pi
cat > jackett.service << EOF
[Unit]
Description=Jackett Daemon
After=network.target

[Service]
User=pi
Restart=always
RestartSec=5
Type=simple
ExecStart=/usr/bin/mono --debug /opt/Jackett/JackettConsole.exe --NoRestart
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF
do_with_root mv jackett.service /lib/systemd/system/jackett.service

echo -e '\nStarting service:  Jackett' >> /var/log/rpi-config_install.log &&
echo -e "\e[0;96m> Starting service:\e[0;92m  Jackett \e[0m" &&
sudo systemctl enable jackett >> /var/log/rpi-config_install.log &&
sudo systemctl start jackett &&
sudo systemctl status jackett >> /var/log/rpi-config_install.log
