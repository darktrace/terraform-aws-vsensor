data "aws_ssm_parameter" "dt_update_key" {
  name            = var.update_key
  with_decryption = false
}

data "aws_ssm_parameter" "dt_push_token" {
  name            = var.push_token
  with_decryption = false
}

data "aws_ssm_parameter" "dt_os_sensor_hmac_token" {
  count = var.os_sensor_hmac_token != "" ? 1 : 0

  name            = var.os_sensor_hmac_token
  with_decryption = false
}

data "aws_region" "current" {}

data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

locals {
  s3_list_bucket   = var.lifecycle_pcaps_s3_bucket == 0 ? null : join("", ["arn:", data.aws_partition.current.partition, ":s3:::", aws_s3_bucket.vsensor_pcaps_s3[0].id])
  s3_access_bucket = var.lifecycle_pcaps_s3_bucket == 0 ? null : join("", [local.s3_list_bucket, "/*"])
}

data "aws_vpc" "vsensors_asg" {
  id = local.vpc_id
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}
