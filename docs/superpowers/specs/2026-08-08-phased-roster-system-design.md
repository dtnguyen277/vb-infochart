# Phased Roster System — Design

**Date:** 2026-08-08
**File touched:** `volleyball-opengym.html` (single-file app)

## Summary

Add an optional "phased roster" system: once the initial teams are set, the
author can vary the **players** on each team per schedule round. Selecting a
round changes which rosters the team board displays. Later rounds start as
copies of Round 1 and can be edited independently. The feature is gated behind
a toggle, **"Different teams per round"**, disabled by default. When off, the
app behaves exactly as it does today.

Team **names and colors are shared across all rounds** — only the players
(roster entries, including subs) vary per round. The schedule pairings and
structure are unchanged by this feature; only the board rosters swap.

## Requirements (settled in brainstorming)

- **Q1 = A:** Selecting a round swaps only the team board's rosters. Schedule
  pairings/structure stay the same.
- **Q2 = A:** Round selector is a row of round tabs directly above the team board.
- **Q3 = A:** Number of roster phases automatically tracks the schedule's round
  count. Add a schedule round → new phase (copied from previous round). Remove a
  round → its phase drops.
- **Q4 = yes:** Only players change per round; names and colors are shared.
- **Q5 = B:** Turning the toggle OFF is non-destructive — per-round data is kept
  but hidden; re-enabling restores it.
- **Q6 = A:** A "Reset rounds" button resets all rounds to copies of Round 1,
  with one-level undo.

## Data model

New/changed `CONFIG` fields:

- `differentTeamsPerRound: false` — feature toggle, default off.
- `roundRosters` — array indexed by round; `roundRosters[r]` is an array of
  roster arrays, one entry per team (parallel to `CONFIG.teams`, same order).
  Holds **only players**, never names/colors. May be `null`/absent when the
  feature has never been enabled.

Unchanged / source-of-truth rules:

- `CONFIG.teams[t].roster` remains the source of truth for **Round 1** and is
  kept in sync with `roundRosters[0]` whenever the feature is on.
- When the feature is OFF, all rendering/editing reads `teams[].roster` exactly
  as today. `roundRosters` is ignored (but preserved).

UI state (not necessarily persisted):

- `currentRound` — zero-based index of the round the board is showing. Clamped
  into `[0, roundCount-1]` on every render.

### Round count source

The canonical resolved schedule is:

```js
CONFIG.matches ?? generateRoundRobin(CONFIG.teams, CONFIG.roundRobinRounds)
```

Its `.length` is the number of rounds, and therefore the number of roster
phases. A single helper (e.g. `resolvedRoundCount()`) computes this so tabs and
reconciliation share one definition.

### Reconciliation

A helper (e.g. `syncRoundRosters()`) runs lazily whenever the board/tabs
render, keeping `roundRosters` consistent with the current round count and team
structure:

- If feature on and `roundRosters` missing → initialize: every round = deep
  copy of Round 1's rosters (`teams[].roster`).
- If round count grew → append new entries, each a deep copy of the previous
  round's rosters.
- If round count shrank → truncate extra entries.
- If team count changed → add/remove the corresponding per-team roster slot in
  every round (keep parallel with `teams`).
- Keep `roundRosters[0]` and `teams[].roster` in sync.
- Clamp `currentRound` into range.

## UI & behavior

### Round tabs

- A row of buttons above the team board: `Round 1 | Round 2 | … | Round N`,
  active round highlighted. Visible **only when the feature is ON**.
- Clicking a tab sets `currentRound` and re-renders the board with that round's
  rosters.
- Adjacent **"Reset rounds"** button (see below).

### Toggle: "Different teams per round"

- Lives in the editor with the other config controls. Default off.
- **ON:** initialize `roundRosters` (every round a deep copy of Round 1). Tabs
  appear.
- **OFF (non-destructive):** keep `roundRosters`, board reverts to
  `teams[].roster`, tabs hide, `currentRound` resets to 0. Re-enabling restores
  the stored per-round edits.

### Reset rounds button

- Next to the round tabs. Resets **all** rounds to deep copies of **Round 1**
  (`teams[].roster`).
- One-level **Undo**, matching the existing "Reset scores" / schedule-reset undo
  pattern (snapshot before reset, restore on undo, invalidate appropriately).

### Editing & randomize scope (feature ON)

- **Randomize** (🎲 Positions / 🎲 Everyone FABs) applies to **`currentRound`
  only**.
- **Live board swaps/drags** apply to **`currentRound` only**.
- **Editor roster text edits** apply to **`currentRound`**. Editing Round 1
  keeps `teams[].roster` and `roundRosters[0]` in sync.
- **Structural changes** (add/remove a team, add/remove a player/sub slot)
  apply across **all rounds** so team count and slot counts stay consistent.

### Board rendering

- Feature OFF → render `teams[].roster` (today's behavior).
- Feature ON → render `roundRosters[currentRound]` for each team, using each
  team's shared name/color.

## Persistence

- `differentTeamsPerRound` and `roundRosters` are included in export/import.
- Importing an older file lacking these fields runs with the feature off; no
  migration step required (treated as default off / absent).

## Backward compatibility

- Feature off is the default and preserves current behavior exactly.
- `roundRosters` absent/null is a valid state.
- No change to schedule generation, pairings, scoring, or king-of-the-court
  logic.

## Out of scope (YAGNI)

- Per-round team names or colors.
- Per-round schedule pairing differences (pairings remain shared).
- Independent roster-phase management decoupled from schedule rounds.
