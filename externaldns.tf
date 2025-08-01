#   ################################################
#   ## Trust policy for Pod Identity
#   #############################################

data "aws_iam_policy_document" "externaldns_assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole", "sts:TagSession"]
  }
}

### IAM Role for ExternalDNS
resource "aws_iam_role" "externaldns" {
  name               = "externaldns-pod-identity-role"
  assume_role_policy = data.aws_iam_policy_document.externaldns_assume_role_policy.json
}

# IAM Policy for Route53
resource "aws_iam_policy" "externaldns" {
  name   = "externaldns-policy"
  policy = file("${path.module}/policy_docs/externaldns_policy.json")
}

# Attach policy to the role
resource "aws_iam_role_policy_attachment" "externaldns_attach" {
  role       = aws_iam_role.externaldns.name
  policy_arn = aws_iam_policy.externaldns.arn
}

# Associate IAM role to Kubernetes service account
resource "aws_eks_pod_identity_association" "externaldns" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system" 
  service_account = "external-dns"
  role_arn        = aws_iam_role.externaldns.arn
}

# #############################################################################
#  ## external-dns Helm Installation
# #############################################################################

resource "helm_release" "external_dns" {
  name       = "external-dns"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.14.4"

  values = [
    yamlencode({
      provider = "aws"
      policy   = "sync"

      serviceAccount = {
        create = true
        name   = "external-dns"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.externaldns.arn
        }
      }

      txtOwnerId = var.cluster_name
    })
  ]
  

}

   