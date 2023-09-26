data "aws_ami" "bastion_amazon_linux_2" {
  most_recent = true


  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }


  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

data "aws_ami" "bastion_ubuntu" {
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

locals {
  bastion_ami_id = tomap({
    Amazon-Linux2-HVM           = data.aws_ami.bastion_amazon_linux_2.id
    Ubuntu-Server-20_04-LTS-HVM = data.aws_ami.bastion_ubuntu.id
  })
}

resource "aws_instance" "bastion" {
  count = local.bastion_enable ? 1 : 0

  ami                    = local.bastion_ami_id[local.bastion_ami]
  instance_type          = local.bastion_instance_type
  subnet_id              = local.bastion_subnet_id
  vpc_security_group_ids = [aws_security_group.bastion_sg[0].id]

  key_name = var.bastion_ssh_keyname

  # kics-scan ignore-line
  associate_public_ip_address = true # required for the jump host; Security Group will limit the inbound to tcp/22

  root_block_device {
    delete_on_termination = true
    volume_size           = 8
    volume_type           = "gp2"
    encrypted             = true
  }

  tags = merge(
    local.all_tags,
    {
      Name = "${local.deployment_id}-jump-host"
    }
  )
}

resource "aws_eip" "remote_access_eip" {
  count = local.bastion_enable ? 1 : 0

  domain = "vpc" #aws provider version 5
  #vpc = true #aws provider version 4

  tags = merge(
    local.all_tags,
    {
      Name = "${local.deployment_id}-vsensors-remote-access"
    }
  )

  depends_on = [aws_internet_gateway.main_igw[0]]
}

resource "aws_eip_association" "remote_access_eip_assoc" {
  count = local.bastion_enable ? 1 : 0

  instance_id   = aws_instance.bastion[0].id
  allocation_id = aws_eip.remote_access_eip[0].id
}

resource "aws_security_group" "bastion_sg" {
  count = local.bastion_enable ? 1 : 0

  name        = "bastion_sg"
  description = "Security group for the remote access."
  vpc_id      = local.vpc_id
  tags = merge(
    local.all_tags,
    {
      Name = "${local.deployment_id}-bastion-sg}"
    }
  )
}

resource "aws_security_group_rule" "bastion_to_any" {
  count = local.bastion_enable ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion_sg[0].id
}

resource "aws_security_group_rule" "remote_ssh" {
  count = local.bastion_enable ? 1 : 0

  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = local.bastion_ssh_cidrs
  security_group_id = aws_security_group.bastion_sg[0].id
}

#If creating bastion is enabled then allow ssh from the bastion's Security Group
resource "aws_security_group_rule" "bastion_ssh_access" {
  count = local.bastion_enable ? 1 : 0

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion_sg[0].id
  security_group_id        = aws_security_group.vsensors_asg_sg.id
}
