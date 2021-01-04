#!/bin/bash

set -o errtrace
set -o pipefail

KAFKA_PATH=$HOME/kafka_2.12-2.5.0
KAFKA_PAYLOADS_PATH=$HOME/Downloads/jsons/kafka
ACTIONS=("consume" "produce" "create" "start" "topics")

main() {
  while getopts 'cptsld' flag; do
    case "${flag}" in
    c) create ;;
    p) produce ;;
    t) topics ;;
    s) start ;;
    l) consume ;;
    d) delete ;;
    *) default ;;
    esac
    exit
  done

  default
}

default() {
  case "$(echo "${ACTIONS[*]}" | tr " " "\n" | fzf)" in
  "consume") consume ;;
  "produce") produce ;;
  "create") create ;;
  "topics") topics ;;
  "delete") delete ;;
  "start") start ;;
  esac
}

consume() {
  topics | xargs "$KAFKA_PATH"/bin/kafka-console-consumer.sh --zookeeper localhost:2181 --topic
}

produce() {
  topic=$(topics)
  ls "$KAFKA_PAYLOADS_PATH" | fzf --preview "cat $KAFKA_PAYLOADS_PATH/{} | tr -d '#' | jq -C" | xargs -I {} cat "$KAFKA_PAYLOADS_PATH"/{} |
    "$KAFKA_PATH"/bin/kafka-console-producer.sh --zookeeper localhost:2181 --topic "$topic" --property "parse.key=true" --property "key.separator=#"
}

create() {
  read -r -p "provide topic name: " topicName
  "$KAFKA_PATH"/bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic "$topicName"
}

topics() {
  "$KAFKA_PATH"/bin/kafka-topics.sh --zookeeper localhost:2181 --list | rg -v TABLE | fzf
}

start() {
  case "$(printf "kafka\nzookeeper\nredis" | fzf)" in
  kafka)
    "$KAFKA_PATH"/bin/kafka-server-start.sh "$KAFKA_PATH"/config/server.properties
    ;;
  zookeeper)
    "$KAFKA_PATH"/bin/zookeeper-server-start.sh "$KAFKA_PATH"/config/zookeeper.properties
    ;;
  redis)
    docker-compose -f "$HOME/Downloads/redis.yaml" up --scale redis-sentinel=3 -d
    ;;
  esac
}

delete() {
  topic=$(topics)
  "$KAFKA_PATH"/bin/kafka-topics.sh --zookeeper localhost:2181 --topic "$topic" --delete
}

main "$@"
