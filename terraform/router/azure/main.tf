terraform {
  required_version = ">= 0.12.0"
}

provider "azurerm" {
  version = "~> 1.37"
}

provider "http" {
  version = "~> 1.1"
}

provider "kubernetes" {
  version = "~> 1.11"
}

locals {
  tags = {
    System = "convox"
    Rack   = var.name
  }
}

module "nginx" {
  source = "../nginx"

  providers = {
    kubernetes = kubernetes
  }

  namespace = var.namespace
  rack      = var.name
}

resource "kubernetes_service" "router" {
  metadata {
    namespace = var.namespace
    name      = "router"
  }

  spec {
    type = "LoadBalancer"

    load_balancer_source_ranges = var.whitelist

    port {
      name        = "http"
      port        = 80
      protocol    = "TCP"
      target_port = 80
    }

    port {
      name        = "https"
      port        = 443
      protocol    = "TCP"
      target_port = 443
    }

    selector = module.nginx.selector
  }

  lifecycle {
    ignore_changes = [metadata[0].annotations]
  }
}

data "http" "alias" {
  url = "https://alias.convox.com/alias/${length(kubernetes_service.router.load_balancer_ingress) > 0 ? kubernetes_service.router.load_balancer_ingress.0.ip : ""}"
}
