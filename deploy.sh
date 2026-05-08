#!/usr/bin/env bash
set -euo pipefail

# ========== 設定 ==========
REGION="us-east-1"
ENV_FILE=".deploy-env"

if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
  echo "既存環境を使用: HASH=$HASH"
else
  HASH=$(echo -n "$(whoami)-$(date +%s)" | shasum | cut -c1-6)
  echo "HASH=$HASH" > "$ENV_FILE"
  echo "新規環境を作成: HASH=$HASH"
fi

STACK_NAME="fsverify-${HASH}"
SUFFIX="fsverify-${HASH}"
REPO="fsverify-${HASH}-img"
RUNTIME_NAME="fsverify_${HASH}_agent"

# ========== 1. CFn デプロイ ==========
echo "=== 1/5 CFn デプロイ ==="
aws cloudformation deploy \
  --template-file infra/s3files-stack.yaml \
  --stack-name "$STACK_NAME" \
  --parameter-overrides "Suffix=$SUFFIX" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION" \
  --no-fail-on-empty-changeset

# CFn Outputs を取得
outputs=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs" \
  --output json)

get_output() { echo "$outputs" | uv run python3 -c "import sys,json; print(next(o['OutputValue'] for o in json.load(sys.stdin) if o['OutputKey']=='$1'))"; }

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
SUBNET_IDS=$(get_output SubnetIds)
SG_ID=$(get_output SecurityGroupId)
BUCKET=$(get_output BucketName)
AP_ARN=$(get_output AccessPointArn)
ROLE_ARN=$(get_output RuntimeRoleArn)

echo "  bucket:  $BUCKET"
echo "  ap_arn:  $AP_ARN"
echo "  role:    $ROLE_ARN"

# ========== 2. ECR push ==========
echo ""
echo "=== 2/5 ECR push ==="
TAG=$(date +%Y%m%d-%H%M%S)
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO}"
URI="${ECR_BASE}:${TAG}"

aws ecr describe-repositories --repository-names "$REPO" --region "$REGION" >/dev/null 2>&1 \
  || aws ecr create-repository --repository-name "$REPO" --region "$REGION" >/dev/null

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

docker buildx build --platform linux/arm64 -t "$URI" -t "${ECR_BASE}:latest" --push agent_server/

echo "  image:   $URI"

# ========== 3. AgentCore Runtime 作成 ==========
echo ""
echo "=== 3/5 AgentCore Runtime 作成 ==="

SUBNET_JSON=$(uv run python3 -c "import json; print(json.dumps('$SUBNET_IDS'.split(',')))")

uv run python3 - "$REGION" "$RUNTIME_NAME" "$URI" "$ROLE_ARN" "$SUBNET_JSON" "$SG_ID" "$AP_ARN" <<'PYEOF'
import boto3, json, sys, time, pathlib, re

REGION, RUNTIME_NAME, URI, ROLE_ARN, SUBNET_JSON, SG_ID, AP_ARN = sys.argv[1:8]
subnets = json.loads(SUBNET_JSON)

c = boto3.client("bedrock-agentcore-control", region_name=REGION)

from botocore.exceptions import ClientError

def find_runtime(client, name):
    paginator = client.get_paginator("list_agent_runtimes") if hasattr(client, "get_paginator") else None
    if paginator:
        for page in paginator.paginate():
            for r in page.get("agentRuntimes", []):
                if r["agentRuntimeName"] == name:
                    return r["agentRuntimeId"]
    else:
        for r in client.list_agent_runtimes().get("agentRuntimes", []):
            if r["agentRuntimeName"] == name:
                return r["agentRuntimeId"]
    return None

rid = find_runtime(c, RUNTIME_NAME)

runtime_kwargs = dict(
    agentRuntimeArtifact={"containerConfiguration": {"containerUri": URI}},
    roleArn=ROLE_ARN,
    networkConfiguration={
        "networkMode": "VPC",
        "networkModeConfig": {
            "subnets": subnets,
            "securityGroups": [SG_ID],
        },
    },
    filesystemConfigurations=[{
        "s3FilesAccessPoint": {
            "accessPointArn": AP_ARN,
            "mountPath": "/mnt/data",
        }
    }],
)

if rid:
    print(f"  既存ランタイムを更新: {rid}")
    c.update_agent_runtime(agentRuntimeId=rid, **runtime_kwargs)
else:
    try:
        print("  新規ランタイムを作成")
        r = c.create_agent_runtime(agentRuntimeName=RUNTIME_NAME, **runtime_kwargs)
        rid = r["agentRuntimeId"]
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConflictException":
            print("  名前衝突 → 既存ランタイムを検索して更新")
            rid = find_runtime(c, RUNTIME_NAME)
            if not rid:
                raise
            c.update_agent_runtime(agentRuntimeId=rid, **runtime_kwargs)
        else:
            raise

for i in range(60):
    d = c.get_agent_runtime(agentRuntimeId=rid)
    status = d["status"]
    if status == "READY":
        print(f"  status: {status}")
        arn = d["agentRuntimeArn"]
        print(f"  arn:    {arn}")
        break
    elif status == "FAILED":
        print(f"  FAILED: {d.get('statusReasons', '')}")
        sys.exit(1)
    print(f"  waiting... ({status})")
    time.sleep(10)
else:
    print("  timeout")
    sys.exit(1)

p = pathlib.Path("invoke_agent.py")
if p.exists():
    text = re.sub(r'RUNTIME_ARN = ".*"', f'RUNTIME_ARN = "{arn}"', p.read_text())
    p.write_text(text)
    print("  invoke_agent.py の RUNTIME_ARN を更新しました")
PYEOF

# ========== 4. S3 ナレッジアップロード ==========
echo ""
echo "=== 4/5 S3 ナレッジアップロード ==="

aws s3 sync knowledge/ "s3://${BUCKET}/agent/" --region "$REGION" --delete

echo "  同期待ち (60s)..."
sleep 60

# ========== 5. 動作確認 ==========
echo ""
echo "=== 5/5 動作確認 ==="
uv run python invoke_agent.py "/mnt/data 配下のファイル一覧を教えてください。"

echo ""
echo "=== デプロイ完了 ==="
