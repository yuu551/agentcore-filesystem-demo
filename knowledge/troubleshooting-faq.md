# AgentCore Runtime トラブルシューティング FAQ

## Q1. ランタイムのステータスが FAILED になる

### 原因1: コンテナイメージが ARM64 でない
AgentCore Runtime は ARM64 アーキテクチャで動作します。`docker buildx build --platform linux/arm64` でビルドしてください。

### 原因2: コンテナが root で起動している
Claude Agent SDK を使用する場合、Claude Code CLI は root ユーザーでの起動を拒否します。Dockerfile で非 root ユーザー（uid 1000 推奨）に切り替えてください。

### 原因3: ヘルスチェックに失敗
コンテナは 8080 ポートで `GET /ping` に 200 を返す必要があります。起動に時間がかかる場合はコールドスタートタイムアウトに注意してください。

## Q2. Bedrock の呼び出しが 403 エラーになる

RuntimeRole に `bedrock:InvokeModel` と `bedrock:InvokeModelWithResponseStream` の権限が必要です。リージョナル推論プロファイルを使う場合は inference-profile の ARN も Resource に含めてください。

```yaml
- Effect: Allow
  Action:
    - bedrock:InvokeModel
    - bedrock:InvokeModelWithResponseStream
  Resource:
    - !Sub "arn:aws:bedrock:*::foundation-model/anthropic.claude-*"
    - !Sub "arn:aws:bedrock:*:${AWS::AccountId}:inference-profile/*anthropic.claude-*"
```

## Q3. S3 Files マウントしたファイルが見えない

1. S3 にアップロードしてから NFS 同期まで数十秒〜1分かかります
2. MountTarget が AgentCore Runtime と同じサブネットにあるか確認
3. AccessPoint の `RootDirectory` がバケット上の正しいプレフィックスを指しているか確認
4. セキュリティグループで NFS (TCP 2049) の自己参照ルールがあるか確認

## Q4. Claude Agent SDK がハングする

執筆時点（2026年5月）では、Bedrock 経由の一部モデル・リージョンでハングする報告があります。

- まず Haiku 4.5（リージョナル推論プロファイル）で疎通を確認
- Sonnet や別リージョンは動作が不安定な場合がある
- GitHub Issue: https://github.com/anthropics/claude-agent-sdk-python/issues/224

## Q5. invoke_agent_runtime のレスポンスが遅い

- 初回呼び出しはコールドスタートがあるため 30 秒〜1 分かかることがある
- 2回目以降はウォーム状態で 5〜15 秒程度
- `max_turns` を小さくするとターン数の上限で打ち切れる
- Haiku は Sonnet より応答が速い（コストも低い）

## Q6. BedrockAgentCoreApp のストリーミングが効かない

`@app.entrypoint` を `async def` にして `yield` でイベントを返すと、SSE（text/event-stream）でストリーミングされます。

```python
@app.entrypoint
async def invoke(payload, context=None):
    async for msg in query(prompt=payload["prompt"], options=options):
        yield json.dumps({"type": "text", "text": "..."})
```

クライアント側では `invoke_agent_runtime` のレスポンスを `iter_lines()` で逐次読み取ります。
