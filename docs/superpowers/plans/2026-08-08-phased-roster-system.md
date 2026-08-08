# Phased Roster System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the author vary each team's players per schedule round, gated behind a default-off "Different teams per round" toggle, with round tabs above the team board and a reset-to-Round-1 button.

**Architecture:** The app is one file (`volleyball-opengym.html`) with a plain-DOM render loop and `localStorage` persistence. Per-round rosters are stored in a new `CONFIG.roundRosters` array (one roster-array per team, per round). The key simplification: **`CONFIG.teams[t].roster` always mirrors the *currently displayed* round**. Switching a round flushes the board into the store and loads the new round back onto `teams[*].roster`. Because every existing feature (shuffle, tap/drag swap, editor roster fields) reads and writes `teams[*].roster`, they all operate on the current round with **zero changes**. When the feature is off, `currentRound` is pinned to 0 and the board shows Round 1 exactly as today.

**Tech Stack:** Vanilla JS, DOM helpers (`el`, `$`), `localStorage`. No build step, no test framework.

## Global Constraints

- Single file only: `volleyball-opengym.html`. No new files, no dependencies.
- `CORE_SLOTS = 6`, `MAX_SUBS = 2`, `SLOT_COUNT = 8` (existing constants — do not change).
- `STORAGE_KEY = "vb-opengym-config"` (existing).
- Team **name and color are shared across rounds**; only roster (player) entries vary per round.
- Feature is **off by default** and must preserve current behavior byte-for-byte when off.
- Backward compatibility: importing/loading an old config without the new fields must work (feature off, `roundRosters` absent).
- Deep-copy rosters everywhere (arrays of arrays of strings) — never share array references between rounds. Use `store[r].map(a => [...a])` style copies (the app already assumes `structuredClone` exists — it is used elsewhere).
- Follow the existing "snapshot + one-level undo" pattern used by `scheduleUndo` / "Reset scores" for the new "Reset rounds" undo.

**Architecture refinement vs. spec:** The spec said `teams[].roster` is the source of truth for Round 1. This plan refines that: `teams[].roster` mirrors the *currently displayed* round (and equals Round 1 whenever the feature is off, since `currentRound` is pinned to 0). Observable behavior is identical to the spec; this refinement is what lets all existing mutation code stay untouched.

**No automated tests exist.** Every task verifies via the running page: open `volleyball-opengym.html` in a browser, interact, and inspect `localStorage.getItem("vb-opengym-config")` in the DevTools console. Before manual checks, clear stale state with `localStorage.removeItem("vb-opengym-config")` and reload when a task says to start clean.

---

### Task 1: Data model — config fields, state, and round helpers

Adds the feature flag, the `roundRosters` store, the `currentRound` UI state, and the core helper functions. Wires `flushCurrentRound()` into `saveConfig` and the round reconciliation + load into `render()`. No visible UI yet except that (with the flag manually set) round switching works from the console.

**Files:**
- Modify: `volleyball-opengym.html`
  - `DEFAULT_CONFIG` object (starts line 17) — add `differentTeamsPerRound: false`
  - `normalizeConfig` (lines 1210-1220) — coerce new fields
  - `saveConfig` (lines 1321-1323) — flush current round before persisting
  - Insert new helper block right after `let CONFIG = loadConfig();` (line 1326)
  - `render` (lines 2141-2148) — sync + load current round, guarded by feature flag

**Interfaces:**
- Produces (used by later tasks):
  - `let currentRound` — 0-based index of the displayed round
  - `phasedOn(): boolean` — feature enabled
  - `resolvedRoundCount(): number` — number of rounds (≥1)
  - `cloneRosters(): string[][]` — deep copy of every team's current roster
  - `flushCurrentRound(): void` — push board rosters into `CONFIG.roundRosters[currentRound]`
  - `syncRoundRosters(): void` — reconcile store dims with round/team counts; clamp `currentRound`
  - `loadRound(r): void` — copy `roundRosters[r]` onto `CONFIG.teams[*].roster`
  - `switchRound(r): void` — flush, set `currentRound=r`, load, save, render

- [ ] **Step 1: Add the default flag**

In `DEFAULT_CONFIG` (line 17 block), add the flag next to `scheduleMode`. Find:

```js
  scheduleMode: "round-robin",
```

Replace with:

```js
  scheduleMode: "round-robin",

  // Phased rosters: when true, each schedule round can have different players
  // (team names/colors stay shared). Off = single shared roster (legacy).
  differentTeamsPerRound: false,
```

- [ ] **Step 2: Normalize the new fields on load/import**

In `normalizeConfig` (lines 1210-1220), find:

```js
  function normalizeConfig(cfg) {
    cfg.matches = normalizeMatches(cfg.matches);
```

Replace with:

```js
  function normalizeConfig(cfg) {
    cfg.matches = normalizeMatches(cfg.matches);
    // Phased rosters: coerce the flag and drop a malformed store.
    cfg.differentTeamsPerRound = !!cfg.differentTeamsPerRound;
    if (!Array.isArray(cfg.roundRosters)) cfg.roundRosters = undefined;
```

- [ ] **Step 3: Flush the current round inside saveConfig**

Find `saveConfig` (lines 1321-1323):

```js
  function saveConfig(cfg) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(cfg));
  }
```

Replace with:

```js
  function saveConfig(cfg) {
    // Keep the per-round store in sync with the live board before persisting.
    if (cfg === CONFIG) flushCurrentRound();
    localStorage.setItem(STORAGE_KEY, JSON.stringify(cfg));
  }
```

(`flushCurrentRound` is a hoisted function declaration added in the next step; it is only called at runtime, so ordering is fine.)

- [ ] **Step 4: Add the helper block**

Find (line 1326):

```js
  let CONFIG = loadConfig();
```

Insert immediately after it:

```js

  // ---- Phased rosters (per-round roster storage) ---------------------------
  // UI state: which round's rosters the board shows (0-based). Not persisted;
  // resets to 0 on reload.
  let currentRound = 0;

  function phasedOn() { return !!CONFIG.differentTeamsPerRound; }

  // Number of rounds in the resolved schedule = number of roster phases.
  function resolvedRoundCount() {
    const matches = CONFIG.matches ?? generateRoundRobin(CONFIG.teams, CONFIG.roundRobinRounds);
    return Math.max(matches.length, 1);
  }

  // Deep copy of every team's current roster (array of arrays of strings).
  function cloneRosters() { return CONFIG.teams.map(t => [...t.roster]); }

  // Push the live board (CONFIG.teams[*].roster) into the store for the round
  // currently displayed, so persistence and switching stay consistent.
  function flushCurrentRound() {
    if (!phasedOn() || !Array.isArray(CONFIG.roundRosters)) return;
    CONFIG.roundRosters[currentRound] = cloneRosters();
  }

  // Reconcile the store with the current round count and team count. Safe to
  // call on every render. New rounds copy the previous round (round 0 copies
  // the live board). New teams copy their current roster into every round.
  function syncRoundRosters() {
    if (!phasedOn()) return;
    if (!Array.isArray(CONFIG.roundRosters)) CONFIG.roundRosters = [];
    const store = CONFIG.roundRosters;
    const rounds = resolvedRoundCount();
    const teamCount = CONFIG.teams.length;
    for (let r = 0; r < rounds; r++) {
      if (!Array.isArray(store[r])) {
        store[r] = r === 0 ? cloneRosters() : store[r - 1].map(a => [...a]);
      }
      while (store[r].length < teamCount) {
        const ti = store[r].length;
        store[r].push([...CONFIG.teams[ti].roster]);
      }
      if (store[r].length > teamCount) store[r].length = teamCount;
    }
    if (store.length > rounds) store.length = rounds;
    if (currentRound >= rounds) currentRound = rounds - 1;
    if (currentRound < 0) currentRound = 0;
  }

  // Load a round's stored rosters onto the live board.
  function loadRound(r) {
    if (!phasedOn() || !Array.isArray(CONFIG.roundRosters)) return;
    const snap = CONFIG.roundRosters[r];
    if (!snap) return;
    CONFIG.teams.forEach((t, i) => { t.roster = snap[i] ? [...snap[i]] : []; });
  }

  // Switch the visible round: save the current board, load the target round.
  function switchRound(r) {
    if (r === currentRound) return;
    swapSel = null;
    flushCurrentRound();
    currentRound = r;
    loadRound(r);
    saveConfig(CONFIG);
    render();
  }
```

(`swapSel` is an existing module-level `let` declared later at line ~1486; it is referenced only at call time, so this is fine.)

- [ ] **Step 5: Sync + load the current round at the top of render**

Find `render` (lines 2141-2148):

```js
  function render() {
    closeTeamPicker();
    const stage = $("#stage");
```

Replace with:

```js
  function render() {
    closeTeamPicker();
    if (phasedOn()) { syncRoundRosters(); loadRound(currentRound); }
    const stage = $("#stage");
```

- [ ] **Step 6: Verify manually (console-driven)**

Open `volleyball-opengym.html` in a browser. In DevTools console, run:

```js
localStorage.removeItem("vb-opengym-config"); location.reload();
```

After reload, confirm the board looks exactly as before (feature off). Then in the console verify the flag exists in defaults:

```js
JSON.parse(localStorage.getItem("vb-opengym-config"))?.differentTeamsPerRound
// Expected: (may be null if not yet saved) — acceptable. Now force-enable:
```

The `CONFIG` variable is not exposed globally, so drive the feature through persisted state: manually write an enabled config and reload.

```js
// Enable the feature and give round storage a nudge, then reload:
const c = JSON.parse(localStorage.getItem("vb-opengym-config")) || {};
```

If the above returns `null` (nothing saved yet), first make any edit in the editor and Save so a config is persisted, then re-run the enable snippet:

```js
const c = JSON.parse(localStorage.getItem("vb-opengym-config"));
c.differentTeamsPerRound = true;
localStorage.setItem("vb-opengym-config", JSON.stringify(c));
location.reload();
```

Expected after reload: page still renders normally (no tabs yet — that's Task 2), and inspecting storage shows `roundRosters` was created and every round holds a copy of the rosters:

```js
const s = JSON.parse(localStorage.getItem("vb-opengym-config")).roundRosters;
// Expected: an array; s.length === number of schedule rounds; each s[r] is an
// array of per-team roster arrays, all copies of the initial rosters.
```

(Note: `roundRosters` is written when `saveConfig` runs — trigger one save by making any board change, e.g. a shuffle, then re-inspect. Confirm `s.length` equals the round count shown in the schedule.)

- [ ] **Step 7: Commit**

```bash
git add volleyball-opengym.html
git commit -m "Add phased-roster data model: flag, round store, and helpers

Introduce CONFIG.differentTeamsPerRound and CONFIG.roundRosters, plus
currentRound state and helpers (syncRoundRosters/flushCurrentRound/
loadRound/switchRound). teams[*].roster now mirrors the displayed round;
render() reconciles and loads it. No visible UI yet.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Round tabs, Reset rounds button, and undo

Renders the round selector above the board (only when the feature is on), wires tab clicks to `switchRound`, and adds "Reset rounds" with a one-level undo mirroring the "Reset scores" pattern.

**Files:**
- Modify: `volleyball-opengym.html`
  - Insert `renderRoundTabs()`, `resetRounds()`, `undoResetRounds()`, and `let roundsResetUndo` near the other render/undo helpers (place directly before `function render()`, ~line 2141)
  - `render` — insert the tabs block between header and teams when the feature is on
  - `commitSave` (lines 2649-2667) — invalidate `roundsResetUndo` on editor save (structure may change)
  - Add CSS for `.teams-block`, `.round-tabs`, `.round-tab` near the existing `.shuffle-fab` styles (~line 552)

**Interfaces:**
- Consumes: `phasedOn`, `resolvedRoundCount`, `currentRound`, `switchRound`, `flushCurrentRound`, `loadRound`, `saveConfig`, `render`, `el`, `structuredClone`
- Produces: `renderRoundTabs(): HTMLElement`, `resetRounds(): void`, `undoResetRounds(): void`, `roundsResetUndo` (snapshot or `undefined`)

- [ ] **Step 1: Add tabs + reset/undo functions**

Find (line 2141):

```js
  function render() {
    closeTeamPicker();
```

Insert immediately BEFORE it:

```js
  // Snapshot of roundRosters taken before a "Reset rounds", for one-level undo.
  // `undefined` means no undo is available.
  let roundsResetUndo = undefined;

  // Reset every round to a copy of Round 1's rosters.
  function resetRounds() {
    if (!phasedOn()) return;
    flushCurrentRound();
    syncRoundRosters();
    roundsResetUndo = structuredClone(CONFIG.roundRosters);
    const base = CONFIG.roundRosters[0].map(a => [...a]);
    CONFIG.roundRosters = CONFIG.roundRosters.map(() => base.map(a => [...a]));
    loadRound(currentRound);
    saveConfig(CONFIG);
    render();
  }

  function undoResetRounds() {
    if (roundsResetUndo === undefined) return;
    CONFIG.roundRosters = structuredClone(roundsResetUndo);
    roundsResetUndo = undefined;
    loadRound(currentRound);
    saveConfig(CONFIG);
    render();
  }

  function renderRoundTabs() {
    const rounds = resolvedRoundCount();
    const bar = el("div", { class: "round-tabs" });
    for (let r = 0; r < rounds; r++) {
      bar.appendChild(el("button", {
        class: "round-tab" + (r === currentRound ? " active" : ""),
        onclick: () => switchRound(r),
      }, "Round " + (r + 1)));
    }
    bar.appendChild(el("button", {
      class: "round-tab reset",
      title: "Reset all rounds to copies of Round 1",
      onclick: () => resetRounds(),
    }, "↺ Reset rounds"));
    if (roundsResetUndo !== undefined) {
      bar.appendChild(el("button", {
        class: "round-tab",
        title: "Undo the round reset",
        onclick: () => undoResetRounds(),
      }, "↩ Undo"));
    }
    return bar;
  }

```

- [ ] **Step 2: Render the tabs above the board**

In `render` (now just below the inserted block), find:

```js
    stage.appendChild(renderHeader());
    stage.appendChild(renderTeams());
```

Replace with:

```js
    stage.appendChild(renderHeader());
    if (phasedOn()) {
      stage.appendChild(el("div", { class: "teams-block" },
        renderRoundTabs(), renderTeams()));
    } else {
      stage.appendChild(renderTeams());
    }
```

(Wrapping tabs + board in one `.teams-block` keeps the 3-row stage grid intact — the block occupies the existing middle "auto" row.)

- [ ] **Step 3: Invalidate reset-undo on editor save**

In `commitSave` (lines 2649-2667), find:

```js
    shuffleUndoStack = [];
    clearScheduleUndo();
```

Replace with:

```js
    shuffleUndoStack = [];
    clearScheduleUndo();
    roundsResetUndo = undefined;
```

- [ ] **Step 4: Add CSS**

Find the `.shuffle-fab {` rule (line 552) and insert this block immediately before it:

```css
  .teams-block { display: flex; flex-direction: column; gap: 1vh; min-height: 0; }
  .round-tabs { display: flex; flex-wrap: wrap; gap: 0.6vw; align-items: center; }
  .round-tab {
    background: var(--panel-2); color: var(--muted);
    border: 1px solid var(--border); border-radius: 0.6vh;
    padding: 0.5vh 1vw; font-size: 1.7vh; font-weight: 600;
    cursor: pointer; transition: background 0.12s, color 0.12s, border-color 0.12s;
  }
  .round-tab:hover { color: var(--text); border-color: var(--text); }
  .round-tab.active { background: var(--accent); color: #0b0f17; border-color: var(--accent); }
  .round-tab.reset { margin-left: auto; }
```

- [ ] **Step 5: Verify manually**

With the feature enabled from Task 1 (or enable it via the storage snippet again), reload. Expected:
1. A row of tabs `Round 1 | Round 2 | … | ↺ Reset rounds` appears above the team board.
2. Round 1 is highlighted. Click **Round 2** → it highlights; the board still shows the same players (all rounds start as copies).
3. On Round 2, click **🎲 Everyone** (bottom-right FAB) to shuffle. Switch to **Round 1** → Round 1's players are unchanged. Switch back to **Round 2** → the shuffled order persists. (This confirms per-round isolation.)
4. Click **↺ Reset rounds** → all rounds become copies of Round 1; an **↩ Undo** tab appears. Switch to Round 2 → it now matches Round 1. Click **↩ Undo** → Round 2's shuffled order returns.
5. Inspect storage: `JSON.parse(localStorage.getItem("vb-opengym-config")).roundRosters` shows distinct arrays per round after shuffling.

- [ ] **Step 6: Commit**

```bash
git add volleyball-opengym.html
git commit -m "Add round tabs, Reset rounds, and undo to the board

Render a round selector above the team board when phased rosters are on;
clicking a tab switches the displayed round. Reset rounds collapses all
rounds to copies of Round 1 with one-level undo, matching the Reset scores
pattern.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Editor toggle + per-round save reconciliation

Adds the user-facing "Different teams per round" checkbox to the editor and makes `commitSave` reconcile the store: enabling initializes/keeps per-round data, disabling is non-destructive (keeps the store, shows Round 1), and editor roster edits land on the current round.

**Files:**
- Modify: `volleyball-opengym.html`
  - `renderEditor` Teams section (starts line 2220) — add the toggle row with a "(editing Round N)" hint
  - `commitSave` (lines 2649-2667) — reconcile phased state after `CONFIG = structuredClone(DRAFT)`
  - Add CSS for `.ed-toggle` near the other editor styles

**Interfaces:**
- Consumes: `DRAFT`, `phasedOn`, `syncRoundRosters`, `flushCurrentRound`, `loadRound`, `currentRound`, `el`
- Produces: no new exports; wires `DRAFT.differentTeamsPerRound`

- [ ] **Step 1: Add the toggle to the editor**

In `renderEditor`, find (line 2220):

```js
    const teamsSec = el("details", { class: "ed-section" }, el("summary", {}, "Teams & Rosters"));
    DRAFT.teams.forEach((team, ti) => {
```

Replace with:

```js
    const teamsSec = el("details", { class: "ed-section" }, el("summary", {}, "Teams & Rosters"));
    // Phased-roster toggle. When on, the roster fields below edit the round
    // currently shown on the board.
    (() => {
      const cb = el("input", { type: "checkbox" });
      cb.checked = !!DRAFT.differentTeamsPerRound;
      cb.addEventListener("change", (e) => {
        DRAFT.differentTeamsPerRound = e.target.checked;
        renderEditor();
      });
      const hint = DRAFT.differentTeamsPerRound
        ? el("span", { class: "ed-toggle-hint" }, "editing Round " + (currentRound + 1))
        : null;
      teamsSec.appendChild(el("label", { class: "ed-toggle" },
        cb, el("span", {}, "Different teams per round"), hint));
    })();
    DRAFT.teams.forEach((team, ti) => {
```

- [ ] **Step 2: Reconcile phased state on save**

In `commitSave`, find:

```js
    CONFIG = structuredClone(DRAFT);
    // Editing may change rosters, team count, or the schedule, so stale undo
    // snapshots no longer apply.
```

Replace with:

```js
    CONFIG = structuredClone(DRAFT);
    // Phased rosters: reconcile the store with the (possibly edited) config.
    if (phasedOn()) {
      // Ensure dims match, then push the editor's roster edits (which targeted
      // the current round) into the store for that round.
      syncRoundRosters();
      flushCurrentRound();
    } else {
      // Feature off: pin to Round 1 and show it. The store (if any) is kept.
      currentRound = 0;
      loadRound(0);
    }
    // Editing may change rosters, team count, or the schedule, so stale undo
    // snapshots no longer apply.
```

- [ ] **Step 3: Add CSS**

Find the `.shuffle-fab {` rule (line 552) — the `.teams-block` block from Task 2 sits just before it. Insert this immediately after the `.round-tab.reset` rule you added in Task 2:

```css
  .ed-toggle { display: flex; align-items: center; gap: 8px; margin-bottom: 10px; font-size: 13px; }
  .ed-toggle input { width: auto; }
  .ed-toggle-hint { color: var(--muted); font-style: italic; }
```

- [ ] **Step 4: Verify manually**

Start clean: `localStorage.removeItem("vb-opengym-config"); location.reload();`. Then:
1. Open the editor (✎). In **Teams & Rosters**, confirm a **☐ Different teams per round** checkbox at the top, unchecked.
2. Check it → a "editing Round 1" hint appears. Click **Save**. Expected: round tabs now show on the board; feature is on.
3. Reopen editor, switch board to **Round 2** first (close editor, click Round 2 tab, reopen editor) → the hint reads "editing Round 2". Change a player name, Save. Expected: only Round 2's board changed; Round 1 unchanged.
4. Reopen editor, **uncheck** the toggle, Save. Expected: tabs disappear, board shows Round 1. Inspect storage: `roundRosters` is still present (non-destructive).
5. Reopen editor, **re-check** the toggle, Save. Expected: tabs return and Round 2's earlier edit is still there.

- [ ] **Step 5: Commit**

```bash
git add volleyball-opengym.html
git commit -m "Add editor toggle and per-round save reconciliation

Add the 'Different teams per round' checkbox (with an editing-Round-N hint)
to the editor. commitSave now flushes editor roster edits to the current
round when on, and non-destructively pins to Round 1 when off (keeping the
stored per-round data for re-enable).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Round-count sync and export/import verification

No new feature code is expected — this task confirms the store correctly tracks schedule round changes (add/remove round, add/remove team) and survives export/import round-trips. Add small fixes only if a check fails.

**Files:**
- Modify (only if a check below fails): `volleyball-opengym.html`

**Interfaces:**
- Consumes everything from Tasks 1-3. No new exports.

- [ ] **Step 1: Verify add/remove round syncs phases**

Enable the feature (editor toggle, Save). On the board:
1. Note the number of round tabs equals the schedule's round count.
2. Add a schedule round (the **+** control on the schedule / round-robin). Expected: a new round tab appears; switching to it shows a copy of the previous round's rosters.
3. Remove a round. Expected: the tab count drops; if you were on the removed round, the selection clamps into range without error.
4. Inspect storage: `roundRosters.length` matches the tab count after each change.

- [ ] **Step 2: Verify add/remove team syncs across rounds**

1. In the editor, add a team, Save. Expected: the new team appears in every round (switch tabs to confirm it is present in each).
2. Remove a team, Save. Expected: it disappears from every round; no console errors; `roundRosters[r].length` equals the team count for every `r`.

- [ ] **Step 3: Verify export/import round-trip**

1. With the feature on and rounds diverged (e.g. Round 2 shuffled), open the editor's Import/Export (JSON) section and **copy** the exported JSON. Confirm it contains `"differentTeamsPerRound": true` and a populated `"roundRosters"` array.
2. Start clean (`localStorage.removeItem("vb-opengym-config"); location.reload();`), open the editor, **paste** that JSON into the import field, apply, and Save. Expected: the feature is on, tabs appear, and each round's rosters match what was exported.
3. Import an **old-style** config (delete the `differentTeamsPerRound` and `roundRosters` keys from a copy of the JSON, then import). Expected: loads cleanly with the feature off and no tabs.

- [ ] **Step 4: Fix only if needed**

If Step 3's old-style import throws or leaves the feature in a bad state, confirm `normalizeConfig` (Task 1, Step 2) runs on the imported object. Locate the import-apply handler (search the file for where the Import/Export textarea value is parsed and assigned to `DRAFT`) and ensure the parsed object passes through `normalizeConfig(...)` before use. Add that call if missing. Re-run Step 3.

- [ ] **Step 5: Commit (only if code changed)**

If Step 4 required a change:

```bash
git add volleyball-opengym.html
git commit -m "Normalize imported configs for phased rosters

Ensure imported JSON without the new phased-roster fields loads cleanly
with the feature off.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

If no code changed, record verification in the task tracker and move on (no empty commit).

---

## Self-Review

**Spec coverage:**
- Toggle, default off → Task 3 (editor checkbox), Task 1 (default flag). ✓
- Round tabs above board (Q2=A) → Task 2. ✓
- Selecting a round swaps only board rosters (Q1=A) → Task 1 (`switchRound`/`loadRound`), Task 2 (tabs). Schedule untouched. ✓
- Later rounds start as copies of Round 1 → Task 1 (`syncRoundRosters` copies previous/round-0). ✓
- Randomize/swaps affect current round only → automatic (teams[*].roster mirrors current round); verified in Task 2 Step 5. ✓
- Round phases track schedule round count (Q3=A) → Task 1 (`resolvedRoundCount`/`syncRoundRosters`), verified Task 4. ✓
- Names/colors shared (Q4) → store holds rosters only; names/colors never written per-round. ✓
- Toggle off non-destructive (Q5=B) → Task 3 commitSave keeps `roundRosters`. ✓
- Reset rounds → copies of Round 1, with undo (Q6=A) → Task 2. ✓
- Persistence in export/import → Task 4. ✓
- Backward compatibility with old configs → Task 1 (normalize), Task 4 Step 3. ✓

**Placeholder scan:** No TBD/TODO/"handle edge cases"/"similar to Task N". All code blocks are complete. ✓

**Type consistency:** Helper names are used identically across tasks: `phasedOn`, `resolvedRoundCount`, `cloneRosters`, `flushCurrentRound`, `syncRoundRosters`, `loadRound`, `switchRound`, `renderRoundTabs`, `resetRounds`, `undoResetRounds`, `roundsResetUndo`. `roundRosters` is `string[][]` per round throughout. ✓
