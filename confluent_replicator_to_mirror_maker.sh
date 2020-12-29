!/bin/bash

# example offset format from REPLICATOR_OFFSET_TOPIC
# ["replicator",{"topic":"foo","partition":2}]	{"offset":1}
# ["replicator",{"topic":"foo","partition":0}]  {"offset":3}

# example offset format from MM2_OFFSET_TOPIC
# ["MirrorSourceConnector",{"cluster":"primary","partition":1,"topic":"foo”}]    {"offset":10}
# ["MirrorSourceConnector",{"cluster":"primary","partition":0,"topic":"foo”}]    {"offset":13}

# REPLACE ME, this should be the cluster alias of primary/source cluster set in mirrormaker config
MM2_CLUSTER_ALIAS="primary"
MM2_CONSUMER_GROUP="MirrorSourceConnector"
MM2_OFFSET_TOPIC="mm2-offsets.primary.internal"

# REPLACE ME, this should be the list (comma separated) of kafka broker url on secondary/target cluster
BROKER_LIST="localhost:9092"

REPLICATOR_OFFSET_TOPIC="connect-offsets"

SCRIPT_GROUP_ID="test"
SCRIPT_CONSUME_TIMEOUT_MS=1000

IFS=$'\n'

# consume new "offset" messages from REPLICATOR_OFFSET_TOPIC, truncate to only keep "partition", "topic" and "offset" info, then save to 'output' array 
# to exit from blocking kafka-console-consumer.sh, it is expected to see Timeout Exception after running the command with --timeout-ms=SCRIPT_CONSUME_TIMEOUT_MS
output=( $(kafka-console-consumer.sh --bootstrap-server ${BROKER_LIST} --topic ${REPLICATOR_OFFSET_TOPIC} --consumer-property group.id=${SCRIPT_GROUP_ID} --timeout-ms=${SCRIPT_CONSUME_TIMEOUT_MS} --property print.key=true |  cut -d '{' -f 2-3) )
echo "processing ${#output[@]} messages from connect-offsets topic"

for (( i=0; i<${#output[@]}; i++ ))
do
    str="[\"${MM2_CONSUMER_GROUP}\",{\"cluster\":\"${MM2_CLUSTER_ALIAS}\",${output[$i]}"

    # replace space with % as key-value delimiter
    produce_str=${str//$'\t'/%}

    echo $produce_str
    # produce newly formatted "offset" messages to MM2_OFFSET_TOPIC
    echo $produce_str | kafka-console-producer.sh --broker-list ${BROKER_LIST} --topic ${MM2_OFFSET_TOPIC} --property "parse.key=true" --property "key.separator=%"
done
