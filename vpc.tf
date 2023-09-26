resource "aws_vpc" "main" {
  count = local.vpc_enable ? 1 : 0

  cidr_block = local.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.all_tags,
    {
      Name = "${local.deployment_id}-vpc"
    }
  )
}

resource "aws_subnet" "private" {
  count = local.vpc_enable ? length(local.availability_zone) : 0

  vpc_id = local.vpc_id

  availability_zone = local.availability_zone[count.index]
  cidr_block        = local.private_cidrs[count.index]

  map_public_ip_on_launch = false

  tags = merge(
    local.all_tags,
    {
      Name = "${local.deployment_id}-private-${local.availability_zone[count.index]}"
    }
  )
}

resource "aws_subnet" "public" {
  count = local.vpc_enable ? length(local.availability_zone) : 0

  vpc_id = local.vpc_id

  availability_zone = local.availability_zone[count.index]
  cidr_block        = local.public_cidrs[count.index]

  map_public_ip_on_launch = false

  tags = merge(
    local.all_tags,
    {
      Name = "${local.deployment_id}-public-${local.availability_zone[count.index]}"
    }
  )
}

resource "aws_internet_gateway" "main_igw" {
  count = local.vpc_enable ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = merge(
    local.all_tags,
    {
      Name = "${local.deployment_id}-igw"
    }
  )
}

resource "aws_route_table" "main_rt" {
  count = local.vpc_enable ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw[0].id
  }

  tags = merge(
    local.all_tags,
    {
      Name = "${local.deployment_id}-public"
    }
  )
}

resource "aws_route_table_association" "public_rta" {
  count = local.vpc_enable ? length(local.availability_zone) : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.main_rt[0].id
}

resource "aws_eip" "vsensor_nat_gw_eip" {
  count = local.vpc_enable ? length(local.availability_zone) : 0

  domain = "vpc" #aws provider version 5
  #vpc = true #aws provider version 4

  tags = merge(
    local.all_tags,
    {
      Name = "${local.deployment_id}-${local.availability_zone[count.index]}"
    }
  )

  depends_on = [aws_internet_gateway.main_igw[0]]
}

resource "aws_nat_gateway" "vsensor_nat_gw" {
  count = local.vpc_enable ? length(local.availability_zone) : 0

  allocation_id = aws_eip.vsensor_nat_gw_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    local.all_tags,
    {
      Name = "${local.deployment_id}-${local.availability_zone[count.index]}"
    }
  )

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.main_igw[0]]
}

resource "aws_route_table" "vsensor_rt" {
  count = local.vpc_enable ? length(local.availability_zone) : 0

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.vsensor_nat_gw[count.index].id
  }

  tags = merge(
    local.all_tags,
    {
      Name = "${local.deployment_id}-vsensor-rt"
    }
  )
}

resource "aws_route_table_association" "vsensor_rta" {
  count = local.vpc_enable ? length(local.availability_zone) : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.vsensor_rt[count.index].id
}
