## Motivation

The command reference duplicated CLI help and required separate updates.

## Summary

- Added deterministic JSON export of public commands.
- Merged main at 3333333333333333333333333333333333333333 and resolved generated-file conflicts.
- Configured the App variable and reran the build after lunch.

## Related Changes

The documentation consumer must support schema version 2 before the release dispatcher is enabled.

## Testing

- Covered deterministic output and omission of hidden commands with offline tests.
- Ran the formatter, build, and spell checker.
- An earlier local container build failed before the final revision.
- Live release-to-documentation synchronization has not been exercised.
