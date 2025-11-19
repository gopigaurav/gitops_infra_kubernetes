variable "cluster_name" {
  default = "dev-cluster"
}

variable "namespace" {
  default = "default"
}

variable "ambient_mode_enabled" {
  type    = bool
  default = false
}

variable "letsencrypt_email" {
  type    = string
  default = "admin@example.com"
}
