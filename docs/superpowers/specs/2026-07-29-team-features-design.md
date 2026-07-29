# Volleyball Infochart — Team Features Design

Date: 2026-07-29
File under change: `volleyball-opengym.html` (single-file vanilla-JS app; CONFIG/DRAFT state, `el()` DOM helper, localStorage persistence, editor overlay).

## Goals

1. Show each player's court position (S, OH1, M, OPP, OH2, L) beside their name.
2. Custom colors per team (already largely implemented — enhance discoverability).
3. Randomize teams: "by position" or "fully random".
4. Dynamic team count: 2–6 teams.

## 1. Positions (fixed per row)

- Add module constant `POSITIONS = ["S", "OH1", "M", "OPP", "OH2", "L"]`.
- Row index maps to position; rosters remain a 6-element string array (no data-model change).
- **Main view** (`renderTeams`): each roster `<li>` shows a position badge before the name (e.g. `S` · `Alice`). Empty rows show badge + `—`. Badge styled as a small muted/tinted chip.
- **Editor** (`renderEditor`, roster-grid): each of the 6 inputs gets its position label to the left.

## 2. Custom colors

- Existing per-team `<input type="color">` in the editor already sets `team.color` and drives `--team-color` everywhere. Keep it.
- Enhancement: add a row of ~8 preset color swatches beneath the color input; clicking one sets `team.color` and updates the card. Low-risk, no new data.

## 3. Dynamic team count (2–6)

- `.teams` grid: replace hardcoded `repeat(4, 1fr)` with an inline `grid-template-columns: repeat(N, 1fr)` set from `CONFIG.teams.length` in `renderTeams`.
- Editor "Teams & Rosters" section:
  - **+ Add Team** button (disabled at 6). New team: default name (e.g. "Team N"), a default color from a palette, 6 empty roster slots.
  - Per-team **✕ remove** button (disabled when only 2 teams remain).
- Round-robin schedule regenerates from `CONFIG.teams`, so it adapts automatically.
- King mode is designed for 4 teams / 2 courts. When team count ≠ 4 it retains existing behavior (operates on available/TBD slots); not blocked, not specially handled.

## 4. Randomize (two buttons, editor Teams section)

Operate on `DRAFT`, then re-render editor; persist on Save like other edits.

- **🎲 By position**: for each row index 0–5, gather that row's non-empty names across all teams, shuffle, redistribute back into the same row index across teams. Team 1's M can land as M on any team. Blank slots stay blank.
- **🎲 Fully random**: gather all non-empty names across all teams, shuffle, refill slots top-to-bottom, team-by-team. Remaining slots blank.
- Shuffle: Fisher–Yates helper.

## Constraints / non-goals

- All changes remain in the single HTML file, following existing `el()`/CONFIG/DRAFT patterns.
- Persistence via existing `saveConfig`; `normalizeConfig` already tolerates variable team counts.
- No per-player editable position field (positions are fixed per row).
- No changes to king-mode logic beyond tolerating non-4 team counts.
