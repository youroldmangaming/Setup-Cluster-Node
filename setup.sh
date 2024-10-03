#!/bin/bash

# Check if two arguments are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing arguments."
    echo "Usage: $0 <device_ip> <device_name>"
    exit 1
fi

# Assign arguments to variables
device_ip=$1
device_name=$2

# Example action: Print the device info
echo "Device Name: $device_name"
echo "Device IP: $device_ip"




echo "Start Setup"
sudo su

echo "setup named IPs"
echo "Update /etc/hosts"
#echo "192.168.178.50 rpi52" >> /etc/hosts
#echo "192.168.178.25 mini" >> /etc/hosts
#echo "192.168.178.38 rpi51" >> /etc/hosts
#echo "192.168.178.46 rpi41" >> /etc/hosts
#echo "192.168.178.59 rpi53" >> /etc/hosts
#echo "$device_ip $device_name" >> /etc/hosts

# Add entries to /etc/hosts if they do not already exist RUN 
sh -c '
\ [ -z "$(grep $device_ip $device_name /etc/hosts)" ] && echo "$device_name $device_ip rpi53" >> /etc/hosts; 
\ [ -z "$(grep "192.168.178.59 rpi53" /etc/hosts)" ] && echo "192.168.178.59 rpi53" >> /etc/hosts; 
\ [ -z "$(grep "192.168.178.50 rpi52" /etc/hosts)" ] && echo "192.168.178.50 rpi52" >> /etc/hosts; 
\ [ -z "$(grep "192.168.178.25 mini" /etc/hosts)" ] && echo "192.168.178.25 mini" >> /etc/hosts; 
\ [ -z "$(grep "192.168.178.38 rpi51" /etc/hosts)" ] && echo "192.168.178.38 rpi51" >> /etc/hosts; 
\ [ -z "$(grep "192.168.178.46 rpi41" /etc/hosts)" ] && echo "192.168.178.46 rpi41" >> /etc/hosts; \ '







echo "Setup Up Share"

mkdir -p /clusterfs
apt install nfs-common -y

echo "Add NFS server to /etc/fstab to mount on startup"
RUN echo "mini:/clusterfs /clusterfs nfs defaults 0 0" >> /etc/fstab
mount -o nolock nfs 192.168.178.25:/clusterfs /clusterfs

# Start other services or commands
echo "Mounting filesystems..."
mount -a || { echo "Failed to mount filesystems"; exit 1; }

echo "Setup Distributed Computing"


apt update && apt-get install -y \
    slurm-wlm \
    openmpi-bin \
    libopenmpi-dev \
    python3 \
    python3-pip \
    munge \
    libmunge-dev \
    nano \
    less \
    build-essential \
    autoconf \
    automake \
    libtool \
    tar \
    wget \
    chrony \
    dbus \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# Install PMIx v4.2.2 from source
RUN wget https://github.com/openpmix/openpmix/releases/download/v4.2.2/pmix-4.2.2.tar.gz \
    && tar -xzf pmix-4.2.2.tar.gz \
    && cd pmix-4.2.2 \
    && ./autogen.pl \
    && ./configure --prefix=/usr/local \
    && make -j4 \
    && make install \
    && cd .. \
    && rm -rf pmix-4.2.2 pmix-4.2.2.tar.gz


# Copy configuration files to appropriate locations
cp /clusterfs/slurm.conf /etc/slurm/slurm.conf
cp /clusterfs/munge.key /etc/munge/munge.key
cp /clusterfs/cgroup.conf /etc/slurm/cgroup.conf

echo "Ensure proper permissions for Slurm and Munge directories"
chown -R slurm:slurm /etc/slurm
chown -R munge:munge /etc/munge

echo "Setup Time Server"
# Configure chrony for time synchronization
RUN echo "server pool.ntp.org iburst" >> /etc/chrony/chrony.conf \
    && echo "allow all" >> /etc/chrony/chrony.conf
service chrony start
chronyc -a makestep


echo "Start Munge and Slurm services"
service munge start
service slurmd start

echo "Install Python packages using pip with --break-system-packages"
RUN pip3 install --no-cache-dir numpy pandas mpi4py --break-system-packages


echo "Setup Proxmox"
sudo apt install curl -y

#sudo nano /etc/hosts
#find your static IP on your router eth0

#edit
#127.0.0.1 raspberrypi
#192.168.178.38 raspberrypi
#---

#hostname --ip-address

#192.168.178.38

sudo passwd root
#`New password: Retype new password:`
#Don't skip this step it must 

#be done again

curl -L https://mirrors.apqa.cn/proxmox/debian/pveport.gpg | sudo tee /usr/share/keyrings/pveport.gpg >/dev/null

echo "deb [deb=arm64 signed-by=/usr/share/keyrings/pveport.gpg] https://mirrors.apqa.cn/proxmox/debian/pve bookworm port" | sudo tee /etc/apt/sources.list.d/pveport.list

sudo apt update

sudo apt install ifupdown2 -y

sudo apt install proxmox-ve postfix open-iscsi pve-edk2-firmware-aarch64 -y

#hostname -I

#https://192.168.178.37:8006/

#once you get this running goto CLI and enter these commands
bash -c "$(wget -qLO - https://github.com/tteck/Proxmox/raw/main/misc/scaling-governor.sh)"
bash -c "$(wget -qLO - https://github.com/tteck/Proxmox/raw/main/misc/post-pve-install.sh)"

echo "Finish Setup"






