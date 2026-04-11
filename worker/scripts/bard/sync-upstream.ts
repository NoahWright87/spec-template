#!/usr/bin/env tsx
/**
 * sync-upstream.ts — Upstream sync for Bard phrases files.
 *
 * Updates BEGIN UPSTREAM / END UPSTREAM blocks in a downstream phrases.yaml
 * with the canonical phrases from the spec-template repo, while preserving
 * any phrases the team has suppressed (commented out within the block).
 *
 * Usage:
 *   npx tsx sync-upstream.ts \
 *     --phrases-file .agents/scout/phrases.yaml \
 *     --upstream-repo NoahWright87/spec-template \
 *     --agent scout
 *
 * Exit codes:
 *   0 — success (or graceful no-op)
 *   1 — fatal error (missing required args, unreadable file)
 *   2 — upstream fetch failed (non-fatal in practice; caller decides)
 */

import { execSync } from 'child_process'
import { readFileSync, writeFileSync } from 'fs'

// ── Argument parsing ──────────────────────────────────────────────────────────

const args = process.argv.slice(2)

function getArg(flag: string): string | undefined {
  const idx = args.indexOf(flag)
  return idx !== -1 ? args[idx + 1] : undefined
}

const phrasesFile = getArg('--phrases-file')
const upstreamRepo = getArg('--upstream-repo')
const agent = getArg('--agent')

if (!phrasesFile || !upstreamRepo || !agent) {
  console.error('Usage: sync-upstream.ts --phrases-file <path> --upstream-repo <owner/repo> --agent <name>')
  process.exit(1)
}

// ── Fetch upstream phrases via gh CLI ─────────────────────────────────────────
// Uses gh (already authenticated by the worker) rather than bundling an HTTP client.

interface UpstreamPhrases {
  [category: string]: string[]
}

function fetchUpstreamPhrases(repo: string, agentName: string): UpstreamPhrases | null {
  const apiPath = `repos/${repo}/contents/agents/${agentName}/phrases.yaml`
  try {
    const encoded = execSync(`gh api "${apiPath}" --jq '.content'`, { encoding: 'utf8' }).trim()
    // GitHub returns base64 with newlines; strip them before decoding
    const decoded = Buffer.from(encoded.replace(/\s/g, ''), 'base64').toString('utf8')
    // Parse the YAML using yq (already installed in the worker image)
    const json = execSync(`echo ${JSON.stringify(decoded)} | yq -o=json '.phrases'`, {
      encoding: 'utf8',
    }).trim()
    return JSON.parse(json) as UpstreamPhrases
  } catch (err) {
    console.error(`[sync-upstream] WARNING: Could not fetch upstream phrases for ${agentName} from ${repo}`)
    console.error(`[sync-upstream] Upstream block will be preserved as-is.`)
    if (err instanceof Error) console.error(`[sync-upstream] Detail: ${err.message}`)
    return null
  }
}

// ── File parsing ──────────────────────────────────────────────────────────────

const BEGIN_MARKER = /^# BEGIN UPSTREAM: (.+)$/
const END_MARKER = /^# END UPSTREAM: (.+)$/
const SUPPRESSED_LINE = /^# (- .+)$/  // "# - "phrase"" → suppressed list item

interface Block {
  category: string         // e.g. "scout/intro"
  startLine: number        // index of BEGIN line
  endLine: number          // index of END line
  suppressions: Set<string> // phrase texts that are currently suppressed
}

function parseBlocks(lines: string[]): Block[] {
  const blocks: Block[] = []
  let current: Partial<Block> | null = null

  for (let i = 0; i < lines.length; i++) {
    const beginMatch = lines[i].match(BEGIN_MARKER)
    const endMatch = lines[i].match(END_MARKER)

    if (beginMatch) {
      current = { category: beginMatch[1], startLine: i, suppressions: new Set() }
    } else if (endMatch && current) {
      current.endLine = i
      blocks.push(current as Block)
      current = null
    } else if (current) {
      // Inside a block — check for suppressed phrases
      const suppressedMatch = lines[i].match(SUPPRESSED_LINE)
      if (suppressedMatch) {
        // Extract the phrase text from "# - "text"" or "# - text"
        const phraseText = suppressedMatch[1].replace(/^- /, '').trim()
        current.suppressions!.add(phraseText)
      }
    }
  }

  return blocks
}

// ── Block replacement ─────────────────────────────────────────────────────────

function buildNewBlock(category: string, canonicalPhrases: string[], suppressions: Set<string>): string[] {
  const lines: string[] = []
  for (const phrase of canonicalPhrases) {
    // Match suppressions by phrase content (normalized: strip surrounding quotes if present)
    const normalized = phrase.replace(/^["']|["']$/g, '').trim()
    const isSuppressed = [...suppressions].some(s => {
      const sNorm = s.replace(/^["']|["']$/g, '').replace(/^- /, '').trim()
      return sNorm === normalized || s.includes(normalized)
    })
    if (isSuppressed) {
      lines.push(`# - ${phrase}`)
    } else {
      lines.push(`- ${phrase}`)
    }
  }
  return lines
}

function applySync(lines: string[], blocks: Block[], upstreamPhrases: UpstreamPhrases): string[] {
  // Process blocks in reverse order so line indices stay valid as we replace
  const sorted = [...blocks].sort((a, b) => b.startLine - a.startLine)
  const result = [...lines]

  for (const block of sorted) {
    // Extract the category name (e.g. "scout/intro" → "intro")
    const categoryKey = block.category.split('/').pop()!
    const canonicalPhrases = upstreamPhrases[categoryKey]

    if (!canonicalPhrases || canonicalPhrases.length === 0) {
      console.error(`[sync-upstream] No upstream phrases for category "${categoryKey}" — skipping block`)
      continue
    }

    const newBlockLines = buildNewBlock(block.category, canonicalPhrases, block.suppressions)

    // Replace lines between (exclusive) the BEGIN and END markers
    const before = result.slice(0, block.startLine + 1)         // up to and including BEGIN
    const after = result.slice(block.endLine)                    // from END onward
    result.splice(0, result.length, ...before, ...newBlockLines, ...after)
  }

  return result
}

// ── Main ──────────────────────────────────────────────────────────────────────

let fileContent: string
try {
  fileContent = readFileSync(phrasesFile, 'utf8')
} catch {
  console.error(`[sync-upstream] ERROR: Cannot read phrases file: ${phrasesFile}`)
  process.exit(1)
}

const lines = fileContent.split('\n')
const blocks = parseBlocks(lines)

if (blocks.length === 0) {
  console.log(`[sync-upstream] No upstream blocks found in ${phrasesFile} — nothing to sync`)
  process.exit(0)
}

console.log(`[sync-upstream] Found ${blocks.length} upstream block(s) in ${phrasesFile}`)

const upstreamPhrases = fetchUpstreamPhrases(upstreamRepo, agent)

if (!upstreamPhrases) {
  // Fetch failed — exit with code 2 so caller can decide whether to abort
  process.exit(2)
}

const updatedLines = applySync(lines, blocks, upstreamPhrases)
const updatedContent = updatedLines.join('\n')

if (updatedContent === fileContent) {
  console.log(`[sync-upstream] No changes — upstream blocks already current`)
  process.exit(0)
}

// Atomic write: temp file + rename
const tmpFile = `${phrasesFile}.sync-tmp`
writeFileSync(tmpFile, updatedContent, 'utf8')
execSync(`mv "${tmpFile}" "${phrasesFile}"`)

console.log(`[sync-upstream] Synced ${blocks.length} upstream block(s) in ${phrasesFile}`)
process.exit(0)
