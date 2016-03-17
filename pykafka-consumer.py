from pykafka import KafkaClient

client = KafkaClient(hosts='10.68.83.119:2181')
print client
print client.topics

topic = client.topics['eaither.test']
consumer = topic.get_simple_consumer()


for msg in consumer:
    print msg


