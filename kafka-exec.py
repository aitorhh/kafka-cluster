from kafka import KafkaConsumer

consumer = KafkaConsumer('eaither.test', bootstrap_servers='10.68.83.119:9092')

for msg in consumer:
    print msg


