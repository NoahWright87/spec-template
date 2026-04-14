# Report Template: Technical (Detailed)

Schema reference for the `SprintReport` JSON format consumed by [repo-report](https://github.com/NoahWright87/repo-report). Scout reads this file to understand the expected structure and field semantics. Replace `"..."` placeholders with real values from the pre-gathered data.

```jsonc
{
  "meta": {
    "title": "Progress Report — {date}",
    "team": "{repo-name}",
    "dateRange": { "start": "{baseline-date}", "end": "{date}" },
    "repos": [{ "name": "{repo-name}", "url": "https://github.com/{owner}/{repo-name}" }],
    "generatedAt": "{iso-timestamp}"
  },

  "summary": {
    "type": "summary",
    "slug": "summary",
    "title": "Summary",

    // Stat cards. `change` (optional) is a % change vs prior period.
    // `lowerIsBetter: true` inverts the color (green = down, e.g. for incidents).
    "stats": [
      { "label": "PRs Merged",   "value": 0, "icon": "🔀" },
      { "label": "Issues Closed","value": 0, "icon": "✅" },
      { "label": "Open PRs",     "value": 0, "icon": "📬" },
      { "label": "Filed Issues", "value": 0, "icon": "📋" }
    ],

    // 3-5 sentence narrative. What shipped? What's active? Notable patterns?
    "highlights": ["..."],

    // contributor-list: group merged-prs.json by author.login for prsMerged;
    // count commits per author from git-log.txt.
    "detailBlocks": [
      {
        "type": "contributor-list",
        "title": "Contributors",
        "contributors": [
          { "name": "...", "username": "...", "commits": 0, "prsMerged": 0 }
        ]
      }
    ]
  },

  // One theme slide per logical work area found in merged-prs.json.
  // status: "completed" | "in-progress" | "blocked"
  "themes": [
    {
      "type": "theme",
      "slug": "...",       // kebab-case
      "title": "...",
      "status": "completed",
      "description": "...",  // shown in the slide picker dropdown

      // progress / problems / plans are optional 3-column layout.
      // Omit any column that has nothing to say.
      "progress": {
        "items": [{ "text": "..." }]
      },

      "detailBlocks": [
        {
          "type": "link-list",
          "title": "Merged PRs",
          "links": [
            {
              "label": "...",        // PR title
              "url": "...",          // PR URL
              "type": "pr",
              "description": "..."  // one sentence from PR body — what problem it solved
            }
          ]
        }
      ]
    },

    // In Progress theme — omit if no open PRs
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
            { "label": "...", "url": "...", "type": "pr", "description": "..." }
          ]
        }
      ]
    },

    // Upcoming theme — omit if no intake:filed issues
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
              "label": "...",
              "url": "...",
              "type": "issue",
              "description": "size: S | M | L | XL"  // include size label if present
            }
          ]
        }
      ]
    }
  ]
}
```
