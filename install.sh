#!/bin/bash

# Stop on the first sign of trouble
set -e

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

VERSION="master"
if [[ $1 != "" ]]; then VERSION=$1; fi

echo "The Things Network Gateway installer"
echo "Version $VERSION"

# Update the gateway installer to the correct branch (defaults to master)
echo "Updating installer files..."
OLD_HEAD=$(git rev-parse HEAD)
git fetch
git checkout -q $VERSION
git pull
NEW_HEAD=$(git rev-parse HEAD)

if [[ $OLD_HEAD != $NEW_HEAD ]]; then
    echo "New installer found. Restarting process..."
    exec "./install.sh" "$VERSION"
fi

# Retrieve gateway configuration for later
echo "Configure your gateway:"
printf "       Descriptive name [ttn-ic880a]:"
read GATEWAY_NAME
if [[ $GATEWAY_NAME == "" ]]; then GATEWAY_NAME="ttn-ic880a"; fi

printf "       Contact email: "
read GATEWAY_EMAIL

printf "       Latitude [0]: "
read GATEWAY_LAT
if [[ $GATEWAY_LAT == "" ]]; then GATEWAY_LAT=0; fi

printf "       Longitude [0]: "
read GATEWAY_LON
if [[ $GATEWAY_LON == "" ]]; then GATEWAY_LON=0; fi

printf "       Altitude [0]: "
read GATEWAY_ALT
if [[ $GATEWAY_ALT == "" ]]; then GATEWAY_ALT=0; fi


# Change hostname if needed
CURRENT_HOSTNAME=$(hostname)
NEW_HOSTNAME="ttn-gateway"

if [[ $NEW_HOSTNAME != $CURRENT_HOSTNAME ]]; then
    echo "Updating hostname to '$NEW_HOSTNAME'..."
    hostname $NEW_HOSTNAME
    echo $NEW_HOSTNAME > /etc/hostname
    sed -i "s/$CURRENT_HOSTNAME/$NEW_HOSTNAME/" /etc/hosts
fi

# Check dependencies
echo "Installing dependencies..."
apt-get install swig libftdi-dev python-dev

# Install LoRaWAN packet forwarder repositories
INSTALL_DIR="/opt/ttn-gateway"
if [ ! -d "$INSTALL_DIR" ]; then mkdir $INSTALL_DIR; fi
pushd $INSTALL_DIR

# Build libraries
if [ ! -d libmpsse ]; then
    git clone https://github.com/devttys0/libmpsse.git
    pushd libmpsse/src
else
    pushd libmpsse/src
    git reset --hard
    git pull
fi

./configure --disable-python
make
make install
ldconfig

popd

# Build LoRa gateway app
if [ ! -d lora_gateway ]; then
    git clone https://github.com/TheThingsNetwork/lora_gateway.git
    pushd lora_gateway
else
    pushd lora_gateway
    git reset --hard
    git pull
fi

cp ./libloragw/99-libftdi.rules /etc/udev/rules.d/99-libftdi.rules

sed -i -e 's/CFG_SPI= native/CFG_SPI= ftdi/g' ./libloragw/library.cfg
sed -i -e 's/PLATFORM= kerlink/PLATFORM= lorank/g' ./libloragw/library.cfg
sed -i -e 's/ATTRS{idProduct}=="6010"/ATTRS{idProduct}=="6014"/g' /etc/udev/rules.d/99-libftdi.rules

make

popd

# Build packet forwarder
if [ ! -d packet_forwarder ]; then
    git clone https://github.com/TheThingsNetwork/packet_forwarder.git
    pushd packet_forwarder
else
    pushd packet_forwarder
    git pull
    git reset --hard
fi

make

popd

# Symlink poly packet forwarder
if [ ! -d bin ]; then mkdir bin; fi
if [ -f ./bin/poly_pkt_fwd ]; then rm ./bin/poly_pkt_fwd; fi
ln -s $INSTALL_DIR/packet_forwarder/poly_pkt_fwd/poly_pkt_fwd ./bin/poly_pkt_fwd
cp -f ./packet_forwarder/poly_pkt_fwd/global_conf.json ./bin/global_conf.json

echo -e "{\n\t\"gateway_conf\": {\n\t\t\"gateway_ID\": \"0000000000000000\",\n\t\t\"servers\": [ { \"server_address\": \"croft.thethings.girovito.nl\", \"serv_port_up\": 1700, \"serv_port_down\": 1701, \"serv_enabled\": true } ],\n\t\t\"ref_latitude\": $GATEWAY_LAT,\n\t\t\"ref_longitude\": $GATEWAY_LON,\n\t\t\"ref_altitude\": $GATEWAY_ALT,\n\t\t\"contact_email\": \"$GATEWAY_EMAIL\",\n\t\t\"description\": \"$GATEWAY_NAME\" \n\t}\n}" >./bin/local_conf.json

# Reset gateway ID based on MAC
./packet_forwarder/reset_pkt_fwd.sh start ./bin/local_conf.json

popd

echo "Installation completed."

# Start packet forwarder as a service
cp ./start.sh $INSTALL_DIR/bin/
cp ./ttn-gateway.service /lib/systemd/system/
systemctl enable ttn-gateway.service

echo "The system will reboot in 5 seconds..."
sleep 5
shutdown -r now
