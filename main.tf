variable "aws_region" {}
variable "instance_type" {}
variable "vpc_cidr" {}
variable "subnets_cidr" {
  type = list(string)
}
variable "availability_zones" {
  type = list(string)
}
variable "cloudflare_api_token" {}
variable "github_token" {}
variable "domain" {}
variable "environments" {
  type = map(
    object(
      {
        subdomain                   = string
        deploy_key_pvt              = string
        deploy_key_pub              = string
        instance_key_pvt            = string
        instance_key_pub            = string
        override                    = string
        traefik_basicauth           = string
        acme_email                  = string
        postgres_password_superuser = string
        postgres_password_app       = string
        postgres_password_app_admin = string
        postgres_user_app_power     = string
        azure_tenant_id             = string
        azure_client_id             = string
      }
    )
  )
}

terraform {
  backend "s3" {}
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    github = {
      source = "integrations/github"
    }
  }
}

provider "local" {}

provider "null" {}

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "github" {
  token = var.github_token
}


locals {
  config_dir = "${path.module}/config"
  env        = terraform.workspace
  env_vars   = lookup(var.environments, local.env, null)
}

data "cloudflare_zones" "dtrack_zone" {
  filter {
    name   = var.domain
    status = "active"
    paused = false
  }
}

data "http" "ip" {
  url = "https://ifconfig.me/ip"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

resource "aws_vpc" "dtrack_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${local.env}-dtrack-vpc"
  }
}

resource "aws_subnet" "dtrack_subnet" {
  count                   = length(var.subnets_cidr)
  vpc_id                  = aws_vpc.dtrack_vpc.id
  cidr_block              = element(var.subnets_cidr, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.env}-dtrack-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "dtrack_igw" {
  vpc_id = aws_vpc.dtrack_vpc.id
  tags = {
    Name = "${local.env}-dtrack-igw"
  }
}

resource "aws_route_table" "dtrack_route_table" {
  vpc_id = aws_vpc.dtrack_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dtrack_igw.id
  }
  tags = {
    Name = "${local.env}-dtrack-route-table"
  }
}

resource "aws_route_table_association" "dtrack_route_table_association" {
  count          = length(var.subnets_cidr)
  subnet_id      = element(aws_subnet.dtrack_subnet.*.id, count.index)
  route_table_id = aws_route_table.dtrack_route_table.id
}

resource "aws_security_group" "dtrack_sg" {
  name        = "${local.env}-dtrack-sg"
  description = "Allow SSH and HTTP from a specific IP"
  vpc_id      = aws_vpc.dtrack_vpc.id
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.ip.response_body)}/32"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.env}-dtrack-sg"
  }
}

resource "aws_key_pair" "dtrack_key_pair" {
  key_name   = "${local.env}-dtrack-key-pair"
  public_key = file(local.env_vars.instance_key_pub)
  tags = {
    Name = "${local.env}-dtrack-key-pair"
  }
}

resource "aws_instance" "dtrack_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  availability_zone      = var.availability_zones.0
  subnet_id              = aws_subnet.dtrack_subnet.0.id
  vpc_security_group_ids = [aws_security_group.dtrack_sg.id]
  key_name               = aws_key_pair.dtrack_key_pair.key_name
  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    tags = {
      Name = "${local.env}-dtrack-instance-root-block-device"
    }
  }
  tags = {
    Name = "${local.env}-dtrack-instance"
  }
  provisioner "local-exec" {
    command = <<EOT
      until nc -z -v -w5 ${aws_instance.dtrack_instance.public_ip} 22; do
        echo "Waiting for SSH to become available..."
        sleep 5
      done
      echo "$(ssh-keyscan ${aws_instance.dtrack_instance.public_ip})" > "${local.config_dir}/ansible/${local.env}.known_hosts"
      sed -i "s/${aws_instance.dtrack_instance.public_ip}/${local.env_vars.subdomain}.${var.domain}/" "${local.config_dir}/ansible/${local.env}.known_hosts"
    EOT
  }
}

resource "cloudflare_record" "dtrack_record" {
  zone_id = data.cloudflare_zones.dtrack_zone.zones[0].id
  name    = local.env_vars.subdomain
  value   = aws_instance.dtrack_instance.public_ip
  type    = "A"
  ttl     = 120
}

resource "cloudflare_record" "dtrack_traefik_record" {
  zone_id = data.cloudflare_zones.dtrack_zone.zones[0].id
  name    = "traefik.${local.env_vars.subdomain}"
  value   = aws_instance.dtrack_instance.public_ip
  type    = "A"
  ttl     = 120
}

resource "github_repository_deploy_key" "dtrack_deploy_key" {
  title      = "${local.env}-dtrack-deploy-key"
  repository = "dtrack"
  key        = file(local.env_vars.deploy_key_pub)
  read_only  = "true"
}

resource "local_file" "ansible_hosts" {
  content = templatefile(
    "${local.config_dir}/ansible/templates/hosts.ini.tpl",
    {
      environments = var.environments
      domain       = var.domain
    }
  )
  filename        = "${local.config_dir}/ansible/hosts.ini"
  file_permission = "0600"
}
