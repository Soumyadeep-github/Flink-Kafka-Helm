from kafka import KafkaProducer
import json, time
from faker import Faker
import random

if __name__ == "__main__":
    # broker="streaming-cluster-kafka-bootstrap.streaming.svc.cluster.local:9092"
    # broker = ["192.168.65.240:9094"]
    broker = [
        "localhost:9092","localhost:9093","localhost:9094","127.0.0.1:9096"
    ]
    producer = KafkaProducer(bootstrap_servers=broker,
                             value_serializer=lambda v: json.dumps(v).encode('utf-8'))

    faker = Faker()

    while True:
        data = {
            "user": {
                "id": random.randint(1, 100),
                "name": faker.name(),
                "location": faker.city(),
            },
            "event": {
                "type": random.choice(["click", "purchase", "view"]),
                "timestamp": faker.unix_time(),
                "amount": round(random.uniform(10, 500), 2)
            }
        }
        producer.send("input-topic", value=data)
        print(f"Sent: {data}")
        time.sleep(1)
