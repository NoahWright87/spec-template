# Report Template: Summary (Stakeholder)

This file is a schema reference and annotated example for the `SprintReport` JSON format consumed by [repo-report](https://github.com/NoahWright87/repo-report). This template produces a concise stakeholder-level report focused on outcomes rather than technical detail — no contributor breakdown, fewer themes.

## Schema Reference

```jsonc
{
  "meta": {
    "title": "Progress Report — 2026-04-12",
    "team": "my-repo",
    "dateRange": {
      "start": "2026-03-29",
      "end": "2026-04-12"
    },
    "repos": [
      { "name": "my-repo", "url": "https://github.com/owner/my-repo" }
    ],
    "generatedAt": "2026-04-12T10:00:00Z"
  },

  "summary": {
    "type": "summary",
    "slug": "summary",
    "title": "Summary",

    // High-level outcome metrics — keep to 3-4 stats.
    "stats": [
      { "label": "Features Shipped", "value": 3,  "icon": "🚀" },
      { "label": "Bugs Fixed",       "value": 5,  "icon": "🐛" },
      { "label": "Open PRs",         "value": 2,  "icon": "📬" }
    ],

    // 3-5 sentences answering: "Are we on track? What got done? What's next?"
    // Avoid technical jargon — write for a non-engineering audience.
    "highlights": [
      "The team shipped three significant features this period, including the new multi-agent worker architecture.",
      "Five bug fixes landed, resolving the most-reported user-facing issues.",
      "Work is on track — two PRs are in review and expected to close next cycle."
    ],

    // No contributor-list for stakeholder reports — keep detailBlocks empty.
    "detailBlocks": []
  },

  "themes": [
    // ── What shipped — group by feature area or milestone ────────────────
    {
      "type": "theme",
      "slug": "what-shipped",
      "title": "What Shipped",
      "status": "completed",
      "description": "Completed features and improvements delivered this period.",
      "progress": {
        "items": [
          { "text": "Multi-agent fleet manager architecture" },
          { "text": "Improved CI/CD pipeline reliability" },
          { "text": "Documentation and onboarding improvements" }
        ]
      },
      "detailBlocks": [
        {
          "type": "link-list",
          "title": "Key PRs",
          "links": [
            {
              "label": "Port multi-agent worker infrastructure",
              "url": "https://github.com/owner/my-repo/pull/30",
              "type": "pr",
              "description": "Core architectural milestone for multi-agent support."
            }
          ]
        }
      ]
    },

    // ── In Progress ──────────────────────────────────────────────────────
    // Omit if no open PRs.
    {
      "type": "theme",
      "slug": "in-progress",
      "title": "In Progress",
      "status": "in-progress",
      "detailBlocks": [
        {
          "type": "link-list",
          "title": "Active Work",
          "links": [
            {
              "label": "Status assessment command",
              "url": "https://github.com/owner/my-repo/pull/25",
              "type": "pr",
              "description": "In review — expected next cycle."
            }
          ]
        }
      ]
    },

    // ── Coming up ────────────────────────────────────────────────────────
    // Open issues labeled `intake:filed`. Omit if none.
    {
      "type": "theme",
      "slug": "upcoming",
      "title": "Coming Up",
      "status": "in-progress",
      "detailBlocks": [
        {
          "type": "link-list",
          "title": "Queued Issues",
          "links": [
            {
              "label": "Add retry logic to agent worker",
              "url": "https://github.com/owner/my-repo/issues/18",
              "type": "issue",
              "description": "size: S"
            }
          ]
        }
      ]
    }
  ]
}
```
