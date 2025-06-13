
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
          chmod +x script-repo/build_v2/ec2-scale-build-start.sh
          script-repo/build_v2/ec2-scale-build-start.sh
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
          chmod +x script-repo/build_v2/ec2-scale-build-end.sh
          script-repo/build_v2/ec2-scale-build-end.sh
        shell: bash

      - name: 🧼 Limpar chave SSH temporária
        if: always()
        run: |
          rm -f /tmp/ec2_key.pem
          echo "🧽 Chave SSH temporária removida com sucesso."
        shell: bash
```

</details>

---

## ✅ Pré-requisitos

### No Servidor EC2 (Ubuntu)
- Docker e Docker Compose instalados
- Projeto já clonado no diretório (ex: `/home/ubuntu/app`)
- Acesso SSH com chave `.pem`
- Permissões adequadas no diretório

### No Repositório GitHub
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