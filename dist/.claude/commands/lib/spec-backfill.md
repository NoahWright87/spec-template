<!-- AUTO-GENERATED loader stub — do not edit.
     The full command lives in the spec-template source repo.
     To update this stub: run /respec -->

# /spec-backfill

This command is managed by [spec-template](https://github.com/NoahWright87/spec-template).

## Execute

1. Read `specs/.meta.json` and extract the `source` field (the source repo URL)
2. Construct the raw file URL: replace the GitHub URL with a raw content URL, targeting the `main` branch, path: `.claude/commands/lib/spec-backfill.md`
   - For `https://github.com/OWNER/REPO`, the raw URL is `https://raw.githubusercontent.com/OWNER/REPO/main/.claude/commands/lib/spec-backfill.md`
3. Use WebFetch to retrieve the full command file
4. Follow the fetched instructions exactly — they are the complete command
