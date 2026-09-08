#!/usr/bin/env bash
set -euxo pipefail

# wait for cloud-init to finish
sudo cloud-init status --wait || true

# wait for the yum lock to clear (max 5 min)
for i in $(seq 1 60); do
  sudo fuser /var/run/yum.pid >/dev/null 2>&1 || break
  echo "yum locked, retry $i/60"
  sleep 5
done

sudo yum -y update
sudo yum install -y git jq unzip docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

#--- 1. patch the base OS -------------------------------------------
dnf -y update

#--- 2. baseline tooling --------------------------------------------
dnf install -y git jq unzip

#--- 3. AWS SSM Agent ------------------------------------------------
# Preinstalled on AL2023 — just guarantee it starts at boot.
systemctl enable amazon-ssm-agent

#--- 4. CloudWatch Agent ---------------------------------------------
dnf install -y amazon-cloudwatch-agent

# Bake a baseline config. Quoted heredoc so ${aws:InstanceId}
# reaches the agent instead of being eaten by the shell.
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'EOF'
{
  "agent": { "metrics_collection_interval": 60 },
  "metrics": {
    "append_dimensions": { "InstanceId": "${aws:InstanceId}" },
    "metrics_collected": {
      "mem":  { "measurement": ["mem_used_percent"] },
      "disk": { "measurement": ["used_percent"], "resources": ["/"] }
    }
  },
  "logs": {
    "logs_collected": {
      "files": { "collect_list": [
        { "file_path": "/var/log/messages",
          "log_group_name": "/ec2/golden-ami/messages",
          "log_stream_name": "{instance_id}" }
      ]}
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
systemctl enable amazon-cloudwatch-agent

#--- 5. Docker --------------------------------------------------------
dnf install -y docker
systemctl enable docker          # enable, NOT start — see note
usermod -aG docker ec2-user

#--- 6. clean the image before the snapshot ---------------------------
dnf clean all
rm -rf /var/cache/dnf
rm -f  /etc/ssh/ssh_host_*       # cloud-init regenerates on first boot
rm -f  /home/ec2-user/.bash_history /root/.bash_history
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;

echo "golden image provisioning complete"
