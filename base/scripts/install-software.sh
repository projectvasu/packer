#!/bin/bash
set -euo pipefail

echo "=== Updating OS packages ==="
sudo dnf update -y

echo "=== Installing Docker ==="
sudo dnf install -y docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

echo "=== Ensuring AWS SSM Agent is enabled ==="
sudo systemctl enable amazon-ssm-agent

echo "=== Installing CloudWatch Agent ==="
sudo dnf install -y amazon-cloudwatch-agent
sudo systemctl enable amazon-cloudwatch-agent

echo "=== Installing default CloudWatch Agent config ==="
# The agent translates this JSON on every start, so {instance_id} etc. resolve on the launched instance
python3 -m json.tool /tmp/amazon-cloudwatch-agent.json > /dev/null
sudo install -m 0644 -o root -g root /tmp/amazon-cloudwatch-agent.json \
  /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
rm -f /tmp/amazon-cloudwatch-agent.json

echo "=== Cleaning up ==="
sudo dnf clean all