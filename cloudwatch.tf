resource "aws_cloudwatch_log_group" "vsensor_log_group" {
  name = local.cw_log_group_name

  kms_key_id        = local.kms_key_arn
  retention_in_days = var.cloudwatch_logs_days

  tags = merge(
    local.all_tags,
    {
      Name = "${local.deployment_id}-vsensor-log-group"
    }
  )
}
