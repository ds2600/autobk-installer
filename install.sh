#!/bin/bash

# Exit if there is an error
set -e
AB_GET_URL="https://dev.ishiganto.com/autobk/autobk.zip"
GUI_GET_URL="https://dev.ishiganto.com/autobk/cabgui.zip"
SQL_GET_URL="https://dev.ishiganto.com/autobk/autobk-installer.sql"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CFG_LOCATION="www/inc/config.php"
DB_ROOT_P=$( echo $RANDOM | md5sum | head -c 24 )

configure() {
   local ARG_FIX=$( echo "$2" | sed 's/\//\\\//g' )
   sed -i 's/{'"$1"'}/'"$ARG_FIX"'/' $GUI_LOCATION$CFG_LOCATION > $SCRIPT_DIR/install.log 2>&1
}

spin() {
pid=$! # Get PID of background command
while kill -0 $pid  # Signal 0 just tests whether the process exists
do
  echo -n "."
  sleep 0.5
done
}
# Execute as superuser preserving env variables
if [ $EUID != 0 ]; then
    sudo -E "$0" "$@"
        exit $?
fi

# Get .env file
if [ -f $SCRIPT_DIR/.env ]; then
    source $SCRIPT_DIR/.env
fi

echo -e "\n############\n" > $SCRIPT_DIR/install.log

# Install required packages
echo -e "(1/10) Updating Apt packages"
/usr/bin/apt update -y > $SCRIPT_DIR/install.log 2>&1 

echo -e "(2/10) Installing Apache2 web server"
/usr/bin/apt install -y apache2 > $SCRIPT_DIR/install.log 2>&1 

echo -e "(3/10) Installing PHP & Requirements" 
/usr/bin/apt install -y libapache2-mod-php7.4 php7.4 php7.4-common php7.4-curl php7.4-dev php7.4-gd php-pear php7.4-mysql > $SCRIPT_DIR/install.log 2>&1 

echo -e "(4/10) Installing Python & Requirements"
/usr/bin/apt install -y python3 > $SCRIPT_DIR/install.log 2>&1
/usr/bin/apt install -y python3-pip > $SCRIPT_DIR/install.log 2>&1
pip3 install beautifulsoup4
pip3 install easysnmp
pip3 install mysql-connector-python
pip3 install pyOpenSSL
pip3 install simplejson


# Install MariaDB server unless specified in .env
if [ $INSTALL_DB == "yes" ]; then
	echo -e $DB_ROOT_P > $SCRIPT_DIR/install.log
	echo -e "(5a/10) Installing MariaDB"
	/usr/bin/apt install -y mariadb-server > $SCRIPT_DIR/install.log 2>&1

	echo -e "(5b/10) Configuring MariaDB"
	# Set root password, delete anonymous users, delete remote root, delete test database, flush privileges
	mysql -sfu root -Bse "UPDATE mysql.user SET Password=PASSWORD('${DB_ROOT_P}') WHERE User='root';DELETE FROM mysql.user WHERE User='';DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';FLUSH PRIVILEGES;" > $SCRIPT_DIR/install.log 2>&1
	
	# Create user as designated in the .env file
	mysql -u root -p$DB_ROOT_P -Bse "CREATE USER '${SQL_UN}'@localhost IDENTIFIED BY '${SQL_PASS}';GRANT ALL PRIVILEGES ON *.* TO '${SQL_UN}'@localhost IDENTIFIED BY '${SQL_PASS}';FLUSH PRIVILEGES;" > $SCRIPT_DIR/install.log 2>&1

	# Create the AutoBk Database
	echo "CREATE DATABASE AutoBk;" | mysql -u $SQL_UN -p$SQL_PASS
#	mysql -u $SQL_UN -p$SQL_PASS < echo("CREATE DATABASE AutoBk;")
	
	# Get the latest AutoBK SQL and load it
	wget --no-cache $SQL_GET_URL > $SCRIPT_DIR/install.log 2>&1

	mysql -u $SQL_UN -p$SQL_PASS AutoBk < $SCRIPT_DIR/autobk-installer.sql


#		-- set root password
#		-- delete anonymous users
#		-- delete remote root capabilities
#		-- drop database 'test'
#		-- also make sure there are lingering permissions to it
#		-- create AutoBk user based on .env
#		-- grant AutoBk user privileges to all databases
#		-- grant AutoBk user privileges to JUST the AutoBk Database - disabled for now
#		-- GRANT ALL PRIVILEGES ON '${AUTOBK_DB}'.* TO '${SQL_UN}'@localhost;
#		-- make changes immediately

else
	echo -e "(5/10) Skipping MariaDB installation per user"
fi
	
echo -e "(6/10) Installing Unzip"
/usr/bin/apt install -y unzip > $SCRIPT_DIR/install.log 2>&1

echo -e "(7/10) Setting up AutoBk"
wget --no-cache $AB_GET_URL > $SCRIPT_DIR/install.log 2>&1


echo -e "(8/10) Setting up AutoBk web interface"
# if cabgui.zip doesn't exist in the current directory, download it and unzip it to
# the install directory listed in .env
if [ ! -f $SCRIPT_DIR/cabgui.zip ]; then
	wget --no-cache $GUI_GET_URL > $SCRIPT_DIR/install.log 2>&1
	unzip cabgui.zip -d $GUI_LOCATION > $SCRIPT_DIR/install.log 2>&1
	cp ${GUI_LOCATION}www/inc/config.example.php $GUI_LOCATION$CFG_LOCATION 
fi

# Modify configuration file to match .env
configure 'timezone' $TIME_ZONE
configure 'guilocation' $GUI_LOCATION
configure 'sqlun' $SQL_UN
configure 'sqlpass' $SQL_PASS
configure 'sqlhost' $SQL_HOST
configure 'sqlport' $SQL_PORT
configure 'sqlchar' $SQL_CHAR
configure 'ablocation' $AB_LOCATION
configure 'smtphost' $SMTP_HOST
configure 'smtpfrom' $SMTP_FROM
configure 'smtpemail' $SMTP_EMAIL

# Disable the default virtual host
a2dissite 000-default > $SCRIPT_DIR/install.log 2>&1

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
a2ensite 000-default > $SCRIPT_DIR/install.log 2>&1

echo -e "(7/7) Restarting Apache"
systemctl reload apache2 > $SCRIPT_DIR/install.log 2>&1

echo -e "Installation complete"

if [ $INSTALL_DB == "yes" ]; then
	echo -e "Your database 'root' password, you should save this as it won't be visible again:\n ${DB_ROOT_P}"
fi

