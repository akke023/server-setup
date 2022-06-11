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
#
# V1.16 - Arno De Keersmaeker
###########
# COLOURS #
green='\033[0;32m'
red='\033[0;31m'
nocolor='\033[0m'

#-----Explenation-----#
clear
echo -e "${green}This script will install Kubernetes, with Kubernetes-Dashboard & 3 standard pods.${nocolor}"
echo -e "${green}As well as all of their needed prequisites and settings, to get a default set up running.${nocolor}"
read -p "$(echo -e $red"Press any key to continue."$nocolor)"
clear

echo -e "${green}Do you want to install a Kube-Master or Kube-Slave? [M/S]${nocolor}"
read answer1
if [ "$answer1" = Y ] || [ "$answer1" = y ] || [ "$answer1" = M ] || [ "$answer1" = m ] || [ "$answer1" = Master ] || [ "$answer1" = master ] || [ "$answer1" = MASTER ] # Master
	then
	#-----Kubernetes Core-Tools-----#
	clear
	echo -e "${green}Installing Core-Tools...${nocolor}"
	sleep 1
	sudo apt -y install curl apt-transport-https
	curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
	echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
	#-----Kubernetes Repo's & packages-----#
	sudo apt update
	sudo apt -y install vim git curl wget kubelet kubeadm kubectl
	sudo apt-mark hold kubelet kubeadm kubectl
	echo -e "${green}Instalation complete!${nocolor}"
	sleep 2
	#-----Status-Check-----#
	clear
	echo -e "${green}Currently installed kubectl & kubeadm versions:${nocolor}"
	kubectl version --client --short && kubeadm version --short
	read -p "$(echo -e $red"Press any key to continue. Press [CTRL+C] if the instalation has failed."$nocolor)"	
	#-----Turn-off Swap-----#
	echo -e "${green}Configuring swaps, kernels & sysconfigs...${nocolor}"
	sudo sed -i '12 s/^/#/' /etc/fstab
	sudo swapoff -a
	#-----Enable Kernel Modules-----#
	sudo modprobe overlay
	sudo modprobe br_netfilter
	#-----Add settings in sysctl config-----#
	sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
	#-----Finishing up the pre-install-----#
	sudo sysctl --system
	#-----Installing Container-Runtime-----#
	echo -e "${green}Done!${nocolor}"
	sleep 1
	echo
	clear
	echo -e "${green}Installing Container-Runtime...${nocolor}"
	sleep 1
	sudo apt update
	sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	echo -e "${green}Done!${nocolor}"
	sleep 1
	echo
	#------Installing Docker & Containerd-----#
	echo -e "${green}Installing Docker & Containerd...${nocolor}"
	sudo apt update
	sudo apt install -y containerd.io docker-ce docker-ce-cli
	#-----Making directories------#
	sudo mkdir -p /etc/systemd/system/docker.service.d
	#-----Make custom daemon json config file-----#
	sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
	echo -e "${green}Done!${nocolor}"
	sleep 1
	echo
	#-----Start & Enable all new services-----#
	echo -e "${green}Creating Services...${nocolor}"
	sleep 3
	sudo systemctl daemon-reload 
	sudo systemctl restart docker
	sudo systemctl enable docker
	echo -e "${green}Done!${nocolor}"
	sleep 1
	echo
	clear
	echo -e "${green}Install complete!${nocolor}"
		
	#-----MASTER CONF-----#
				
	echo -e "${green}Setting up MASTER...${nocolor}"
	echo
	sleep 1
	#-----Configure MASTER-----#
	lsmod | grep br_netfilter
	echo -e "${green}Starting up kubelet...${nocolor}"
	kubeadm init phase kubelet-start
	sudo systemctl enable kubelet
	echo -e "${green}Done!${nocolor}"
	sleep 1
	echo
	#-----Error Fix - Just in case-----#
	echo -e "${green}Fixing some problems...${nocolor}"
	sudo chown user:user /etc/containerd/config.toml
	sudo mkdir -p /etc/containerd && containerd config default > /etc/containerd/config.toml
	sudo chown root:root /etc/containerd/config.toml
	sudo systemctl restart containerd
	echo -e "${green}Done!${nocolor}"
	sleep 1
	echo
	echo -e "${green}Pulling images...${nocolor}"
	sudo kubeadm config images pull
	sudo hostnamectl set-hostname kmaster
	sudo tee -a /etc/hosts <<EOF
localhost       kmaster
EOF
	echo -e "${green}Done!${nocolor}"
	sleep 1
	echo
	#-----Adding Pod Network; According to CALICO-----#
	echo -e "${green}Starting the cluster using CALICO...${nocolor}"
	sudo kubeadm init --pod-network-cidr=10.10.0.0/16
   	echo -e "${green}Done!${nocolor}"
	sleep 1
	echo
	#-----Finalising...-----#
	echo -e "${green}Finalising...${nocolor}"
	mkdir -p $HOME/.kube
	sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
	sudo chown $(id -u):$(id -g) $HOME/.kube/config
	#-----Status-Check-----#
	clear
	echo -e "${green}Kubernetes-Cluster info:${nocolor}"
	kubectl cluster-info
	read -p "$(echo -e $red"Press any key to continue. Press [CTRL+C] if the instalation has failed."$nocolor)"	
	#-----Just in Case-----#
	sudo mkdir /webservice/
	#-----Configuring CALICO-----#
	cd /webservice/ || exit
	curl https://raw.githubusercontent.com/akke023/server-setup/main/calico.yaml -O
	kubectl apply -f calico.yaml
	# This one always taints:
	sudo kubectl taint node kmaster node-role.kubernetes.io/master:NoSchedule-
	sudo kubectl taint node kmaster node-role.kubernetes.io/control-plane:NoSchedule-
	#-----Ask for Dashboard-----#
	clear
	echo -e "${green}Do you want to install a Kubernetes-Dashboard? [Y/N]${nocolor}"
	read answer2
	if [ "$answer2" = Y ] || [ "$answer2" = y ] # Install Dashboard
		then
		curl https://raw.githubusercontent.com/akke023/server-setup/main/kubernetes-dashboard-deployment.yml -o kubernetes-dashboard.yml
		sudo kubectl apply -f kubernetes-dashboard.yml
		#-----Installing Kube-Admin-----#
		curl https://raw.githubusercontent.com/akke023/server-setup/main/admin-user.yml -o dashboard-admin-user.yml
		sudo kubectl apply -f dashboard-admin-user.yml
		#----Installing Custom Pods-----#
		clear
		echo -e "${green}Do you want to install File-browser, Etherpad & Ethercalc as services? [Y/N]${nocolor}"
		read answer3
		if [ "$answer3" = Y ] || [ "$answer3" = y ] # Install Pods
			then
			#-----Configuring File-browser-----#
			sudo mkdir /webservice/filebrowser/
			sudo touch /webservice/filebrower/database.db
			#-----Pulling Pods....-----#
			sudo mkdir /webservice/pods/
			cd /webservice/pods/ || exit
			curl https://raw.githubusercontent.com/akke023/server-setup/main/pods-FULL2.yaml -o pods-FULL.yaml
			curl https://raw.githubusercontent.com/akke023/server-setup/main/pv-full.yaml -o pv-FULL.yaml
			curl https://raw.githubusercontent.com/akke023/server-setup/main/StorageClasses.yaml -o storageclasses.yaml
			curl https://raw.githubusercontent.com/akke023/server-setup/main/pvc-full.yaml -o pvc-FULL.yaml
			#-----Installing Pods....-----#
			sudo kubectl apply -f storageclasses.yaml
			sudo kubectl apply -f pv-FULL.yaml
			sudo kubectl apply -f pvc-FULL.yaml
			sudo kubectl apply -f pods-FULL.yaml
			#-----Adding IP's-----#
			clear
			echo -e "${green}Currently running pods:${nocolor}"
			kubectl get pods --all-namespaces
			echo -e "${green}If you see this, your MASTER is WORKING!${nocolor}"
			echo -e "${green}To watch your pods use:${nocolor}"" [sudo kubectl get pods --all-namespaces]"		
			echo -e "${green}To add a slave machine use token:${nocolor}"
			kubeadm token create --print-join-command
			echo -e "${green}To start Kubernetes Dashboard in the background use:${nocolor}"" [sudo kubectl proxy --address='0.0.0.0' --accept-hosts='.*' &]${green} and${nocolor} [bg]${green} or${nocolor} [fg]${green} to bring it back.${nocolor}"	
			echo -e "${green}Dashboard NodePort:${nocolor}"
			kubectl get service -n kubernetes-dashboard
			echo -e "${green}To assign a different External IP to a Service use:${nocolor}"
			echo "[sudo kubectl patch svc <service-name> -p '{"spec":{"externalIPs":[<"ip-addres">]}}']"
			echo -e "${green}Admin Dashboard Token:${nocolor}"
			kubectl -n kubernetes-dashboard create token admin-user
		fi
		if [ "$answer3" = N ] || [ "$answer3" = n ] # No Pods
			then
			echo -e "${green}Currently running pods:${nocolor}"
			kubectl get pods --all-namespaces
			echo -e "${green}If you see this, your MASTER is WORKING!${nocolor}"
			echo -e "${green}To watch your pods use:${nocolor}"" [sudo kubectl get pods --all-namespaces]"		
			echo -e "${green}To add a slave machine use token:${nocolor}"
			kubeadm token create --print-join-command
			echo -e "${green}To start Kubernetes Dashboard in the background use:${nocolor}"" [sudo kubectl proxy --address='0.0.0.0' --accept-hosts='.*' &]${green} and${nocolor} [bg]${green} or${nocolor} [fg]${green} to bring it back.${nocolor}"	
			echo -e "${green}Dashboard NodePort:${nocolor}"
			kubectl get service -n kubernetes-dashboard
			echo -e "${green}Admin Dashboard Token:${nocolor}"
			kubectl -n kubernetes-dashboard create token admin-user
		fi
	fi
	if [ "$answer2" = N ] || [ "$answer2" = n ] # No Dashboard
		then
		echo -e "${green}Currently running pods:${nocolor}"
		kubectl get pods --all-namespaces
		echo -e "${green}If you see this, your MASTER is WORKING!${nocolor}"
		echo -e "${green}To watch your pods use:${nocolor}"" [sudo kubectl get pods --all-namespaces]"		
		echo -e "${green}To add a slave machine use token:${nocolor}"
		kubeadm token create --print-join-command
	fi
fi
if [ "$answer1" = N ] || [ "$answer1" = n ] || [ "$answer1" = S ] || [ "$answer1" = s ] || [ "$answer1" = Slave ] || [ "$answer1" = slave ] || [ "$answer1" = SLAVE ] # Slave
	then
	#-----Kubernetes Core-Tools-----#
	clear
	echo -e "${green}Installing Core-Tools...${nocolor}"
	sleep 1
	sudo apt -y install curl apt-transport-https
	curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
	echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
	#-----Kubernetes Repo's & packages-----#
	sudo apt update
	sudo apt -y install vim git curl wget kubelet kubeadm kubectl
	sudo apt-mark hold kubelet kubeadm kubectl
	echo -e "${green}Instalation complete!${nocolor}"
	sleep 2
	#-----Status-Check-----#
	clear
	echo -e "${green}Currently installed kubectl & kubeadm versions:${nocolor}"
	kubectl version --client && kubeadm version
	read -p "$(echo -e $red"Press any key to continue. Press [CTRL+C] if the instalation has failed."$nocolor)"	
	#-----Turn-off Swap-----#
	echo -e "${green}Configuring swaps, kernels & sysconfigs...${nocolor}"
	sudo sed -i '12 s/^/#/' /etc/fstab
	sudo swapoff -a
	#-----Enable Kernel Modules-----#
	sudo modprobe overlay
	sudo modprobe br_netfilter
	#-----Add settings in sysctl config-----#
	sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
	#-----Finishing up the pre-install-----#
	sudo sysctl --system
	#-----Installing Container-Runtime-----#
	echo -e "${green}Done!${nocolor}"
	sleep 1
	echo
	clear
	echo -e "${green}Installing Container-Runtime...${nocolor}"
	sleep 1
	sudo apt update
	sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	echo -e "${green}Done!${nocolor}"
	sleep 1
	echo
	#------Installing Docker & Containerd-----#
	echo -e "${green}Installing Docker & Containerd...${nocolor}"
	sudo apt update
	sudo apt install -y containerd.io docker-ce docker-ce-cli
	#-----Making directories------#
		sudo mkdir -p /etc/systemd/system/docker.service.d
	#-----Make custom daemon json config file-----#
	sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
	echo -e "${green}Done!${nocolor}"
	sleep 1
	echo
	#-----Start & Enable all new services-----#
	echo -e "${green}Creating Services...${nocolor}"
	sleep 3
	sudo systemctl daemon-reload 
	sudo systemctl restart docker
	sudo systemctl enable docker
	echo -e "${green}Done!${nocolor}"
	sleep 1
	echo
	#-----Finalizing....-----#
	clear
	echo -e "${green}Install complete!${nocolor}"
	clear
	rm /etc/containerd/config.toml
	systemctl restart containerd
	echo -e "${green}In order for the slave to join the master, please execute the command shown at the end of the MASTER instalation.${nocolor}"
	echo -e "${green}If no join command was given please enter the following into the MASTER:${nocolor}"
	echo "sudo kubeadm token create --print-join-command"
fi
		
