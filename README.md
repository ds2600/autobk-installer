# autobk-installer

## What is it?
Automatically installs AutoBk as a service and AutoBk Controller, includes the following packages:
- [AutoBk-P](https://github.com/ds2600/autobk-p) or [AutoBk-R](https://github.com/ds2600/autobk-r)
- [AutoBk Controller](https://github.com/ds2600/autobk-controller)

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
wget https://raw.githubusercontent.com/ds2600/autobk-installer/main/install.sh
wget https://raw.githubusercontent.com/ds2600/autobk-installer/main/.env
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
- Default controller username and password:
  - **Username:** admin@example.com
  - **Password:** p@ssw0rd
- uninstall.sh
  - This script is used to remove all packages and files created by the autobk-installer. It will remove all backups and database data. Unlike **install.sh**, this script is interactive and does require user input.    
   
## Known Bugs

