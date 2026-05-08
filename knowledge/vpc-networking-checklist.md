# AgentCore Runtime VPC ネットワーク構成チェックリスト

## 構成図

```
[ Internet ]
      │
[ Internet Gateway ]
      │
[ Public Subnet ]
      │ NAT Gateway
      ▼
[ Private Subnet ]
   ├── AgentCore Runtime ENI
   ├── S3 Files MountTarget (NFS 2049)
   └── S3 Gateway VPC Endpoint
```

## チェックリスト

### VPC
- [ ] DNS サポートが有効（EnableDnsSupport: true）
- [ ] DNS ホスト名が有効（EnableDnsHostnames: true）

### サブネット
- [ ] プライベートサブネットが最低2つ（異なる AZ）
- [ ] パブリックサブネットに NAT Gateway を配置
- [ ] プライベートサブネットのデフォルトルートが NAT Gateway を指す

### セキュリティグループ
- [ ] NFS (TCP 2049) の自己参照インバウンドルール
- [ ] アウトバウンドは全許可（0.0.0.0/0）

### VPC エンドポイント
- [ ] S3 Gateway VPC Endpoint を作成（ECR pull 高速化）
- [ ] プライベートルートテーブルに関連付け

### NAT Gateway
- [ ] Elastic IP を割り当て
- [ ] パブリックサブネットに配置
- [ ] Internet Gateway へのルートがパブリックルートテーブルにある

## よくあるトラブル

### ランタイムが FAILED になる
- セキュリティグループの NFS ルールが不足
- サブネットが NAT Gateway にルーティングされていない
- ECR からのイメージ pull に失敗（S3 Gateway Endpoint を確認）

### Bedrock 呼び出しが 403
- RuntimeRole に bedrock:InvokeModel 権限がない
- リージョナル推論プロファイルの ARN が Resource に含まれていない

### S3 Files のファイルが見えない
- MountTarget が対象サブネットに作成されていない
- AccessPoint の RootDirectory が正しいか確認
- S3 バケットへのアップロードから同期まで1分程度待つ
