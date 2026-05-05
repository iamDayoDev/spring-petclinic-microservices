terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

# ── AVAILABILITY ZONES ──────────────────────────────────────
data "aws_availability_zones" "available" {
  state = "available"
}

# ── VPC ─────────────────────────────────────────────────────
resource "aws_vpc" "petclinic" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "petclinic-vpc"
    Environment = var.environment
  }
}

# ── PUBLIC SUBNETS ───────────────────────────────────────────
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.petclinic.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name                                        = "petclinic-public-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}

# ── PRIVATE SUBNETS ──────────────────────────────────────────
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.petclinic.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name                                        = "petclinic-private-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

# ── INTERNET GATEWAY ─────────────────────────────────────────
resource "aws_internet_gateway" "petclinic" {
  vpc_id = aws_vpc.petclinic.id
  tags   = { Name = "petclinic-igw" }
}

# ── NAT GATEWAY ──────────────────────────────────────────────
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "petclinic-nat-eip" }
}

resource "aws_nat_gateway" "petclinic" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "petclinic-nat" }
  depends_on    = [aws_internet_gateway.petclinic]
}

# ── ROUTE TABLES ─────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.petclinic.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.petclinic.id
  }
  tags = { Name = "petclinic-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.petclinic.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.petclinic.id
  }
  tags = { Name = "petclinic-private-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ── ECR REPOSITORIES ─────────────────────────────────────────
resource "aws_ecr_repository" "services" {
  for_each             = toset(var.services)
  name                 = "petclinic/${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "petclinic-${each.key}"
    Environment = var.environment
  }
}