# Claude Agent SDK リファレンス

## 概要

Claude Agent SDK（`claude-agent-sdk`）は、Claude Code の機能をプログラムから利用するための Python / TypeScript SDK です。内部で Claude Code CLI を起動し、ファイル操作・コード実行・検索などのツールを自律的に使いながらタスクを遂行するエージェントを構築できます。

## インストール

```bash
pip install claude-agent-sdk
```

Node.js が必要です（Claude Code CLI が内部で使用するため）。

## 基本的な使い方

```python
from claude_agent_sdk import query, ClaudeAgentOptions, ResultMessage

async def run():
    options = ClaudeAgentOptions(
        allowed_tools=["Read", "Bash", "Grep", "Glob"],
        permission_mode="acceptEdits",
        model="us.anthropic.claude-haiku-4-5-20251001-v1:0",
        max_turns=8,
    )
    async for msg in query(prompt="ファイル一覧を教えて", options=options):
        if isinstance(msg, ResultMessage):
            print(msg.result)
```

## ClaudeAgentOptions

| パラメータ | 型 | 説明 |
|-----------|-----|------|
| cwd | str | エージェントの作業ディレクトリ |
| allowed_tools | list[str] | 許可するツールのリスト |
| disallowed_tools | list[str] | 禁止するツールのリスト |
| permission_mode | str | 権限モード（後述） |
| model | str | 使用するモデル ID |
| max_turns | int | 最大ターン数 |
| env | dict | 環境変数 |

## Permission Mode

| モード | 説明 |
|--------|------|
| default | ツール実行時にユーザー確認を求める |
| acceptEdits | ファイル編集を自動承認 |
| dontAsk | allowed_tools のみ自動承認、それ以外は拒否 |
| bypassPermissions | 全ツールを自動承認（隔離環境向け） |

ヘッドレス環境（AgentCore Runtime 等）では `acceptEdits` または `dontAsk` を推奨。

## メッセージタイプ

`query()` は async generator で、以下のメッセージを yield します。

### AssistantMessage
エージェントの応答。`content` に以下のブロックが含まれます。

- `TextBlock`: テキスト応答
- `ToolUseBlock`: ツール呼び出し（name, input）
- `ThinkingBlock`: 思考プロセス（拡張思考モデルの場合）

### ResultMessage
エージェントの実行完了。以下のフィールドを持ちます。

- `result`: 最終的なテキスト結果
- `duration_ms`: 実行時間（ミリ秒）
- `num_turns`: ターン数
- `stop_reason`: 停止理由（end_turn, max_turns 等）
- `total_cost_usd`: 推定コスト（USD）

## 組み込みツール

| ツール | 説明 |
|--------|------|
| Read | ファイルの読み取り |
| Write | ファイルの書き込み |
| Edit | ファイルの部分編集 |
| Bash | シェルコマンドの実行 |
| Grep | 正規表現によるファイル検索 |
| Glob | パターンによるファイル名検索 |

## Bedrock 経由で使用する場合

環境変数で設定します。

```python
env={
    "CLAUDE_CODE_USE_BEDROCK": "1",
    "AWS_REGION": "us-east-1",
}
model="us.anthropic.claude-haiku-4-5-20251001-v1:0"
```

AWS の認証情報は IAM ロール（SigV4）から自動的に取得されるため、API キーは不要です。
