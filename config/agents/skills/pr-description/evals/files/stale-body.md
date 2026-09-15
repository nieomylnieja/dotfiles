## Motivation

The command reference duplicated CLI help and required separate updates.

## Summary

Added deterministic JSON export of public commands and release-driven documentation updates. Rebased onto the latest main.

## Related Changes

The documentation consumer must support schema version 2 before the release dispatcher is enabled.

## Testing

Covered deterministic output and omission of hidden commands with offline tests. Live release-to-documentation synchronization has not been exercised.
