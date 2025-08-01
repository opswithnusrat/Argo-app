
data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2) # Use only 1a and 1b
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = local.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # nat_gateway configuration
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  # Enable VPC hostnames and DNS support
  enable_dns_hostnames   = true
  enable_dns_support     = true
  map_public_ip_on_launch = true

 ##########################################
  # subnet taging for Karpenter & ELB
  ###########################################

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    # Tags subnets for Karpenter auto-discovery
     "karpenter.sh/discovery" = var.cluster_name
     "kubernetes.io/cluster/${var.cluster_name}" = "shared"

  }

  private_subnet_tags = {
        "kubernetes.io/role/internal-elb" = 1
        # Tags subnets for Karpenter auto-discovery
        "karpenter.sh/discovery" = var.cluster_name
        "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }



  tags = {
    Name        = "demo-vpc"
    Environment = "dev"
  }
}
