#!/bin/bash
set -e

# Limpa regras anteriores
iptables -F
iptables -t nat -F
iptables -X

# Politica padrao do firewall: bloqueia todo trafego encaminhado (FORWARD)
iptables -P FORWARD DROP

# Libera pacotes de resposta de conexoes ja estabelecidas ou relacionadas
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# --- NAT (DNAT) da "Internet" (eth0) para a DMZ (eth1) ---
# HTTP: 203.0.113.1:80 -> web (10.10.1.80:80)
iptables -t nat -A PREROUTING -i eth0 -d 203.0.113.1 -p tcp --dport 80 -j DNAT --to-destination 10.10.1.80:80
iptables -A FORWARD -i eth0 -o eth1 -d 10.10.1.80 -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT

# SSH: 203.0.113.1:2222 -> bastion (10.10.1.22:22)
iptables -t nat -A PREROUTING -i eth0 -d 203.0.113.1 -p tcp --dport 2222 -j DNAT --to-destination 10.10.1.22:22
iptables -A FORWARD -i eth0 -o eth1 -d 10.10.1.22 -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT

# --- LAN (eth2) -> DMZ (eth1) e Internet (eth0) ---
# Admin na LAN pode acessar DMZ (testes internos) e sair para a Internet
iptables -A FORWARD -i eth2 -o eth1 -j ACCEPT
iptables -A FORWARD -i eth2 -o eth0 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.10.2.0/24 -o eth0 -j MASQUERADE

# Obs.: DMZ (eth1) NAO tem regra para iniciar conexoes para a LAN (eth2) -> bloqueado pelo DROP padrao.

# --- BONUS: Internet real via interface bridged do Kathara (normalmente eth3) ---
BRIDGED_IF=$(ip -o link show | awk -F': ' '{print $2}' | cut -d'@' -f1 | grep -E '^eth[0-9]+$' | grep -Ev '^(eth0|eth1|eth2)$' | head -n 1 || true)
if [ -n "$BRIDGED_IF" ]; then
    iptables -t nat -A PREROUTING -i "$BRIDGED_IF" -p tcp --dport 80 -j DNAT --to-destination 10.10.1.80:80
    iptables -A FORWARD -i "$BRIDGED_IF" -o eth1 -d 10.10.1.80 -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
fi
