#!/bin/bash -xe

function exittrap() {
    exitcode="$?"
    set +e
    if [ "$exitcode" -gt 0 ]; then
        echo "Failed to successfully configure vSensor, more details in /var/log/user-data.log"
        aws autoscaling complete-lifecycle-action --lifecycle-action-result ABANDON  --instance-id "$INSTANCE_ID" --lifecycle-hook-name ${asg_hook_name} --auto-scaling-group-name ${asg_name}  --region ${vsensor_region}
    fi
    systemctl enable unattended-upgrades
    exit "$exitcode"
}

exec > >(tee -a /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

trap exittrap EXIT

date

apt-get update

apt-get install -y awscli

###AmazonCloudWatch
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb

dpkg -i -E ./amazon-cloudwatch-agent.deb

cat >CW_AGENT.conf <<'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "${cw_log_group}",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/sabreserver/lite/sabreserverlite.log",
            "log_group_name": "${cw_log_group}",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/darktrace-apt-dist-upgrade.log",
            "log_group_name": "${cw_log_group}",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/dpkg.log",
            "log_group_name": "${cw_log_group}",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/darktrace-bro-keepalive.log",
            "log_group_name": "${cw_log_group}",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/apt/term.log",
            "log_group_name": "${cw_log_group}",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/apt/history.log",
            "log_group_name": "${cw_log_group}",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/darktrace-sabre-mole/manager.log",
            "log_group_name": "${cw_log_group}",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "${cw_log_group}",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "${cw_log_group}",
            "log_stream_name": "{instance_id}-userdata"
          }
        ]
      }
    }
EOF

if [[ ${cw_metrics_enable} == false ]]; then
  cat >>CW_AGENT.conf <<'EOF'
  }
}
EOF
else
  cat >>CW_AGENT.conf <<'EOF'
  },
  "metrics": {
    "namespace": "${cw_namespace}",
    "append_dimensions": {
      "AutoScalingGroupName": "$${aws:AutoScalingGroupName}",
      "ImageId": "$${aws:ImageId}",
      "InstanceId": "$${aws:InstanceId}",
      "InstanceType": "$${aws:InstanceType}"
    },
    "aggregation_dimensions": [["AutoScalingGroupName"], ["InstanceId", "InstanceType"]],
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_active",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ],
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          "used_percent",
          "inodes_free"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "diskio": {
        "measurement": [
          "io_time"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "net": {
        "measurement": [
          "net_bytes_recv",
          "net_bytes_sent",
          "net_drop_in",
          "net_drop_out",
          "net_err_in",
          "net_err_out",
          "net_packets_sent",
          "net_packets_recv"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "statsd": {
        "metrics_aggregation_interval": 60,
        "metrics_collection_interval": 10,
        "service_address": ":8125"
      },
      "swap": {
        "measurement": [
          "swap_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF
fi

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:./CW_AGENT.conf -s

systemctl start amazon-cloudwatch-agent


###get instance ID and attempt to disable source-dest checking metadata
echo "Getting instance ID and attempt to disable source-dest checking metadata."
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 120" -s`
INSTANCE_ID=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id -s`
aws ec2 modify-instance-attribute --no-source-dest-check --instance-id $INSTANCE_ID --region ${vsensor_region} && echo "Succeeded to set --no-source-dest-check." || echo "Failed to set --no-source-dest-check. Continuing anyway." # This is not considered a fatal condition.


###vSensor installation

update_key=$(aws ssm get-parameter --name ${update_key} --with-decryption --query "Parameter.Value" --output text --region ${vsensor_region})


bash <(wget https://packages.darktrace.com/install -O -) --updateKey "$update_key"


push_token=$(aws ssm get-parameter --name ${push_token} --with-decryption --query "Parameter.Value" --output text --region ${vsensor_region})
set_pushtoken.sh "$push_token" ${instance_host_name}:${instance_port} ${vsensor_proxy}

set_ephemeral.sh 1

if [ -n "${s3_pcaps_bucket}" ]; then
  set_pcap_s3_bucket.sh ${s3_pcaps_bucket}
else
  set_pcap_size.sh 0
fi

if [ -n "${os_sensor_hmac_token}" ]; then
  os_sensor_hmac_token=$(aws ssm get-parameter --name ${os_sensor_hmac_token} --with-decryption --query "Parameter.Value" --output text --region ${vsensor_region})
  set_ossensor_hmac.sh "$os_sensor_hmac_token"
fi

echo "Successful configuration of vSensor. Now telling the ASG the AWS vSensor is ready (without waiting for upgrades)."
aws autoscaling complete-lifecycle-action --lifecycle-action-result CONTINUE --instance-id "$INSTANCE_ID" --lifecycle-hook-name ${asg_hook_name} --auto-scaling-group-name ${asg_name}  --region ${vsensor_region}

#start upgrades in the background
/usr/sbin/cron-apt-dist-upgrade.sh || true

#do NOT delete the below line (although it is commented out)
#${parameter_version}
