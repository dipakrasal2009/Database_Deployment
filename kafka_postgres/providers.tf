# ===========================================
# Terraform Configuration
# ===========================================
terraform {
  # Require Terraform CLI version 1.0 or higher
  required_version = ">= 1.0"
  
  # Define required providers (plugins)
  required_providers {
    # Kubernetes provider (used to manage K8s resources directly)
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32.0"
    }

    # Helm provider (used to deploy Helm charts into Kubernetes/OpenShift)
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15.0"
    }
  }
}

# ===========================================
# Kubernetes Provider
# ===========================================
provider "kubernetes" {
  # Path to your kubeconfig file
  # This allows Terraform to talk to the Kubernetes / OpenShift cluster
  config_path = "~/.kube/config"
}

# ===========================================
# Helm Provider
# ===========================================
provider "helm" {
  kubernetes {
    # Use the same kubeconfig for Helm provider
    config_path = "~/.kube/config"
  }
  
  # Path to Helm registry configuration
  # This enables support for OCI-based Helm charts (Bitnami uses OCI registry)
  registry_config_path = "~/.config/helm/registry/config.json"
}
