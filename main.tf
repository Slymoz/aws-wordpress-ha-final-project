terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- 1. NETWORK & TOPOLOGY DISCOVERY ---
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_vpc" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "default_vpc" {
  for_each = toset(data.aws_subnets.default_vpc.ids)
  id       = each.value
}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  subnets_by_az = { for _, s in data.aws_subnet.default_vpc : s.availability_zone => s.id... }
  selected_azs  = slice(sort(keys(local.subnets_by_az)), 0, 2)
  subnet_ids    = [for az in local.selected_azs : sort(local.subnets_by_az[az])[0]]
  common_tags = {
    Course  = "cloud-computing-aws"
    Project = "final-ha-wordpress-cluster"
  }
}

# --- 2. FIREWALL LAYER (SECURITY GROUPS) ---
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Permit public ingress traffic to load balancing interface"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-alb-sg" })
}

resource "aws_security_group" "ec2" {
  name        = "${var.name_prefix}-ec2-sg"
  description = "Isolate computing node access exclusively to proxies ALB endpoints"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-ec2-sg" })
}

resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Restrict database processing vectors directly to application pool instances"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-rds-sg" })
}

# --- 3. STATELESS PERSISTENCE STORAGE LAYER ---
resource "aws_s3_bucket" "media" {
  bucket_prefix = "${var.name_prefix}-media-"
  force_destroy = true
  tags          = local.common_tags
}

# --- 4. DATABASE MANAGED LAYER ---
resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = local.subnet_ids
  tags       = local.common_tags
}

resource "aws_db_instance" "wordpress" {
  identifier             = "${var.name_prefix}-db-cluster"
  allocated_storage      = 20
  db_name                = var.db_name
  engine                 = "mysql"
  instance_class         = "db.t3.micro"
  username               = var.db_master_username
  password               = var.db_master_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  tags                   = merge(local.common_tags, { Name = "${var.name_prefix}-db" })
}

# --- 5. TRAFFIC CORRELATION LAYER (ALB) ---
resource "aws_lb_target_group" "web" {
  name        = "${var.name_prefix}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    path     = "/"
    port     = "80"
    matcher  = "200"
    interval = 15
    timeout  = 5
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-tg" })
}

resource "aws_lb" "web" {
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.subnet_ids
  tags               = merge(local.common_tags, { Name = "${var.name_prefix}-alb" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# --- 6. HIGH AVAILABILITY & AUTOMATED SCALING LAYER (ASG) ---
resource "aws_launch_template" "web" {
  name_prefix   = "${var.name_prefix}-tpl-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2.id]
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    db_name     = var.db_name
    db_username = var.db_master_username
    db_password = var.db_master_password
    db_host     = aws_db_instance.wordpress.address
    db_port     = aws_db_instance.wordpress.port
  }))

  tags = local.common_tags
}

resource "aws_autoscaling_group" "web" {
  name                = "${var.name_prefix}-autoscaling-group"
  vpc_zone_identifier = local.subnet_ids
  target_group_arns   = [aws_lb_target_group.web.arn]
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  lifecycle {
    create_before_destroy = true
  }
}
