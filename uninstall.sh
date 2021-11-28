#!/bin/bash

read -p "Are you sure you want to run uninstall? This action is destructive and un-recoverable.[y/n] " -n 1 -r
echo -e "\n"    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi
# Exit if there is an error
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Execute as superuser preserving env variables
if [ $EUID != 0 ]; then
    sudo -E "$0" "$@"
        exit $?
fi

# Get .env file
if [ -f $SCRIPT_DIR/.env ]; then
    source $SCRIPT_DIR/.env
fi

autobk-remove() {
    /usr/bin/apt purge -y $1 >> $SCRIPT_DIR/uninstall.log 2>&1
}

# Install required packages
echo -e "Uninstalling Apache2 web server"
autobk-remove apache2

echo -e "Uninstalling PHP & Requirements"
autobk-remove libapache2-mod-php7.4
autobk-remove php7.4
autobk-remove php7.4-common
autobk-remove php7.4-curl
autobk-remove php7.4-dev
autobk-remove php7.4-gd
autobk-remove php-pear
autobk-remove php7.4-mysql


echo -e "Uninstalling MariaDB database"
autobk-remove mariadb-server
/usr/bin/apt-get --purge autoremove -y mariadb-* 
/usr/bin/apt-get --purge autoremove -y mysql-* 

echo -e "Uninstalling Unzip"
autobk-remove unzip

echo -e "Removing AutoBk web interface"
rm -f -R ${GUI_LOCATION} > $SCRIPT_DIR/uninstall.log 2>&1
rm -f -R cabgui.zip > $SCRIPT_DIR/uninstall.log 2>&1
rm -f install.log > $SCRIPT_DIR/uninstall.log 2>&1

echo -e "Remove AutoBk"
rm -f -R ${SCRIPT_LOCATION} > $SCRIPT_DIR/uninstall.log 2>&1
rm -f /etc/systemd/system/autobk.service > $SCRIPT_DIR/uninstall.log 2>&1

if [ $RM_ORPHAN_DEP == "yes" ]; then
        echo -e "Removing orphaned packages"
        /usr/bin/apt autoremove -y > $SCRIPT_DIR/uninstall.log 2>&1
else
        echo -e "Not removing orphaned packages per .env"
fi

echo -e "Uninstallation complete"
