resource "aws_ec2_traffic_mirror_target" "vsensor_lb_target" {
  description               = "vSensors NLB target"
  network_load_balancer_arn = aws_lb.vsensor_lb.arn
  tags                      = local.all_tags
}

resource "aws_ec2_traffic_mirror_filter" "vsensor_filter" {
  description = "vSensor traffic mirror filter"
  tags        = local.all_tags
}

resource "aws_ec2_traffic_mirror_filter_rule" "rulein" {
  description              = "Traffic mirror filter allow ingress"
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.vsensor_filter.id
  destination_cidr_block   = var.filter_dest_cidr_block
  source_cidr_block        = var.filter_src_cidr_block
  rule_number              = var.traffic_mirror_target_rule_number
  rule_action              = "accept"
  traffic_direction        = "ingress"
}

resource "aws_ec2_traffic_mirror_filter_rule" "ruleout" {
  description              = "Traffic mirror filter allow egress"
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.vsensor_filter.id
  destination_cidr_block   = var.filter_dest_cidr_block
  source_cidr_block        = var.filter_src_cidr_block
  rule_number              = var.traffic_mirror_target_rule_number
  rule_action              = "accept"
  traffic_direction        = "egress"
}
