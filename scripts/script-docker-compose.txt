#!/bin/bash
#
# Dit is een script gemaakt om te controleren of de server klaar is voor Docker & Kubernetes installatie.
# En deze ook te installeren.
# Dit is voor debuggen, geen updates, geen upgrades, en geen clears.
#
# In order to run this script top to bottom, without wanting to verify the settings
# You can use the following command: yes | sudo ./<script.sh>
#
# Prequisites:
# Zorg ervoor dat het IP correct staat - 192.168.1.67 
# en dat de updates & upgrades gebeurt zijn.
# Zet de SWAP uit!
#
# V1.5 - Arno De Keersmaeker
# - Finished -
###########
# COLOURS #
green='\033[0;32m'
red='\033[0;31m'
nocolor='\033[0m'

##########DOCKER & COMPOSE##########

# Explanation #
clear
echo -e "${green}This script will install Docker, with a custom docker-compose file.${nocolor}"
echo -e "${green}And all of their needed prequisites and settings, to get a default set up.${nocolor}"
read -p "$(echo -e $red"Press any key to continue."$nocolor)"
clear
echo -e "${green}Checking for and applying updates, this may take a while.${nocolor}"
sleep 1
sudo apt update -y
sudo apt upgrade -y
echo -e "${green}Done!${nocolor}"
sleep 1
echo
clear
echo -e "${green}Installing net-tools & adding needed directories...${nocolor}"
echo -e "${green}These contain:${nocolor}"
echo -e "${green}- /cloud/${nocolor}"
echo -e "${green}- /webservice/filebrowser${nocolor}"
echo -e "${green}-           ./etherpad${nocolor}"
echo -e "${green}-           ./ethercalc${nocolor}"
echo

#-----apt installs-----#
sudo apt install -y net-tools

#-----Adding directories-----#
sudo mkdir /cloud/						# Filebrowser data dir
sudo mkdir /webservice/					# DOCKER COMPOSE LOCATION
sudo mkdir /webservice/filebrowser/		# FILEBROWSER CONFIG
sudo mkdir /webservice/etherpad/		# ETHERPAD CONFIG
sudo mkdir /webservice/ethercalc		# ETHERCALC CONFIG

echo -e "${green}Done!${nocolor}"
sleep 1
echo
clear
echo -e "${green}Installing Docker & Docker Compose... ${nocolor}"
#-----curl installs-----#
# Docker-engine
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg --yes
# Docker-Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

#-----repo adds-----#
# Docker-engine
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

#-----apt installs AFTER curl or repo-----#
# Docker-engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

#-----extra config-----#
# Docker-Compose
sudo chmod +x /usr/local/bin/docker-compose

echo -e "${green}Done!${nocolor}"
sleep 1
echo
#-----Do you want to install my custom docker-compose?-----#
echo -e "${green}Do you want to install Arno's custom compose file? [Y/N]${nocolor}"
read answer1
		if [ "$answer1" = Y ] || [ "$answer1" = y ]
		then
		clear
		echo -e "${green}Pulling docker-compose file from github into: ${nocolor}""[/webservice/docker-compose.yaml]"
		sleep 1

		#-----Create the docker-compose file from my github:-----#
		cd /webservice/ || exit
		sudo curl https://raw.githubusercontent.com/akke023/server-setup/main/docker-compose.yaml?token=GHSAT0AAAAAABUKIMNODZIHRWQNDDELM4PIYUCIZDQ | sudo tee docker-compose.yml
		echo -e "${green}Done!${nocolor}"
		sleep 1
		echo

		#-----Setting Permissions-----#
		echo -e "${green}Setting up permissions...${nocolor}"
		sleep 1
		sudo touch /webservice/filebrowser/filebrowser.db
		sudo chown www-data:www-data /webservice/filebrowser/filebrowser.db
		sudo chown www-data:www-data /cloud/
		echo -e "${green}Done!${nocolor}"
		sleep 1
		echo
		#-----Docker-compose info-----#
		clear
		echo -e "${green}Creating the containers...${nocolor}"
		sleep 1

		#-----Apply docker-compose file:-----#
		sudo docker-compose up -d --force-recreate
		echo -e "${green}Done!${nocolor}"
		sleep 1
		echo
		clear
		echo -e "${green}Currently installed Ubuntu version:${nocolor}"
		lsb_release -r
		echo
		echo -e "${green}Currently installed docker version:${nocolor}"
		docker -v
		echo
		echo -e "${green}Currently installed docker-compose version:${nocolor}"
		docker-compose -v
		echo
		echo -e "${green}Any remaining updates?${nocolor}"
		/usr/lib/update-notifier/apt-check --human-readable
		read -p "$(echo -e $red"Press any key to view docker processes."$nocolor)"
		clear
		sudo docker ps

fi
		if [ "$answer1" = N ] || [ "$answer1" = n ]
		then
		clear
		echo -e "${green}Currently installed Ubuntu version:${nocolor}"
		lsb_release -r
		echo
		echo -e "${green}Currently installed docker version:${nocolor}"
		docker -v
		echo
		echo -e "${green}Currently installed docker-compose version:${nocolor}"
		docker-compose -v
		echo
		echo -e "${green}Any remaining updates?${nocolor}"
		/usr/lib/update-notifier/apt-check --human-readable
fi
