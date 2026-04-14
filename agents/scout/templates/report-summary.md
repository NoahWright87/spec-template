# Report Template: Summary (Stakeholder)

Stakeholder-level variant of the `SprintReport` schema — fewer themes, no contributor breakdown, outcome-focused language. Scout reads this file when `report_instructions` points here.

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

    // 3-4 outcome-level stats — avoid raw counts, prefer milestone language.
    "stats": [
      { "label": "Features Shipped", "value": 0, "icon": "🚀" },
      { "label": "Bugs Fixed",       "value": 0, "icon": "🐛" },
      { "label": "Open PRs",         "value": 0, "icon": "📬" }
    ],

    // 3-5 sentences answering: "Are we on track? What got done? What's next?"
    // Avoid technical jargon — write for a non-engineering audience.
    "highlights": ["..."],

    "detailBlocks": []  // no contributor list for stakeholder reports
  },

  "themes": [
    // Group completed work by feature area or milestone — not by PR.
    {
      "type": "theme",
      "slug": "...",
      "title": "What Shipped",
      "status": "completed",
      "description": "...",
      "progress": {
        "items": [{ "text": "..." }]
      },
      "detailBlocks": [
        {
          "type": "link-list",
          "title": "Key PRs",
          "links": [
            { "label": "...", "url": "...", "type": "pr", "description": "..." }
          ]
        }
      ]
    },

    // In Progress — omit if no open PRs
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
            { "label": "...", "url": "...", "type": "pr", "description": "..." }
          ]
        }
      ]
    },

    // Upcoming — omit if no intake:filed issues
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
            { "label": "...", "url": "...", "type": "issue", "description": "..." }
          ]
        }
      ]
    }
  ]
}
```
