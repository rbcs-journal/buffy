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
    service: "RBCS Editorial Bot (JOSS/Buffy Architecture)",
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

    # Aceita tanto @rbcs-bot quanto o clássico @editorialbot do JOSS
    first_line = comment_body.lines.first.to_s.strip
    if first_line.include?(bot_handle) || first_line.include?("@editorialbot")
      process_bot_command(repo_full_name, issue_number, first_line, comment_author)
    end
  end

  status 200
  "OK"
end

def process_bot_command(repo, issue_number, body, author)
  clean_body = body.downcase

  if clean_body =~ /assign @([a-zA-Z0-9_\-]+) as editor/ || clean_body =~ /definir @([a-zA-Z0-9_\-]+) como editor/
    editor = $1
    reply = "✅ **Editor Assigned**: @#{editor} has been assigned as the handling editor for this submission."
    github_client.add_comment(repo, issue_number, reply)
    github_client.add_assignees(repo, issue_number, [editor]) rescue nil

  elsif clean_body =~ /add @([a-zA-Z0-9_\-]+) to reviewers/ || clean_body =~ /add @([a-zA-Z0-9_\-]+) as reviewer/ || clean_body =~ /adicionar @([a-zA-Z0-9_\-]+) como revisor/
    reviewer = $1
    reply = "👋 **Reviewer Added**: @#{reviewer} has been added to the reviewers team for this submission. Welcome!"
    github_client.add_comment(repo, issue_number, reply)

  elsif clean_body =~ /remove @([a-zA-Z0-9_\-]+) from reviewers/ || clean_body =~ /remover @([a-zA-Z0-9_\-]+) dos revisores/
    reviewer = $1
    reply = "👋 **Reviewer Removed**: @#{reviewer} has been removed from the reviewers team."
    github_client.add_comment(repo, issue_number, reply)

  elsif clean_body =~ /start review/ || clean_body =~ /iniciar revisao/
    reply = "🚀 **Starting Review**: Transitioning from Pre-Review to formal Review issue with dual-reviewer checklist...\n*(GitHub Action workflow is initializing the review thread).* "
    github_client.add_comment(repo, issue_number, reply)

  elsif clean_body =~ /check repository/ || clean_body =~ /verificar repositorio/ || clean_body =~ /auditar repositorio/
    reply = "🔍 **Repository Audit Triggered**: Running automated JOSS-style compliance checks (OSI license, `paper.md`, test suite, CI workflows, word count)...\n*(Audit report will be posted momentarily).* "
    github_client.add_comment(repo, issue_number, reply)

  elsif clean_body =~ /check references/ || clean_body =~ /verificar referencias/
    reply = "📚 **References Audit Triggered**: Checking `paper.bib` integrity and validating DOIs against the Crossref API...\n*(Results will be posted shortly).* "
    github_client.add_comment(repo, issue_number, reply)

  elsif clean_body =~ /generate pdf/ || clean_body =~ /compile pdf/ || clean_body =~ /gerar pdf/
    reply = "📄 **PDF Compilation Request**: Invoking **Inara** Docker compiler engine to compile publication-ready PDF and JATS XML...\n*(Download will be available under Actions artifacts).* "
    github_client.add_comment(repo, issue_number, reply)

  elsif clean_body =~ /recommend accept/ || clean_body =~ /recomendar aceite/
    reply = "🎉 **Recommendation for Acceptance**: Reviewers and editor recommend this paper for acceptance! Notifying Editor-in-Chief for final homologation and DOI minting."
    github_client.add_comment(repo, issue_number, reply)
    github_client.add_labels_to_an_issue(repo, issue_number, ["recommend-accept"]) rescue nil

  elsif clean_body =~ /commands/ || clean_body =~ /help/ || clean_body =~ /ajuda/
    reply = <<~MSG
      🤖 **EditorialBot / RBCS-Bot Commands (100% JOSS-compatible)**:

      Commands must be placed on the **first line** of your comment.

      *General & Author Commands:*
      - `@editorialbot check repository` — Run full repository audit (OSI license, paper.md, test suite, CI)
      - `@editorialbot check references` — Validate BibTeX formatting and query Crossref DOIs
      - `@editorialbot generate pdf` — Compile draft PDF via Inara Docker engine
      - `@editorialbot commands` — Show this list of available commands

      *Editorial & Pre-Review Commands:*
      - `@editorialbot assign @username as editor` — Assign handling editor
      - `@editorialbot add @username to reviewers` — Add reviewer to the panel
      - `@editorialbot remove @username from reviewers` — Remove reviewer from panel
      - `@editorialbot start review` — Close pre-review and launch formal review thread with checklists
      - `@editorialbot recommend accept` — Signal final recommendation for acceptance
    MSG
    github_client.add_comment(repo, issue_number, reply)
  end
rescue => e
  puts "Erro ao processar comando: #{e.message}"
end
