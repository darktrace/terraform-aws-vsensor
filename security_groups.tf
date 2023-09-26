resource "aws_security_group" "vsensors_asg_sg" {
  name        = "${local.deployment_id}-vsensors-asg-sg"
  description = "Security group for vSensors ASG"
  vpc_id      = local.vpc_id
  tags = merge(
    local.all_tags,
    {
      Name = "${local.deployment_id}-vsensors-asg-sg"
    }
  )
}

resource "aws_security_group_rule" "ssh_access" {
  count = local.ssh_cidrs != null ? 1 : 0

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_cidrs
  security_group_id = aws_security_group.vsensors_asg_sg.id
}

resource "aws_security_group_rule" "allow_ossesnsors_80" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.vsensors_asg.cidr_block]
  security_group_id = aws_security_group.vsensors_asg_sg.id
}

resource "aws_security_group_rule" "allow_ossesnsors_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.vsensors_asg.cidr_block]
  security_group_id = aws_security_group.vsensors_asg_sg.id
}

resource "aws_security_group_rule" "allow_mirror_4789" {
  type              = "ingress"
  from_port         = 4789
  to_port           = 4789
  protocol          = "udp"
  cidr_blocks       = [data.aws_vpc.vsensors_asg.cidr_block]
  security_group_id = aws_security_group.vsensors_asg_sg.id
}

resource "aws_security_group_rule" "to_pkgs_80" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vsensors_asg_sg.id
}

resource "aws_security_group_rule" "to_pkgs_443" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vsensors_asg_sg.id
}
