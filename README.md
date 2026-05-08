# AgentCore Runtime + Claude Agent SDK + S3 Files

Claude Agent SDK を Amazon Bedrock AgentCore Runtime 上で動かし、S3 Files にマウントしたドキュメントを自然言語で検索するファイル検索エージェントのサンプルです。

## 構成

```
agent_server/
  main.py          # Claude Agent SDK + BedrockAgentCoreApp（SSE ストリーミング対応）
  Dockerfile       # ARM64 コンテナ + OpenTelemetry 自動計装
infra/
  s3files-stack.yaml  # VPC / S3 Files / IAM ロール（CloudFormation）
knowledge/            # S3 にアップロードするサンプルナレッジ
invoke_agent.py       # ストリーミング対応の呼び出しクライアント
deploy.sh             # ワンショットデプロイスクリプト
```

## 前提

- AWS CLI / Docker（buildx + ARM64）/ uv
- us-east-1 リージョン
- boto3 / botocore 1.43.5 以降

## デプロイ

```bash
./deploy.sh
```

以下が自動で実行されます。

1. CloudFormation デプロイ（VPC / S3 Files / IAM ロール）
2. Docker イメージのビルド & ECR push
3. AgentCore Runtime の作成（または更新）→ READY 待ち
4. S3 バケットへナレッジファイルをアップロード
5. 動作確認

初回実行時にハッシュが `.deploy-env` に保存され、2回目以降は同じ環境を更新します。

## 使い方

```bash
uv run python invoke_agent.py "ファイルシステムマウントの種類を教えて"
uv run python invoke_agent.py "/mnt/data にある Python コードを探してツール定義を教えて"
```

## ブログ記事

https://dev.classmethod.jp/articles/bedrock-agentcore-runtime-s3-files-native-mount/
