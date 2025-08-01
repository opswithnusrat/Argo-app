#   ################################################
#   ## Trust policy for Pod Identity
#   #############################################

data "aws_iam_policy_document" "cert_manager_assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole", "sts:TagSession"]
  }
}

### IAM Role for cert_manager
resource "aws_iam_role" "cert_manager" {
  name               = "cert_manager-pod-identity-role"
  assume_role_policy = data.aws_iam_policy_document.cert_manager_assume_role_policy.json
}

# IAM Policy for Route53
resource "aws_iam_policy" "cert_manager" {
  name   = "cert_manager-policy"
  policy = file("${path.module}/policy_docs/cert_policy.json")
}

# Attach policy to the role
resource "aws_iam_role_policy_attachment" "cert_manager_attach" {
  role       = aws_iam_role.cert_manager.name
  policy_arn = aws_iam_policy.cert_manager.arn
}

# Associate IAM role to Kubernetes service account
resource "aws_eks_pod_identity_association" "cert_manager" {
  cluster_name    = var.cluster_name
  namespace       = "cert-manager" 
  service_account = "cert-manager"
  role_arn        = aws_iam_role.cert_manager.arn
}


# #############################################################################
#  ## cert_manager Helm Installation
# #############################################################################

    resource "helm_release" "cert_manager" {
    name       = "cert-manager"
    namespace  = "cert-manager"
    repository = "https://charts.jetstack.io"
    chart      = "cert-manager"
    version    = "v1.18.2"
    create_namespace = true

   values = [
    yamlencode({
      crds = {
        enabled = true
        keep    = false
      }
    })
   ]
  set {
    name  = "serviceAccount.name"
    value = "cert-manager"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cert_manager.arn
  }

}

 resource "kubectl_manifest" "letsencrypt_prod_issuer" {
   yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email:  xxxxxxxxxxxxx
        privateKeySecretRef:
          name: letsencrypt-prod-private-key
        solvers:
          - dns01:
              route53:
                region: xxxxxxxxx
                hostedZoneID: xxxxxxxxxxxxxxxxx
   YAML
 }