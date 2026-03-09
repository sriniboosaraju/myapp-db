#!/bin/bash
set -euo pipefail

# -------------------------------------------------------------------
# User data bootstrap script for ${app_name} (${environment})
# Rendered by Terraform – do not edit manually.
# -------------------------------------------------------------------

# System updates
dnf update -y

# Install useful tools
dnf install -y \
  amazon-cloudwatch-agent \
  aws-cli \
  jq \
  curl \
  unzip

# Set hostname
hostnamectl set-hostname "${app_name}-${environment}"

# Configure CloudWatch agent (basic config)
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "metrics": {
    "namespace": "${app_name}/${environment}",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent"],
        "resources": ["/"],
        "metrics_collection_interval": 60
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/${app_name}/${environment}/system",
            "log_stream_name": "{instance_id}/messages",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

echo "Bootstrap complete for ${app_name} (${environment}) in ${aws_region}"
