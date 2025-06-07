# 🚀 Deploy Automático com GitHub Actions + Docker

Esse projeto usa **GitHub Actions** para fazer deploy automático em uma instância VMs com Docker toda vez que um `push` é feito na branch `master`.

---

## ✅ Pré-requisitos

### No Servidor EC2 (Ubuntu)
- Docker e Docker Compose instalados
- Projeto já clonado em um diretório (ex: `/home/ubuntu/app`)
- Acesso SSH com chave `.pem`

### No Repositório GitHub
Configure os seguintes **secrets** em `Settings > Secrets and variables > Actions`:

| Nome             | Descrição                                          |
|------------------|---------------------------------------------------|
| `EC2_SSH_KEY`    | Conteúdo da `.pem` codificado em base64           |
| `EC2_USER`       | Usuário SSH da VM (ex: `ubuntu`)                 |
| `EC2_HOST`       | IP público da VM                                 |
| `EC2_DEPLOY_DIR` | Caminho no servidor onde está o projeto clonado   |

Para gerar o conteúdo do `EC2_SSH_KEY`:
```bash
base64 -w 0 ./<keyPath>.pem > keyssh.pem.b64
```

---

## 🚀 Como funciona

Ao dar `git push origin master`:

1. GitHub Actions clona seu repositório
2. Cria a chave `.pem` temporária
3. Acessa sua VM via SSH
4. Executa:
   - `git reset --hard && git pull`
   - `docker-compose down`
   - `docker-compose up -d --build`
5. Apaga a chave temporária

---

## 📂 Estrutura esperada no servidor

No caminho definido por `EC2_DEPLOY_DIR`, deve haver:

- Projeto já clonado
- `docker-compose.yml` pronto para rodar
- Permissões corretas (usuário VM dono do diretório)

---

## 🛡️ Segurança

- A chave `.pem` **não é salva no repositório**
- É gerada e apagada automaticamente após o deploy
- Secrets do GitHub são mascarados nos logs

---

## 💡 Exemplo de uso

```bash
# Faça alterações no projeto
git add .
git commit -m "update"
git push origin master
```

E pronto. O deploy será feito automaticamente na VMs.

---

## 📁 Arquivo de workflow

O workflow está em:  
`.github/workflows/main.yml`

```yaml
name: 🚀 Deploy Docker em EC2

on:
  push:
    branches: [ "master" ]

jobs:
  deploy:
    name: 🔄 Deploy automático via SSH
    runs-on: ubuntu-latest
    environment: aws

    env:
      SSH_KEY_PATH: ./ec2_key.pem
      DEPLOY_DIR: ${{ secrets.EC2_DEPLOY_DIR }}
      EC2_USER: ${{ secrets.EC2_USER }}
      EC2_HOST: ${{ secrets.EC2_HOST }}

    steps:
      - name: 📦 Clonar o repositório
        uses: actions/checkout@v3

      - name: 🔐 Criar chave SSH temporária a partir do secret base64
        run: |
          echo "${{ secrets.EC2_SSH_KEY }}" | base64 -d > "$SSH_KEY_PATH"
          chmod 600 "$SSH_KEY_PATH"

      - name: 🚀 Conectar na EC2 e executar o deploy
        run: |
          echo "🔗 Conectando na EC2 em $EC2_HOST com o usuário $EC2_USER..."
          ssh -tt -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_HOST" "
            set -e
            echo '📁 Entrando no diretório do projeto...'
            cd '$DEPLOY_DIR'
            echo '🌀 Resetando alterações locais (git reset --hard)...'
            git reset --hard HEAD
            git clean -fd
            echo '📥 Fazendo pull da branch master...'
            git pull origin master
            echo '🛑 Parando containers antigos...'
            docker-compose down
            echo '🧱 Recriando containers com build...'
            docker-compose up -d --build >/dev/null 2>&1 &&
            echo '✅ Deploy finalizado com sucesso!' || echo '❌ Deploy falhou!'
          "

      - name: 🧼 Limpar chave SSH temporária
        run: rm -f "$SSH_KEY_PATH"
```