FROM ruby:3.3-slim

# SQLiteとヘッドレスブラウザ(Ferrum)を動かすためのChromiumをインストール
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    chromium \
    build-essential \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# コンテナ内の作業ディレクトリを指定
WORKDIR /app

# Gemfileをコピーしてライブラリをインストール
# (Gemfile.lockがあればそれもコピーするためアスタリスクを使用)
COPY Gemfile Gemfile.lock* ./
RUN bundle install

# アプリケーションのコードをすべてコンテナ内にコピー
COPY . .

# Webサーバー(Sinatra)が使うポートを公開
EXPOSE 4567

# デフォルトの実行コマンド (Webサーバーの起動)
CMD ["bundle", "exec", "ruby", "app.rb"]
