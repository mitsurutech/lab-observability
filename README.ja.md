# Docker Compose で学ぶ Prometheus と Grafana のオブザーバビリティラボ：専用のコピーでアラートルールを書く

[English](README.md) | [Français](README.fr.md) | [日本語](README.ja.md) | [Español](README.es.md)

[![check](https://github.com/mitsurutech/lab-observability/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-observability/actions/workflows/check.yml)

授業ですぐに使える**監視とオブザーバビリティのラボ**です。[MitsuruTech ラーニングプラットフォーム](https://mitsurutech.co.uk/ja/learning)から提供しており、学校では生徒一人ひとりにブラウザー上の専用データベース、コンテナ、ターミナルを用意できます。生徒は、監視対象の小さな Web サーバー、そのメトリクスを集める **Prometheus**、それを描画する **Grafana** がすでにつながった状態で、自分専用のコピーを受け取ります。そのうえで Prometheus に**アラートルールを書き**、わざとサーバーを止めて、アラートが pending から firing に変わるのを確認します。DevOps、運用、クラウドの単元で、監視、PromQL、ダッシュボード、アラートを初めて学ぶのに向いており、何もインストールする必要がなく、誰のマシンにも影響しません。

ファイルは `docker-compose` 用の `compose.yaml` 1 つだけで、お手元のマシンでもプラットフォーム上でも同じように動きます。プラットフォームでは、生徒ごとにインターネットへの接続がない専用のコピーが使えます。

## 内容

| サービス | イメージ | メモリ | 内容 |
| --- | --- | --- | --- |
| `app` | [`nginx:1.27-alpine`](https://hub.docker.com/_/nginx) | 64 MB | 監視対象の Web サーバー。権限のないアカウント（101）で動き、ステータスページは別のポートで公開されます |
| `exporter` | [`nginx/nginx-prometheus-exporter:1.5.3`](https://hub.docker.com/r/nginx/nginx-prometheus-exporter) | 32 MB | ステータスページを読み、`nginx_up` や `nginx_http_requests_total` などの Prometheus メトリクスとして公開します |
| `prometheus` | [`prom/prometheus:v3.13.4`](https://hub.docker.com/r/prom/prometheus) | 256 MB | 5 秒ごとにメトリクスを集め、PromQL での問い合わせに答え、アラートルールを読み込みます |
| `grafana` | [`grafana/grafana:13.2.4`](https://hub.docker.com/r/grafana/grafana) | 512 MB | メトリクスを描画します。コピーを使う 1 人としてログイン済みで、Prometheus にもすでに接続されています |

制限の合計は 864 MB です。待機中のコピーが使うのはおよそ 280 MB で、そのほとんどは Grafana です。起動から 20 秒以内に正常になります。初回の起動ではイメージをダウンロードします。Grafana のイメージが最も大きなものです。

イメージはサードパーティ製のプログラムで、各プロジェクトが公開しているイメージを変更せずにそのまま使い、バージョンを固定しています（`latest` は使いません）。そのため、レッスンとレッスンの間でラボが変わってしまうことはありません。ここで何かをビルドすることはなく、このリポジトリの内容がイメージに含まれて配布されることもありません。各イメージに必要な設定は、compose ファイルをもとにそれぞれのエントリポイントが書き出すので、ほかにダウンロードするものはありません。

## プラットフォームで使う

[MitsuruTech ラーニングプラットフォーム](https://mitsurutech.co.uk/ja/learning)では、生徒一人ひとりにラボの専用コピーを、ブラウザー上でターミナルと並べて用意します。

**試すには：** [コンテナのページ](https://mitsurutech.co.uk/ja/container)を開き、**Sample labs** の中からこのラボを探して Start を押します。試すだけならアカウントは不要です。マニュアルのページは [Observability lab](https://mitsurutech.co.uk/ja/help/lab-observability) で、レッスン **Observability Basics** がこのラボを順に解説しています。

**クラスの課題として出すには：**

1. モジュールで種類が **Lab** の課題を作り、**In a GitHub repository** を選びます。
2. `https://github.com/mitsurutech/lab-observability` とブランチ `main` を指定します。compose ファイルは既定の `compose.yaml` です。ファイルを変更したい場合は、先にリポジトリをフォークしてください。
3. 公開します。生徒のコピーはどれも、あなたが公開したコミットから始まるので、あとからここを変更しても、すでに出したラボは変わりません。
4. 課題に何を提出するかを書き（[教員の方へ](#教員の方へ)を参照）、ほかの課題と同じように配布します。

マニュアルの[コンテナラボのガイド](https://mitsurutech.co.uk/ja/help/labs)には、compose ファイルに書けること、コピーが使えるメモリの量、教員が生徒のコピーを開いて見守り、採点する方法など、残りの内容があります。

学校のアカウントはまだありませんか？ [最初の 1 年間は無料](https://mitsurutech.co.uk/ja/pricing)で、生徒 50 人まで利用でき、[アカウント作成](https://mitsurutech.co.uk/ja/signup)に必要なのはメールアドレスだけです。

## 自分のマシンで動かす

Docker と Compose プラグインが必要です。初回の起動ではイメージをダウンロードします。

```bash
docker compose -f compose.yaml -f local.yaml up
```

Prometheus は <http://localhost:9090>、Grafana は <http://localhost:3000> で開きます。Grafana はログイン不要です。Web サーバー自体は <http://localhost:8080> にあります。

`local.yaml` はポートを `127.0.0.1` のみに公開するので、ラボにはお使いのコンピューターからだけアクセスでき、ほかのどこからもアクセスできません。`Ctrl-C` で停止し、ボリュームごと削除するには `docker compose -f compose.yaml -f local.yaml down -v` を実行します。

## 進め方

1. **Prometheus に問い合わせる。** Prometheus で `nginx_up` を実行し、続いて `rate(nginx_http_requests_total[1m])` を実行します。ラボのネットワーク上のターミナルからは、同じ問い合わせを `curl 'http://prometheus:9090/api/v1/query?query=nginx_up'` で行えます。
2. **トラフィックを作る。** `curl "http://app:8080/?n=[1-300]"` は 1 つのコマンドで 300 件のリクエストを送り、レートが上がります。
3. **グラフにする。** Grafana で **Explore** を開き（またはダッシュボードを作り）、すでに用意されている **Prometheus** データソースを選んで、同じクエリを実行します。
4. **アラートルールを書く。** `docker exec`（自分のマシンでは `docker compose exec`）を使って、`prometheus` サービスの `/etc/prometheus/rules/` に `.yml` ファイルを置きます。たとえば `expr` が `nginx_up == 0`、`for` が `10s` のルールです。その後 `curl -X POST http://prometheus:9090/-/reload` で Prometheus を再読み込みし、**Alerts** を見ます。
5. **発火させる。** `docker stop app` でサーバーを止めます。アラートはルールで指定した 10 秒の間 pending になり、その後 firing になります。`docker start app` で解消します。

Prometheus の設定（`/etc/prometheus/prometheus.yml`）、書いたルール、Grafana のダッシュボードは名前付きボリュームにあり、ラボを停止してもう一度起動しても残ります。測定値は保存されないため、再起動したラボのグラフは空から始まります。設定が書き込まれるのは最初の起動のときだけで、設定を変更しても、再起動で元に戻ることはありません。

## 教員の方へ

このラボには自動採点はありません。生徒が証拠を提出し、ほかのラボと同じように先生が採点します。

**証拠は 2 つに分けて求めます。** 1 つ目は作業の証拠で、ルールそのもの、Prometheus の Alerts ページで**発火**している様子のスクリーンショット、同じ信号を表す Grafana のパネルです。2 つ目は理解で、ルールが何を問うているのか、なぜ 10 秒なのか、発火したときに当番の担当者は何をするかを、1、2 文で書かせます。さらに深めたい場合は、リクエストレートなど別の信号に対する 2 つ目のルールと、すべての数値でアラートを出すよりもユーザーが気づく症状でアラートを出すほうがよい理由の説明を求めてください。

**コースでの位置づけ。** DevOps、運用、クラウド、システムの単元で、監視、メトリクス、ダッシュボード、アラートを初めて学ぶ場面に向いています。また、メトリクスを公開しないソフトウェアを監視する方法である exporter の考え方を学ぶのにも適しています。正確な表現は、各自の認定団体の単元でご確認ください。ここでは引用していません。

**誰が何を見られるか。** コピーは、それを起動した生徒だけのものです。そのモジュールを教える教職員はコピーを開いて、生徒が何をしたかを確認できます。生徒の作業を開くとアクセスログに記録され、生徒はそのログを読めます。

## ラボでできないこと

ラボにはインターネットへの接続がないので、何かをダウンロードすることはできず、Grafana のプラグインカタログと更新の確認は無効になっています。アラートは見ることはできても、どこにも送れません。通知先のメールやチャットがないためです。ラボを停止すると、測定値は保存されません。ルールを書くには Prometheus サービスへの `docker exec` を使い、プラットフォーム上のラボのターミナルではこれが使えます。ラボの `docker` コマンドを提供できないマシンでは、自分の Docker でルールを書いてください。

## トラブルシューティング

- **Start の直後に Grafana のページが空白になる。** 数秒待ってからもう一度 Open を押してください。ラボは Prometheus が応答して初めて準備完了と表示し、Grafana はそのあとに続きます。
- **再読み込みしてもアラートが表示されない。** ルールファイルに誤りがあると再読み込みは失敗します。`curl -s -X POST http://prometheus:9090/-/reload` は「failed to reload config」と表示し、Prometheus はそれまでのルールを保持します。理由はサービスのログ（`docker logs prometheus`）にあります。ルールは `/etc/prometheus/rules/*.yml` からのみ読み込まれます。
- **自分のマシンで 9090、3000、8080 のいずれかのポートがすでに使われている。** `local.yaml` の左側の番号を変更して、そのポートを開いてください。

## ラボの検証

`test/check.sh` は、プラットフォームのランナーがすべてのサービスを起動するのと同じ方法（すべての capability を削除、`no-new-privileges`、プロセス数の制限、メモリの制限、インターネットへの接続なし）でラボを起動し、そのネットワークの内側から、このページが約束している内容を検証します。すべてのサービスが正常であること、Prometheus が exporter をスクレイプしていること、PromQL のクエリが応答すること、Grafana にログイン済みでデータソースが動作すること、ボリュームに書いたルールが pending、firing を経て解消されること、設定とルールが停止と起動を経ても残ることです。Docker が必要で、push のたびに実行されます。それが先頭のバッジです。

```bash
test/check.sh
```

## バージョンとライセンス

[nginx](https://nginx.org) は BSD-2-Clause、[NGINX Prometheus exporter](https://github.com/nginx/nginx-prometheus-exporter) と [Prometheus](https://github.com/prometheus/prometheus) は Apache-2.0、[Grafana](https://github.com/grafana/grafana) は AGPL-3.0 です。いずれもそれぞれのイメージから変更せずに実行しており、ここでは配布していません。イメージは `nginx:1.27-alpine`、`nginx/nginx-prometheus-exporter:1.5.3`、`prom/prometheus:v3.13.4`、`grafana/grafana:13.2.4` です。

compose ファイル、テスト、このドキュメントは当社のもので、下の[ライセンス](#ライセンス)が適用されます。中のアプリケーションは、上にリンクした各プロジェクト自身のライセンスのままです。

## 提供元

[Mitsuru Technologies](https://mitsurutech.co.uk) が [MitsuruTech ラーニングプラットフォーム](https://mitsurutech.co.uk/ja/learning)のために作りました。このプラットフォームは、学校向けに Python、Java、Go、Node、SQL、Linux をブラウザーで学べるようにし、コンテナラボ、GitHub からデプロイする Web アプリ、自動で採点されるクイズを備えています。アカウントなしでコードを試すなら[プレイグラウンド](https://mitsurutech.co.uk/ja/playground)をご利用ください。[ヘルプのマニュアル](https://mitsurutech.co.uk/ja/help/labs)にすべてのラボが載っています。

同じ提供元のほかのラボ：[lab-juice-shop](https://github.com/mitsurutech/lab-juice-shop)、[lab-dvwa](https://github.com/mitsurutech/lab-dvwa)、[lab-webgoat](https://github.com/mitsurutech/lab-webgoat)、[lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin)、[lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea)、[lab-sample](https://github.com/mitsurutech/lab-sample)。

## ライセンス

この作品は [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) でライセンスされています。Mitsuru Technologies Ltd のクレジットを表示し、商用に使わず、これをもとに作ったものを同じライセンスで共有するなら、学習と授業のために共有・改変できます。全文は `LICENSE` ファイルにあります。
