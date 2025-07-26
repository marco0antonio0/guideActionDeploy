
# 🚀 Deploy Automático com GitHub Actions + Autoscaling EC2 para build docker compose

<details>
<summary><strong>📋 Clique aqui para copiar o workflow V1</strong></summary>

```yaml
name: 🚀 EC2 Autoscaling + Deploys

on:
  push:
    branches: [ "master" ]

jobs:
  deploy:
    name: 🚀 Deploys + Autoscaling
    runs-on: ubuntu-latest
    environment: aws

    steps:
      - name: 📥 Clonar repositório com script
        uses: actions/checkout@v3
        with:
          repository: marco0antonio0/guideActionDeploy
          path: script-repo  

      - name: 🔐 Criar chave SSH temporária
        run: |
          echo "${{ secrets.EC2_SSH_KEY }}" | base64 -d > /tmp/ec2_key.pem
          chmod 600 /tmp/ec2_key.pem

      - name: 🔧 Executar script com variáveis de ambiente
        run: |
          export REPO_URL="${{ secrets.REPO_URL }}"
          export AWS_ACCESS_KEY_ID="${{ secrets.AWS_ACCESS_KEY_ID }}"
          export AWS_SECRET_ACCESS_KEY="${{ secrets.AWS_SECRET_ACCESS_KEY }}"
          export AWS_DEFAULT_REGION="us-east-1"
          export EC2_USER="${{ secrets.EC2_USER }}"
          export EC2_HOST="${{ secrets.EC2_HOST }}"
          export SSH_KEY_B64_PATH="/tmp/ec2_key.pem"
          export INSTANCE_ID="${{ secrets.EC2_INSTANCE_ID }}"
          export TYPE_INITIAL="${{ secrets.TYPE_INITIAL }}"
          export TYPE_BUILD="${{ secrets.TYPE_BUILD }}"
          export DEPLOY_DIR="${{ secrets.EC2_DEPLOY_DIR }}"
          chmod +x script-repo/ec2-scale-build.sh
          script-repo/ec2-scale-build.sh

      - name: 🧼 Limpar chave SSH temporária
        if: always()
        run: |
          rm -f /tmp/ec2_key.pem
          echo "🧽 Chave SSH temporária removida com sucesso."
```

</details>

<details>
<summary><strong>📋 Clique aqui para copiar o workflow V2</strong></summary>

```yaml
name: 🚀 EC2 Autoscaling + Deploy

on:
  push:
    branches: [ "master" ]

jobs:
  deploy:
    name: 🚀 Deploy + Autoscaling EC2
    runs-on: ubuntu-latest
    environment: aws

    steps:
      - name: 📥 Clonar repositório com scripts de deploy
        uses: actions/checkout@v3
        with:
          repository: marco0antonio0/guideActionDeploy
          path: script-repo  

      - name: 🔐 Criar chave SSH temporária
        run: |
          echo "${{ secrets.EC2_SSH_KEY }}" | base64 -d > /tmp/ec2_key.pem
          chmod 600 /tmp/ec2_key.pem
        shell: bash

      - name: ⚙️ 🔼 Etapa 1 Auto Scaling para instância mais forte
        run: |
          export AWS_ACCESS_KEY_ID="${{ secrets.AWS_ACCESS_KEY_ID }}"
          export AWS_SECRET_ACCESS_KEY="${{ secrets.AWS_SECRET_ACCESS_KEY }}"
          export AWS_DEFAULT_REGION="us-east-1"
          export TYPE_BUILD="${{ secrets.TYPE_BUILD }}"
          export INSTANCE_ID="${{ secrets.EC2_INSTANCE_ID }}"
          chmod +x script-repo/build_v2/ec2-scale-build-scaling-start.sh
          script-repo/build_v2/ec2-scale-build-scaling-start.sh
          
        shell: bash

      - name: ⚙️ 🚀 Etapa 2 Deploy da aplicação na instância EC2
        if: success()  
        run: |
          export REPO_URL="${{ secrets.REPO_URL }}"
          export EC2_USER="${{ secrets.EC2_USER }}"
          export EC2_HOST="${{ secrets.EC2_HOST }}"
          export SSH_KEY_B64_PATH="/tmp/ec2_key.pem"
          export DEPLOY_DIR="${{ secrets.EC2_DEPLOY_DIR }}"
          chmod +x script-repo/build_v2/ec2-scale-build.sh
          script-repo/build_v2/ec2-scale-build.sh
        shell: bash

      - name: ⚙️ 🔽 Etapa 3 Reverter para instância padrão (autoscaling reverso)
        if: always()
        run: |
          echo "♻️ Executando reversão para tipo inicial da instância EC2..."
          export AWS_ACCESS_KEY_ID="${{ secrets.AWS_ACCESS_KEY_ID }}"
          export AWS_SECRET_ACCESS_KEY="${{ secrets.AWS_SECRET_ACCESS_KEY }}"
          export AWS_DEFAULT_REGION="us-east-1"
          export TYPE_INITIAL="${{ secrets.TYPE_INITIAL }}"
          export INSTANCE_ID="${{ secrets.EC2_INSTANCE_ID }}"
          chmod +x script-repo/build_v2/ec2-scale-build-scaling-end.sh
          script-repo/build_v2/ec2-scale-build-scaling-end.sh
        shell: bash

      - name: 🧼 Limpar chave SSH temporária
        if: always()
        run: |
          rm -f /tmp/ec2_key.pem
          echo "🧽 Chave SSH temporária removida com sucesso."
        shell: bash
```

</details>

<details>
<summary><strong>📋 Clique aqui para copiar o workflow V3</strong></summary>

```yaml
name: 🚀 Deploy EC2 via SSH + Docker

on:
  push:
    branches: [ "main" ]

jobs:
  deploy:
    name: 🧰 Deploy 
    runs-on: ubuntu-latest
    environment: production
    env:
      BRANCH: main
      TYPE_BUILD: t2.medium
      TYPE_INITIAL: t2.micro
      AWS_DEFAULT_REGION: us-east-1
      DEPLOY_DIR: /home/admin/dev/seu-dir-projeto

    steps:
      - name: Instalar AWS CLI se necessário
        run: |
          if ! command -v aws &>/dev/null; then
            echo "🧰 AWS CLI não encontrada, instalando..."
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip -q awscliv2.zip
            sudo ./aws/install
            rm -rf aws awscliv2.zip
          else
            echo "✅ AWS CLI já está instalada: $(aws --version)"
          fi

      - name: 🔐 Configurar AWS CLI
        run: |
          export AWS_ACCESS_KEY_ID="${{ secrets.AWS_ACCESS_KEY_ID }}"
          export AWS_SECRET_ACCESS_KEY="${{ secrets.AWS_SECRET_ACCESS_KEY }}"
          aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
          aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
          aws configure set region "$AWS_DEFAULT_REGION"

      - name: ⚙️ Escalar instância para Build
        run: |
          export INSTANCE_ID="${{ secrets.EC2_INSTANCE_ID }}"
          aws ec2 stop-instances --instance-ids "$INSTANCE_ID"
          aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"
          aws ec2 modify-instance-attribute --instance-id "$INSTANCE_ID" --instance-type "{\"Value\": \"${TYPE_BUILD}\"}"
          aws ec2 start-instances --instance-ids "$INSTANCE_ID"
          aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
          echo "✅ Instância escalada para $TYPE_BUILD"

      - name: 🧪 SSH Deploy + Docker
        if: always()
        continue-on-error: true
        run: |
          export EC2_USER="${{ secrets.EC2_USER }}"
          export EC2_HOST="${{ secrets.EC2_HOST }}"
          export SSH_KEY_B64="${{ secrets.EC2_SSH_KEY }}"

          echo "${{ secrets.EC2_SSH_KEY }}" | base64 -d > chave.pem
          chmod 400 chave.pem

          for i in {1..30}; do
            echo "⏳ Aguardando SSH responder ($i/30)..."
            if nc -z "$EC2_HOST" 22; then
              echo "✅ Porta 22 (SSH) disponível"
              break
            fi
            sleep 5
          done

          ssh -i chave.pem -o StrictHostKeyChecking=no $EC2_USER@$EC2_HOST bash <<EOF
          set -e
          printf '=%.0s' {1..63}; echo
          echo -e "               🖧 Conexão SSH estabelecida"
          printf '=%.0s' {1..63}; echo

          cd "$DEPLOY_DIR"
          if [ -d ".git" ]; then
            echo "🔄 Resetando código..."
            git fetch origin
            git reset --hard "origin/$BRANCH"
            git clean -fd
          else
            echo "❌ Pasta não é um repositório Git."
            exit 1
          fi

          echo "🐳 Verificando containers..."
          docker ps -a --format '{{.Names}}' | grep -q . && docker-compose down || echo "Nenhum container ativo."

          echo "🚀 Subindo containers com build..."
          if docker-compose up -d --build > /dev/null 2>&1; then
            echo -e "✅ [OK] Deploy finalizado com sucesso."
          else
            echo -e "❌ [ERRO] Deploy falhou durante o build/start."
            exit 1
          fi

          printf '=%.0s' {1..63}; echo
          echo -e "               🔚 Conexão SSH encerrada"
          printf '=%.0s' {1..63}; echo
          EOF

      - name: 🔽 Escalar instância para tipo original
        if: always()
        continue-on-error: true
        run: |
          export INSTANCE_ID="${{ secrets.EC2_INSTANCE_ID }}"
          aws ec2 stop-instances --instance-ids "$INSTANCE_ID"
          aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"
          aws ec2 modify-instance-attribute --instance-id "$INSTANCE_ID" --instance-type "{\"Value\": \"${TYPE_INITIAL}\"}"
          aws ec2 start-instances --instance-ids "$INSTANCE_ID"
          aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
          echo "🧹 Instância restaurada para $TYPE_INITIAL"

      - name: 🧼 Limpeza final
        if: always()
        continue-on-error: true
        run: |
          rm -f chave.pem || true
          echo "🧼 Workflow finalizado e limpo."
```

</details>
---

## ✅ Pré-requisitos

### No Servidor EC2 (Ubuntu)
- Docker e Docker Compose instalados
- Projeto já clonado no diretório (ex: `/home/ubuntu/app`)
- Acesso SSH com chave `.pem`
- Permissões adequadas no diretório

### No Repositório GitHub - modelo v3
Configure os seguintes **secrets** em  
`Settings > Secrets and variables > Actions`:
`Private vars -> variaveis secrets de ambiente configuração interna`:
`Documents vars -> variaveis secrets configuração no codigo action`:

| Nome                     | Descrição                                                       |
|--------------------------|-----------------------------------------------------------------|
| `EC2_SSH_KEY`            | Private vars conteúdo da `.pem` codificado em base64            |
| `EC2_USER`               | Private vars Usuário SSH da EC2 (ex: `ubuntu`, `admin`)         |
| `EC2_HOST`               | Private vars IP público ou DNS da instância EC2                 |
| `EC2_INSTANCE_ID`        | Private vars ID da instância EC2 (ex: `i-00dac334671257ec59`)   |
| `AWS_ACCESS_KEY_ID`      | Private vars Chave pública do IAM                               |
| `AWS_SECRET_ACCESS_KEY`  | Private vars Chave secreta do IAM                               |
| `EC2_DEPLOY_DIR`         | Documents vars Caminho completo do projeto na EC2               |
| `TYPE_INITIAL`           | Documents vars Máquina inicial (ex: `t2.micro`)                 |
| `TYPE_BUILD`             | Documents vars Máquina build (ex: `t2.medium`)                  |
| `REPO_URL`               | URL do repositorio(opcional)                                    |


### No Repositório GitHub - modelo v1 & v2
Configure os seguintes **secrets** em  
`Settings > Secrets and variables > Actions`:

| Nome                     | Descrição                                          |
|--------------------------|----------------------------------------------------|
| `EC2_SSH_KEY`            | Conteúdo da `.pem` codificado em base64            |
| `EC2_USER`               | Usuário SSH da EC2 (ex: `ubuntu`, `admin`)         |
| `EC2_HOST`               | IP público ou DNS da instância EC2                 |
| `EC2_INSTANCE_ID`        | ID da instância EC2 (ex: `i-00dac334671257ec59`)   |
| `AWS_ACCESS_KEY_ID`      | Chave pública do IAM                               |
| `AWS_SECRET_ACCESS_KEY`  | Chave secreta do IAM                               |
| `EC2_DEPLOY_DIR`         | Caminho completo do projeto na EC2                 |
| `TYPE_INITIAL`           | Máquina inicial (ex: `t2.micro`)                   |
| `TYPE_BUILD`             | Máquina build (ex: `t2.medium`)                    |
| `REPO_URL`               | URL do repositorio(opcional)                       |

Para gerar o conteúdo do `EC2_SSH_KEY`:

```bash
base64 -w 0 ./ec2_key.pem > ec2_key.pem.b64
```

Para copiar o conteúdo do `.b64`:

```bash
cat ec2_key.pem.b64
```

---

## 🚀 Como funciona

Quando você executa:

```bash
git add .
git commit -m "feat: update"
git push origin master
```

O seguinte ocorre:

1. GitHub Actions clona o repositório onde está o script Bash
2. Decodifica a chave SSH `.pem`
3. Define as variáveis de ambiente necessárias (AWS, EC2)
4. Executa o script, que:
   - Para a instância
   - Escala para `t2.medium`
   - Faz o deploy com `git pull` e `docker-compose up`
   - Retorna a instância para `t2.micro`
5. Remove a chave temporária

---

## 📁 Estrutura esperada no servidor EC2

O diretório definido por `DEPLOY_DIR` (no script) deve conter:

- Projeto clonado do repositório
- Arquivo `docker-compose.yml`
- Scripts e permissões adequadas ao usuário SSH

---

## 🛡️ Segurança

- A chave `.pem` é **armazenada como secret codificada**
- Só é criada e usada temporariamente no runner
- Secrets do GitHub são protegidos e ocultos nos logs
- A instância EC2 escala apenas durante o deploy