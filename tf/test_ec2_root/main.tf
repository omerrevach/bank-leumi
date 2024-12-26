terraform {
  backend "s3" {
    bucket         = "my-terraform-state-vpc"
    key            = "test-ec2/terraform.tfstate"
    region         = "eu-north-1"
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "my-terraform-state-vpc"
    key    = "vpc/terraform.tfstate"
    region = "eu-north-1"
  }
}

module "test_ec2" {
  source                  = "../modules/compute/ec2"
  instance_type           = "t3.micro"
  ami                     = "ami-089146c5626baa6bf"
  subnet_id               = data.terraform_remote_state.vpc.outputs.public_subnets[0]
  vpc_id                  = data.terraform_remote_state.vpc.outputs.vpc_id
  instance_name           = "testec2-instance"
  user_data               = file("${path.module}/user_data.sh")
  key_name                = "omer_key"

  ingress_from_port       = 80
  ingress_to_port         = 80
  ingress_protocol        = "tcp"
  ingress_cidr_blocks     = ["91.231.246.50/32"]
  security_group_name     = "testec2-sg"
}

module "nlb" {
  source             = "../modules/compute/alb"
  name               = "testec2-nlb"
  vpc_id             = data.terraform_remote_state.vpc.outputs.vpc_id
  public_subnet_ids  = data.terraform_remote_state.vpc.outputs.public_subnets
  load_balancer_type = "network"
  ingress_from_port  = 80
  ingress_to_port    = 80
  target_group_port  = 80
  protocol           = "TCP"
  health_check_port  = 80
  listener_port      = 80
  instance_id        = module.test_ec2.instance_id
}

resource "aws_eip" "test_ec2_eip" {
  instance = module.test_ec2.instance_id
  domain   = "vpc"
}

resource "aws_lb_target_group_attachment" "test_ec2_attachment" {
  target_group_arn = module.nlb.target_group_arn
  target_id        = module.test_ec2.instance_id
  port             = 80
}
