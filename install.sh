#!/bin/bash

# Exit if there is an error
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
GUI_URL="https://dev.ishiganto.com/autobk/cabgui.zip"

# Execute as superuser preserving env variables
if [ $EUID != 0 ]; then
    sudo -E "$0" "$@"
        exit $?
fi

# Get .env file
if [ -f $SCRIPT_DIR/.env ]; then
    source $SCRIPT_DIR/.env
fi

echo -e "\n############\n" >> $SCRIPT_DIR/install.log

# Install required packages
echo -e "(1/7) Updating Apt packages"
/usr/bin/apt update -y > $SCRIPT_DIR/install.log 2>&1

echo -e "(2/7) Installing Apache2 web server"
/usr/bin/apt install -y apache2 >> $SCRIPT_DIR/install.log 2>&1

echo -e "(3/7) Installing PHP & Requirements"
/usr/bin/apt install -y libapache2-mod-php7.4 php7.4 php7.4-common php7.4-curl php7.4-dev php7.4-gd php-pear php7.4-mysql >> $SCRIPT_DIR/install.log 2>&1

if [ $INSTALL_DB == "yes" ]; then
	echo -e "(4/7) Installing MySQL database"
	/usr/bin/apt install -y mysql-server mysql-client >> $SCRIPT_DIR/install.log 2>&1
else
	echo -e "(4/7) Skipping MySQL installation"
fi
	
echo -e "(5/7) Installing Unzip"
/usr/bin/apt install -y unzip >> $SCRIPT_DIR/install.log 2>&1

echo -e "(6/7) Setting up AutoBk web interface"
if [ ! -f $SCRIPT_DIR/cabgui.zip ]; then
	wget --no-cache $GUI_URL >> $SCRIPT_DIR/install.log 2>&1
	unzip cabgui.zip -d /cabgui/ >> $SCRIPT_DIR/install.log 2>&1
fi
a2dissite 000-default > $SCRIPT_DIR/install.log 2>&1
sed -i '1i<Directory \/cabgui\/>' /etc/apache2/sites-available/000-default.conf
sed -i '2iOptions Indexes FollowSymLinks' /etc/apache2/sites-available/000-default.conf
sed -i '3iAllowOverride None' /etc/apache2/sites-available/000-default.conf
sed -i '4iRequire all granted' /etc/apache2/sites-available/000-default.conf
sed -i '5i<\/Directory> ' /etc/apache2/sites-available/000-default.conf
sed -i 's/\/var\/www\/html/\/cabgui\/www/' /etc/apache2/sites-available/000-default.conf > $SCRIPT_DIR/install.log 2>&1
chown -R www-data:www-data /var/www/html/
chown -R www-data:www-data /cabgui/www/
chmod -R 755 /cabgui/www/
chmod -R 755 /var/www/html/
a2ensite 000-default >> $SCRIPT_DIR/install.log 2>&1

echo -e "(7/7) Restarting Apache"
systemctl reload apache2 >> $SCRIPT_DIR/install.log 2>&1

echo -e "Installation complete"

