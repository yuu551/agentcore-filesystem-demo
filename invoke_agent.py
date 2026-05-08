import boto3
import json
import sys
import time
import uuid

REGION = "us-east-1"
RUNTIME_ARN = "arn:aws:bedrock-agentcore:us-east-1:034362035978:runtime/fsverify_6dc00b_agent-hwR6MEF7S6"

CHAR_DELAY = 0.015


def typewrite(text: str) -> None:
    for ch in text:
        sys.stdout.write(ch)
        sys.stdout.flush()
        time.sleep(CHAR_DELAY)


def invoke(prompt: str) -> None:
    client = boto3.client("bedrock-agentcore", region_name=REGION)
    session_id = ("cas-" + uuid.uuid4().hex + uuid.uuid4().hex)[:60]

    print(f"\033[90msession: {session_id}\033[0m")
    print(f"\033[36m> {prompt}\033[0m\n")
    t0 = time.time()

    resp = client.invoke_agent_runtime(
        agentRuntimeArn=RUNTIME_ARN,
        runtimeSessionId=session_id,
        payload=json.dumps({"prompt": prompt}).encode(),
    )

    stream = resp["response"]
    tool_idx = 0

    for line in stream.iter_lines():
        line = line.strip()
        if not line:
            continue

        text = line.decode("utf-8")
        if text.startswith("data: "):
            text = text[6:]

        try:
            text = json.loads(text)
        except (json.JSONDecodeError, TypeError):
            pass

        if not isinstance(text, str) or not text.strip():
            continue

        try:
            event = json.loads(text)
        except json.JSONDecodeError:
            continue

        t = event.get("type")
        if t == "tool_use":
            tool_idx += 1
            name = event["name"]
            inp = event.get("input", {})
            summary = inp.get("pattern") or inp.get("file_path") or inp.get("command") or inp.get("prompt", "")
            if len(summary) > 60:
                summary = summary[:57] + "..."
            typewrite(f"  \033[33m[{tool_idx}] {name}({summary})\033[0m\n")
        elif t == "text":
            typewrite(event["text"])
            print()
        elif t == "result":
            elapsed = time.time() - t0
            print(f"\n\033[90m--- {event.get('num_turns', '?')} turns | {elapsed:.1f}s | ${event.get('total_cost_usd', 0):.4f} ---\033[0m")


if __name__ == "__main__":
    prompt = sys.argv[1] if len(sys.argv) > 1 else (
        "/mnt/data 配下のファイル一覧を教えてください。"
    )
    invoke(prompt)
