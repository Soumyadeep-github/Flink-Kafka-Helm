resource "null_resource" "k8s_role_apply" {
  depends_on = [kubernetes_namespace.streaming]
    provisioner "local-exec" {
        command     = <<-EOT
              kubectl apply -f ${path.module}/../helm/streaming/templates/flink-rbac.yaml
              EOT
        interpreter = ["/bin/bash", "-c"]
    }
}


resource "null_resource" "cleanup_streaming_ns" {
  provisioner "local-exec" {
    command     = <<-EOT
      # kubectl patch namespace ${var.namespace_streaming} -p '{"metadata":{"finalizers":[]}}' --type=merge || true
      kubectl delete all --all -n ${var.namespace_streaming} --ignore-not-found || true
      kubectl delete namespace ${var.namespace_streaming} --ignore-not-found || true
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

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

# ─── INSTALL Strimzi Kafka Operator ─────────────────────────────────────────────
resource "null_resource" "install_strimzi" {
  depends_on = [null_resource.wait_for_cert_manager, kubernetes_namespace.streaming]
  provisioner "local-exec" {
    command     = <<-EOT
      kubectl wait --for=condition=Established namespace/${var.namespace_streaming} --timeout=60s
      curl -L "https://strimzi.io/install/latest?namespace=${var.namespace_streaming}" \
        | sed 's/namespace:.*/namespace: ${var.namespace_streaming}/' \
        | kubectl apply -f -
    EOT
    interpreter = ["/bin/bash", "-c"]
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
    null_resource.k8s_role_apply
    # kubernetes_role.flink_session_ha,
    # kubernetes_role_binding.flink_session_ha_binding
  ]

  set {
    name  = "namespace"
    value = var.namespace_streaming
  }
  set {
    name  = "kafka.replicas"
    value = var.kafka_replicas
  }
  set {
    name  = "kafka.zookeeperReplicas"
    value = var.zookeeper_replicas
  }
  set {
    name  = "kafka.topic.partitions"
    value = var.kafka_topic_partitions
  }
  set {
    name  = "kafka.topic.replicas"
    value = var.kafka_topic_replicas
  }
  set {
    name  = "kafkaUI.replicas"
    value = var.kafka_ui_replicas
  }
  set {
    name  = "kafkaUI.image"
    value = var.kafka_ui_image
  }
  set {
    name  = "flinkSession.image"
    value = var.flink_image
  }
  set {
    name  = "flinkSession.flinkVersion"
    value = var.flink_version
  }
  set {
    name  = "flinkSession.jobManager.memory"
    value = var.flink_jobmanager_memory
  }
  set {
    name  = "flinkSession.jobManager.cpu"
    value = var.flink_jobmanager_cpu
  }
  set {
    name  = "flinkSession.taskManager.memory"
    value = var.flink_taskmanager_memory
  }
  set {
    name  = "flinkSession.taskManager.cpu"
    value = var.flink_taskmanager_cpu
  }
  set {
    name  = "flinkSession.taskSlots"
    value = var.flink_task_slots
  }
  set {
    name  = "flinkSession.serviceAccount.create"
    value = "true" # or "false" if you want to use a pre-existing SA
  }
  set {
    name  = "flinkSession.serviceAccount.name"
    value = "streaming-session-sa"
  }
}



