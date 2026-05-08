"""Strands Agents フレームワークを使ったシンプルなエージェントのサンプル。

AgentCore Runtime にデプロイ可能な天気+計算エージェント。
Strands は AWS が推奨するエージェントフレームワーク。
"""
import os
from strands import Agent, tool
from strands.models import BedrockModel
from bedrock_agentcore.runtime import BedrockAgentCoreApp

app = BedrockAgentCoreApp()


@tool
def get_weather(city: str) -> str:
    """指定された都市の天気を取得する"""
    weather_data = {
        "東京": "晴れ 28°C",
        "大阪": "曇り 25°C",
        "札幌": "雨 18°C",
        "福岡": "晴れ 30°C",
    }
    return weather_data.get(city, f"{city}の天気データは見つかりませんでした")


@tool
def calculate(expression: str) -> str:
    """数式を計算する"""
    try:
        result = eval(expression)  # noqa: S307
        return str(result)
    except Exception as e:
        return f"計算エラー: {e}"


model = BedrockModel(
    model_id=os.getenv("BEDROCK_MODEL_ID", "us.anthropic.claude-haiku-4-5-20251001-v1:0"),
)

agent = Agent(
    model=model,
    tools=[get_weather, calculate],
    system_prompt="日本語で簡潔に回答してください。天気の問い合わせと簡単な計算ができます。",
)


@app.entrypoint
def invoke(payload):
    user_input = payload.get("prompt", "")
    response = agent(user_input)
    return response.message["content"][0]["text"]


if __name__ == "__main__":
    app.run()
