resource "aws_lb" "vsensor_lb" {
  #name_prefix is restricted to 6 characters
  name = "${local.deployment_id}-vsensor-lb"

  load_balancer_type               = "network"
  internal                         = true
  subnets                          = local.vpc_private_subnets
  enable_cross_zone_load_balancing = var.cross_zone_load_balancing_enable
  dns_record_client_routing_policy = var.cross_zone_load_balancing_enable ? "any_availability_zone" : "availability_zone_affinity"

  enable_deletion_protection = false

  tags = local.all_tags
}

resource "aws_lb_listener" "vsensor_lb_listener" {
  for_each = local.ports_map

  load_balancer_arn = aws_lb.vsensor_lb.arn
  port              = each.value.port
  protocol          = each.value.proto

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vsensor_tg[each.key].arn
  }

  tags = local.all_tags
}

resource "aws_lb_target_group" "vsensor_tg" {
  for_each = local.ports_map

  name = join("", [local.deployment_id, "-", each.value.proto, each.value.port])

  port     = each.value.port
  protocol = each.value.proto
  vpc_id   = local.vpc_id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/healthcheck"
    port                = each.value.port != 4789 ? each.value.port : 443
    protocol            = each.value.port != 80 ? "HTTPS" : "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 10
    matcher             = "200-399"
  }

  tags = local.all_tags

  #Terraform's default is false regardless of the target group protocol.
  #According to AWS documentation, for UDP/TCP_UDP target groups the default is true. Otherwise, the default is false.
  #https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-target-groups.html#target-group-attributes
  connection_termination = each.value.proto == "UDP" ? true : false

}
