Offset Migration Tool: from Confluent Replicator to MirrorMaker 2
============

Why need this
-----------------
Recently users from the community have been migrating from Confluent Replicator (an enterprise commercial “cross-cluster” replication tool) to MirrorMaker and [they were facing the following problem](https://lists.apache.org/thread.html/r928922036031df0db11a873ac076dae071a57a7f638bcb5911d34580%40%3Cusers.kafka.apache.org%3E):

> messages which are already replicated by Confluent Replicator is getting replicated again when the Mirror Maker is started on the same topic. This should not happen as messages are getting duplicated at the target cluster.

As Confluent Replicator and MirrorMaker are both built as “connector” of Kafka Connect, or more specifically Source Connector, they maintain an internal “offset topic” to store the consumer offsets, which track the consumption progress and are only loaded when Confluent Replicator or MirrorMaker restarts.

For Confluent Replicator, offset topic defaults to “connect-offsets”. While it is named “mm2-offsets.primary.internal” in MirrorMaker,
Another difference is the content format. For Confluent Replicator, the message content looks like:

> [“replicator”,{“topic”:”foo”,”partition”:2}] {“offset”:1}

(“replicator” is the default consumer group name of Confluent Replicator)

For MirrorMaker, the message context looks like:

> ["MirrorSourceConnector",{"cluster":"primary","partition":1,"topic":"foo”}] {"offset":10}

(“MirrorSourceConnector” is the default consumer group name of MirrorMaker)

Resolution
-----------------

It may sound feasible to tweak open-source MirrorMaker using different offset topic and adapt to a different message format. But from practice, this requires in-depth knowledge and code change of MirrorMaker.
As a community thread discussed, a non-intrusive, simple, working solution:

> For each topic and partition, whenever a new message is replicated a new message with same key but increased offset is produced to the connect-offsets topic, convert the key of this message to Mirror Maker format and produce it in the internal "offset topic" of Mirror Maker.

> Key : ["replicator-group",{"topic":"TEST","partition":0}] 
> Value: {"offset":24}

> After posting the message, once the mirror maker is restarted, it will read the internal topic to get the latest offset of that topic for which the message has to be replicated and this way we can ensure no duplicate messages are replicated.

> Key: ["mirrormaker-group",{"cluster":"primary","partition":0,"topic":"TEST"}]
> Value: {"offset":24}

The [script](https://github.com/ning2008wisc/mm2-migration/blob/master/confluent_replicator_to_mirror_maker.sh) in this repo leverages `kafka-console-consumer.sh` and `kafka-console-producer.sh` [(part of Apache Kafka)](https://github.com/apache/kafka/tree/trunk/bin), leading to several benefits over other options [(kafkacat)](https://github.com/edenhill/kafkacat):

- no third-party dependency
- programming language and OS agnostic
- better integrate with Kafka (as kafka-console-*.sh should always work)
- easy debug, execution and monitoring, e.g. corn job
