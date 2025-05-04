# pick your project & zone first:
GCP_PROJECT="data-bolt-409915"
gcloud config set project $GCP_PROJECT
gcloud config set compute/zone us-central1-a

# create a 3-node (or more) cluster with Workload Identity enabled:
gcloud container clusters create streaming-cluster \
  --num-nodes=3 \
  --machine-type=e2-standard-4 \
  --workload-pool=$GCP_PROJECT.svc.id.goog

# enable the GCS CSI driver in your cluster
gcloud services enable storage.googleapis.com

# install the GCS CSI driver via its Helm chart
helm repo add gcs-csi-driver https://storage.googleapis.com/gcp-csi-charts
helm repo update
kubectl create namespace kube-system
helm upgrade --install gcs-csi-driver gcs-csi-driver/gcs-csi-driver \
  --namespace kube-system \
  --set workloadIdentity.enabled=true \
  --set gcp.project=$GCP_PROJECT

kubectl apply -f gcs-sc.yaml


# make sure the streaming namespace exists
kubectl create namespace streaming || true

# install cert-manager
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.8.2/cert-manager.yaml
kubectl rollout status deploy/cert-manager          -n cert-manager --timeout=120s
kubectl rollout status deploy/cert-manager-webhook  -n cert-manager --timeout=120s
kubectl rollout status deploy/cert-manager-cainjector -n cert-manager --timeout=120s

# install Strimzi (you can also do via helm if you prefer)
kubectl apply -f https://strimzi.io/install/latest?namespace=streaming

# wait for operator
kubectl rollout status deploy/strimzi-cluster-operator -n streaming --timeout=120s

# finally, your umbrella chart
helm upgrade --install streaming ./helm/streaming \
  --namespace streaming \
  -f ./helm/streaming/values.yaml

# Kafka UI
kubectl port-forward svc/streaming-kafka-ui 8080:8080 -n streaming

# Flink Web UI
kubectl port-forward svc/streaming-session-rest 8081:8081 -n streaming

# Produce / consume a message
# (you need kubectl exec into a Kafka pod)
POD=$(kubectl get pods -l strimzi.io/name=streaming-cluster-kafka-0 -n streaming -o name)
kubectl exec -it $POD -n streaming -- \
  kafka-console-producer.sh \
    --broker-list localhost:9092 \
    --topic input-topic

kubectl exec -it $POD -n streaming -- \
  kafka-topics.sh \
    --broker-list localhost:9092 \
    --list

# in another window:
kubectl exec -it $POD -n streaming -- \
  kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 \
    --topic input-topic \
    --from-beginning

kubectl exec -ti streaming-cluster-kafka-0 -n streaming -- \
  bin/kafka-console-producer.sh \
    --broker-list streaming-cluster-kafka-bootstrap:9092 \
    --topic input-topic

kubectl exec -ti streaming-cluster-kafka-0 -n streaming -- \
  bin/kafka-topics.sh \
    --bootstrap-server streaming-cluster-kafka-bootstrap:9092 \
    --list

kubectl exec -ti streaming-cluster-kafka-0 -n streaming -- \
  bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --list

kubectl exec -ti streaming-cluster-kafka-0 -n streaming -- \
  bin/kafka-topics.sh \
    --bootstrap-server 192.168.65.3:9094 \
    --list

kafka-topics.sh \
    --bootstrap-server 192.168.65.3:9094 \
    --list \
    --timeout



kubectl exec -ti streaming-cluster-kafka-0 -n streaming -- \
  bin/kafka-console-consumer.sh \
    --bootstrap-server streaming-cluster-kafka-bootstrap:9092 \
    --topic input-topic \
    --from-beginning

