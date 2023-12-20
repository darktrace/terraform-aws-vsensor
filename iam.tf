#vSensor IAM role
resource "aws_iam_role" "vsensor_iam" {
  name = "${local.deployment_id}-vsensor-iam"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  tags = local.all_tags
}

data "aws_iam_policy_document" "vsensor_iam" {

  dynamic "statement" {
    for_each = var.lifecycle_pcaps_s3_bucket != 0 ? [1] : []

    content {
      sid       = "ListPCAPBucket"
      effect    = "Allow"
      actions   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:GetLifecycleConfiguration"]
      resources = [local.s3_list_bucket]
    }
  }

  dynamic "statement" {
    for_each = var.lifecycle_pcaps_s3_bucket != 0 ? [1] : []

    content {
      sid       = "AccessPCAPBucket"
      effect    = "Allow"
      actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:PutObjectTagging"]
      resources = [local.s3_access_bucket]
    }
  }

  statement {
    sid     = "GetSSMParameter"
    effect  = "Allow"
    actions = ["ssm:GetParameter"]
    resources = (
      var.os_sensor_hmac_token != "" ?
      [data.aws_ssm_parameter.dt_update_key.arn, data.aws_ssm_parameter.dt_push_token.arn, data.aws_ssm_parameter.dt_os_sensor_hmac_token[0].arn] :
      [data.aws_ssm_parameter.dt_update_key.arn, data.aws_ssm_parameter.dt_push_token.arn]
    )
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutRetentionPolicy"
    ]
    resources = [
      aws_cloudwatch_log_group.vsensor_log_group.arn,
      "${aws_cloudwatch_log_group.vsensor_log_group.arn}:*",
      "${aws_cloudwatch_log_group.vsensor_log_group.arn}:*:*"
    ]
  }

  statement {
    sid       = "CloudWatchMetrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData", "ec2:DescribeVolumes", "ec2:DescribeTags"]
    resources = ["*"]
  }

  statement {
    sid       = "ModifyInstanceAttribute"
    effect    = "Allow"
    actions   = ["ec2:ModifyInstanceAttribute"]
    resources = ["*"]
    condition {
      #restrict the policy to the vSensors only
      test     = "StringEquals"
      variable = "ec2:InstanceProfile"
      values   = [aws_iam_instance_profile.vsensor.arn]
    }
  }

  statement {
    sid     = "CompleteLifecycleAction"
    effect  = "Allow"
    actions = ["autoscaling:CompleteLifecycleAction"]
    resources = [
      #https://docs.aws.amazon.com/autoscaling/ec2/userguide/tutorial-lifecycle-hook-instance-metadata.html
      "arn:aws:autoscaling:*:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${local.deployment_id}-vsensors-asg*"
    ]
  }

  dynamic "statement" {
    for_each = var.ssm_session_enable ? [1] : []

    content {
      #IAM policy with minimal Session Manager permissions
      #https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-create-iam-instance-profile.html
      sid    = "AllowSsmMessages"
      effect = "Allow"
      actions = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
        "ssm:UpdateInstanceInformation"
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = var.ssm_session_enable ? [1] : []

    content {
      #required to encrypt the ssm session; it uses the same key as for the CloudWatch logs
      #https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-create-iam-instance-profile.html
      sid       = "AllowSSMSessionsEncryption"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = [local.kms_key_arn]
    }
  }

  dynamic "statement" {
    for_each = var.ssm_session_enable ? [1] : []

    content {
      #required because of a ssm-session-worker error in /var/log/amazon/ssm/amazon-ssm-agent.log requesting
      #to perform logs:DescribeLogGroups action on resource arn:aws:logs:<region>:<account_id>:log-group::log-stream:
      sid       = "SsmLog"
      effect    = "Allow"
      actions   = ["logs:DescribeLogGroups"]
      resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"]
    }
  }
}


resource "aws_iam_policy" "vsensor_iam" {
  name        = "${local.deployment_id}-vsensor-iam"
  description = "Policy required by vSensors to write pcaps to s3 bucket"

  tags = local.all_tags

  policy = data.aws_iam_policy_document.vsensor_iam.json

}

resource "aws_iam_role_policy_attachment" "vsensor_iam" {
  role       = aws_iam_role.vsensor_iam.name
  policy_arn = aws_iam_policy.vsensor_iam.arn
}
