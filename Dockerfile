FROM ruby:3.2-slim

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev git curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile ./
RUN bundle install

COPY . .

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "-", "-b", "tcp://0.0.0.0:3000"]
