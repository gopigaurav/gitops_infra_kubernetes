# resource "null_resource" "kind_cluster" {
#   provisioner "local-exec" {
#     command = "bash ${path.module}/scripts/kind-create.sh"
#   }
# }

# When we are trying to create the new cluster
resource "null_resource" "kind_cluster" {
  provisioner "local-exec" {
    command = "kind create cluster --name dev-cluster --config=${path.module}/kind-config.yaml"
  }
}


resource "null_resource" "wait_for_cluster" {
  depends_on = [null_resource.kind_cluster]

  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting for kind cluster dev-cluster to be ready..."
      for i in {1..30}; do
        kubectl get nodes && break || sleep 2
      done
    EOT
  }
}

resource "null_resource" "helm_repo_update" {
  provisioner "local-exec" {
    command = <<EOT
      helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
      helm repo add bitnami https://charts.bitnami.com/bitnami || true
      helm repo add bank-vaults https://ghcr.io/bank-vaults/helm-charts || true
      helm repo update
    EOT
  }
}


resource "helm_release" "monitoring" {
  depends_on = [
    null_resource.kind_cluster,
    null_resource.helm_repo_update,
    null_resource.wait_for_cluster
  ]

  name       = "monitoring"
  namespace  = "monitoring"
  create_namespace = true
  dependency_update = true
  chart      = "../charts/monitoring"
  values = [
    file("${path.module}/../overlays/dev/monitoring-values.yaml")
  ]
}

# Kafka
resource "helm_release" "kafka" {
  name       = "kafka"
  chart      = "../charts/kafka/"
  namespace  = "kafka"
  create_namespace = true
  # Ensure Helm will download/chart dependencies declared in Chart.yaml
  dependency_update = true
  values = [
    file("${path.module}/../overlays/dev/kafka-values.yaml")
  ]
  # Give Helm/cluster more time to pull images and start the Kafka pods
  timeout = 600
  force_update = true 
  depends_on = [null_resource.kind_cluster, null_resource.wait_for_cluster]
}

# Producer
resource "helm_release" "producer" {
  name       = "producer"
  chart      = "../charts/producer"
  namespace  = var.namespace
  values = [
    file("${path.module}/../overlays/dev/producer-values.yaml")
  ]
  depends_on = [helm_release.kafka, null_resource.wait_for_cluster]
}

# Consumer
resource "helm_release" "consumer" {
  name       = "consumer"
  chart      = "../charts/consumer"
  namespace  = var.namespace
  values = [
    file("${path.module}/../overlays/dev/consumer-values.yaml")
  ]
  depends_on = [helm_release.kafka, null_resource.wait_for_cluster]
}

# Optional: ArgoCD
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  create_namespace = true
  timeout = 600
  values = [
    file("${path.module}/../charts/monitoring/argocd-values.yaml")
  ]
  depends_on = [null_resource.kind_cluster, null_resource.wait_for_cluster]
}

# Optional: Jenkins
resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  namespace  = "jenkins"
  create_namespace = true
  timeout = 600
  values = [
    file("${path.module}/../charts/monitoring/jenkins-values.yaml")
  ]
  # values           = [file("${path.module}/../overlays/dev/jenkins-values.yaml")]
  depends_on = [null_resource.kind_cluster, null_resource.kind_cluster, null_resource.wait_for_cluster]
}


#############################
# Kubernetes Dashboard Helm Release
#############################


##############################
# 1. Helm Release: Kubernetes Dashboard
##############################
resource "helm_release" "kubernetes_dashboard" {
  depends_on      = [null_resource.helm_repo_update, null_resource.wait_for_cluster]

  name             = "kubernetes-dashboard"
  chart            = "kubernetes-dashboard"
  namespace        = "kubernetes-dashboard"
  create_namespace = true
  repository       = "https://kubernetes.github.io/dashboard/"
  version          = "5.0.0"

  values = [
    yamlencode({
      rbac = { clusterAdminRole = true }
      service = {
        type     = "NodePort"
        nodePort = 30090
      }
    })
  ]
}

##############################
# 2. Dashboard Admin ServiceAccount
##############################
resource "kubernetes_service_account" "dashboard_admin" {
  metadata {
    name      = "dashboard-admin"
    namespace = "kubernetes-dashboard"
  }

  depends_on = [helm_release.kubernetes_dashboard, null_resource.wait_for_cluster]
}

##############################
# 3. ClusterRoleBinding for Admin
##############################
resource "kubernetes_cluster_role_binding" "dashboard_admin" {
  metadata {
    name = "dashboard-admin-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.dashboard_admin.metadata[0].name
    namespace = kubernetes_service_account.dashboard_admin.metadata[0].namespace
  }

  depends_on = [kubernetes_service_account.dashboard_admin, null_resource.wait_for_cluster]
}

##############################
# 4. Fetch Dashboard Token using local-exec
##############################
resource "null_resource" "dashboard_token" {
  depends_on = [
    kubernetes_service_account.dashboard_admin,
    kubernetes_cluster_role_binding.dashboard_admin
  ]

  provisioner "local-exec" {
    command = <<EOT
      echo "==== Kubernetes Dashboard Token ===="
      kubectl -n kubernetes-dashboard create token dashboard-admin
      echo "==================================="
    EOT
  }
}

##############################
# 5. Optional Output Instructions
##############################
output "dashboard_token_instructions" {
  value = "Run 'terraform apply' and check the null_resource output to get the dashboard token. Use this token to log in to the Kubernetes Dashboard UI."
}



# commands to get the cluster ip
# kubectl get svc -n kubernetes-dashboard


# kubectl get endpoints -n kubernetes-dashboard  => To get the enpoint for the kubernetes dashboard
# kubectl get svc kubernetes-dashboard -n kubernetes-dashboard -o yaml => code for service


# [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\Git\usr\bin", "User") => way to set the env variable for grep example

# Since this is a local cluster, the easiest is port-forwarding, which bypasses NodePort and targetPort issues:
# kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard 8443:443 => port forwarding


# chrome://flags/#allow-insecure-localhost -> for chrome dev


# Token command for kubernetes dashboard => kubectl -n kubernetes-dashboard create token dashboard-admin

# command to see the role permissions => kubectl get clusterrolebinding dashboard-admin-binding -o yaml



# Roles related
# kubectl auth can-i list pods --as=system:serviceaccount:kubernetes-dashboard:dashboard-admin
# kubectl auth can-i get deployments --all-namespaces --as=system:serviceaccount:kubernetes-dashboard:dashboard-admin



# port forwarding for argocd server 
# kubectl port-forward svc/argocd-server -n argocd 8081:80 => username - admin
# application - https://localhost:8081/applications


# TO get the argocd password - windows
# [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}")))

# alternate command to get the password from argocd
# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode


# TO get the jenkins username - windows
# $Username = kubectl get secret jenkins -n jenkins -o jsonpath="{.data.jenkins-admin-user}" [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Username))


# To get the jenkins password - windows
# $Password = kubectl get secret jenkins -n jenkins -o jsonpath="{.data.jenkins-admin-password}" [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Password))
# [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((kubectl get secret jenkins -n jenkins -o jsonpath="{.data.jenkins-admin-password}")))


# Alternate to get jenkins password
# kubectl get secret jenkins-admin -n jenkins -o jsonpath="{.data.password}" | base64 --decode
# kubectl get secret jenkins-admin -n jenkins -o jsonpath="{.data.username}" | base64 --decode


# To get the token from kubernetes dashboard
# kubectl -n kubernetes-dashboard create token dashboard-admin


# To get the jenkins service info
# kubectl get svc jenkins -n jenkins


# Uing kaniko for jenkins docker
# kubectl create secret generic dockerhub-creds \
#  --from-file=config.json=/path/to/docker/config.json \
#  -n jenkins



# To create config.json for jenkinsfile to use kaniko
# kubectl create secret generic dockerhub-creds --from-file=config.json=C:\Users\gopig\.docker\config.json -n jenkins 
# And to check whether its created or not - kubectl get secrets -n jenkins