#!/bin/bash

# Script para configurar o Nginx do projeto

# Nome do projeto (altere conforme necessário)
NOME_DO_PROJETO="controle-patrimonio"
ARQUIVO_CONF="${NOME_DO_PROJETO}.conf"

# Verificar se está sendo executado como root
if [ "$EUID" -ne 0 ]; then
  echo "Este script precisa ser executado como root (use sudo)"
  exit 1
fi

echo "Configurando Nginx para o projeto ${NOME_DO_PROJETO}..."

# Diretórios conforme info.md
CONFIGS_DIR="/home/ifsul/configs"
NGINX_APPS_DIR="/etc/nginx/conf.d/apps"

# Verificar se os diretórios existem
if [ ! -d "$CONFIGS_DIR" ]; then
  echo "Diretório $CONFIGS_DIR não encontrado. Criando..."
  mkdir -p "$CONFIGS_DIR"
fi

if [ ! -d "$NGINX_APPS_DIR" ]; then
  echo "Diretório $NGINX_APPS_DIR não encontrado. Criando..."
  mkdir -p "$NGINX_APPS_DIR"
fi

# Copiar arquivo de configuração para o diretório de configurações
echo "Copiando ${ARQUIVO_CONF} para $CONFIGS_DIR..."
cp ${ARQUIVO_CONF} "$CONFIGS_DIR/"

# Copiar arquivo de configuração para o diretório de aplicações do Nginx
echo "Copiando ${ARQUIVO_CONF} para $NGINX_APPS_DIR..."
cp ${ARQUIVO_CONF} "$NGINX_APPS_DIR/"

# Verificar a configuração do Nginx
echo "Verificando a configuração do Nginx..."
nginx -t

if [ $? -eq 0 ]; then
  # Reiniciar o serviço Nginx
  echo "Reiniciando o serviço Nginx..."
  systemctl reload nginx

  echo "Configuração do Nginx concluída com sucesso!"
  echo "O projeto ${NOME_DO_PROJETO} está configurado."
else
  echo "Erro na configuração do Nginx. Por favor, verifique o arquivo de configuração."
  exit 1
fi
