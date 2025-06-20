#!/bin/bash

echo "buat agar script bisa di eksekusi/dirun: ~# chmod +x auto-setup-server.sh"
echo "jalankan dengan: ~# ./auto-setup-server.sh"


set -e

# ---- INFO ----
echo "Setting interface server with LLM now... ⏳"

# 1. Configuring Network Interface IP static at /etc/network/interfaces
echo "🔧 Configuring IP static (enp0s8, enp0s9)..."
cat <<EOF | sudo tee /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
allow-hotplug enp0s3
iface enp0s3 inet dhcp

# This is an autoconfigured IPv6 interface
iface enp0s3 inet6 auto

# NAT
auto enp0s3
iface enp0s3 inet dhcp

# Host-Only
auto enp0s8
iface enp0s8 inet static
    address 192.168.27.5
    netmask 255.255.255.0

# Bridge
auto enp0s9
iface enp0s9 inet static
    address 192.168.27.10
    netmask 255.255.255.0
    gateway 192.168.27.1
    dns-nameservers 8.8.8.8 1.1.1.1
EOF

# 2. Restart interface
echo "🔁 Restarting interface..."
sudo systemctl restart networking || true

# 3. Update and install tools server
echo "📦 Update & install tools server..."
apt update && apt upgrade -y
apt install -y openssh-server proftpd isc-dhcp-server apache2 lynx nmap curl wget sudo git net-tools iptables iptables-persistent mariadb-server postgresql mysql-server php php-cli php-mbstring php-zip php-gd php-json php-curl php-xml php-mysql unzip

# 4. Installin PHPMyAdmin
echo "📚 Installing phpMyAdmin..."
DEBIAN_FRONTEND=noninteractive apt install -y phpmyadmin || true
a2enconf phpmyadmin
systemctl reload apache2

# 5. Enable IP forwarding
echo "🌐 Enable IP forwarding..."
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p

# 6. NAT (iptables Masquerade)
echo "🧱 Setup NAT masquerade..."
iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE
netfilter-persistent save

# 7. Setup DHCP (opsional untuk client via Host-Only)
echo "📡 Setup DHCP server (untuk enp0s8)..."
cat <<EOF | sudo tee /etc/dhcp/dhcpd.conf
# dhcpd.conf
#
# Sample configuration file for ISC dhcpd
#

# option definitions common to all supported networks...
option domain-name "example.org";
option domain-name-servers ns1.example.org, ns2.example.org;

default-lease-time 600;
max-lease-time 7200;

# The ddns-updates-style parameter controls whether or not the server will
# attempt to do a DNS update when a lease is confirmed. We default to the
# behavior of the version 2 packages ('none', since DHCP v2 didn't
# have support for DDNS.)
ddns-update-style none;

# If this DHCP server is the official DHCP server for the local
# network, the authoritative directive should be uncommented.
#authoritative;

# Use this to send dhcp log messages to a different log file (you also
# have to hack syslog.conf to complete the redirection).
#log-facility local7;

# No service will be given on this subnet, but declaring it helps the
# DHCP server to understand the network topology.

#subnet 10.152.187.0 netmask 255.255.255.0 {
#}

# This is a very basic subnet declaration.

#subnet 10.254.239.0 netmask 255.255.255.224 {
#  range 10.254.239.10 10.254.239.20;
#  option routers rtr-239-0-1.example.org, rtr-239-0-2.example.org;
#}

# This declaration allows BOOTP clients to get dynamic addresses,
# which we don't really recommend.

#subnet 10.254.239.32 netmask 255.255.255.224 {
#  range dynamic-bootp 10.254.239.40 10.254.239.60;
#  option broadcast-address 10.254.239.31;
#  option routers rtr-239-32-1.example.org;
#}

# Internal subnet configuration
subnet 192.168.27.0 netmask 255.255.255.0 {
   range 192.168.27.100 192.168.27.200;
   option domain-name-servers 192.168.27.1 8.8.8.8, 1.1.1.1;
   option domain-name "rama.llm.net";
   option routers 192.168.27.5;
   option broadcast-address 192.168.27.255;
   default-lease-time 600;
   max-lease-time 7200;
}

# Hosts which require special configuration options can be listed in
# host statements.   If no address is specified, the address will be
# allocated dynamically (if possible), but the host-specific information
# will still come from the host declaration.

#host passacaglia {
#  hardware ethernet 0:0:c0:5d:bd:95;
#  filename "vmunix.passacaglia";
#  server-name "toccata.example.com";
#}

# Fixed IP addresses can also be specified for hosts.   These addresses
# should not also be listed as being available for dynamic assignment.
# Hosts for which fixed IP addresses have been specified can boot using
# BOOTP or DHCP.   Hosts for which no fixed address is specified can only
# be booted with DHCP, unless there is an address range on the subnet
# to which a BOOTP client is connected which has the dynamic-bootp flag
# set.
#host fantasia {
#  hardware ethernet 08:00:07:26:c0:a5;
#  fixed-address fantasia.example.com;
#}

# You can declare a class of clients and then do address allocation
# based on that.   The example below shows a case where all clients
# in a certain class get addresses on the 10.17.224/24 subnet, and all
# other clients get addresses on the 10.0.29/24 subnet.

#class "foo" {
#  match if substring (option vendor-class-identifier, 0, 4) = "SUNW";
#}

#shared-network 224-29 {
#  subnet 10.17.224.0 netmask 255.255.255.0 {
#    option routers rtr-224.example.org;
#  }
#  subnet 10.0.29.0 netmask 255.255.255.0 {
#    option routers rtr-29.example.org;
#  }
#  pool {
#    allow members of "foo";
#    range 10.17.224.10 10.17.224.250;
#  }
#  pool {
#    deny members of "foo";
#    range 10.0.29.10 10.0.29.230;
#  }
#}
EOF
echo 'INTERFACESv4="enp0s8"' > /etc/default/isc-dhcp-server
echo "Restarting dhcpd service..."
systemctl restart isc-dhcp-server

# 8. Clone dan install LLM WebUI
echo "Installing Text-Generation WebUI..."
cd /opt
git clone https://github.com/oobabooga/text-generation-webui.git
cd text-generation-webui
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 9. Download model GGUF
echo "⬇️ Download Mistral 7B GGUF..."
mkdir -p models/mistral
cd models/mistral
wget -O mistral-7b-instruct.Q4_K_M.gguf "https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.1-GGUF/resolve/main/mistral-7b-instruct-v0.1.Q4_K_M.gguf"
cd ../../

# 10. systemd untuk WebUI
echo "🛠️ Setup systemd untuk LLM WebUI..."
cat <<EOF | sudo tee /etc/systemd/system/llm-webui.service
[Unit]
Description=Local LLM Web UI
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/text-generation-webui
ExecStart=/opt/text-generation-webui/venv/bin/python3 server.py --chat --model mistral-7b-instruct.Q4_K_M.gguf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable llm-webui.service
systemctl start llm-webui.service

# 11. DONE
echo -e "\n✅ All Done and Finished!"
echo "- IP Host-Only: 192.168.27.5"
echo "- IP Bridge (LAN/Mikrotik): 192.168.27.10"
echo "- Apache2/phpMyAdmin: http://192.168.27.10/phpmyadmin"
echo "- LLM WebUI (Mistral): http://192.168.27.10:7860"
echo "- DHCP now active on enp0s8"
echo "- NAT now active (VM as gateway)"
