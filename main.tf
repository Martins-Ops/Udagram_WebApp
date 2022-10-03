terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.32.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  env_name  = "Udagram-app"
}
resource "aws_vpc" "VPC" {
  cidr_block       =  var.cidr_block
  enable_dns_hostnames = true

  tags = {
    Name = local.env_name
  }
}

resource "aws_internet_gateway" "gw" {
  tags = {
    Name = local.env_name
  }
}

resource "aws_internet_gateway_attachment" "gw-attach" {
  internet_gateway_id = aws_internet_gateway.gw.id
  vpc_id              = aws_vpc.VPC.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "PublicSubnet1" {
  vpc_id                  = aws_vpc.VPC.id
  cidr_block              = var.cidr_block_pub1 
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "udagram PublicSubnet1"
  }
}

resource "aws_subnet" "PublicSubnet2" {
  vpc_id                  = aws_vpc.VPC.id
  cidr_block              = var.cidr_block_pub2
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "udagram PublicSubnet2"
  }
}

resource "aws_subnet" "PrivateSubnet1" {
  vpc_id                  = aws_vpc.VPC.id
  cidr_block              = var.cidr_block_pri1
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "udagram PrivateSubnet1"
  }
}

resource "aws_subnet" "PrivateSubnet2" {
  vpc_id                  = aws_vpc.VPC.id
  cidr_block              = var.cidr_block_pri2
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "udagram PrivateSubnet2"
  }
}

resource "aws_eip" "NatEIP1" {
  vpc          = true
  depends_on   = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "NatGw1" {
  allocation_id = aws_eip.NatEIP1.allocation_id
  subnet_id     = aws_subnet.PublicSubnet1.id
}

resource "aws_eip" "NatEIP2" {
  vpc          = true
  depends_on   = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "NatGw2" {
  allocation_id = aws_eip.NatEIP2.allocation_id
  subnet_id     = aws_subnet.PublicSubnet2.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.VPC.id

  tags = {
  Name = "udagram route table"
}
}

resource "aws_route" "route1" {
  route_table_id            = aws_route_table.rt.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.gw.id
  depends_on                = [aws_internet_gateway_attachment.gw-attach]
}

resource "aws_route_table_association" "rt_ass" {
  subnet_id      = aws_subnet.PublicSubnet1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table" "rt2" {
  vpc_id = aws_vpc.VPC.id

  tags = {
  Name = "udagram route table2"
}
}

resource "aws_route" "route2" {
  route_table_id            = aws_route_table.rt2.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id                = aws_internet_gateway.gw.id
  depends_on                = [aws_internet_gateway_attachment.gw-attach]
}

resource "aws_route_table_association" "rt_ass2" {
  subnet_id      = aws_subnet.PublicSubnet2.id
  route_table_id = aws_route_table.rt2.id
}

resource "aws_route_table" "pri-rt1" {
  vpc_id = aws_vpc.VPC.id

  tags = {
  Name = "udagram priv route"
}
}

resource "aws_route" "pri-route" {
  route_table_id            = aws_route_table.pri-rt1.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id             = aws_nat_gateway.NatGw1.id
  depends_on                = [aws_internet_gateway_attachment.gw-attach]
}

resource "aws_route_table_association" "pri_rt_ass" {
  subnet_id      = aws_subnet.PrivateSubnet1.id
  route_table_id = aws_route_table.pri-rt1.id
}

resource "aws_route_table" "pri-rt2" {
  vpc_id = aws_vpc.VPC.id

  tags = {
  Name = "udagram priv route2"
}
}

resource "aws_route" "pri-route2" {
  route_table_id            = aws_route_table.pri-rt2.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id             = aws_nat_gateway.NatGw2.id
  depends_on                = [aws_internet_gateway_attachment.gw-attach]
}

resource "aws_route_table_association" "pri_rt_ass2" {
  subnet_id      = aws_subnet.PrivateSubnet2.id
  route_table_id = aws_route_table.pri-rt2.id
}

resource "aws_security_group" "lb-secgroup" {
  name        = "allow_http_lb"
  description = "Allow http to our load balancer"
  vpc_id      = aws_vpc.VPC.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }
}

resource "aws_security_group" "udagram-secgroup" {
  name        = "allow_http_host"
  description = "Allow http to our host"
  vpc_id      = aws_vpc.VPC.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

    ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }
}

resource "aws_launch_configuration" "udagram_conf" {
  name                    = "udagram_launch_config"
  image_id                = var.ami
  key_name                = "femi"
  instance_type           = "t2.micro"
  iam_instance_profile    = aws_iam_instance_profile.udagram_profile.name
  security_groups         = [aws_security_group.udagram-secgroup.id]
  user_data               = <<-EOF
  #!/bin/bash
  apt-get update -y
  apt-get install apache2 -y
  systemctl start apache2.service
  cd /var/www/html
  echo " it works! Udagram, Udacity " > index.html 
  EOF

  ebs_block_device  {
    device_name = "/dev/sdk"
    volume_size = "10"
  }

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_lb_target_group" "udagram_target_grp" {
  name        = "udagram-lb-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.VPC.id
  
  health_check {
    healthy_threshold    = 4
    path                 = "/"
    protocol             = "HTTP"
    unhealthy_threshold  = 5
    timeout              = 60
    interval             = 120
  }
}

resource "aws_autoscaling_group" "udagram_autogroup" {
  name                     = "udagram-atg"
  launch_configuration     = aws_launch_configuration.udagram_conf.name
  max_size                 = 7
  min_size                 = 4
  vpc_zone_identifier      = [aws_subnet.PrivateSubnet1.id , aws_subnet.PrivateSubnet2.id ]
  target_group_arns        = [aws_lb_target_group.udagram_target_grp.arn]
}

resource "aws_lb" "udagram-lb" {
  name               = "uda-lb"
  subnets            = [aws_subnet.PublicSubnet1.id , aws_subnet.PublicSubnet2.id]
  security_groups    = [aws_security_group.lb-secgroup.id]
}

resource "aws_lb_listener" "udagram-lb_list" {
  load_balancer_arn = aws_lb.udagram-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
  type             = "forward"
  target_group_arn = aws_lb_target_group.udagram_target_grp.arn
}
}

resource "aws_lb_listener_rule" "udagram-lb_list_rule" {
  listener_arn = aws_lb_listener.udagram-lb_list.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.udagram_target_grp.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

  resource "aws_iam_role" "udagram_s3_role" {
  name = "udagram-s3-role"
  path = "/"
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  
}

data "aws_iam_policy_document" "policy_doc" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::*"]
    effect = "Allow"
  }
  statement {
  actions   = ["s3:ListBucket"]
  resources = ["arn:aws:s3:::*"]
  effect = "Allow"
}
}

resource "aws_iam_policy" "udagram_policy" {
  name        = "udagram-policy"
  policy      =  data.aws_iam_policy_document.policy_doc.json
}

resource "aws_iam_role_policy_attachment" "attachment" {
  role       = aws_iam_role.udagram_s3_role.name
  policy_arn = aws_iam_policy.udagram_policy.arn
}

resource "aws_iam_instance_profile" "udagram_profile" {
  name = "udagram-profile"
  path = "/"
  role = aws_iam_role.udagram_s3_role.name
}