.PHONY: build install clean test

APP_NAME := llmcommit
LDFLAGS := -s -w

.PHONY: build
build:
	go build -ldflags="$(LDFLAGS)" -o $(APP_NAME) ./cmd/$(APP_NAME)/

.PHONY: install
install:
	go install -ldflags="$(LDFLAGS)" ./cmd/$(APP_NAME)/
