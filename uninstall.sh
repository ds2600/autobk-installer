#!/bin/bash

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

echo -e "\n############\n" > $SCRIPT_DIR/uninstall.log

# Install required packages
echo -e "\nUninstalling Apache2 web server"
/usr/bin/apt purge -y apache2 > $SCRIPT_DIR/uninstall.log 2>&1

echo -e "\nUninstalling PHP & Requirements"
/usr/bin/apt purge -y libapache2-mod-php7.4 php7.4 php7.4-common php7.4-curl php7.4-dev php7.4-gd php-pear php7.4-mysql > $SCRIPT_DIR/uninstall.log 2>&1

echo -e "\nUninstalling MySQL database"
/usr/bin/apt purge -y mysql-server mysql-client > $SCRIPT_DIR/uninstall.log 2>&1

echo -e "\nUninstalling Unzip"
/usr/bin/apt purge -y unzip > $SCRIPT_DIR/uninstall.log 2>&1

echo -e "\nRemoving AutoBk web interface"
rm -R /cabgui/
rm -R cabgui.zip
rm install.log

if [ $RM_ORPHAN_DEP == "yes" ]; then
        echo -e "\nRemoving orphaned packages"
        /usr/bin/apt autoremove -y > $SCRIPT_DIR/uninstall.log 2>&1
else
        echo -e "\nNot removing orphaned packages"
fi

echo -e "\nUninstallation complete"
