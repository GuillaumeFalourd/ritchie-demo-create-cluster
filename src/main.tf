variable "region" {
  default = ""
}
provider "aws" {
  region = var.region
}

terraform {
  required_version = "0.13.5"
  required_providers {
    aws = "3.3.0"
	kubernetes = "~> 1.11.0"
	local      = "1.4.0"
	template   = "2.1.2"
	helm       = "1.3.0"
	external   = "1.2.0"
	tls        = "2.1.1"
	archive    = "1.3.0"
	random     = "2.2.1"
  }

  backend "s3" {
  }
}

variable "vpc_name" {
  type = string
}
variable "vpc_cidr" {
  type = string
}

variable "vpc_azs" {
  type = list(string)
}

variable "customer_name" {
  default = ""
}
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  version = "2.57.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs = var.vpc_azs
  private_subnets = [
    for num in [1, 2, 3] :
    cidrsubnet(var.vpc_cidr, 5, num)
  ]
  public_subnets = [
    for num in [4, 5, 6] :
    cidrsubnet(var.vpc_cidr, 5, num)
  ]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = var.customer_name
  }
}


# --------------------------------------

data "aws_eks_cluster" "cluster" {
	name = module.kubernetes_cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
	name = module.kubernetes_cluster.cluster_id
}

provider "kubernetes" {
	host                   = data.aws_eks_cluster.cluster.endpoint
	cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
	token                  = data.aws_eks_cluster_auth.cluster.token
	load_config_file       = false
	version                = "~> 1.9"
}

variable "kubernetes_cluster_name" {
	default = ""
}

module "kubernetes_cluster" {
	version         									= "13.2.1"
	source          									= "terraform-aws-modules/eks/aws"
	cluster_name    									= var.kubernetes_cluster_name
	cluster_version 									= "1.17"
	subnets         									= module.vpc.private_subnets
	vpc_id          									= module.vpc.vpc_id
	worker_create_cluster_primary_security_group_rules 	= true
	enable_irsa                                        	= true
	write_kubeconfig                                   	= false

	worker_groups = [
		{
			instance_type = "t2.small"
			asg_max_size  = 5
		}
	]
}

# --------------------------------------- dns zone to expose your applications
variable "domain_name" {
	default = ""
}

module "dns" {
	source = "./modules/dns_zone"
	domain_name = var.domain_name
}

# --------------------------------------- iam to do things on k8s
module "iam_k8s" {
	source = "./modules/iam_k8s"

	kubernetes_cluster_name = var.kubernetes_cluster_name
	kubernetes_worker_iam_role_name = module.kubernetes_cluster.worker_iam_role_name

}

# --------------------------------------- helm
provider "helm" {
	kubernetes {
		host                   = data.aws_eks_cluster.cluster.endpoint
		cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
		token                  = data.aws_eks_cluster_auth.cluster.token
		load_config_file       = false
	}
}

# --------------------------------------- helm repositories
module "helm_deps" {

	source = "./modules/helm_deps"
	kubernetes_cluster = module.kubernetes_cluster
	kubernetes_cluster_name = var.kubernetes_cluster_name
	region = var.region
	dns_zone_id = module.dns.zone_id
	vpc_id = module.vpc.vpc_id

}
# -------------------------------- helm test exposure

variable "namespace" {
	default = ""
}
