# ヨドバシ価格チェッカー (Yodobashi Price Checker)

ヨドバシ.comの気になる商品を登録しておくだけで、自動で定期的に価格をトラッキングし、目標価格を下回ったり在庫が復活した際にDiscordへ自動で通知してくれるツールです。

![Dashboard Preview](https://via.placeholder.com/800x400.png?text=Yodobashi+Price+Checker+Dashboard)

## 特徴
* 📊 **価格推移のグラフ化**: 最大10年間、価格の推移をビジュアルで確認できます。
* 🏷️ **目標価格アラート**: 登録価格の10%OFFなど、指定した価格を下回るとDiscordに通知。
* 🟢 **在庫復活アラート**: 「販売休止中」や「お取り寄せ」の商品が「在庫あり」になった瞬間に検知します。
* 🚨 **特大アラート**: 登録時の価格から半額（50%OFF）になった場合、特別なアラートでお知らせします。
* 🐳 **Dockerで簡単構築**: 依存関係で悩むことなく、コマンド一発ですぐに起動できます。

## 使い方（起動方法）

DockerがインストールされているPC（Mac/Windows/Linux）であれば、以下のコマンドを実行するだけで起動します。

```bash
# 1. リポジトリをクローン
git clone https://github.com/GokkaAkagiri/yodobashichecker.git
cd yodobashichecker

# 2. コンテナのビルドと起動（バックグラウンド実行）
docker-compose up -d --build
```

起動後、ブラウザで [http://localhost:4567](http://localhost:4567) にアクセスするとダッシュボードが開きます。

## 初期設定（Discord通知の設定）
ダッシュボード右上の「⚙️設定」ボタンを開き、ご自身のDiscordサーバーの「Webhook URL」を登録してください。
この設定を行わないと通知が飛びませんのでご注意ください。

## 商品の登録方法
ダッシュボード上部のフォームに、トラッキングしたいヨドバシ.comの商品URLを貼り付けて「登録」ボタンを押すだけです。
（※複数行を一気に貼り付けて「一括登録」することも可能です）

## 停止方法
トラッキングを完全に停止したい場合は、以下のコマンドを実行してください。
```bash
docker-compose down
```

## データの保存先について
登録した商品データやDiscordのWebhook URLは、コンテナ内のデータベースではなく、手元の `db/database.sqlite3` ファイルに保存されます。
このファイルは `.gitignore` で除外されているため、Gitに誤ってプッシュされることはありません。ご安心ください。

## 動作要件
* Docker
* Docker Compose
