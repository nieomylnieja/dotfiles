# Configuration

Not everything can be easily configured declaratively.
This document lists manual steps for setting up Claude Code.

## Plugins

1. [pg-aiguide](https://github.com/timescale/pg-aiguide/tree/main?tab=readme-ov-file#-quickstart) for Postgres.
  ```
  claude plugin marketplace add timescale/pg-aiguide
  claude plugin install pg@aiguide
  ```
