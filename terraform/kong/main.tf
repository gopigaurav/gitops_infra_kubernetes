terraform {
  required_providers {
    helm       = { source = "hashicorp/helm" }
    kubernetes = { source = "hashicorp/kubernetes" }
  }
}

provider "helm" { kubernetes { config_path = var.kubeconfig_path } }
provider "kubernetes" { config_path = var.kubeconfig_path }

resource "helm_release" "kong" {
  name       = "kong"
  repository = "https://charts.konghq.com"
  chart      = "kong"
  namespace  = "kong"
  create_namespace = true
  version    = "2.11.0"
  values = [file("${path.module}/values.kong.yaml")]
}

resource "kubernetes_service" "kong_proxy" {
  metadata { name = "kong-proxy" namespace = "kong" }
  spec {
    selector = { app = "kong" }
    port { name = "proxy" port = 80 target_port = 8000 }
    port { name = "proxy-ssl" port = 443 target_port = 8443 }
    type = "LoadBalancer"
  }
}

resource "null_resource" "kong_declarative_push" {
  depends_on = [helm_release.kong, kubernetes_service.kong_proxy]

  provisioner "local-exec" {
    command = <<EOT
# Wait for LB IP
for i in {1..30}; do
  IP=$(kubectl get svc kong-proxy -n kong -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || true)
  if [ -n "$IP" ]; then break; fi
  sleep 5
done
if [ -z "$IP" ]; then echo "Kong LB not ready"; exit 1; fi
# push declarative config
curl -sS -X POST http://$IP:8001/config -d @${path.module}/kong.yml -H "Content-Type: application/json"
EOT
    interpreter = ["/bin/bash", "-c"]
  }
}
