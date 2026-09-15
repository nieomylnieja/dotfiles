# Review evidence

This is an offline fixture for the public repository `example/reference-export`.
The reviewed base is `1111111111111111111111111111111111111111`.
The reviewed head is `2222222222222222222222222222222222222222`.
The repository template permits Motivation, Summary, Related Changes, and Testing.

The user requested generated command-reference data to replace duplicated CLI help.
The diff added a deterministic JSON exporter, omitted hidden commands, and retained
short descriptions. Official releases now trigger the documentation consumer.
The consumer must support schema version 2 before the dispatcher is enabled.
These are complete requirements for this fixture.

Representative diff:

```diff
+ exportCommandTree({schemaVersion: 2, includeHidden: false, sort: true});
+ onOfficialRelease(dispatchReferenceUpdate);
+ test("deterministic export", comparesRepeatedExports);
+ test("hidden commands are omitted", checksPublicCommands);
```

Recorded verification: both named tests passed against the reviewed head.
The live release-to-documentation path has not been exercised.
No private names or credentials occur in the supplied sources.

The author also merged a newer base, resolved a generated-file conflict, and
configured an App variable. An old local container test failed before the final
revision. These facts do not change the delivered behavior or current review risk.
