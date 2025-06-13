#!/bin/bash

set -e

# ========================
# 🔧 CONFIGURAÇÕES GERAIS
# ========================

# ▶️ Credenciais AWS
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# ▶️ Instância EC2 configure
INSTANCE_ID="${INSTANCE_ID}"
TYPE_INITIAL="${TYPE_INITIAL:-t2.micro}"
# TYPE_BUILD="${TYPE_BUILD:-t2.medium}"

# ========================
# ✅ Funções utilitárias
# ========================

log()         { echo -e "[INFO] $1"; }
log_success() { echo -e "[OK] ✅ $1"; }
log_error()   { echo -e "[ERRO] ❌ $1"; exit 1; }

check_aws_env() {
  if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" || -z "$AWS_DEFAULT_REGION" ]]; then
    log_error "❌ Variáveis AWS não definidas corretamente."
  fi
  return 0
}

install_aws_cli_if_missing() {
  if ! aws --version &> /dev/null; then
    log_error "❌ AWS CLI não detectada. Verifique se está corretamente instalada no sistema."
  else
    log "✅ AWS CLI detectada: $(aws --version)"
  fi
}

configure_aws_cli() {
  log "🔐 Configurando AWS CLI com as variáveis definidas..."
  aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
  aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
  aws configure set region "$AWS_DEFAULT_REGION"
  aws configure set output json
}

stop_instance() {
  aws ec2 stop-instances --instance-ids "$INSTANCE_ID" > /dev/null
  aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"
}

change_instance_type() {
  local type="$1"
  # Espera garantir que esteja 100% parada
  aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"

  aws ec2 modify-instance-attribute \
    --instance-id "$INSTANCE_ID" \
    --instance-type "{\"Value\": \"$type\"}"
}

start_instance() {
  aws ec2 start-instances --instance-ids "$INSTANCE_ID" > /dev/null
  aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
}

scale_instance() {
  local type="$1"

  echo -e "\nℹ️ Iniciando processo de autoscaling para tipo $type..."

  (
    while true; do
      echo -e "ℹ️ [INFO] Autoscaling em andamento..."
      sleep 4
    done
  ) &
  local spinner_pid=$!

  stop_instance
  change_instance_type "$type"
  start_instance

  kill "$spinner_pid" >/dev/null 2>&1 || true
  wait "$spinner_pid" 2>/dev/null || true

  log_success "Instância escalonada para $type com sucesso."
}

# ========================
# 🚀 Execução principal
# ========================

main() {
  check_aws_env
  install_aws_cli_if_missing
  configure_aws_cli
  scale_instance "$TYPE_INITIAL"
}


main
