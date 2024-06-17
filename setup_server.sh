#!/bin/bash

# Verificar Conexão com a Internet
echo "Verificando conexão..."
if ping -c 1 8.8.8.8 &>/dev/null; then
    clear
else
    echo "Erro: Sem conexão com a internet."
    exit 1
fi

# Instalação do iptables
echo "Instalando iptables..."
sudo apt update > /dev/null 2>&1
sudo apt install -y iptables > /dev/null 2>&1
echo "iptables instalado"

# Instalar o Squid
echo "Instalando Squid..."
sudo apt install -y squid > /dev/null 2>&1
echo "Squid instalado"

# Apagar todas as regras do iptables
echo "Apagando todas as regras do iptables..."
sudo iptables -F
echo "Regras do iptables apagadas"

# Bloquear todo o acesso à internet
echo "Bloqueando todo o acesso à internet..."
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT DROP
echo "Acesso à internet bloqueado"

# Criar o script /usr/local/sbin/gateway.sh
echo "Criando arquivo gateway.sh..."
cat <<EOL | sudo tee /usr/local/sbin/gateway.sh > /dev/null 2>&1
#!/bin/bash
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE
EOL
echo "Arquivo gateway.sh criado"

# Garantir que o script seja executável
echo "Alterando permissões do arquivo gateway.sh..."
sudo chmod +x /usr/local/sbin/gateway.sh
echo "Permissões do arquivo gateway.sh alteradas"

# Criar o arquivo /etc/systemd/system/gateway.service
echo "Criando arquivo gateway.service..."
cat <<EOL | sudo tee /etc/systemd/system/gateway.service > /dev/null 2>&1
[Unit]
Description=Gateway
After=network.target

[Service]
ExecStart=/usr/local/sbin/gateway.sh

[Install]
WantedBy=multi-user.target
EOL
echo "Arquivo gateway.service criado"

# Habilitar o serviço de gateway
echo "Habilitando o serviço gateway.service..."
sudo systemctl enable gateway.service
echo "Serviço gateway.service habilitado"

# Iniciar o Squid
echo "Iniciando Squid..."
sudo systemctl start squid
echo "Squid iniciado"

# Parar o Squid
echo "Parando Squid..."
sudo systemctl stop squid
echo "Squid parado"

# Renomear o arquivo de configuração original do Squid
echo "Renomeando arquivo de configuração original do Squid..."
sudo mv /etc/squid/squid.conf /etc/squid/squid.conf.bkp
echo "Arquivo de configuração original do Squid renomeado"

# Criar um novo arquivo de configuração do Squid
echo "Criando novo arquivo de configuração do Squid..."
sudo touch /etc/squid/squid.conf
echo "Novo arquivo de configuração do Squid criado"

# Editar o novo arquivo de configuração do Squid
echo "Editando arquivo de configuração do Squid..."
cat <<EOL | sudo tee /etc/squid/squid.conf > /dev/null 2>&1
http_port 3128
visible_hostname Squid-Server
cache_mem 8 MB
cache_dir ufs /var/log/squid/ 100 16 256
cache_access_log /var/log/squid/access.log
cache_store_log /var/log/squid/store.log
cache_log /var/log/squid/cache.log
cache_mgr Suporte@megatoiga.com
acl localhost src 127.0.0.0
acl redelocal1 src 192.168.0.0/24
acl bloqueio url_regex -i '/etc/squid/bloqueio.txt'
http_access deny bloqueio
http_access allow localhost
http_access allow redelocal1
http_access deny all
EOL
echo "Arquivo de configuração do Squid editado"

# Criar os diretórios e arquivos de acordo com squid.conf
echo "Criando diretórios e arquivos para Squid..."
sudo mkdir -p /var/cache/squid/
sudo touch /var/log/squid/store.log
sudo touch /etc/squid/bloqueio.txt
echo "Diretórios e arquivos para Squid criados"

# Definir as permissões apropriadas
echo "Alterando permissões dos arquivos e diretórios do Squid..."
sudo chown proxy:proxy /etc/squid/bloqueio.txt
sudo chown proxy:proxy /var/log/squid/ -R
sudo chown proxy:proxy /var/cache/squid/ -R
echo "Permissões dos arquivos e diretórios do Squid alteradas"

# Reiniciar o Squid
echo "Reiniciando Squid..."
sudo systemctl restart squid
echo "Squid reiniciado"
sleep 3
clear
# Reboot do servidor
echo "Reiniciando servidor..."
sleep 7
reboot
