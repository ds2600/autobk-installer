#!/bin/bash

cat << "EOF"
                _        ____  _
     /\        | |      |  _ \| |
    /  \  _   _| |_ ___ | |_) | | __
   / /\ \| | | | __/ _ \|  _ <| |/ /
  / ____ \ |_| | || (_) | |_) |   <
 /_/    \_\__,_|\__\___/|____/|_|\_\

EOF


# Exit if there is an error
set -e

# Global variables
ABP_GET_URL="https://github.com/ds2600/autobk-p/archive/refs/tags/latest.zip"
ABR_GET_URL="https://github.com/ds2600/autobk-r/archive/refs/tags/latest.zip"
GUI_GET_URL="https://github.com/ds2600/autobk-controller/archive/refs/tags/latest.zip"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DB_ROOT_PWD=$( echo $RANDOM | md5sum | head -c 24 )

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

# autobk-install() is used to install various dependencies using apt
autobk-install() {
	/usr/bin/apt install -y $1 >> $SCRIPT_DIR/install.log 2>&1 &
}

echo -e "############### " && date >> $SCRIPT_DIR/install.log 2>&1

# Make the core AutoBk directory
mkdir -p $AUTOBK_DIR

# Install required packages
echo -e "Updating Apt packages"
/usr/bin/apt update -y >> $SCRIPT_DIR/install.log 2>&1 &

echo -e "\nInstalling required apt packages"
autobk-install unzip
autobk-install python3
autobk-install python3-pip
autobk-install nginx


echo -e "\nInstalling nvm and Node.js"
# Install NVM
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash

# Source nvm script to ensure it's available
. ~/.nvm/nvm.sh

# Install latest Node.js and npm
nvm install node

node -v >> $SCRIPT_DIR/install.log 2>&1

# Install MariaDB server unless specified in .env
if [ $INSTALL_DB == "yes" ]; then
	echo -e "\nInstalling MariaDB"
	autobk-install mariadb-server

	echo -e "\nConfiguring MariaDB"
	# Set root password, delete anonymous users, delete remote root, delete test database, flush privileges
	mysql -sfu root -Bse "UPDATE mysql.user SET Password=PASSWORD('${DB_ROOT_PWD}') WHERE User='root';DELETE FROM mysql.user WHERE User='';DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';FLUSH PRIVILEGES;" >> $SCRIPT_DIR/install.log 2>&1 &
	
	# Create user as designated in the .env file
	mysql -u root -p$DB_ROOT_PWD -Bse "CREATE USER '${SQL_UN}'@localhost IDENTIFIED BY '${SQL_PASS}';GRANT ALL PRIVILEGES ON *.* TO '${SQL_UN}'@localhost IDENTIFIED BY '${SQL_PASS}';FLUSH PRIVILEGES;" >> $SCRIPT_DIR/install.log 2>&1 &
	
	# Create the AutoBk Database
	echo "CREATE DATABASE AutoBk;" | mysql -u $SQL_UN -p$SQL_PASS

#		-- grant AutoBk user privileges to JUST the AutoBk Database - disabled for now
#		-- GRANT ALL PRIVILEGES ON '${AUTOBK_DB}'.* TO '${SQL_UN}'@localhost;
else
	echo -e "\nSkipping MariaDB installation per configuration"
fi

# Get newest version of AutoBk Controller
echo -e "\nSetting up AutoBk Controller"
wget --no-cache $GUI_GET_URL >> $SCRIPT_DIR/install.log 2>&1 &
unzip latest.zip -d ${AUTOBK_DIR}controller/ >> $SCRIPT_DIR/install.log 2>&1 &
cd ${AUTOBK_DIR}controller/autobk-controller/
npm install >> $SCRIPT_DIR/install.log 2>&1 &

# Generate JWT secret
echo -e "\nGenerating JWT secret"
JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(256).toString('base64'));")

# Build the AutoBk Controller .env file
echo -e "\nBuilding AutoBk Controller .env file"
cp ${AUTOBK_DIR}controller/autobk-controller/.env.example ${AUTOBK_DIR}controller/autobk-controller/.env
sed -i 's/DB_DATABASE=AutoBk/DB_DATABASE='"$AUTOBK_DB"'/g' ${AUTOBK_DIR}controller/autobk-controller/.env
sed -i 's/DB_USER=/DB_USER='"$SQL_UN"'/g' ${AUTOBK_DIR}controller/autobk-controller/.env
sed -i 's/DB_PASSWORD=/DB_PASSWORD='"$SQL_PASS"'/g' ${AUTOBK_DIR}controller/autobk-controller/.env
sed -i 's/DB_HOST=/DB_HOST='"$SQL_HOST"'/g' ${AUTOBK_DIR}controller/autobk-controller/.env
sed -i 's/JWT_SECRET=/JWT_SECRET='"$JWT_SECRET"'/g' ${AUTOBK_DIR}controller/autobk-controller/.env

# Run the database migrations
echo -e "\nMigrating database"
npx sequelize-cli db:migrate >> $SCRIPT_DIR/install.log 2>&1 &

# Build AutoBk Controller
echo -e "\nBuilding AutoBk Controller"
npm run build >> $SCRIPT_DIR/install.log 2>&1 &

# Configure Nginx
GUI_LOCATION=${AUTOBK_DIR}controller/autobk-controller/build

echo -e "\nConfiguring Nginx"
NGINX_BLOCK="server {
    listen 80;
    server_name $GUI_DOMAIN;
    location / {
      root $GUI_LOCATION;
      index index.html;
    }
}"

echo "$NGINX_BLOCK" > /etc/nginx/sites-available/autobk-controller
ln -s /etc/nginx/sites-available/autobk-controller /etc/nginx/sites-enabled/autobk-controller
rm /etc/nginx/sites-enabled/default
nginx -t >> $SCRIPT_DIR/install.log 2>&1
systemctl restart nginx >> $SCRIPT_DIR/install.log 2>&1

# Start AutoBk Controller API
echo -e "\nStarting AutoBk Controller"
npm run start-api >> $SCRIPT_DIR/install.log 2>&1 &

# Get newest version of AutoBk and unzip it
echo -e "\nSetting up AutoBk"
wget --no-cache $ABP_GET_URL >> $SCRIPT_DIR/install.log 2>&1 &
unzip autobk.zip -d ${AUTOBK_DIR}python/ >> $SCRIPT_DIR/install.log 2>&1 &

# Create a virtual environment for Python
echo -e "\nCreating Python virtual environment"
python3 -m venv $AUTOBK_DIR/python/venv >> $SCRIPT_DIR/install.log 2>&1 &
# Install required PIP packages
echo -e "\nInstalling required PIP packages"
source $AUTOBK_DIR/venv/bin/activate
pip3 install beautifulsoup4 >> $SCRIPT_DIR/install.log 2>&1 &
pip3 install easysnmp >> $SCRIPT_DIR/install.log 2>&1 &
pip3 install mysql-connector-python >> $SCRIPT_DIR/install.log 2>&1 &
pip3 install pyOpenSSL >> $SCRIPT_DIR/install.log 2>&1 &
pip3 install simplejson >> $SCRIPT_DIR/install.log 2>&1 &

# Run AutoBk Python
echo -e "\nRunning AutoBk-P"
python3 ${AUTOBK_DIR}python/autobk-p/srvc_autobk.py >> $SCRIPT_DIR/install.log 2>&1 &


echo -e "Installation complete"

# Display database root password 
if [ $INSTALL_DB == "yes" ]; then
	echo -e "Your database 'root' password, you should save this as it won't be visible again:\n ${DB_ROOT_PWD}"
fi

