import json
import os

from bedrock_agentcore.runtime import BedrockAgentCoreApp
from claude_agent_sdk import (
    AssistantMessage,
    ClaudeAgentOptions,
    ResultMessage,
    TextBlock,
    ToolUseBlock,
    query,
)

MOUNT = os.environ.get("MOUNT_PATH", "/mnt/data")

app = BedrockAgentCoreApp()


@app.entrypoint
async def invoke(payload, context=None):
    prompt = payload.get("prompt", "")
    options = ClaudeAgentOptions(
        cwd=MOUNT,
        allowed_tools=["Read", "Write", "Bash", "Grep", "Glob", "WebFetch", "WebSearch"],
        permission_mode="acceptEdits",
        max_turns=8,
        env={
            "CLAUDE_CODE_USE_BEDROCK": "1",
            "AWS_REGION": "us-east-1",
            "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
            "CLAUDE_CODE_ENHANCED_TELEMETRY_BETA": "1",
        },
        model="us.anthropic.claude-haiku-4-5-20251001-v1:0",
    )

    async for msg in query(prompt=prompt, options=options):
        if isinstance(msg, AssistantMessage):
            for block in msg.content:
                if isinstance(block, TextBlock):
                    yield json.dumps({"type": "text", "text": block.text}, ensure_ascii=False) + "\n"
                elif isinstance(block, ToolUseBlock):
                    yield json.dumps({"type": "tool_use", "name": block.name, "input": block.input}, ensure_ascii=False) + "\n"
        elif isinstance(msg, ResultMessage):
            yield json.dumps({
                "type": "result",
                "duration_ms": msg.duration_ms,
                "num_turns": msg.num_turns,
                "stop_reason": msg.stop_reason,
                "total_cost_usd": msg.total_cost_usd,
            }, ensure_ascii=False) + "\n"


if __name__ == "__main__":
    app.run()
