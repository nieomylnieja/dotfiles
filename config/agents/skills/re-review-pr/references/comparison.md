# Compare the completed fresh review

Apply this workflow as the coordinator after the independent review. Compare its verified
findings with the supplied prior review and current threads at the exact current base/head.
Retain fresh coverage, checks, limitations, coordination, and adversarial records.

## Classify previous findings

Use current code and test evidence:

- `proved fixed`: the defect is absent and evidence exercises the fix.
- `not reproduced`: the fresh review did not report it, but no direct proof exists.
- `still present`: the defect remains.
- `intentionally rejected`: the thread records a reasoned decision not to change it.
- `regressed`: a previously resolved defect is present again.

Thread resolution is context, not proof that code is correct. Absence from a fresh stochastic
review is not proof of a fix. Verify a previous defect against current code even when the fresh
review did not report it. If confirmed, include it in the current findings before filtering.

## Filter for publication

For each independently verified current finding:

- keep new, still-present, orphaned, and regressed defects;
- mark a matching open thread as already tracked and exclude it from publishable `findings`;
- retain a present defect even if a matching thread is resolved;
- exclude an intentionally rejected suggestion unless new evidence invalidates the recorded decision.

Return only publishable findings in the final report's `findings` array. Preserve already-tracked
defects separately in `re_review.already_tracked`; an empty publishable array does not mean that
the code has no verified defects. Base the verdict on all verified current defects and material
limits, including those already tracked.

Set `base_commit_id` and `commit_id` to the current PR base and head OIDs. Add this optional
version-1 object with actual counts and prior metadata when available:

```json
{
  "re_review": {
    "previous_review_path": "<path or null>",
    "previous_commit_id": "<SHA or null>",
    "classification_counts": {
      "proved_fixed": 0,
      "not_reproduced": 0,
      "still_present": 0,
      "intentionally_rejected": 0,
      "regressed": 0
    },
    "already_tracked": []
  }
}
```

Return the filtered report to the main session with the separate comparison categories.
Keep inaccessible history and unresolved comparisons in the report's limitations.
