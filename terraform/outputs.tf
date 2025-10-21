output "kafka_service" {
  value = "Kafka running in namespace kafka"
}

output "producer_url" {
  value = "http://localhost:30010/api/prod/event"
}

output "consumer_logs_cmd" {
  value = "kubectl logs -l app=consumer -n default"
}

output "jenkins_url" {
  value = "http://localhost:8080"
}

output "argocd_url" {
  value = "http://localhost:8081"
}
