output "deployment_id" {
  value       = local.deployment_id
  description = "The unique deployment ID."
}

# Load Balancer
output "vsensor_lb_arn" {
  value       = aws_lb.vsensor_lb.arn
  description = "The ARN of the Load Balancer."
}

output "vsensor_lb_arn_suffix" {
  value       = aws_lb.vsensor_lb.arn_suffix
  description = "The ARN suffix of the Load Balancer for use with CloudWatch Metrics."
}

output "vsensor_lb_dns_name" {
  value       = aws_lb.vsensor_lb.dns_name
  description = "The DNS name of the load balancer."
}

# Load Balancer Listener
output "vsensor_lb_listener_arn" {
  value       = { for k, v in aws_lb_listener.vsensor_lb_listener : k => v.arn }
  description = "A list of the ARNs of the LB listeners."
}

# Load Balancer Target Group
output "vsensor_lb_target_group_arn_suffix" {
  value       = { for k, v in aws_lb_target_group.vsensor_tg : k => v.arn_suffix }
  description = "A list of the ARN suffixes for use with CloudWatch Metrics."
}

output "vsensor_lb_target_group_arn" {
  value       = { for k, v in aws_lb_target_group.vsensor_tg : k => v.arn }
  description = "A list of the ARNs of the Target Groups."
}

output "vsensor_lb_target_group_name" {
  value       = { for k, v in aws_lb_target_group.vsensor_tg : k => v.name }
  description = "A list of the names of the Target Groups."
}

# S3 PCAPs
output "pcaps_s3_bucket_name" {
  value       = var.lifecycle_pcaps_s3_bucket == 0 ? null : aws_s3_bucket.vsensor_pcaps_s3[0].id
  description = "The name of the s3 bucket that stores the PCAPs."
}

output "pcaps_s3_bucket_domain_name" {
  value       = var.lifecycle_pcaps_s3_bucket == 0 ? null : aws_s3_bucket.vsensor_pcaps_s3[0].bucket_domain_name
  description = "The s3 bucket's domain name."
}

# ASG Security Group
output "vsensors_autoscaling_security_group_name" {
  value       = aws_security_group.vsensors_asg_sg.name
  description = "The name of the security group for the vSensors."
}

output "vsensors_autoscaling_security_group_arn" {
  value       = aws_security_group.vsensors_asg_sg.arn
  description = "The ARN of the security group for the vSensors."
}

# Traffic mirror
output "traffic_mirror_target_id" {
  value       = aws_ec2_traffic_mirror_target.vsensor_lb_target.id
  description = "The ID of the Traffic Mirror target."
}

output "traffic_mirror_target_arn" {
  value       = aws_ec2_traffic_mirror_target.vsensor_lb_target.arn
  description = "The ARN of the traffic mirror target."
}

output "traffic_mirror_filter_arn" {
  value       = aws_ec2_traffic_mirror_filter.vsensor_filter.arn
  description = "The ARN of the traffic mirror filter."
}

output "traffic_mirror_filter_id" {
  value       = aws_ec2_traffic_mirror_filter.vsensor_filter.id
  description = "The name of the traffic mirror filter."
}

output "launch_template_vsensor_name" {
  value       = aws_launch_template.vsensor.name
  description = "The name of the launch template."
}

output "launch_template_vsensor_arn" {
  value       = aws_launch_template.vsensor.arn
  description = "The ARN of the launch template."
}

output "autoscaling_group_vsensors_asg_name" {
  value       = aws_autoscaling_group.vsensors_asg.name
  description = "The name of the Auto Scaling Group."
}

# new VPC
output "vpc_id" {
  value       = local.vpc_enable ? aws_vpc.main[0].id : null
  description = "The ID of the new VPC."
}

output "private_subnets_id" {
  value       = { for k, v in aws_subnet.private : k => v.id }
  description = "If vpc_enable = true - a list of the new private subnets."
}

output "public_subnets_id" {
  value       = { for k, v in aws_subnet.public : k => v.id }
  description = "If vpc_enable = true - a list of the new public subnets."
}

output "ssh_remote_access_ip" {
  value       = local.bastion_enable ? aws_eip.remote_access_eip[0].public_ip : null
  description = "The public IP for the ssh remote access."
}

output "nat_gw_eip_public_ip" {
  value       = { for k, v in aws_eip.vsensor_nat_gw_eip : k => v.public_ip }
  description = "If vpc_enable = true - a list of the public IP addresses fo the NAT gateways."
}

# Cloudwatch
output "vsensor_cloudwatch_log_group_arn" {
  value       = aws_cloudwatch_log_group.vsensor_log_group.arn
  description = "The CloudWatch group ARN."
}

output "vsensor_cloudwatch_log_group_name" {
  value       = aws_cloudwatch_log_group.vsensor_log_group.name
  description = "The CloudWatch group name."
}

output "kms_key_vsensor_logs_arn" {
  value       = var.kms_key_enable ? aws_kms_key.vsensor_logs[0].arn : null
  description = "The new kms key."
}

# SSM Session Manager
output "session_manager_preferences_name" {
  value       = var.ssm_session_enable ? aws_ssm_document.session_manager_preferences[0].name : null
  description = "The name of the SSM Session Manager document."
}
