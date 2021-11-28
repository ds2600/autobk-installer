#!/bin/bash

# Exit if there is an error
set -e

# Global variables
AB_GET_URL="https://dev.ishiganto.com/autobk/autobk.zip"
GUI_GET_URL="https://dev.ishiganto.com/autobk/cabgui.zip"
SQL_GET_URL="https://dev.ishiganto.com/autobk/autobk-installer.sql"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CFG_LOCATION="www/inc/config.php"
DB_ROOT_P=$( echo $RANDOM | md5sum | head -c 24 )


# configure() is used to enter .env variables into the AutoBk-GUI configuration file
configure() {
   local ARG_FIX=$( echo "$3" | sed 's/\//\\\//g' )
   if [ $1 == 'autobk' ]; then
     sed -i 's/{'"$2"'}/'"$ARG_FIX"'/' ${SCRIPT_LOCATION}autobk/autobk.ini >> $SCRIPT_DIR/install.log 2>&1
   else
     sed -i 's/{'"$2"'}/'"$ARG_FIX"'/' $GUI_LOCATION$CFG_LOCATION >> $SCRIPT_DIR/install.log 2>&1
   fi
}

# spin() is used to display the stupid dots during the installation process
spin() {
   pid=$! # Get PID of background command
   while kill -0 $pid > /dev/null 2>&1  # Signal 0 just tests whether the process exists
    do
     echo -n "."
     sleep 1 
   done
}

# autobk-install() is used to install various dependencies using apt
autobk-install() {
	/usr/bin/apt install -y $1 >> $SCRIPT_DIR/install.log 2>&1 &
	spin
}


# Execute as superuser preserving env variables
if [ $EUID != 0 ]; then
    sudo -E "$0" "$@"
        exit $?
fi

# Get .env file
if [ -f $SCRIPT_DIR/.env ]; then
    source $SCRIPT_DIR/.env
else
    echo "You forgot the .env file!"; exit;
fi

mkdir $SCRIPT_LOCATION

# Install required packages
echo -e "Updating Apt packages"
/usr/bin/apt update -y >> $SCRIPT_DIR/install.log 2>&1 &
spin

echo -e "\nInstalling Apache2 web server"
autobk-install apache2

echo -e "\nInstalling PHP & Requirements" 
autobk-install libapache2-mod-php7.4
autobk-install php7.4
autobk-install php7.4-common
autobk-install php7.4-curl
autobk-install php7.4-dev
autobk-install php7.4-gd
autobk-install php-pear
autobk-install php7.4-mysql

echo -e "\nInstalling Python & Requirements"
autobk-install python3
autobk-install python3-pip
# Install Python dependencies
pip3 install beautifulsoup4 >> $SCRIPT_DIR/install.log 2>&1 &
spin
pip3 install easysnmp >> $SCRIPT_DIR/install.log 2>&1 &
spin
pip3 install mysql-connector-python >> $SCRIPT_DIR/install.log 2>&1 &
spin
pip3 install pyOpenSSL >> $SCRIPT_DIR/install.log 2>&1 &
spin
pip3 install simplejson >> $SCRIPT_DIR/install.log 2>&1 &
spin

# Install MariaDB server unless specified in .env
if [ $INSTALL_DB == "yes" ]; then
	echo -e "\nInstalling MariaDB"
	autobk-install mariadb-server

	echo -e "\nConfiguring MariaDB"
	# Set root password, delete anonymous users, delete remote root, delete test database, flush privileges
	mysql -sfu root -Bse "UPDATE mysql.user SET Password=PASSWORD('${DB_ROOT_P}') WHERE User='root';DELETE FROM mysql.user WHERE User='';DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';FLUSH PRIVILEGES;" >> $SCRIPT_DIR/install.log 2>&1 &
	spin
	
	# Create user as designated in the .env file
	mysql -u root -p$DB_ROOT_P -Bse "CREATE USER '${SQL_UN}'@localhost IDENTIFIED BY '${SQL_PASS}';GRANT ALL PRIVILEGES ON *.* TO '${SQL_UN}'@localhost IDENTIFIED BY '${SQL_PASS}';FLUSH PRIVILEGES;" >> $SCRIPT_DIR/install.log 2>&1 &
	spin

	# Create the AutoBk Database
	echo "CREATE DATABASE AutoBk;" | mysql -u $SQL_UN -p$SQL_PASS
	
	# Get the latest AutoBK SQL and load it
	wget --no-cache $SQL_GET_URL >> $SCRIPT_DIR/install.log 2>&1 &
	spin
	mysql -u $SQL_UN -p$SQL_PASS AutoBk < $SCRIPT_DIR/autobk-installer.sql &
	spin


#		-- grant AutoBk user privileges to JUST the AutoBk Database - disabled for now
#		-- GRANT ALL PRIVILEGES ON '${AUTOBK_DB}'.* TO '${SQL_UN}'@localhost;
else
	echo -e "\nSkipping MariaDB installation per user"
fi
	
echo -e "\nInstalling Unzip"
autobk-install unzip

# Get newest version of AutoBk and unzip it
echo -e "\nSetting up AutoBk"
wget --no-cache $AB_GET_URL >> $SCRIPT_DIR/install.log 2>&1 &
spin
unzip autobk.zip -d ${SCRIPT_LOCATION}autobk/ >> $SCRIPT_DIR/install.log 2>&1 &
spin

# Modify AutoBk .ini to match .env
configure autobk 'dir' $SCRIPT_LOCATION
configure autobk 'user' $SQL_UN
configure autobk 'pwd' $SQL_PASS
configure autobk 'host' $SQL_HOST

# Make AutoBk a systemd service
echo -e "\nEnabling AutoBk as a service"

# Create and save the autobk.service file
touch /etc/systemd/system/autobk.service
echo '[Unit]' >> /etc/systemd/system/autobk.service
echo 'Description=AutoBk' >> /etc/systemd/system/autobk.service
echo 'After=multi-user.target' >> /etc/systemd/system/autobk.service
echo '[Service]' >> /etc/systemd/system/autobk.service
echo 'Type=idle' >> /etc/systemd/system/autobk.service
echo 'User=root' >> /etc/systemd/system/autobk.service
echo 'WorkingDirectory='"$SCRIPT_LOCATION"'autobk' >> /etc/systemd/system/autobk.service
echo 'ExecStart=/usr/bin/python3.8 '"$SCRIPT_LOCATION"'autobk/srvc_autobk.py' >> /etc/systemd/system/autobk.service
echo '[Install]' >> /etc/systemd/system/autobk.service
echo 'WantedBy=multi-user.target' >> /etc/systemd/system/autobk.service

# Reload systemd and enable autobk.service
systemctl daemon-reload >> $SCRIPT_DIR/install.log 2>&1
sleep 5
systemctl enable autobk.service >> $SCRIPT_DIR/install.log 2>&1
sleep 5
echo -e "Starting AutoBk"
systemctl start autobk.service >> $SCRIPT_DIR/install.log 2>&1

# Get newest version of AutoBk-GUI and unzip it
echo -e "Setting up AutoBk web interface"
wget --no-cache $GUI_GET_URL >> $SCRIPT_DIR/install.log 2>&1 &
spin
unzip cabgui.zip -d $GUI_LOCATION >> $SCRIPT_DIR/install.log 2>&1 &
spin

# Copy example GUI configuration file
cp ${GUI_LOCATION}www/inc/config.example.php $GUI_LOCATION$CFG_LOCATION 

# Modify GUI configuration file to match .env
configure gui 'timezone' $TIME_ZONE
configure gui 'guilocation' $GUI_LOCATION
configure gui 'sqlun' $SQL_UN
configure gui 'sqlpass' $SQL_PASS
configure gui 'sqlhost' $SQL_HOST
configure gui 'sqlport' $SQL_PORT
configure gui 'sqlchar' $SQL_CHAR
configure gui 'ablocation' $AB_LOCATION
configure gui 'smtphost' $SMTP_HOST
configure gui 'smtpfrom' $SMTP_FROM
configure gui 'smtpemail' $SMTP_EMAIL

# Disable the default virtual host
a2dissite 000-default >> $SCRIPT_DIR/install.log 2>&1

# Add new directory permissions and WWW directory to virtual conf
GUI_NOSLASH=$( echo "$GUI_LOCATION" | sed 's/\//\\\//g' )
sed -i '1i<Directory '"$GUI_NOSLASH"'>' /etc/apache2/sites-available/000-default.conf
sed -i '2iOptions Indexes FollowSymLinks' /etc/apache2/sites-available/000-default.conf
sed -i '3iAllowOverride None' /etc/apache2/sites-available/000-default.conf
sed -i '4iRequire all granted' /etc/apache2/sites-available/000-default.conf
sed -i '5i<\/Directory> ' /etc/apache2/sites-available/000-default.conf
sed -i 's/\/var\/www\/html/'"$GUI_NOSLASH"'www/' /etc/apache2/sites-available/000-default.conf > $SCRIPT_DIR/install.log 2>&1
chown -R www-data:www-data $GUI_LOCATION
chmod -R 755 $GUI_LOCATION
a2ensite 000-default >> $SCRIPT_DIR/install.log 2>&1

echo -e "\nRestarting Apache"
systemctl reload apache2 >> $SCRIPT_DIR/install.log 2>&1

echo -e "Remove downloaded files"
rm -f $SCRIPT_DIR/autobk-installer.sql
rm -f $SCRIPT_DIR/autobk.zip
rm -f $SCRIPT_DIR/cabgui.zip

echo -e "Installation complete"

# Display database root password 
if [ $INSTALL_DB == "yes" ]; then
	echo -e "Your database 'root' password, you should save this as it won't be visible again:\n ${DB_ROOT_P}"
fi

echo -e "\n Please run 'sudo systemctl restart autobk.service'."

