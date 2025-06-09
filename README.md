
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <title>README - Deploy Automático com EC2</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      margin: 2em;
      background-color: #f9f9f9;
      color: #333;
    }
    h1 {
      color: #2c3e50;
    }
    pre {
      background-color: #f3f3f3;
      padding: 1em;
      border: 1px solid #ddd;
      overflow-x: auto;
    }
    button.copy-btn {
      background-color: #4CAF50;
      color: white;
      border: none;
      padding: 1em 2em;
      margin-bottom: 1em;
      cursor: pointer;
      font-size: 14px;
      border-radius: 5px;
      box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
    }
    button.copy-btn:hover {
      background-color: #45a049;
    }
  </style>
</head>
<body>

<h1>🚀 Deploy Automático com GitHub Actions + Autoscaling EC2</h1>
<button class="copy-btn" onclick="copyCode()">📋 Copiar Workflow</button>
<p>Este projeto usa <strong>GitHub Actions</strong> para fazer deploy automático em uma instância EC2 com Docker <strong>incluindo escalonamento automático de recursos</strong> toda vez que um <code>push</code> é feito na branch <code>master</code>.</p>

<h2>✅ Pré-requisitos</h2>

<h3>No Servidor EC2 (Ubuntu)</h3>
<ul>
  <li>Docker e Docker Compose instalados</li>
  <li>Projeto já clonado no diretório (ex: <code>/home/ubuntu/app</code>)</li>
  <li>Acesso SSH com chave <code>.pem</code></li>
  <li>Permissões adequadas no diretório</li>
</ul>

<h3>No Repositório GitHub</h3>
<p>Configure os seguintes <strong>secrets</strong> em <br><code>Settings &gt; Secrets and variables &gt; Actions</code>:</p>

<pre><code>EC2_SSH_KEY
EC2_USER
EC2_HOST
EC2_INSTANCE_ID
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
TYPE_INITIAL
TYPE_BUILD
DEPLOY_DIR</code></pre>

<p>Para gerar o conteúdo do <code>EC2_SSH_KEY</code>:</p>
<pre><code>base64 -w 0 ./ec2_key.pem &gt; ec2_key.pem.b64</code></pre>

<p>Para copiar o conteúdo do <code>.b64</code>:</p>
<pre><code>cat ec2_key.pem.b64</code></pre>

<h2>🚀 Como funciona</h2>
<pre><code>git add .
git commit -m "feat: update"
git push origin master</code></pre>

<p>O seguinte ocorre:</p>
<ol>
  <li>GitHub Actions clona o repositório onde está o script Bash</li>
  <li>Decodifica a chave SSH <code>.pem</code></li>
  <li>Define as variáveis de ambiente necessárias (AWS, EC2)</li>
  <li>Executa o script, que:
    <ul>
      <li>Para a instância</li>
      <li>Escala para <code>t2.medium</code></li>
      <li>Faz o deploy com <code>git pull</code> e <code>docker-compose up</code></li>
      <li>Retorna a instância para <code>t2.micro</code></li>
    </ul>
  </li>
  <li>Remove a chave temporária</li>
</ol>

<h2>📁 Estrutura esperada no servidor EC2</h2>
<p>O diretório definido por <code>DEPLOY_DIR</code> (no script) deve conter:</p>
<ul>
  <li>Projeto clonado do repositório</li>
  <li>Arquivo <code>docker-compose.yml</code></li>
  <li>Scripts e permissões adequadas ao usuário SSH</li>
</ul>

<h2>🛡️ Segurança</h2>
<ul>
  <li>A chave <code>.pem</code> é <strong>armazenada como secret codificada</strong></li>
  <li>Só é criada e usada temporariamente no runner</li>
  <li>Secrets do GitHub são protegidos e ocultos nos logs</li>
  <li>A instância EC2 escala apenas durante o deploy</li>
</ul>

<h2>📁 Arquivo de workflow</h2>

<p>O workflow está em: <code>.github/workflows/deploy.yml</code></p>



<pre id="workflow"><code>name: 🚀 EC2 Autoscaling + Deploys

on:
  push:
    branches: [ "master" ]

jobs:
  deploy:
    name: 🔄 Escalonamento + Deploy via script externo
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
          echo "🧽 Chave SSH temporária removida com sucesso."</code></pre>

<script>
  function copyCode() {
    const text = document.getElementById("workflow").innerText;
    navigator.clipboard.writeText(text).then(() => {
      alert("✅ Workflow copiado com sucesso!");
    }, () => {
      alert("❌ Erro ao copiar o workflow.");
    });
  }
</script>

</body>
</html>