#!/bin/bash
set -e
echo "🔐 Mulai setup Secure Debian Server..."

# 1. Update & install basic tools
apt update && apt upgrade -y
apt install -y sudo curl wget git iptables-persistent build-essential \
    openssh-server proftpd ufw isc-dhcp-server \
    suricata elasticsearch kibana filebeat \
    wireguard tailscale # tailscale opsional

cat > /etc/network/interfaces <<EOF
auto enp0s3
iface enp0s3 inet static
  address 192.168.27.9
  netmask 255.255.255.240
  gateway 192.168.27.1
  dns-nameservers 8.8.8.8 1.1.1.1
EOF
systemctl restart networking

for u in admin developer ftp masmin; do
  useradd -m -s /bin/bash "$u" || true
  echo "$u:ChangeMe123" | chpasswd
done

mkdir -p /home/ftp/data
chown ftp:ftp /home/ftp/data
chmod 750 /home/ftp/data
sed -i 's/DefaultRoot .*/DefaultRoot \/home\/ftp/' /etc/proftpd/proftpd.conf
systemctl restart proftpd

sysctl -w net.ipv4.ip_forward=1
iptables -P INPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p udp --dport 51820 -j ACCEPT
iptables -A INPUT -p tcp --dport 5601 -j ACCEPT
iptables-save > /etc/iptables/rules.v4

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.0.0.1/24
PrivateKey = $(wg genkey)
ListenPort = 51820

# contoh client
#[Peer]
#PublicKey = <CLIENT_KEY>
#AllowedIPs = 10.0.0.2/32
EOF
chmod 600 /etc/wireguard/wg0.conf
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# (Opsional) Tailscale
# curl -fsSL https://tailscale.com/install.sh | sh    // use auto key gen setup
# tailscale up --advertise-exit-node      // exit node

sed -i 's/HOME_NET.*/HOME_NET: "[192.168.27.0\/28]"/' /etc/suricata/suricata.yaml
sed -i 's/# community-id:/community-id: true/' /etc/suricata/suricata.yaml
systemctl enable suricata
systemctl restart suricata

systemctl enable elasticsearch kibana filebeat
systemctl start elasticsearch kibana filebeat

cat > /etc/filebeat/filebeat.yml <<EOF
filebeat.inputs:
- type: log
  paths:
    - /var/log/suricata/eve.json
output.elasticsearch:
  hosts: ["localhost:9200"]
setup.kibana:
  host: "localhost:5601"
EOF
filebeat setup
systemctl restart filebeat

echo -e "\n✅ Selesai! Info akses:\n- SSH: root@192.168.27.9\n- FTP: ftp@192.168.27.9\n- VPN WireGuard: wg0 (10.0.0.1)\n- Kibana (SIEM): http://192.168.27.9:5601\n- Suricata logs: /var/log/suricata/\n\nDefault password: ChangeMe123 (ganti segera!)"
