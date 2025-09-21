# Smalruby Koshien Server

スモウルビー甲子園の競技用サーバーです。GraphQL APIを提供し、Rubyで作成されたAIプログラム同士の対戦を管理します。

## 技術スタック

- **Ruby**: 3.3.9
- **Rails**: 8.0.2.1
- **Database**: SQLite3
- **API**: GraphQL
- **Proxy**: Thruster (HTTP/2)
- **Container**: Docker
- **Solid Series**: Solid Cache, Solid Queue, Solid Cable

## 開発環境

### 必要な環境

- Ruby 3.3.9
- Node.js (必要に応じて)
- Docker & Docker Compose

### セットアップ

```bash
# リポジトリクローン
git clone https://github.com/smalruby/smalruby-koshien.git
cd smalruby-koshien

# 依存関係インストール
bundle install

# データベース準備
bin/rails db:prepare

# サーバー起動
bin/rails server
```

### Docker を使用した開発

```bash
# 開発用コンテナ起動
docker-compose up dev

# 本番用コンテナ起動
docker-compose up app
```

## API エンドポイント

- **GraphQL API**: `POST /graphql`
- **Health Check**: `GET /health`
- **Rails Health**: `GET /up`

## テスト

```bash
# テスト実行
bin/rails test

# セキュリティスキャン
bin/brakeman

# コードスタイルチェック
bin/rubocop
```

## デプロイ

AWS EC2 + Docker環境での運用を想定しています。

```bash
# 本番用ビルド
docker build -t smalruby-koshien .

# コンテナ起動
docker run -d -p 80:80 -e RAILS_MASTER_KEY=<master_key> smalruby-koshien
```
