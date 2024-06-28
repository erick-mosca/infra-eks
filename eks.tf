data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

data "aws_ecrpublic_authorization_token" "token" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.public_subnets
  control_plane_subnet_ids = module.vpc.public_subnets


  eks_managed_node_groups = {
    example = {
      min_size     = 1
      max_size     = 10
      desired_size = 1

      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
        AmazonEC2FullAccess          = "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
        nodegroup_policy_karpenter   = resource.aws_iam_policy.nodegroup_policy_karpenter.arn
      }
    }
  }

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = "dev"
    tofu   = "true"
    "karpenter.sh/discovery"  : var.cluster_name
  }

}
  


resource "aws_iam_policy" "nodegroup_policy_karpenter" {
  name        = "nodegroup_policy_karpenter"
  path        = "/"
  description = "policy to karpenter scaling ec2"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "iam:CreateInstanceProfile",
                "iam:GetInstanceProfile",
                "pricing:GetProducts",
                "iam:TagInstanceProfile",
                "iam:AddRoleToInstanceProfile",
                "iam:PassRole",
                "iam:DeleteInstanceProfile",
                "ssm:GetParameter",
                "ec2:DescribeImages"
            ],
            "Resource": "*"
        }
    ]
  })

  tags = {
    Environment = "dev"
    tofu   = "true"
    "karpenter.sh/discovery"  : var.cluster_name
  }
}

################################################################################
#EKS Addons
################################################################################

module "eks_blueprints_addons" {
  depends_on = [module.eks]
  source     = "aws-ia/eks-blueprints-addons/aws"
  version    = "1.16.3"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  create_delay_dependencies = [for prof in module.eks.eks_managed_node_groups : prof.node_group_arn]

  enable_metrics_server                  = true
  enable_kube_prometheus_stack           = true
}