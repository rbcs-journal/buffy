# 🤖 RBCS Buffy — Bot Editorial da Revista

Este repositório contém o serviço do **Bot Editorial (@rbcs-bot)** da Revista Brasileira de Computação e Software Científico (RBCS), inspirado na arquitetura Buffy da [Open Journals](https://github.com/openjournals/buffy).

---

## 🛠️ Como Funciona

1. O bot escuta *webhooks* disparados por comentários nos issues do repositório [`rbcs-journal/reviews`](https://github.com/rbcs-journal/reviews).
2. Quando um comentário menciona `@rbcs-bot` (ou `@editorialbot`), o bot interpreta a instrução e executa a ação correspondente via GitHub API:
   - Designa editores responsáveis
   - Convida revisores com mensagem de boas-vindas
   - Dispara a compilação de PDFs via Inara
   - Altera labels (ex: `recommend-accept`, `in-review`)

---

## 🚀 Executando com Docker

```bash
# Construir a imagem
docker build -t rbcs-buffy .

# Rodar o container
docker run -d -p 3000:3000 \
  -e GITHUB_TOKEN="seu_token_aqui" \
  rbcs-buffy
```

---

## 🔗 Configuração do Webhook no GitHub

No repositório `rbcs-journal/reviews`:
1. Acesse **Settings > Webhooks > Add webhook**.
2. **Payload URL**: `https://seu-servidor.com/dispatch`
3. **Content type**: `application/json`
4. **Events**: Marque **Issue comments** e **Issues**.
5. Salve o webhook.
