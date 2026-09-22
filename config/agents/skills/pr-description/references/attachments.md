# PR attachments

Upload images before reviewing the final body so the review covers the exact attachment URLs.
For draft-only requests, keep images local until publication is authorized.
Apply the skill's source gate to image content before uploading it.

## Upload

GitHub CLI supports [`--attach` on PR commands][cli-docs], but that flag rewrites
the body during publication. This skill reviews the final body first, so upload
separately and insert the returned URLs before the publication gate.

For GitHub.com, `gh api` can use the same endpoint as the
[GitHub CLI attachment uploader][uploader-source]. This also works with older
CLI versions that lack `--attach`.
Use the existing GitHub login with write access to the target repository.

This Bash example uploads a PNG. Replace the repository and local file path:

```bash
repo='OWNER/REPO'
image='/absolute/path/to/screenshot.png'
repository_id="$(gh api "repos/$repo" --jq '.id')"
upload_url='https://uploads.github.com/user-attachments/assets'
upload_url+="?name=screenshot.png&content_type=image%2Fpng&repository_id=$repository_id"
attachment_url="$(
  gh api --method POST "$upload_url" \
    -H 'Content-Type: application/octet-stream' \
    -H 'Accept: application/vnd.github+json' \
    --input "$image" --jq '.url'
)"
```

Keep the file bytes in `--input` and the metadata in the query string.
For another file type or name, change and URL-encode the query values.
Keep a local mapping from each original file to its returned URL.

## Review and verify

1. Verify each uploaded image with an authenticated download before reviewing the body:

   ```bash
   downloaded="$(mktemp)"
   gh api --method GET "$attachment_url" \
     -H 'Accept: application/octet-stream' >"$downloaded" &&
     cmp "$image" "$downloaded"
   ```

2. Insert the returned URLs into the complete body, with meaningful alt text and captions.
   Run the skill's publication gate on that exact body, then publish it with `--body-file`.
3. Verify every image after publication. For a public repository, check without authentication:

   ```bash
   curl --location --fail --silent --show-error \
     --output "$downloaded" "$attachment_url" &&
     cmp "$image" "$downloaded"
   ```

   An anonymous download can return 404 before the attachment appears in a published PR body.
   Confirm an authenticated download first, then repeat the anonymous check after publication.
   For private repositories, verify with authorized access instead; see [GitHub attachment visibility][file-docs].
4. When migrating tracked screenshots, verify the new links before removing their repository copies.
   Check for other references before removing files. Keep images required by repository documentation.
   Use the authorized commit and push workflow for any removals.

[cli-docs]: https://docs.github.com/en/github-cli/github-cli/attaching-files-with-github-cli
[uploader-source]: https://github.com/cli/cli/blob/v2.99.0/internal/attachments/client.go
[file-docs]: https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/attaching-files
