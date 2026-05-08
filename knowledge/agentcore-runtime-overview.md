# Amazon Bedrock AgentCore Runtime 概要

## AgentCore Runtime とは

Amazon Bedrock AgentCore Runtime は、AI エージェントをサーバーレスでデプロイ・実行するためのマネージドサービスです。開発者はエージェントのコードをコンテナイメージとしてパッケージし、AgentCore Runtime にデプロイするだけで、スケーリングやインフラ管理を意識せずにエージェントを運用できます。

## 主な特徴

### サーバーレス実行
- コンテナイメージを ECR に push してランタイムを作成するだけ
- オートスケーリングが組み込まれており、リクエスト数に応じて自動的にスケール
- コールドスタートは初回のみ、以降はウォーム状態が維持される

### セッション管理
- `runtimeSessionId` によるセッション管理が組み込み
- 同一セッション内では状態を保持可能
- セッションタイムアウトは設定可能

### ファイルシステムサポート
AgentCore Runtime は3種類のファイルシステムマウントをサポートしています。

| 種類 | 説明 | スコープ |
|------|------|----------|
| sessionStorage | マネージドな永続ストレージ | セッション単位で隔離 |
| s3FilesAccessPoint | Amazon S3 Files のアクセスポイント | ランタイム全体で共有 |
| efsAccessPoint | Amazon EFS のアクセスポイント | ランタイム全体で共有 |

sessionStorage はセッションごとに個別のボリュームが割り当てられ、ネットワーク設定不要で使えます。一方、s3FilesAccessPoint と efsAccessPoint はランタイム全体で1つのファイルシステムを共有し、VPC 設定が必須です。

### ネットワーク構成
- PUBLIC モード: インターネットアクセス可能（デフォルト）
- VPC モード: プライベートサブネット内で実行、S3 Files / EFS マウントに必要

## API エンドポイント

### コントロールプレーン
- `CreateAgentRuntime`: ランタイムの作成
- `UpdateAgentRuntime`: ランタイムの更新（コンテナイメージの差し替え等）
- `DeleteAgentRuntime`: ランタイムの削除
- `GetAgentRuntime`: ランタイムの状態取得
- `ListAgentRuntimes`: ランタイム一覧

### データプレーン
- `InvokeAgentRuntime`: ランタイムの呼び出し（HTTP、SSE ストリーミング対応）
- WebSocket エンドポイント: 双方向ストリーミング

## コンテナ要件
- アーキテクチャ: ARM64
- ポート: 8080 で HTTP サーバを起動すること
- ヘルスチェック: `GET /ping` に 200 を返すこと
- 呼び出し: `POST /invocations` でリクエストを受け付けること
