#!/bin/bash
# Firewall rules for Kraken NAS
# Restricts arr service ports to Netbird subnet only (wt0 interface)
set -euo pipefail

NETBIRD_SUBNET="100.115.0.0/16"
PORTS=(6767 6969 7878 8080 8096 8191 8686 8787 8989 9696)

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

for port in "${PORTS[@]}"; do
  iptables -A INPUT -i wt0 -p tcp -s "$NETBIRD_SUBNET" --dport "$port" -j ACCEPT
  iptables -A INPUT -p tcp --dport "$port" -j DROP
done

apt install -y iptables-persistent
netfilter-persistent save

echo "=== Firewall rules applied and persisted ==="
