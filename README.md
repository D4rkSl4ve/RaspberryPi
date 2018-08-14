# RaspberryPi

## Scripts
- raspi-torbox
```
sudo su -c "bash <(wget -qO- https://tinyurl.com/raspi-torbox)" root
```

## To-Do After PreAssigned Settings
- Open browser (Chrome or Firefox)
- For Deluge is your torboxIP:8112, set the folders if different
- For Jackett is your torboxIP:9117, and copy the API Key (top-right), as it will be needed for the other apps.
- For Sonarr is your torboxIP:8989, go to Settings, General, and reset the API Key by selecting the red recycle button, follow by Save.  Then go to Indexers, select Jackett indexer, and paste the API Key previously copied from Jackett, tested, and save it.
- Identical set of instructions for Radarr and Lidarr as above.
