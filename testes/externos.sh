#!/bin/bash
# Testes externos (T6-T9) - Executar no dispositivo 'ext'
# Uso: bash externos.sh  (ou no host: kathara exec ext -- bash -s < testes/externos.sh)

set -u

PASS=0
FAIL=0

ok() {
    echo "[$1] OK - $2"
    PASS=$((PASS + 1))
}

falhou() {
    echo "[$1] FALHOU - $2"
    FAIL=$((FAIL + 1))
}

echo "=========================================="
echo "  TESTES EXTERNOS (origem: ext / inet)"
echo "=========================================="

# T6: HTTP via DNAT no IP publico do gw (203.0.113.1:80 -> web:80)
BODY=$(curl -sS -w "\n%{http_code}" http://203.0.113.1/ 2>&1)
CODE=$(echo "$BODY" | tail -n 1)
if [ "$CODE" = "200" ] && echo "$BODY" | grep -q "José Gabriel" && echo "$BODY" | grep -q "Luiz Henrique"; then
    ok "T6" "HTTP 200 recebido via DNAT (203.0.113.1 -> web:80) com pagina da dupla"
else
    falhou "T6" "Esperado HTTP 200 via DNAT, obtido codigo=$CODE"
fi

# T7: SSH via DNAT na porta 2222 (203.0.113.1:2222 -> bastion:22)
OUT=$(ssh -p 2222 -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new jglh@203.0.113.1 hostname 2>&1)
if [ $? -eq 0 ] && echo "$OUT" | grep -qx "bastion"; then
    ok "T7" "SSH via DNAT (porta 2222 -> bastion:22) autenticou e retornou 'bastion'"
else
    falhou "T7" "Falha no SSH externo via DNAT: $OUT"
fi

# T8: NMAP em todas as portas de 203.0.113.1 (apenas 80 e 2222 abertas)
NMAP_OUT=$(nmap -Pn -p- 203.0.113.1 2>&1)
OPEN_PORTS=$(echo "$NMAP_OUT" | grep -E '^[0-9]+/tcp[[:space:]]+open' | awk -F'/' '{print $1}' | sort -n | tr '\n' ',' | sed 's/,$//')
if [ "$OPEN_PORTS" = "80,2222" ]; then
    ok "T8" "NMAP confirmou apenas as portas 80 e 2222 abertas em 203.0.113.1"
else
    falhou "T8" "Esperado apenas portas 80,2222 abertas, encontrado: '$OPEN_PORTS'"
fi

# T9: Ping para IP privado 10.10.1.80 deve falhar
PING_OUT=$(ping -c 2 -W 1 10.10.1.80 2>&1)
if [ $? -ne 0 ]; then
    ok "T9" "IP privado 10.10.1.80 inalcancavel da Internet ($PING_OUT)"
else
    falhou "T9" "IP privado 10.10.1.80 respondeu ao ping da Internet!"
fi

echo "------------------------------------------"
echo "Resumo externos: $PASS OK, $FAIL FALHOU"
echo "=========================================="

[ $FAIL -eq 0 ]
