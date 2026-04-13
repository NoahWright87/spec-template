# Report Template: Technical (Detailed)

This file is a schema reference and annotated example for the `SprintReport` JSON format consumed by [repo-report](https://github.com/NoahWright87/repo-report). Scout reads this file to understand the expected structure. Teams can add, remove, or reorder themes to match their reporting needs.

## Schema Reference

```jsonc
{
  // ── Meta ────────────────────────────────────────────────────────────────
  // Required. Describes the report itself.
  "meta": {
    "title": "Progress Report — 2026-04-12",     // Report title shown in header
    "team": "my-repo",                            // Team or repo name
    "dateRange": {
      "start": "2026-03-29",                      // Baseline date (last report or 30-day lookback)
      "end": "2026-04-12"                         // Report date (today)
    },
    "repos": [
      { "name": "my-repo", "url": "https://github.com/owner/my-repo" }
    ],
    "generatedAt": "2026-04-12T10:00:00Z"        // ISO 8601 timestamp
  },

  // ── Summary Slide ────────────────────────────────────────────────────────
  // Required. The first slide — high-level metrics and narrative.
  "summary": {
    "type": "summary",
    "slug": "summary",
    "title": "Summary",

    // Key metrics shown as stat cards at the top of the slide.
    // `change` is optional percentage change vs. prior period.
    // `lowerIsBetter: true` inverts color logic (green = down, e.g. for incidents).
    "stats": [
      { "label": "PRs Merged",     "value": 8,  "icon": "🔀" },
      { "label": "Issues Closed",  "value": 5,  "icon": "✅" },
      { "label": "Open PRs",       "value": 2,  "icon": "📬" },
      { "label": "Filed Issues",   "value": 11, "icon": "📋" }
    ],

    // 3-5 sentence narrative. Weave in key metrics naturally.
    // What shipped? What's active? Any notable patterns or blockers?
    "highlights": [
      "Eight PRs merged this period, shipping improvements across the agent worker infrastructure and documentation.",
      "The multi-agent fleet manager architecture landed as the major milestone of the period.",
      "Two PRs remain open — both are in review and expected to close next cycle.",
      "Eleven filed issues are queued for upcoming work, with four sized at M or smaller."
    ],

    // Detail widgets shown below the summary content.
    // contributor-list: team activity breakdown derived from merged PRs and git log.
    "detailBlocks": [
      {
        "type": "contributor-list",
        "title": "Contributors",
        "contributors": [
          {
            "name": "Alice Chen",
            "username": "achen",
            "commits": 24,
            "prsMerged": 4
          },
          {
            "name": "Bob Park",
            "username": "bpark",
            "commits": 11,
            "prsMerged": 3
          }
        ]
      }
    ]
  },

  // ── Themes ───────────────────────────────────────────────────────────────
  // Each theme becomes a slide. Group completed PRs by area or initiative.
  // status: "completed" | "in-progress" | "blocked"
  "themes": [
    // ── Completed theme (one per logical work area) ──────────────────────
    {
      "type": "theme",
      "slug": "agent-infrastructure",
      "title": "Agent Infrastructure",
      "status": "completed",
      "description": "Multi-agent worker architecture and fleet manager.",

      // progress / problems / plans: three-column layout on the slide.
      // Each column is optional — omit if empty.
      "progress": {
        "items": [
          { "text": "Fleet manager ships as composable task runner" },
          { "text": "Worker entrypoint refactored for multi-agent support" }
        ]
      },

      // Detail blocks shown below the slide content.
      // link-list: PRs, issues, commits, docs, or external links.
      "detailBlocks": [
        {
          "type": "link-list",
          "title": "Merged PRs",
          "links": [
            {
              "label": "Port multi-agent worker infrastructure from internal fork",
              "url": "https://github.com/owner/my-repo/pull/30",
              "type": "pr",
              "description": "Extracts fleet-manager logic into reusable composable tasks."
            },
            {
              "label": "Back-merge changes from work",
              "url": "https://github.com/owner/my-repo/pull/32",
              "type": "pr",
              "description": "Syncs upstream improvements from internal fork."
            }
          ]
        }
      ]
    },

    // ── In Progress theme ────────────────────────────────────────────────
    // Omit if no open PRs.
    {
      "type": "theme",
      "slug": "in-progress",
      "title": "In Progress",
      "status": "in-progress",
      "detailBlocks": [
        {
          "type": "link-list",
          "title": "Open PRs",
          "links": [
            {
              "label": "Add /what-now status assessment",
              "url": "https://github.com/owner/my-repo/pull/25",
              "type": "pr",
              "description": "Branch: feature/what-now — in review"
            }
          ]
        }
      ]
    },

    // ── Upcoming theme ───────────────────────────────────────────────────
    // Open issues labeled `intake:filed`. Omit if none.
    // Show size label (size:S, size:M, etc.) in description if present.
    {
      "type": "theme",
      "slug": "upcoming",
      "title": "Upcoming",
      "status": "in-progress",
      "detailBlocks": [
        {
          "type": "link-list",
          "title": "Filed Issues",
          "links": [
            {
              "label": "Add retry logic to agent worker entrypoint",
              "url": "https://github.com/owner/my-repo/issues/18",
              "type": "issue",
              "description": "size: S"
            },
            {
              "label": "Support parallel theme generation in scout",
              "url": "https://github.com/owner/my-repo/issues/21",
              "type": "issue",
              "description": "size: M"
            }
          ]
        }
      ]
    }
  ]
}
```
