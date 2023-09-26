locals {
  ports_map = {
    http = {
      port  = 80
      proto = "TCP"
    }
    https = {
      port  = 443
      proto = "TCP"
    }
    mirror = {
      port  = 4789
      proto = "UDP"
    }
  }
  common_tags = {
    deployment_id = local.deployment_id
    dt_product    = "vsensor"
  }
  all_tags = merge(
    local.common_tags,
    var.tags
  )

  ssh_cidrs = var.ssh_cidrs

  vpc_enable = var.vpc_enable

  vpc_id              = local.vpc_enable ? aws_vpc.main[0].id : var.vpc_id
  vpc_private_subnets = local.vpc_enable ? aws_subnet.private.*.id : var.vpc_private_subnets

  availability_zone = local.vpc_enable ? var.availability_zone : []

  vpc_cidr = local.vpc_enable ? var.vpc_cidr : ""

  private_cidrs = local.vpc_enable ? var.private_subnets_cidrs : []
  public_cidrs  = local.vpc_enable ? var.public_subnets_cidrs : []

  asg_tag = local.vpc_enable ? aws_route_table_association.vsensor_rta[0].id : "ExistingVPC"

  cw_namespace      = var.cw_namespace == "" ? local.deployment_id : var.cw_namespace
  cw_log_group_name = var.cw_log_group_name == "" ? "${local.deployment_id}-vsensor-log-group" : var.cw_log_group_name
  kms_key_arn       = var.kms_key_enable ? aws_kms_key.vsensor_logs[0].arn : var.kms_key_arn

  bastion_enable        = var.bastion_enable && local.vpc_enable ? true : false
  bastion_ami           = var.bastion_ami
  bastion_instance_type = var.bastion_instance_type
  bastion_ssh_cidrs     = var.bastion_ssh_cidrs
  bastion_subnet_id     = local.bastion_enable ? aws_subnet.public[0].id : null

  #Validate the number of AZs matches the number of Private and Public CIDRs provided for new VPC
  az_vs_private = local.vpc_enable ? zipmap(local.availability_zone, local.private_cidrs) : zipmap([""], [""])
  az_vs_public  = local.vpc_enable ? zipmap(local.availability_zone, local.public_cidrs) : zipmap([""], [""])
}
