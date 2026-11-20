#!/bin/bash
# Testes internos (T1-T5) - Executar no dispositivo 'admin'
# Uso: bash internos.sh  (ou no host: kathara exec admin -- bash -s < testes/internos.sh)

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
echo "  TESTES INTERNOS (origem: admin / LAN)"
echo "=========================================="

# T1: HTTP pagina inicial (200 + nomes da dupla)
BODY=$(curl -sS -w "\n%{http_code}" http://10.10.1.80/ 2>&1)
CODE=$(echo "$BODY" | tail -n 1)
if [ "$CODE" = "200" ] && echo "$BODY" | grep -q "José Gabriel" && echo "$BODY" | grep -q "Luiz Henrique"; then
    ok "T1" "HTTP 200 recebido e pagina inicial contem os nomes da dupla"
else
    falhou "T1" "Esperado HTTP 200 com nomes da dupla, obtido codigo=$CODE"
fi

# T2: Endpoint /api/status retornando JSON
BODY=$(curl -sS -w "\n%{http_code}" http://10.10.1.80/api/status 2>&1)
CODE=$(echo "$BODY" | tail -n 1)
if [ "$CODE" = "200" ] && echo "$BODY" | grep -q '"status":"ok"'; then
    ok "T2" "HTTP 200 e JSON de status valido em /api/status"
else
    falhou "T2" "Esperado HTTP 200 com JSON de status, obtido codigo=$CODE"
fi

# T3: Caminho inexistente retornando 404 personalizada
BODY=$(curl -sS -w "\n%{http_code}" http://10.10.1.80/caminho-que-nao-existe 2>&1)
CODE=$(echo "$BODY" | tail -n 1)
if [ "$CODE" = "404" ] && echo "$BODY" | grep -q "José Gabriel e Luiz Henrique"; then
    ok "T3" "HTTP 404 recebido com pagina personalizada da dupla"
else
    falhou "T3" "Esperado HTTP 404 personalizado, obtido codigo=$CODE"
fi

# T4: SSH com chave publica (sem senha) retornando hostname 'bastion'
OUT=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new jglh@10.10.1.22 hostname 2>&1)
if [ $? -eq 0 ] && echo "$OUT" | grep -qx "bastion"; then
    ok "T4" "SSH com chave publica autenticou sem senha e retornou 'bastion'"
else
    falhou "T4" "Falha no SSH com chave publica: $OUT"
fi

# T5: SSH sem chave publica deve ser recusado com Permission denied (publickey)
OUT=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -o PubkeyAuthentication=no jglh@10.10.1.22 hostname 2>&1)
STATUS=$?
if [ $STATUS -ne 0 ] && echo "$OUT" | grep -q "Permission denied (publickey)"; then
    ok "T5" "SSH sem chave publica bloqueado corretamente (Permission denied (publickey))"
else
    falhou "T5" "Esperado 'Permission denied (publickey)', obtido status=$STATUS saida='$OUT'"
fi

echo "------------------------------------------"
echo "Resumo internos: $PASS OK, $FAIL FALHOU"
echo "=========================================="

[ $FAIL -eq 0 ]
