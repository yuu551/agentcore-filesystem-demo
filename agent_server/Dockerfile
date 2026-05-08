FROM --platform=linux/arm64 public.ecr.aws/docker/library/python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        nodejs \
        npm \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
        'claude-agent-sdk>=0.1.76' \
        'bedrock-agentcore>=1.9.0'

# S3 Files の access point posixUser に合わせて uid 1000 で動かす
RUN groupadd -g 1000 agent && useradd -m -u 1000 -g agent agent
USER 1000:1000
WORKDIR /home/agent
ENV HOME=/home/agent

COPY --chown=agent:agent main.py /home/agent/main.py

EXPOSE 8080
CMD ["python", "/home/agent/main.py"]
