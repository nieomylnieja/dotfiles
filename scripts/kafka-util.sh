#!/bin/bash

KAFKA_PATH=$HOME/kafka_2.12-2.5.0
ACTIONS=("consume" "produce" "create" "start" "topics")

main() {
  case "$(echo "${ACTIONS[*]}" | tr " " "\n" | fzf)" in
  "consume") consume ;;
  "produce") produce ;;
  "create") create ;;
  "topics") topics ;;
  "start") start ;;
  esac
}

consume() {
  topics | xargs "$KAFKA_PATH"/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic
}

produce() {
  echo "produce"
}

create() {
  echo "create"
}

topics() {
  "$KAFKA_PATH"/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list | fzf
}

start() {
  echo "start"
}

main "$@"
