resource "aws_iam_instance_profile" "vsensor" {
  name = "${local.deployment_id}-vsensor"
  role = aws_iam_role.vsensor_iam.name
  tags = local.all_tags
}

#
locals {
  #will detect any change in the not rendered user data script; the instance_version itself is passed to the vsensor-init.sh and rendering it will cause cycling
  vsensor_init = file("${path.module}/source/vsensor-init.sh")

  #will detect a change in the name or the value of any of the update_key, the dt_push_token, or the os_sensor_hmac_token
  parameter_version = (
    var.os_sensor_hmac_token != "" ?
    "${data.aws_ssm_parameter.dt_update_key.version}${var.update_key}${data.aws_ssm_parameter.dt_push_token.version}${var.push_token}${var.os_sensor_hmac_token}${data.aws_ssm_parameter.dt_os_sensor_hmac_token[0].version}" :
    "${data.aws_ssm_parameter.dt_update_key.version}${var.update_key}${data.aws_ssm_parameter.dt_push_token.version}${var.push_token}"
  )

  #this is to enforce replacing the template and the asg if a change in any of the these takes place
  instance_version = sha1("${local.vsensor_init}${local.parameter_version}${var.instance_type}")
}
#

resource "aws_launch_template" "vsensor" {
  name          = "${local.deployment_id}-vsensor-${local.instance_version}"
  description   = "vSensor Launch Template"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.vsensor.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.vsensors_asg_sg.id]
  }

  key_name = var.ssh_keyname

  user_data = base64encode(templatefile("${path.module}/source/vsensor-init.sh", {
    vsensor_region       = data.aws_region.current.name
    update_key           = var.update_key
    push_token           = var.push_token
    instance_host_name   = var.instance_host_name
    instance_port        = var.instance_port
    vsensor_proxy        = var.proxy
    os_sensor_hmac_token = var.os_sensor_hmac_token
    s3_pcaps_bucket      = var.lifecycle_pcaps_s3_bucket == 0 ? "" : aws_s3_bucket.vsensor_pcaps_s3[0].id
    cw_log_group         = aws_cloudwatch_log_group.vsensor_log_group.name
    cw_namespace         = local.cw_namespace
    cw_metrics_enable    = var.cw_metrics_enable
    asg_name             = "${local.deployment_id}-vsensors-asg-${local.instance_version}"
    asg_hook_name        = "${local.deployment_id}-vsensors-lifecyclehook"
    parameter_version    = local.parameter_version
  }))

  update_default_version = true
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_size           = 20
      volume_type           = "gp2"

    }
  }
  monitoring {
    enabled = true
  }

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.deployment_id}-vsensor"
    }
  }

  tags = local.all_tags
}

resource "aws_autoscaling_group" "vsensors_asg" {
  name_prefix      = "${local.deployment_id}-vsensors-asg-${local.instance_version}-"
  desired_capacity = var.desired_capacity
  max_size         = var.max_size
  min_size         = var.min_size

  default_instance_warmup = 600

  vpc_zone_identifier = local.vpc_private_subnets

  initial_lifecycle_hook {
    name           = "${local.deployment_id}-vsensors-lifecyclehook"
    default_result = "ABANDON"
    #it takes more than 7 min to complete the vSensor installation from the instance launch time hence 15 minutes timeout should be OK
    heartbeat_timeout    = 900
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  }

  target_group_arns = values(aws_lb_target_group.vsensor_tg)[*].arn

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id = aws_launch_template.vsensor.id
  }

  dynamic "tag" {
    for_each = local.all_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  #prevent race conditions where the vSensor spins up and starts the installation process before the NAT Gateway is ready (new VPC deployments only)
  tag {
    key                 = "nat_readiness"
    value               = local.asg_tag
    propagate_at_launch = false
  }

  #this tag is used in the CompleteLifecycleAction policy; the key is a random string (local.deployment_id) to avoid to be overwritten by customer's input tag
  tag {
    key                 = local.deployment_id
    value               = "LifecycleAction"
    propagate_at_launch = false
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }

  depends_on = [
    aws_iam_role_policy_attachment.vsensor_iam
  ]

  wait_for_capacity_timeout = "20m"
}


resource "aws_autoscaling_policy" "vsensors_asg_policy" {
  name                   = "${local.deployment_id}-vsensors-asg-policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.vsensors_asg.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 75.0
  }

  lifecycle {
    create_before_destroy = true
  }

}
