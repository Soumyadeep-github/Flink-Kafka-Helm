resource "null_resource" "k8s_role_apply" {
  depends_on = [kubernetes_namespace.streaming]
    provisioner "local-exec" {
        command     = <<-EOT
              kubectl apply -f ${path.module}/../helm/streaming/templates/flink-rbac.yaml
              EOT
        interpreter = ["/bin/bash", "-c"]
    }
}


# resource "null_resource" "cleanup_streaming_ns" {
#   provisioner "local-exec" {
#     command     = <<-EOT
#       # kubectl patch namespace ${var.namespace_streaming} -p '{"metadata":{"finalizers":[]}}' --type=merge || true
#       kubectl delete all --all -n ${var.namespace_streaming} --ignore-not-found || true
#       kubectl delete namespace ${var.namespace_streaming} --ignore-not-found || true
#     EOT
#     interpreter = ["/bin/bash", "-c"]
#   }
# }

# ─── 1️⃣ CREATE 'streaming' namespace ────────────────────────────────────────────
resource "kubernetes_namespace" "streaming" {
  metadata {
    name = var.namespace_streaming
  }
}

resource "null_resource" "install_cert_manager" {
  depends_on = [kubernetes_namespace.streaming]
  provisioner "local-exec" {
    command     = "kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.8.2/cert-manager.yaml"
    interpreter = ["/bin/bash", "-c"]
  }
}
resource "null_resource" "wait_for_cert_manager" {
  depends_on = [null_resource.install_cert_manager, kubernetes_namespace.streaming]
  provisioner "local-exec" {
    command     = <<-EOT
      kubectl rollout status deployment/cert-manager -n ${var.namespace_cert_manager} --timeout=120s
      kubectl rollout status deployment/cert-manager-webhook -n ${var.namespace_cert_manager} --timeout=120s
      kubectl rollout status deployment/cert-manager-cainjector -n ${var.namespace_cert_manager} --timeout=120s
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "null_resource" "metallb_crds" {
  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/crd/bases/metallb.io_ipaddresspools.yaml  || true
      kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/crd/bases/metallb.io_l2advertisements.yaml  || true
    EOT
    interpreter = ["/bin/bash","-c"]
  }
}

# resource "helm_release" "metallb" {
#   name       = "metallb"
#   repository = "https://metallb.github.io/metallb"
#   chart      = "metallb"
#   version    = "0.13.10"      # or latest
#   namespace  = "metallb-system"
#   create_namespace = true
#   dependency_update = true
#   cleanup_on_fail = true
#   replace = true
#   skip_crds = true
#   # force_update = true
#
#   depends_on = [
#         null_resource.metallb_crds
#     ]
# }
#
# resource "null_resource" "wait_for_metallb" {
#   depends_on = [ helm_release.metallb ]
#   provisioner "local-exec" {
#     command = <<-EOT
#       kubectl rollout status deployment/metallb-controller   -n metallb-system --timeout=120s
#       kubectl rollout status daemonset/metallb-speaker       -n metallb-system --timeout=120s
#     EOT
#     interpreter = ["/bin/bash", "-c"]
#   }
# }

resource "null_resource" "wait_for_metallb_webhook" {
  depends_on = [ null_resource.install_metallb ]
  provisioner "local-exec" {
    interpreter = ["/bin/bash","-c"]
    command     = <<-EOT
      kubectl rollout status deployment/controller   -n metallb-system --timeout=120s
      kubectl rollout status daemonset/speaker       -n metallb-system --timeout=120s
    EOT
  }
}

resource "null_resource" "apply_metallb_pool" {
  depends_on = [ null_resource.wait_for_metallb_webhook ]
  provisioner "local-exec" {
    interpreter = ["/bin/bash","-c"]
    command     = "kubectl apply -f ${path.module}/../helm/streaming/templates/metallb-pool.yaml"
  }
}


resource "null_resource" "install_metallb" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash","-c"]
    command     = <<-EOT
      # 1) CRDs
      kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/crd/bases/metallb.io_ipaddresspools.yaml
      kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/crd/bases/metallb.io_l2advertisements.yaml

      # 2) Controller & Speaker
      kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml
    EOT
  }
}
#
# resource "null_resource" "apply_metallb_pool" {
#   depends_on = [ null_resource.install_metallb ]
#   provisioner "local-exec" {
#     interpreter = ["/bin/bash","-c"]
#     command     = "kubectl apply -f ${path.module}/../helm/streaming/templates/metallb-pool.yaml"
#   }
# }
#
#
# resource "null_resource" "apply_metallb_pool" {
#   depends_on = [null_resource.wait_for_metallb]
#   provisioner "local-exec" {
#     interpreter = ["/bin/bash","-c"]
#     command     = <<-EOT
#       # now your own pool + L2Advertisement
#       kubectl apply -f ${path.module}/../helm/streaming/templates/metallb-pool.yaml
#     EOT
#   }
# }



# ─── INSTALL Strimzi Kafka Operator ─────────────────────────────────────────────
resource "null_resource" "install_strimzi" {
  depends_on = [
    null_resource.wait_for_cert_manager,
    null_resource.apply_metallb_pool,
    kubernetes_namespace.streaming,
  ]
  # provisioner "local-exec" {
  #   command     = <<-EOT
  #     kubectl wait --for=condition=Established namespace/${var.namespace_streaming} --timeout=60s
  #     curl -L "https://strimzi.io/install/latest?namespace=${var.namespace_streaming}" \
  #       | sed 's/namespace:.*/namespace: ${var.namespace_streaming}/' \
  #       | kubectl apply -f -
  #   EOT
  #   interpreter = ["/bin/bash", "-c"]
  # }
  provisioner "local-exec" {
    command = <<-EOT
        kubectl get namespace ${var.namespace_streaming} >/dev/null
        curl -L \
            https://github.com/strimzi/strimzi-kafka-operator/releases/download/0.45.0/strimzi-cluster-operator-0.45.0.yaml \
            | kubectl apply -n ${var.namespace_streaming} -f -

    EOT
    interpreter = ["/bin/bash","-c"]
  }
}
resource "null_resource" "wait_for_strimzi" {
  depends_on = [null_resource.install_strimzi, kubernetes_namespace.streaming]
  provisioner "local-exec" {
    command     = "kubectl rollout status deployment/strimzi-cluster-operator -n ${var.namespace_streaming} --timeout=120s"
    interpreter = ["/bin/bash", "-c"]
  }
}

# ─── INSTALL Flink Operator CRDs & Operator ──────────────────────────────────────
resource "null_resource" "install_flink_crds" {
  depends_on = [null_resource.wait_for_cert_manager, kubernetes_namespace.streaming]
  provisioner "local-exec" {
    command     = <<-EOT
      helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.11.0/
      helm repo update
      helm show crds flink-operator-repo/flink-kubernetes-operator > flink-crds.yaml
      kubectl apply -f flink-crds.yaml
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}
resource "null_resource" "install_flink_operator" {
  depends_on = [null_resource.install_flink_crds]
  provisioner "local-exec" {
    command     = <<-EOT
      helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.11.0/
      helm repo update

      helm upgrade --install flink-operator flink-operator-repo/flink-kubernetes-operator \
        --namespace ${var.namespace_streaming} \
        --create-namespace \
        -f ${path.module}/../helm/streaming/values.yaml
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}
resource "null_resource" "wait_for_flink_operator" {
  depends_on = [null_resource.install_flink_operator]
  provisioner "local-exec" {
    command     = "kubectl rollout status deployment/flink-kubernetes-operator -n ${var.namespace_streaming} --timeout=120s"
    interpreter = ["/bin/bash", "-c"]
  }
}


# ─── DEPLOY umbrella Helm chart ───────────────────────────────────────────────────
resource "helm_release" "streaming" {
  name              = "streaming"
  chart             = "${path.module}/../helm/streaming"
  namespace         = var.namespace_streaming
  create_namespace  = false
  dependency_update = true
  # force_update      = true
  cleanup_on_fail   = true



  depends_on = [
    null_resource.wait_for_strimzi,
    null_resource.install_flink_crds,
    null_resource.install_flink_operator,
    null_resource.wait_for_flink_operator,
    null_resource.k8s_role_apply,
    null_resource.apply_metallb_pool
    # kubernetes_role.flink_session_ha,
    # kubernetes_role_binding.flink_session_ha_binding
  ]

}



