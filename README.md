# Laboratório LSOR — Serviços de Rede no Linux (HTTP, SSH, NAT e Firewall)

Laboratório reproduzível no **Kathará** que publica um servidor web **NGINX** e um servidor **OpenSSH** endurecido em uma **DMZ**, protegidos por um roteador/firewall (`iptables`) com política padrão `DROP` e **DNAT**, sem expor a rede interna (**LAN**).

## Integrantes da Dupla

* **José Gabriel**
* **Luiz Henrique**

---

## Repositórios no Docker Hub

As imagens customizadas estão publicadas como repositórios públicos na tag `1.0`:

* **Servidor Web (`lsor-web:1.0`)**: https://hub.docker.com/r/josegabriel09/lsor-web
* **Ferramentas de Teste (`lsor-tools:1.0`)**: https://hub.docker.com/r/josegabriel09/lsor-tools

---

## Visão de Pássaro — 5W1H de HTTP e SSH

### HTTP (Hypertext Transfer Protocol)

| Pergunta | Resposta |
| :--- | :--- |
| **What (O quê?)** | Protocolo de camada de aplicação (cliente-servidor, sem estado) usado para transferência de páginas web, APIs JSON e arquivos em texto claro. |
| **Why (Por quê?)** | Permitir que clientes na Internet e na LAN acessem o portal da organização e o endpoint de monitoramento `/api/status` de forma padronizada. |
| **Where (Onde?)** | Executado no servidor `web` (`10.10.1.80`, DMZ) na porta `80/tcp`, publicado externamente via DNAT no IP público do `gw` (`203.0.113.1:80`). |
| **When (Quando?)** | Sempre que um navegador ou cliente (`curl`) envia uma requisição (`GET /`, `GET /api/status`, etc.) e recebe uma resposta com código de status (`200`, `404`). |
| **Who (Quem?)** | Qualquer visitante externo (`ext`), o administrador interno (`admin`) ou um dispositivo na rede local (bônus na porta `8080`). |
| **How (Como?)** | Implementado com **NGINX** (`josegabriel09/lsor-web:1.0`), *server block* dedicado (`jglh.conf`), log exclusivo (`/var/log/nginx/jglh_access.log`), rota JSON e página 404 personalizada. |

### SSH (Secure Shell)

| Pergunta | Resposta |
| :--- | :--- |
| **What (O quê?)** | Protocolo criptográfico de camada de aplicação para administração remota segura, execução de comandos e tunelamento sobre redes não confiáveis. |
| **Why (Por quê?)** | Permitir que o administrador gerencie os servidores remotamente com confidencialidade, integridade e autenticação forte, impedindo interceptação (diferente do HTTP em texto claro). |
| **Where (Onde?)** | Executado no servidor `bastion` (`10.10.1.22`, DMZ) na porta `22/tcp`, publicado externamente via DNAT na porta `2222/tcp` do `gw` (`203.0.113.1:2222`). |
| **When (Quando?)** | Durante tarefas de administração remota a partir da LAN (`admin`) ou da Internet (`ext`). |
| **Who (Quem?)** | Apenas o usuário autorizado da dupla (**`jglh`**), com login de `root` explicitamente proibido. |
| **How (Como?)** | Implementado com **OpenSSH** (`kathara/base`), arquivo de *hardening* em `/etc/ssh/sshd_config.d/99-hardening.conf` (apenas chave pública, sem senha) e chaves de host geradas no boot via `ssh-keygen -A`. |

---

## Tabela de Endereçamento e Topologia

| Dispositivo | Interface → Domínio | Endereço IP | Rota padrão | Imagem Docker | Função |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`ext`** | `eth0` → `inet` | `203.0.113.50/24` | não tem | `josegabriel09/lsor-tools:1.0` | Cliente na "Internet" |
| **`gw`** | `eth0` → `inet` | `203.0.113.1/24` | *(bônus: bridged `eth3`)* | `kathara/base` | Roteador, NAT (DNAT/MASQUERADE) e Firewall |
| **`gw`** | `eth1` → `dmz` | `10.10.1.1/24` | — | `kathara/base` | Gateway da DMZ |
| **`gw`** | `eth2` → `lan` | `10.10.2.1/24` | — | `kathara/base` | Gateway da LAN |
| **`web`** | `eth0` → `dmz` | `10.10.1.80/24` | `via 10.10.1.1` | `josegabriel09/lsor-web:1.0` | Servidor HTTP (NGINX) |
| **`bastion`** | `eth0` → `dmz` | `10.10.1.22/24` | `via 10.10.1.1` | `kathara/base` | Servidor SSH endurecido (OpenSSH) |
| **`admin`** | `eth0` → `lan` | `10.10.2.10/24` | `via 10.10.2.1` | `josegabriel09/lsor-tools:1.0` | Estação do administrador |

---

## Decisões de Implementação (Visão de Peixe)

* **Separação das imagens Docker**: A verificação em `kathara/base` mostrou que `sshd`, `iptables`, `curl`, `tcpdump` e `ping` já vêm instalados. Apenas `nginx` (em `lsor-web`) e `nmap` (em `lsor-tools`) precisaram de imagens customizadas, mantendo os containers enxutos.
* **Estratégia de chaves SSH e riscos**: Optamos por **gerar os pares de chaves Ed25519 no boot** em `admin.startup` e `ext.startup`, publicando apenas as chaves públicas (`.pub`) na pasta compartilhada `/shared/keys` do Kathará para que o `bastion.startup` monte o `/home/jglh/.ssh/authorized_keys`.
  * *Vantagem*: nenhuma chave privada é versionada no repositório GitHub (evitando vazamento de credenciais) e cada execução gera chaves novas, inclusive as chaves de host (`ssh-keygen -A`).
  * *Riscos*: em um cenário real de produção, um diretório compartilhado sem controle de acesso não seria um canal seguro para distribuir chaves públicas, pois um host comprometido com permissão de escrita poderia injetar sua própria chave no `authorized_keys`. Em produção, essa distribuição seria feita por ferramentas autenticadas de gerência de configuração (como Ansible) ou certificados SSH.
* **Firewall `DROP` por padrão (`gw/etc/firewall.sh`)**: Toda passagem pela cadeia `FORWARD` é bloqueada por padrão, liberando apenas respostas (`ESTABLISHED,RELATED`), tráfego `eth0 → eth1` nas portas `80` (`web`) e `22` (`bastion`), e acessos originados da LAN (`eth2`). Assim, mesmo que um servidor da DMZ seja comprometido, ele **não** consegue iniciar conexões para a LAN.
* **Bônus (Internet real)**: Com `gw[bridged]="true"` e `gw[port]="8080:80/tcp"`, o script `gw/etc/firewall.sh` identifica automaticamente a interface *bridged* (`eth3`) e cria as regras de DNAT e `FORWARD` para a porta `80` do `web`.

---

## Como Executar o Laboratório

### Pré-requisitos
* Docker em execução
* Kathará instalado (`kathara --version`)

### 1. Clonar e subir o laboratório (sem `docker build`)
```bash
git clone <URL-DO-REPOSITORIO>
cd lsor-lab
kathara lstart
```
*(Opcional: use `kathara lstart --noterminals` para subir sem abrir janelas de terminal.)*

### 2. Rodar os testes automatizados (E2)

**No Linux / macOS / Git Bash:**
```bash
# Testes internos (T1-T5) no admin
kathara exec admin -- bash -s < testes/internos.sh

# Testes externos (T6-T9) no ext
kathara exec ext -- bash -s < testes/externos.sh

# T10: conferir o log de acesso do NGINX no web (origem 203.0.113.50)
kathara exec web -- tail -n 10 /var/log/nginx/jglh_access.log
```

**No Windows (PowerShell):**
```powershell
Copy-Item testes\internos.sh shared\internos.sh -Force
Copy-Item testes\externos.sh shared\externos.sh -Force

kathara exec admin -- bash /shared/internos.sh
kathara exec ext -- bash /shared/externos.sh
kathara exec web -- tail -n 10 /var/log/nginx/jglh_access.log
```

### 3. Testar o Bônus (T11)
No navegador do host ou de outro dispositivo (celular/PC) na mesma rede:
```text
http://<IP-DO-HOST>:8080
```

### 4. Encerrar e limpar o laboratório
```bash
kathara lclean
```

---

## Evidências Coletadas (`evidencias/`)

* `testes_internos.txt` — saída dos testes T1–T5 (`5 OK, 0 FALHOU`).
* `testes_externos.txt` — saída dos testes T6–T9 (`4 OK, 0 FALHOU`).
* `nmap_externo.txt` — varredura `nmap -Pn -p- 203.0.113.1` confirmando apenas `80/tcp` e `2222/tcp` abertas.
* `t10_nginx_access_log.txt` — log exclusivo do NGINX mostrando `203.0.113.50` preservado pelo DNAT.
* `http_claro.pcap` — captura `tcpdump` no `gw` (`eth0`, porta 80) exibindo tráfego HTTP legível em texto claro.
* `ssh_cifrado.pcap` — captura `tcpdump` no `gw` (`eth0`, porta 2222) exibindo tráfego SSH criptografado.
