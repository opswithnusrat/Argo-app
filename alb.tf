# # -------------------------------
# # ALB Controller IAM Policy Doc
# # -------------------------------
data "aws_iam_policy_document" "alb_assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole",
              "sts:TagSession"]
  }
}

resource "aws_iam_role" "alb" {
  name               = "alb-controller-pod-identity-role"
  assume_role_policy = data.aws_iam_policy_document.alb_assume_role_policy.json
}

resource "aws_iam_policy" "alb" {
  name   = "alb-controller-policy"
  policy = file("${path.module}/policy_docs/alb_policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb.name
  policy_arn = aws_iam_policy.alb.arn
}

resource "aws_eks_pod_identity_association" "alb" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.alb.arn
}

# #######################################
# # helm alb controller install 
# #######################################

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.13.0"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  
  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb.arn
  }
   depends_on = [aws_iam_role_policy_attachment.alb_attach]
}

#########################################
# NGINX Ingress Controller
#########################################
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  namespace  = "ingress"
  create_namespace = true

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.10.1"

  values = [
    file("${path.module}/manifest/ingress_values.yaml")
  ]

  depends_on = [helm_release.alb_controller]
}
