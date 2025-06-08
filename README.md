# 🚀 Deploy Automático com GitHub Actions + Autoscaling EC2

Este projeto usa **GitHub Actions** para fazer deploy automático em uma instância EC2 com Docker **incluindo escalonamento automático de recursos** toda vez que um `push` é feito na branch `master`.

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

| Nome                  | Descrição                                           |
|-----------------------|-----------------------------------------------------|
| `EC2_SSH_KEY`         | Conteúdo da `.pem` codificado em base64             |
| `EC2_USER`            | Usuário SSH da EC2 (ex: `ubuntu`, `admin`)          |
| `EC2_HOST`            | IP público ou DNS da instância EC2                  |
| `EC2_INSTANCE_ID`     | ID da instância EC2 (ex: `i-00dac334671257ec59`)     |
| `AWS_ACCESS_KEY_ID`   | Chave pública do IAM                                |
| `AWS_SECRET_ACCESS_KEY` | Chave secreta do IAM                              |

Para gerar o conteúdo do `EC2_SSH_KEY`:

```bash
base64 -w 0 ./ec2_key.pem > ec2_key.pem.b64
```

Para copiar o conteudo do b64:

```bash
cat ec2_key.pem.b64
```

---

## 🚀 Como funciona

Quando você executa:

```bash
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

---

## 💡 Exemplo de uso

```bash
# Faça alterações no projeto
git add .
git commit -m "feat: update de funcionalidade"
git push origin master
```

E pronto. O GitHub Actions cuida do resto.

---

## 📁 Arquivo de workflow

O workflow está em:  
`.github/workflows/deploy.yml`

```yaml
name: 🚀 EC2 Autoscaling + Deploy

on:
  push:
    branches: [ "master" ]

jobs:
  deploy:
    name: 🔄 Escalonamento + Deploy via script externo
    runs-on: ubuntu-latest

    steps:
      - name: 📥 Clonar repositório com script
        uses: actions/checkout@v3
        with:
          repository: marco0antonio0/guideActionDeploy
          path: ec2-scale-build.sh

      - name: 🔐 Criar chave SSH temporária
        run: |
          echo "${{ secrets.EC2_SSH_KEY }}" | base64 -d > /tmp/ec2_key.pem
          chmod 600 /tmp/ec2_key.pem

      - name: 🔧 Executar script com variáveis de ambiente
        run: |
          export AWS_ACCESS_KEY_ID="${{ secrets.AWS_ACCESS_KEY_ID }}"
          export AWS_SECRET_ACCESS_KEY="${{ secrets.AWS_SECRET_ACCESS_KEY }}"
          export AWS_DEFAULT_REGION="us-east-1"

          export EC2_USER="${{ secrets.EC2_USER }}"
          export EC2_HOST="${{ secrets.EC2_HOST }}"
          export SSH_KEY_B64_PATH="/tmp/ec2_key.pem"
          export INSTANCE_ID="${{ secrets.EC2_INSTANCE_ID }}"
          export TYPE_INITIAL="t2.micro"
          export TYPE_BUILD="t2.medium"

          chmod +x ec2-scale-build.sh
          ec2-scale-build.sh

      - name: 🧼 Limpar chave SSH temporária
        if: always()
        run: rm -f /tmp/ec2_key.pem
```
