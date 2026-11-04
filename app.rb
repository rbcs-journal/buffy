require "sinatra"
require "json"
require "octokit"
require "yaml"

set :port, ENV.fetch("PORT", 3000)
set :bind, "0.0.0.0"

SETTINGS = YAML.load_file(File.join(__dir__, "config", "settings.yml"))
GITHUB_TOKEN = ENV.fetch("GH_TOKEN", ENV["GITHUB_TOKEN"])

def github_client
  @client ||= Octokit::Client.new(access_token: GITHUB_TOKEN)
end

get "/" do
  content_type :json
  {
    status: "ok",
    service: "RBCS Editorial Bot (Buffy)",
    journal: SETTINGS["journal"]["name"],
    time: Time.now.utc.iso8601
  }.to_json
end

post "/dispatch" do
  payload_raw = request.body.read
  payload = JSON.parse(payload_raw) rescue {}

  event_type = request.env["HTTP_X_GITHUB_EVENT"]

  if event_type == "issue_comment" && payload["action"] == "created"
    comment_body = payload.dig("comment", "body") || ""
    issue_number = payload.dig("issue", "number")
    repo_full_name = payload.dig("repository", "full_name")
    comment_author = payload.dig("comment", "user", "login")

    bot_handle = "@#{SETTINGS['journal']['bot_github_user']}"

    if comment_body.include?(bot_handle) || comment_body.include?("@editorialbot")
      process_bot_command(repo_full_name, issue_number, comment_body, comment_author)
    end
  end

  status 200
  "OK"
end

def process_bot_command(repo, issue_number, body, author)
  clean_body = body.downcase

  if clean_body =~ /assign @([a-zA-Z0-9_\-]+) as editor/ || clean_body =~ /definir @([a-zA-Z0-9_\-]+) como editor/
    editor = $1
    reply = "✅ **Editor Designado**: @#{editor} foi formalmente designado como editor responsável por este artigo."
    github_client.add_comment(repo, issue_number, reply)
    github_client.add_assignees(repo, issue_number, [editor]) rescue nil

  elsif clean_body =~ /add @([a-zA-Z0-9_\-]+) as reviewer/ || clean_body =~ /adicionar @([a-zA-Z0-9_\-]+) como revisor/
    reviewer = $1
    reply = "👋 **Revisor Adicionado**: Olá @#{reviewer}, você foi incluído na equipe de revisores por pares da RBCS para este artigo!\n\nPor favor, utilize o checklist de revisão disponível no topo do issue e compartilhe seus comentários públicos nesta thread."
    github_client.add_comment(repo, issue_number, reply)

  elsif clean_body =~ /generate pdf/ || clean_body =~ /compile pdf/ || clean_body =~ /gerar pdf/
    reply = "🚀 **Solicitação de Compilação**: Disparando container compilador Inara para gerar prévia do artigo...\n*(Acompanhe o status e baixe o PDF na aba Actions do repositório).* "
    github_client.add_comment(repo, issue_number, reply)

  elsif clean_body =~ /recommend accept/ || clean_body =~ /recomendar aceite/
    reply = "🎉 **Recomendação de Aceite**: A revisão por pares foi concluída com parecer favorável dos revisores! Notificando o Editor-Chefe para homologação final e depósito de DOI."
    github_client.add_comment(repo, issue_number, reply)
    github_client.add_labels_to_an_issue(repo, issue_number, ["recommend-accept"]) rescue nil

  elsif clean_body =~ /help/ || clean_body =~ /ajuda/
    reply = <<~MSG
      🤖 **Comandos disponíveis no @#{SETTINGS['journal']['bot_github_user']}**:
      - `@#{SETTINGS['journal']['bot_github_user']} assign @username as editor`
      - `@#{SETTINGS['journal']['bot_github_user']} add @username as reviewer`
      - `@#{SETTINGS['journal']['bot_github_user']} remove @username as reviewer`
      - `@#{SETTINGS['journal']['bot_github_user']} generate pdf`
      - `@#{SETTINGS['journal']['bot_github_user']} recommend accept`
    MSG
    github_client.add_comment(repo, issue_number, reply)
  end
rescue => e
  puts "Erro ao processar comando: #{e.message}"
end
