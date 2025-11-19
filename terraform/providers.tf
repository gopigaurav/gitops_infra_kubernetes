terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.18"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "~> 7.0"
    }
  }
}

provider "kind" {}

provider "kubernetes" {
  config_path = "~/.kube/config"
  host = var.cluster_endpoint
  token= data.kubernetes_secret.terraform_admin.data["token"]
  cluster_ca_certificate = base64decode(var.cluster_ca)
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "argocd" {
  server_addr = "localhost:30081" # NodePort from your argocd-values.yaml
  auth_token  = var.argocd_token           # Generate using `argocd account generate-token --account admin`
  insecure    = true                        # For local dev
}
  