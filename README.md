# Raspberry-PI-Link-Labs-LoRaWAN-Gateway

Reference setup for LoRaWAN Gateway based on a Raspberry Pi host and the Link Labs [Gateway Board](http://store.link-labs.com/products/lorawan-raspberry-pi-board).

## Hardware setup

[schematic](http://forum.thethingsnetwork.org/uploads/default/original/1X/dbdd7deb2b854bb7104019d79683f2d1ae9f1c51.pdf)

| Description   | RPi pin
|---------------|-----------------
| SX1301 Reset  | 29 GPIO5 output
| GPS Reset     | 31 GPIO6 output
| PPS           |  7 GPIO4 input
| SPI CLK       | 23
| SPI MISO      | 21
| SPI MOSI      | 19
| SPI NSS       | 24

Now you're ready to start the software setup.

## Software setup (Raspbian)

- Download [Raspbian Jessie](https://www.raspberrypi.org/downloads/)
- Follow the [installation instruction](https://www.raspberrypi.org/documentation/installation/installing-images/README.md) to create the SD card
- Connect an Ethernet cable to the RPi
- Plug the power supply of the RPi which will also power the concentrator board (**WARNING**: never power up without the antenna!)
- From a computer in the same LAN, `ssh` into the RPi using the default hostname:

        local $ ssh pi@raspberrypi.local

- Use `raspi-config` utility to: 1) disable graphical boot mode and 2) to **enable SPI** (`Advanced options -> SPI`):

        $ sudo raspi-config

- Reboot
- Configure locales and time zone:

        $ sudo dpkg-reconfigure locales
        $ sudo dpkg-reconfigure tzdata

- Remove desktop-related packages:

        $ sudo apt-get install deborphan
        $ sudo apt-get autoremove --purge libx11-.* lxde-.* raspberrypi-artwork xkb-data omxplayer penguinspuzzle sgml-base xml-core alsa-.* cifs-.* samba-.* fonts-.* desktop-* gnome-.*
        $ sudo apt-get autoremove --purge $(deborphan)
        $ sudo apt-get autoremove --purge
        $ sudo apt-get autoclean
        $ sudo apt-get update

- Create new user for linklabs and add it to sudoers

        $ sudo adduser linklabs 
        $ sudo adduser linklabs sudo

- Logout and login as `linklabs` and remove the default `pi` user

        $ sudo userdel -rf pi

- Clone the installer and start the installation

        $ git clone https://github.com/kersing/Raspberry-PI-Link-Labs-LoRaWAN-Gateway.git ~/linklabs
        $ cd ~/linklabs
        $ sudo ./install.sh


# Credits

These scripts are largely based on the awesome work by [Ruud Vlaming](https://github.com/devlaam) on the [Lorank8 installer](https://github.com/Ideetron/Lorank).
This repository has been forked from https://github.com/mirakonta/Raspberry-PI-Link-Labs-LoRaWAN-Gateway, the changes were made to use older gateway software
required because The Things Network does not yet support the new protocol used by the newest Lora-net/packet_forwarder.
