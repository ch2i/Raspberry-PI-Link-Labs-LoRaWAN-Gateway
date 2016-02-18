#!/bin/bash

# Stop on the first sign of trouble
set -e

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

echo "Link Labs Gateway installer"

# Update the gateway installer to the correct branch
echo "Updating installer files..."
VERSION="spi"
OLD_HEAD=$(git rev-parse HEAD)
git fetch
git checkout -q $VERSION
git pull
NEW_HEAD=$(git rev-parse HEAD)

if [[ $OLD_HEAD != $NEW_HEAD ]]; then
    echo "New installer found. Restarting process..."
    exec "./install.sh"
fi

# Retrieve gateway configuration for later
echo "Configure your gateway:"
printf "       server_address [iot.semtech.com]: "
read SERVER_AD
if [[ $SERVER_AD == "" ]]; then SERVER_AD="iot.semtech.com"; fi

printf "       serv_port_up [1680]: "
read PORT_UP
if [[ $PORT_UP == "" ]]; then PORT_UP="1680"; fi

printf "       serv_port_down [1680]: "
read PORT_DOWN
if [[ $PORT_DOWN == "" ]]; then PORT_DOWN="1680"; fi

printf "       Latitude [0]: "
read GATEWAY_LAT
if [[ $GATEWAY_LAT == "" ]]; then GATEWAY_LAT=0; fi

printf "       Longitude [0]: "
read GATEWAY_LON
if [[ $GATEWAY_LON == "" ]]; then GATEWAY_LON=0; fi

printf "       Altitude [0]: "
read GATEWAY_ALT
if [[ $GATEWAY_ALT == "" ]]; then GATEWAY_ALT=0; fi

# Check dependencies
echo "Installing dependencies..."
apt-get install swig python-dev

# Install LoRaWAN packet forwarder repositories
INSTALL_DIR="/opt/linklabs"
if [ ! -d "$INSTALL_DIR" ]; then mkdir $INSTALL_DIR; fi
pushd $INSTALL_DIR

# Build WiringPi
if [ ! -d wiringPi ]; then
    git clone git://git.drogon.net/wiringPi
    pushd wiringPi
else
    pushd wiringPi
    git reset --hard
    git pull
fi

./build

popd

# Build LoRa gateway app
if [ ! -d lora_gateway ]; then
    git clone https://github.com/Lora-net/lora_gateway.git
    pushd lora_gateway
else
    pushd lora_gateway
    git reset --hard
    git pull
fi

sed -i -e 's/PLATFORM= kerlink/PLATFORM= imst_rpi/g' ./libloragw/library.cfg

make

popd

# Build packet forwarder
if [ ! -d packet_forwarder ]; then
    git clone https://github.com/Lora-net/packet_forwarder.git
    pushd packet_forwarder
else
    pushd packet_forwarder
    git pull
    git reset --hard
fi

make

popd

# Symlink
if [ ! -d bin ]; then mkdir bin; fi
if [ -f ./bin/gps_pkt_fwd ]; then rm ./bin/gps_pkt_fwd; fi
ln -s $INSTALL_DIR/packet_forwarder/basic_pkt_fwd/basic_pkt_fwd ./bin/basic_pkt_fwd
ln -s $INSTALL_DIR/packet_forwarder/beacon_pkt_fwd/beacon_pkt_fwd ./bin/beacon_pkt_fwd
ln -s $INSTALL_DIR/packet_forwarder/gps_pkt_fwd/gps_pkt_fwd ./bin/gps_pkt_fwd
cp -f ./packet_forwarder/gps_pkt_fwd/global_conf.json ./bin/global_conf.json

echo -e "{\n\t\"gateway_conf\": {\n\t\t\"gateway_ID\": \"0000000000000000\",\n\t\t\"servers\": [ { \"server_address\": \"$GATEWAY_AD\", \"serv_port_up\": $PORT_UP, \"serv_port_down\": $PORT_DOWN, \"serv_enabled\": true } ],\n\t\t\"ref_latitude\": $GATEWAY_LAT,\n\t\t\"ref_longitude\": $GATEWAY_LON,\n\t\t\"ref_altitude\": $GATEWAY_ALT,\n\t\t\"contact_email\": \"$GATEWAY_EMAIL\",\n\t\t\"description\": \"$GATEWAY_NAME\" \n\t}\n}" >./bin/local_conf.json

# Reset gateway ID based on MAC
./packet_forwarder/reset_pkt_fwd.sh start ./bin/local_conf.json

popd

echo "Installation completed."

# Start packet forwarder as a service
cp ./start.sh $INSTALL_DIR/bin/
cp ./linklabs.service /lib/systemd/system/
systemctl enable linklabs.service

echo "The system will reboot in 5 seconds..."
sleep 5
shutdown -r now
