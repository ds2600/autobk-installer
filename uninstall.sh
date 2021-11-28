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

echo -e "\n############\n" >> $SCRIPT_DIR/uninstall.log

# Install required packages
echo -e "Uninstalling Apache2 web server"
/usr/bin/apt purge -y apache2 > $SCRIPT_DIR/uninstall.log 2>&1

echo -e "Uninstalling PHP & Requirements"
/usr/bin/apt purge -y libapache2-mod-php7.4 php7.4 php7.4-common php7.4-curl php7.4-dev php7.4-gd php-pear php7.4-mysql > $SCRIPT_DIR/uninstall.log 2>&1

echo -e "Uninstalling MariaDB database"
/usr/bin/apt-get purge -y mariadb-server > $SCRIPT_DIR/uninstall.log 2>&1
/usr/bin/apt-get --purge autoremove -y mariadb-* 
/usr/bin/apt-get --purge autoremove -y mysql-* 

#mv /var/lib/mysql /var/lib/mysql_old
#mv /etc/mysql /etc/mysql_old

echo -e "Uninstalling Unzip"
/usr/bin/apt purge -y unzip > $SCRIPT_DIR/uninstall.log 2>&1

echo -e "Removing AutoBk web interface"
rm -f -R /cabgui/ > $SCRIPT_DIR/uninstall.log 2>&1
rm -f -R cabgui.zip > $SCRIPT_DIR/uninstall.log 2>&1
rm -f autobk-installer.sql > $SCRIPT_DIR/uninstall.log 2>&1
rm -f install.log > $SCRIPT_DIR/uninstall.log 2>&1

echo -e "Remove AutoBk"
rm -f autobk.zip > $SCRIPT_DIR/uninstall.log 2>&1
rm -f -R /backups/ > $SCRIPT_DIR/uninstall.log 2>&1
systemctl disable autobk.service > $SCRIPT_DIR/uninstall.log 2>&1
rm -f /etc/systemd/system/autobk.service > $SCRIPT_DIR/uninstall.log 2>&1

if [ $RM_ORPHAN_DEP == "yes" ]; then
        echo -e "Removing orphaned packages"
        /usr/bin/apt autoremove -y > $SCRIPT_DIR/uninstall.log 2>&1
else
        echo -e "Not removing orphaned packages per .env"
fi

echo -e "Uninstallation complete"
