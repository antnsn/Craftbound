# Craftbound: instructions for AI agents

Profession levelling addon for WoW: Forever (Interface 16001, Lua 5.1, modern
`C_TradeSkillUI` / `C_AuctionHouse` API). Forever only: no Classic or retail branches.
Design: `docs/superpowers/specs/2026-11-22-craftbound-design.md`.

## Skills

Shared knowledge lives in Claude Code skills (plugin `wow-addons`, repo antnsn/addon-skills). Load the
one that fits before working here; this file only holds what is specific to this repo.

- `wow-addons:forever-client`: the Forever client API: secret values, missing globals, API lookups, probing in game
- `wow-addons:addon-release`: releasing: tag, CurseForge webhook, the token, changelog, docs, screenshots

## Build & test

```bash
python3 -I tools/import_wowhead.py   # Wowhead route + catalog JSON (tools/data/wh_*.json, fetched
                                     # by hand, gitignored) -> tools/data/profession-guides.json
python3 tools/build_guides.py        # after changing tools/data/profession-guides.json or the script
for f in *.lua; do luac5.1 -p "$f" || echo "syntax error: $f"; done
~/.luarocks/bin/luacheck .
wowbench check . && wowbench test .  # 0 errors, every scenario ok
```

`Guides.lua` is generated: edit the JSON or `tools/build_guides.py`, never the Lua.
Check that new API exists in `~/code/wowbench/api/client.txt` (many legacy globals are nil on
Forever: `GetTradeSkillInfo`, `GetItemInfo`, `GetItemCount`...). Purchases and crafts only ever
come from a click or a key binding: never from an event handler. Run `/codex:review` before
every commit.

## CurseForge

`CURSEFORGE.md` is the project page (pasted by hand) and `Craftbound.png` its picture (made by
`tools/make_media.py`). Before a release: write the version in `CHANGELOG.md`, run
`python3 tools/sync_curseforge.py` (it copies the changelog to the bottom of the page). The comment
at the top of `CURSEFORGE.md` is the text for CurseForge's "Summary" field (at most 256
characters; the tool checks it, `--summary` prints it).

## NPC data

`NpcData.lua` is generated: `python3 tools/make_npc_data.py` (needs `../QuestieDB`) after the guides
or QuestieDB change. It is QuestieDB data (GPLv3), which is why Craftbound is GPL-3.0-or-later.

## Screenshots

In game: `/craft shots` (not in the help) shows each frame and takes a screenshot; it opens the
active guide's profession window itself, the auction house must be open for its panel. Then
`/reload` and `python3 LibBound/tools/crop_shots.py Craftbound` (from `Interface/AddOns`) cuts
them out into `docs/screenshots/`.

## Git flow

Protected `main`: `git switch -c <topic>`, commit (with `.beads/issues.jsonl`), push,
`gh pr create --fill`, `gh pr merge --squash --delete-branch`. Releases: a `## X` section in
`CHANGELOG.md` and `python3 tools/sync_curseforge.py` (through a PR), then tag `vX` on main and
push the tag: `.github/workflows/release.yml` packs it (`tools/package.py`) and publishes the
GitHub release. CurseForge (project 1824701) also builds every tag through its webhook; details in `wow-addons:addon-release`.

## Issues

Beads (`bd`). No Dolt remote: skip `bd dolt push`.


<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
