# Amazon S3 Files ガイド

## S3 Files とは

Amazon S3 Files は、S3 バケットを NFS 互換のファイルシステムとしてマウントするサービスです。S3 のスケーラビリティと NFS の POSIX 互換ファイルアクセスを組み合わせることで、既存のアプリケーションを変更せずに S3 上のデータにアクセスできます。

## アーキテクチャ

```
[ アプリケーション ]
       │ NFS (port 2049)
       ▼
[ S3 Files MountTarget ]  ← VPC 内のプライベートサブネットに配置
       │
       ▼
[ S3 Files FileSystem ]
       │ 双方向同期
       ▼
[ S3 バケット ]
```

## 主要コンポーネント

### FileSystem
- S3 バケットと 1:1 で紐づくファイルシステム
- バケット内のオブジェクトを NFS ファイルとして公開
- S3 側の変更は数十秒〜1分程度で NFS 側に反映

### MountTarget
- VPC 内のサブネットに配置する NFS エンドポイント
- AZ ごとに1つ必要
- セキュリティグループで NFS (port 2049) のアクセスを制御

### AccessPoint
- POSIX ユーザー（uid/gid）の指定
- ルートディレクトリの指定（バケット内の特定プレフィックスをルートとして公開）
- アクセス権限の設定

## CloudFormation でのデプロイ

```yaml
# FileSystem
FileSystem:
  Type: AWS::S3Files::FileSystem
  Properties:
    Bucket: !GetAtt Bucket.Arn
    RoleArn: !GetAtt S3FilesServiceRole.Arn
    AcceptBucketWarning: true

# MountTarget（AZ ごとに1つ）
MountTargetA:
  Type: AWS::S3Files::MountTarget
  Properties:
    FileSystemId: !Ref FileSystem
    SubnetId: !Ref PrivateSubnetA
    SecurityGroups: [!Ref NfsSg]

# AccessPoint
AccessPoint:
  Type: AWS::S3Files::AccessPoint
  Properties:
    FileSystemId: !Ref FileSystem
    PosixUser:
      Uid: 1000
      Gid: 1000
    RootDirectory:
      Path: /data
      CreationPermissions:
        OwnerUid: 1000
        OwnerGid: 1000
        Permissions: "0755"
```

## AgentCore Runtime との統合

AgentCore Runtime の `filesystemConfigurations` で S3 Files のアクセスポイントを指定すると、コンテナ内の指定パスに自動マウントされます。

```python
filesystemConfigurations=[{
    "s3FilesAccessPoint": {
        "accessPointArn": "arn:aws:s3files:us-east-1:123456789012:file-system/fs-xxx/access-point/fsap-xxx",
        "mountPath": "/mnt/data",
    }
}]
```

マウントパスは `/mnt/<任意の名前>` 形式で、`/mnt/` 直下1階層のみ指定可能です。

## 注意事項

- VPC 内のプライベートサブネットからのみアクセス可能
- NAT Gateway が必要（Bedrock API 等の外部通信用）
- S3 Gateway VPC Endpoint を設定すると ECR pull が高速化
- ファイルの同期は非同期（数十秒〜1分のラグ）
- 大量の小さなファイルの書き込みはパフォーマンスに影響する可能性あり
