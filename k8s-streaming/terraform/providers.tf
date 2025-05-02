terraform {
  required_providers {
    helm       = { source = "hashicorp/helm", version = "~>2.9" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~>2.23" }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}


provider "helm" {
  kubernetes { config_path = "~/.kube/config" }
}
provider "kubernetes" {
  config_path = "~/.kube/config"
}