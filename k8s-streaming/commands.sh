kubectl get pods -n streaming -w
# Check kafka UI
kubectl port-forward svc/kafka-ui 8080:8080 -n streaming
# Check Flink UI
kubectl port-forward svc/streaming-session-rest 8081:8081 -n streaming

kubectl delete role flink-session-configmaps -n streaming --ignore-not-found ;
kubectl delete rolebinding flink-session-configmaps-binding -n streaming --ignore-not-found

# Produce messages to the input topic
kubectl exec -ti streaming-cluster-kafka-0 -n streaming -- \
  bin/kafka-console-producer.sh \
    --broker-list streaming-cluster-kafka-bootstrap:9092 \
    --topic input-topic

# Produce messages to the input topic
kubectl exec -ti streaming-cluster-kafka-0 -n streaming -- \
  bin/kafka-topics.sh \
    --bootstrap-server streaming-cluster-kafka-bootstrap:9092 \
    --list

# Consume messages from the input topic
kubectl exec -ti streaming-cluster-kafka-0 -n streaming -- \
  bin/kafka-console-consumer.sh \
    --bootstrap-server streaming-cluster-kafka-bootstrap:9092 \
    --topic input-topic \
    --from-beginning \
    --timeout-ms 10000

# clean up
kubectl delete all --all -n streaming ; kubectl delete namespace streaming
kubectl delete all --all -n cert-manager ; kubectl delete namespace cert-manager

for i in cert-manager metallb-system; do
  kubectl delete all --all -n $i
  kubectl delete namespace $i
done

helm upgrade streaming k8s-streaming/helm/streaming \
  --namespace streaming \
  --reuse-values

kubectl auth can-i list configmaps \
  --as=system:serviceaccount:streaming::streaming-session-sa \
  -n streaming

kubectl auth can-i list configmaps \
  --as=system:serviceaccount:streaming::flink \
  -n streaming

kubectl run debug-shell3 -n streaming --rm -i --tty --image=bitnami/kubectl \
  --overrides='
{
  "spec": {
    "serviceAccountName": "streaming-session-sa"
  }
}
' -- bash

kubectl delete role flink-session-ha -n streaming --ignore-not-found
kubectl delete rolebinding flink-session-ha-binding -n streaming --ignore-not-found

kubectl auth can-i list pods --as=system:serviceaccount:streaming:streaming-session-sa -n streaming
kubectl auth can-i list configmaps --as=system:serviceaccount:streaming:streaming-session-sa -n streaming

kubectl delete role strimzi-cluster-operator -n streaming --ignore-not-found
kubectl delete rolebinding strimzi-cluster-operator-binding -n streaming --ignore-not-found