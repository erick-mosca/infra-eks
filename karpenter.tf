module "karpenter" {
  source          = "terraform-aws-modules/eks/aws//modules/karpenter"
  cluster_name    = module.eks.cluster_name
  version         = "~> 20.11.1"
  create_iam_role = true
  namespace       = "karpenter"
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}

resource "helm_release" "karpenter" {
  depends_on          = [module.eks]
  create_namespace    = true
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  namespace           = "karpenter"


  set {
    name  = "settings.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }
  set {
    name  = "replicas"
    value = 1
  }
  set {
    name  = "serviceAccount.annotations.eks\\amazonaws\\com/role-arn"
    value = module.karpenter.node_iam_role_name
  }
  set {
    name  = "settings.featureGates.spotToSpotConsolidation"
    value = true
  }
}

resource "kubectl_manifest" "karpenter_ec2_node_class" {
  force_new = true
  wait      = true
  yaml_body = <<YAML
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  role: ${module.karpenter.node_iam_role_name}
  amiFamily: AL2 
  securityGroupSelectorTerms:
  - tags:
      karpenter.sh/discovery: ${module.eks.cluster_name}
  subnetSelectorTerms:
  - tags:
      karpenter.sh/discovery: ${module.eks.cluster_name}
  tags:
    KarpenterNodePoolName: default
    NodeType: default
    karpenter.sh/discovery: ${module.eks.cluster_name}
    Name: eks-services-ng-karpenter
YAML
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<YAML
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default 
spec:  
  template:
    metadata:
      labels:
        intent: apps
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: "karpenter.k8s.aws/instance-category"
          operator: In
          values: ["c", "m", "r", "t"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["2", "4", "8"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
      nodeClassRef:
        name: default
      kubelet:
        containerRuntime: containerd
        systemReserved:
          cpu: 100m
          memory: 100Mi
  disruption:
    consolidationPolicy: WhenUnderutilized
YAML
}