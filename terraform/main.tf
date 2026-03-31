terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Pins to version 5.x to avoid version 6.0 bugs
    }
  }
}


provider "aws" {
  region = "us-east-1"
}


data "aws_availability_zones" "available" {}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "blue-green-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = "blue-green-cluster"
  cluster_version = "1.31"

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
  nodes = {
    min_size     = 1  # You can keep this at 1 to save money
    max_size     = 3  # Increase this to 3
    desired_size = 3 # Keep this at 1; the autoscaler will increase it when needed
    instance_types = ["t3.micro"] # These are small, so the autoscaler is definitely needed!

    # ADD THIS TAG BLOCK HERE
    tags = {
      "k8s.io/cluster-autoscaler/enabled" = "true"
      "k8s.io/cluster-autoscaler/blue-green-cluster" = "owned"
      }
    }
  }
}