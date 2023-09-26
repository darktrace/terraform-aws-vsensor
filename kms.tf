# the policy is based on https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html
# kics-scan ignore-block
resource "aws_kms_key" "vsensor_logs" {
  count = var.kms_key_enable ? 1 : 0

  description             = "KMS key for ${local.deployment_id}"
  deletion_window_in_days = 30
  policy                  = <<EOF
{
    "Version" : "2012-10-17",
    "Id" : "key-default-1",
    "Statement" : [
        {
            "Sid" : "Enable IAM User Permissions for this account",
            "Effect" : "Allow",
            "Principal" : {
                "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
            },
            "Action" : "kms:*",
            "Resource" : "*"
        },
        {
            "Sid": "Allow encrypted logs",
            "Effect": "Allow",
            "Principal": { "Service": "logs.${data.aws_region.current.name}.amazonaws.com" },
            "Action": [ 
                "kms:Encrypt*",
                "kms:Decrypt*",
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:Describe*"
            ],
            "Resource": "*",
            "Condition": {
                "ArnEquals": {
                    "kms:EncryptionContext:aws:logs:arn": "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.cw_log_group_name}"
                }
            }
        }
  ]
}
EOF

  enable_key_rotation = var.kms_key_rotation

  tags = merge(
    local.all_tags,
    {
      Name = "${local.deployment_id}-kms-log-group"
    }
  )
}

resource "aws_kms_alias" "vsensor_logs" {
  count = var.kms_key_enable ? 1 : 0

  name          = "alias/vsensor-${local.deployment_id}"
  target_key_id = aws_kms_key.vsensor_logs[0].key_id
}
