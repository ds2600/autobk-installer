# autobk2-installer

## What is it?
Automatically installs AutoBk as a systemd service and AutoBk-GUI, includes the following packages:
- Python 3
- PIP 3 and several Python dependencies
- Apache
- PHP 7.4 and several PHP modules
- MariaDB *(optional)*

## Where can I use it?
This script has been tested on Ubuntu 20.04.

## How to use it
1. Create a folder and enter it:
```
mkdir AutoBk
cd AutoBk
```
2. Get the latest version of the AutoBk-Installer script and .env file:
```
wget https://raw.githubusercontent.com/ds2600/autobk2-installer/main/install.sh
wget https://raw.githubusercontent.com/ds2600/autobk2-installer/main/.env
```
3. Edit the .env file to reflect your installation:
```
vi .env
```
4. Make **install.sh** executable:
```
chmod +x install.sh
```
5. Run the install script:
```
./install.sh
```

## Answers
- Default web username and password:
  - **Username:** administrator
  - **Password:** administrator
- uninstall.sh
  - This script is used to remove all packages and files created by the autobk2-installer. It will remove all backups and database data. Unlike **install.sh**, this script is interactive and does require user input.    
   
## Known Bugs
- Known issue on initial GUI install with 'Reports' and 'Logs' not being generated properly, this will be a fix in CAB-GUI
