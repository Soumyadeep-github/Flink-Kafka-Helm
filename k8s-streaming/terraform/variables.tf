variable "namespace_streaming" {
  description = "Namespace for Kafka and Flink resources"
  type        = string
  default     = "streaming"
}
variable "namespace_cert_manager" {
  description = "Namespace for cert-manager"
  type        = string
  default     = "cert-manager"
}
variable "kafka_replicas" {
  description = "Number of Kafka broker replicas"
  type        = number
  default     = 3
}
variable "zookeeper_replicas" {
  description = "Number of ZooKeeper replicas"
  type        = number
  default     = 3
}
variable "kafka_topic_partitions" {
  description = "Partitions for the sample Kafka topic"
  type        = number
  default     = 1
}
variable "kafka_topic_replicas" {
  description = "Replication factor for the sample Kafka topic"
  type        = number
  default     = 1
}
variable "kafka_ui_replicas" {
  description = "Replicas for Kafka UI"
  type        = number
  default     = 1
}
variable "kafka_ui_image" {
  description = "Docker image for Kafka UI"
  type        = string
  default     = "provectuslabs/kafka-ui:latest"
}
variable "flink_image" {
  description = "Flink Docker image for session cluster"
  type        = string
  default     = "flink:1.17"
}
variable "flink_version" {
  description = "Flink version identifier for the operator"
  type        = string
  default     = "v1_17"
}
variable "flink_jobmanager_memory" {
  description = "Memory for Flink JobManager"
  type        = string
  default     = "1024m"
}
variable "flink_jobmanager_cpu" {
  description = "CPU for Flink JobManager"
  type        = number
  default     = 1
}
variable "flink_taskmanager_memory" {
  description = "Memory for Flink TaskManager"
  type        = string
  default     = "1024m"
}
variable "flink_taskmanager_cpu" {
  description = "CPU for Flink TaskManager"
  type        = number
  default     = 1
}
variable "flink_task_slots" {
  description = "Number of task slots per TaskManager"
  type        = number
  default     = 2
}

variable "flink_session_service_account_name" {
  description = "ServiceAccount used by the Flink session cluster"
  type        = string
  default     = "streaming-session-sa"
}
variable "kafka_cluster_name" {
  description = "The name of the Strimzi Kafka cluster (without the '-cluster' suffix)"
  type        = string
  default     = "streaming"
}
