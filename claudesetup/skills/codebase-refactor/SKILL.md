---
name: codebase-refactor
description: Orchestrate large-scale, multi-agent codebase refactoring for Astro + React 19 + TypeScript + Tailwind + Supabase + Sanity + Cloudflare projects. Use this skill whenever the user wants to refactor, migrate, rename, update patterns, or apply a transformation across many files. Accepts freeform commands like "convert all useState to nanostores", "add TypeScript strict types to all API files", "migrate inline styles to Tailwind", "add error boundaries to all page components", "rename X to Y across the codebase", or any custom refactoring instruction. Splits work across parallel batch agents for efficiency. Also supports flags like --dry-run, --files, --feature, and --batch-size.
---

# Codebase Refactor Orchestrator

You are the **orchestrator** for a large-scale refactoring task. Your job is to analyze the command, discover relevant files, plan batches, spawn parallel agents, and consolidate their results.

## Step 1: Parse the Command

The user's refactoring command can be:

- **Pattern migration** — "Convert X to Y" (e.g., convert fetch() calls to typed api client)
- **Convention enforcement** — "Ensure all server files use .server.ts suffix"
- **Cleanup** — "Remove dead code", "Add missing return types to exported functions"
- **Structural** — "Move X to Y", "Rename X to Y everywhere"
- **Custom** — Anything freeform

Check for optional flags the user may include:
- `--dry-run` — Agents report *what they would change* but do not edit any files
- `--files <glob>` — Override file discovery with a custom glob (e.g., `--files "src/components/**/*.tsx"`)
- `--feature <name>` — Scope to a specific feature folder (e.g., `--feature shipmojo`)
- `--batch-size <n>` — Override the default batch size (default: 12)

If the command is genuinely ambiguous about *what* to change (not just *where*), ask one focused clarifying question before proceeding.

## Step 2: Discover Files

Scan for relevant source files. This project lives in `src/` and has ~211 TypeScript/TSX/Astro files across:

```
src/
  components/     UI components (React .tsx)
  features/       Feature modules (ui/, server/, client/, domain/ layers)
  pages/          Astro pages and API routes (.astro, .ts)
  lib/            Shared library code
  hooks/          React hooks
  types/          TypeScript type definitions
  constants/      Compile-time and runtime constants
  config/         App configuration
```

Filter files based on the command's intent:
- UI / styling commands → `*.tsx`, `*.astro`
- Type / API / logic commands → `*.ts`, possibly `*.tsx`
- Page-level commands → `src/pages/**/*.astro`
- Cross-cutting commands → all `*.{ts,tsx,astro}`

When uncertain, be inclusive. It's better for an agent to skip an irrelevant file than to miss one that needed changing.

## Step 3: Plan Batches

Divide files into batches of **10–15 files each** (or the `--batch-size` override). Batch cohesively:
- Keep a feature's files together (e.g., all of `src/features/shipmojo/` in one batch)
- Group by layer within components (e.g., all `src/components/ui/` together)
- Don't split files that import each other across different batches if you can avoid it

Before spawning agents, announce the plan:
> "Found X files. Splitting into N batches. Starting all agents in parallel..."

## Step 4: Spawn All Agents in Parallel

Launch **all batch agents in a single message** using the Agent tool. Do not wait for one batch to finish before starting the next — spawn everything at once.

Each agent receives this prompt:

---

```
You are a refactoring agent handling one batch of files.

REFACTOR COMMAND:
<exact command from user>

DRY RUN: <yes/no>

YOUR BATCH (read and potentially edit these files):
<list of absolute file paths, one per line>

STACK CONTEXT (read references/stack-conventions.md in the skill directory for full details):
- Framework: Astro v5 with React 19 islands
- Styling: Tailwind CSS v3 + Radix UI primitives + cn() utility (clsx + tailwind-merge)
- State: nanostores + @nanostores/react (useStore hook); @nanostores/persistent for localStorage
- Database: Supabase JS v2 — client in src/lib/
- CMS: Sanity v3 with @sanity/client
- Payments: Razorpay
- Deployment: Cloudflare Workers — no Node.js built-ins in server code; env via Astro.locals.runtime.env
- TypeScript: strict mode

INSTRUCTIONS:
1. Read each file in your batch
2. Decide which files need changes for this command (some may need none — that's fine)
3. If DRY RUN is no: apply changes using the Edit tool
   If DRY RUN is yes: describe what you would change but do not edit any files
4. After completing your batch, output a summary in EXACTLY this format:

BATCH SUMMARY
Files changed: <count>
Files skipped: <count>

CHANGED:
- <relative path>: <one-line description of the change>

SKIPPED:
- <relative path>: <reason why no change was needed>

NOTES:
<Patterns noticed, edge cases, anything the orchestrator should know>
```

---

## Step 5: Aggregate and Report

After all agents complete, compile results:

```
REFACTOR COMPLETE
=================
Command: <the command>
Mode: <live / dry-run>
Files scanned: <total>

RESULTS
- Changed: X files
- Skipped: Y files
- Batches: Z (ran in parallel)

CHANGED FILES
<group by feature/directory for readability>

FOLLOW-UP
<Patterns agents flagged, inconsistencies across batches, suggested next steps>
```

Flag any cross-batch conflicts — e.g., two agents made different decisions about the same pattern in different files. Suggest a follow-up pass if needed.

## Stack Conventions Reference

For deep context on conventions, read `references/stack-conventions.md` in this skill's directory. Key highlights:

- Server code (Cloudflare): files in `*/server/` or suffixed `.server.ts`. No Node built-ins.
- Feature structure: `ui/` | `server/` | `client/` | `domain/` layers per feature
- Astro pages: server logic in frontmatter, React components loaded with `client:load` or `client:idle`
- State: prefer nanostores over React state for shared/persistent state
- Styling: `cn()` from `src/utils.ts` for conditional Tailwind classes
