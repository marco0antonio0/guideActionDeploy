#!/bin/bash

set -e

# ========================
# 🔧 CONFIGURAÇÕES GERAIS
# ========================

# ▶️ Acesso SSH
EC2_USER="${EC2_USER}"
EC2_HOST="${EC2_HOST}"
SSH_KEY_B64_PATH="${SSH_KEY_B64_PATH:-/tmp/ec2_key.pem}"

# ▶️ Diretório do Projeto na EC2
DEPLOY_DIR="${DEPLOY_DIR}"

# ▶️ Instância EC2 configure
SSH_KEY_TEMP="/tmp/deploy-key.pem"

# ========================
# ✅ Funções utilitárias
# ========================

log()         { echo -e "[INFO] $1"; }
log_success() { echo -e "[OK] ✅ $1"; }
log_error()   { echo -e "[ERRO] ❌ $1"; exit 1; }

decode_ssh_key() {
  cp "$SSH_KEY_B64_PATH" "$SSH_KEY_TEMP"
  chmod 600 "$SSH_KEY_TEMP"
}

deploy_via_ssh() {
  log "ℹ️ [INFO] Conectando via SSH para deploy..."

  ssh -i "$SSH_KEY_TEMP" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" bash <<EOF
    set -e
    echo -e "\n\n\n"
    echo -e "==============================================================="
    echo -e "                   Conexao ssh estabelecida"
    echo -e "==============================================================="

    if [ ! -d "$DEPLOY_DIR" ]; then
      if [ -n "$REPO_URL" ]; then
        echo -e "📁 [INFO] Pasta $DEPLOY_DIR nao existe, clonando repositório..."
        git clone "$REPO_URL" "$DEPLOY_DIR"
      else
        echo -e "❌ [ERRO] Variável REPO_URL não está definida. Não é possível clonar o repositório."
        exit 1
      fi
    fi

    cd "$DEPLOY_DIR"

    if [ -d ".git" ]; then
      echo -e "ℹ️ [INFO] Resetando alterações locais..."
      git reset --hard HEAD
      git clean -fd

      echo -e "ℹ️ [INFO] Fazendo pull da branch..."
      git pull origin
    else
      echo -e "❌ [ERRO] Pasta existe mas nao é um repositório Git."
      exit 1
    fi

    echo -e "ℹ️ [INFO] Verificando containers existentes..."
    if docker ps -a --format '{{.Names}}' | grep -q .; then
      echo -e "ℹ️ [INFO] Containers encontrados, parando..."
      docker-compose down
    else
      echo -e "ℹ️ [INFO] Nenhum container em execução."
    fi

    echo -e "ℹ️ [INFO] Subindo containers com build..."
    if docker-compose up -d --build > /dev/null 2>&1; then
      echo -e "✅ [OK] Deploy finalizado com sucesso."
    else
      echo -e "❌ [ERRO] Deploy falhou durante o build/start."
      exit 1
    fi

    echo -e "==============================================================="
    echo -e "                    Conexao ssh encerrada"
    echo -e "==============================================================="
    echo -e "\n\n\n"
EOF

}

# ========================
# 🚀 Execução principal
# ========================

main() {
  decode_ssh_key
  log "Fazendo deploy..."
  deploy_via_ssh || log_error "Deploy falhou."
}


main
