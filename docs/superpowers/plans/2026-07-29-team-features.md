# Team Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add court-position labels, preset color swatches, team randomization (by-position / fully-random), and a dynamic 2–6 team count to the volleyball infochart.

**Architecture:** All changes live in the single file `volleyball-opengym.html`, following the existing vanilla-JS patterns: `CONFIG` (live state) / `DRAFT` (editor working copy), the `el(tag, attrs, ...children)` DOM builder, `renderTeams()` for the main display, `renderEditor()` for the settings overlay, and `commitSave()`/`saveConfig()` for persistence. Rosters stay 6-element string arrays; positions are fixed per row index (no data-model change).

**Tech Stack:** Plain HTML/CSS/JS, no build, no test framework. Verification is manual in a browser plus DevTools console.

## Global Constraints

- Single file only: `volleyball-opengym.html`. No new files, no dependencies.
- Positions are fixed per roster row: `POSITIONS = ["S","OH1","M","OPP","OH2","L"]`. Rosters remain 6-element string arrays.
- Team count range: minimum 2, maximum 6.
- Follow existing patterns: `el()` builder, `DRAFT` for editor edits, re-render via `renderEditor()`, persist via `commitSave()`.
- No `Math.random` restriction here — this is browser runtime code, so `Math.random()` is allowed for shuffling.

**Verification convention (all tasks):** "Open in browser" means open `volleyball-opengym.html` in a browser (or reload the existing tab). "Console" means the browser DevTools console. There are no automated tests; each task's verification is a concrete manual check.

---

### Task 1: Position labels constant + main-view badges

**Files:**
- Modify: `volleyball-opengym.html` (add constant near other module constants ~line 1055; edit `renderTeams` ~lines 1441-1465; add CSS near `.roster li` ~line 157)

**Interfaces:**
- Produces: module-level `const POSITIONS = ["S","OH1","M","OPP","OH2","L"];` used by Tasks 1, 2, 4.
- Produces: CSS class `.pos-badge`.

- [ ] **Step 1: Add the POSITIONS constant**

Add just above `const STORAGE_KEY = "vb-opengym-config";` (~line 1055):

```javascript
const POSITIONS = ["S", "OH1", "M", "OPP", "OH2", "L"];
```

- [ ] **Step 2: Add badge CSS**

Add after the `.roster li.empty` rule (~line 166):

```css
  .roster li { display: flex; align-items: center; gap: 0.8vw; }
  .pos-badge {
    flex: none;
    min-width: 3.2ch;
    text-align: center;
    font-size: 1.2vh;
    font-weight: 800;
    letter-spacing: 0.02em;
    color: #fff;
    background: color-mix(in srgb, var(--team-color, var(--accent)) 55%, transparent);
    border: 1px solid color-mix(in srgb, var(--team-color, var(--accent)) 70%, transparent);
    border-radius: 0.6vh;
    padding: 0.2vh 0.4vw;
  }
```

- [ ] **Step 3: Render badge beside each roster name**

Replace the loop body in `renderTeams` (~lines 1446-1451):

```javascript
      for (let i = 0; i < 6; i++) {
        const name = t.roster[i];
        const badge = el("span", { class: "pos-badge" }, POSITIONS[i]);
        roster.appendChild(name
          ? el("li", {}, badge, el("span", { class: "player-name" }, name))
          : el("li", { class: "empty" }, badge, el("span", { class: "player-name" }, "—")));
      }
```

- [ ] **Step 4: Verify in browser**

Open in browser. Expected: each team card lists 6 rows, each showing a colored position badge (`S`, `OH1`, `M`, `OPP`, `OH2`, `L`) to the left of the player name; empty slots show the badge next to `—`. No console errors.

- [ ] **Step 5: Add mobile badge sizing**

In the mobile `@media` block, find `.roster li { font-size: 13px; padding: 4px 0; }` (~line 914) and add after it:

```css
    .roster li { gap: 8px; }
    .pos-badge { font-size: 10px; min-width: 3.2ch; padding: 1px 4px; border-radius: 4px; }
```

- [ ] **Step 6: Verify mobile**

Open in browser, narrow the window below the mobile breakpoint. Expected: badges remain legible and aligned, cards stack without overflow.

- [ ] **Step 7: Commit**

```bash
git add volleyball-opengym.html
git commit -m "Show court position labels beside each player"
```

---

### Task 2: Position labels in the editor roster grid

**Files:**
- Modify: `volleyball-opengym.html` (edit roster-grid loop in `renderEditor` ~lines 1709-1721; add CSS near `.roster-grid` ~line 644)

**Interfaces:**
- Consumes: `POSITIONS` (Task 1).
- Produces: CSS class `.roster-pos-row`, `.roster-pos-label`.

- [ ] **Step 1: Add editor position-row CSS**

Add after the `.roster-grid input` rule (~line 651):

```css
  .roster-pos-row { display: flex; align-items: center; gap: 8px; }
  .roster-pos-label {
    flex: none; min-width: 3.5ch; text-align: right;
    font-size: 11px; font-weight: 800; color: var(--muted);
  }
  .roster-pos-row input { flex: 1; }
```

- [ ] **Step 2: Wrap each roster input with its position label**

Replace the roster-grid loop in `renderEditor` (~lines 1709-1721):

```javascript
      const rosterInputs = el("div", { class: "roster-grid" });
      for (let ri = 0; ri < 6; ri++) {
        const val = team.roster[ri] ?? "";
        const field = el("input", {
          type: "text",
          value: val,
          placeholder: "Player " + (ri + 1),
          oninput: (e) => { team.roster[ri] = e.target.value; },
        });
        rosterInputs.appendChild(el("div", { class: "roster-pos-row" },
          el("span", { class: "roster-pos-label" }, POSITIONS[ri]),
          field));
      }
```

- [ ] **Step 3: Verify in browser**

Open in browser, click the edit (gear/pencil) button, expand "Teams & Rosters". Expected: each of the 6 roster inputs per team has its position label (`S`…`L`) to its left. Typing a name still updates it; Save persists it. No console errors.

- [ ] **Step 4: Commit**

```bash
git add volleyball-opengym.html
git commit -m "Label roster inputs with court positions in editor"
```

---

### Task 3: Preset color swatches per team in the editor

**Files:**
- Modify: `volleyball-opengym.html` (edit `team-edit-head` construction in `renderEditor` ~lines 1722-1738; add CSS near `.team-edit-head` ~line 637)

**Interfaces:**
- Produces: module-level `const COLOR_PRESETS`; CSS classes `.color-swatches`, `.color-swatch`.

- [ ] **Step 1: Add the presets constant**

Add just below the `POSITIONS` constant (from Task 1):

```javascript
const COLOR_PRESETS = ["#ef4444", "#f97316", "#eab308", "#22c55e", "#14b8a6", "#3b82f6", "#8b5cf6", "#ec4899"];
```

- [ ] **Step 2: Add swatch CSS**

Add after the `.team-edit-head input[type="text"]` rule (~line 643):

```css
  .color-swatches { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 10px; }
  .color-swatch {
    width: 20px; height: 20px; border-radius: 50%;
    border: 2px solid transparent; cursor: pointer; padding: 0;
  }
  .color-swatch.active { border-color: var(--text); }
```

- [ ] **Step 3: Render swatches under the team head**

In `renderEditor`, the team card is built as `el("div", { class: "team-edit", ... }, el("div", { class: "team-edit-head" }, colorInput, nameInput), rosterInputs)`. Change it so the color input's `oninput` also refreshes swatch highlighting, and insert a swatches row between the head and `rosterInputs`. Replace the `const card = el("div", { class: "team-edit", ...` block (~lines 1722-1740) with:

```javascript
      const colorInput = el("input", {
        type: "color",
        value: team.color,
        oninput: (e) => {
          team.color = e.target.value;
          card.style.setProperty("--team-color", e.target.value);
          updateSwatches();
        },
      });
      const swatches = el("div", { class: "color-swatches" });
      function updateSwatches() {
        Array.from(swatches.children).forEach(sw => {
          sw.classList.toggle("active", sw.dataset.color.toLowerCase() === (team.color || "").toLowerCase());
        });
      }
      COLOR_PRESETS.forEach(c => {
        swatches.appendChild(el("button", {
          class: "color-swatch",
          style: { background: c },
          "data-color": c,
          title: c,
          onclick: () => {
            team.color = c;
            colorInput.value = c;
            card.style.setProperty("--team-color", c);
            updateSwatches();
          },
        }));
      });
      const card = el("div", { class: "team-edit", style: { "--team-color": team.color } },
        el("div", { class: "team-edit-head" },
          colorInput,
          el("input", {
            type: "text",
            value: team.name,
            placeholder: "Team name",
            oninput: (e) => team.name = e.target.value,
          }),
        ),
        swatches,
        rosterInputs,
      );
      updateSwatches();
```

Note: the `el()` helper routes unknown attribute keys through `setAttribute`, so `"data-color": c` becomes a real `data-color` attribute readable as `sw.dataset.color`. (Confirmed against the helper at line 1370.)

- [ ] **Step 4: Verify in browser**

Open in browser, open editor, expand "Teams & Rosters". Expected: under each team's name/color row is a row of 8 colored circles; the one matching the team's current color has a highlighted ring. Clicking a swatch recolors the team card's left border and updates the native color input. In console, run `document.querySelector('.color-swatch').dataset.color` — expect a hex string (confirms Step 3's data attribute note). Save, reopen — color persists.

- [ ] **Step 5: Commit**

```bash
git add volleyball-opengym.html
git commit -m "Add preset color swatches per team in editor"
```

---

### Task 4: Randomize buttons (by-position and fully-random)

**Files:**
- Modify: `volleyball-opengym.html` (add helper functions near other DRAFT-editing functions ~line 1216; add a controls row inside the Teams section in `renderEditor` after the teams loop ~line 1743; add CSS near `.add-round` ~line 669)

**Interfaces:**
- Consumes: `DRAFT.teams`, `renderEditor()`.
- Produces: functions `shuffleInPlace(arr)`, `randomizeByPosition()`, `randomizeFully()`.

- [ ] **Step 1: Add controls CSS**

Add after the `.add-rule, .add-round { ... }` rule (~line 669):

```css
  .team-tools { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 8px; }
  .team-tools button {
    background: transparent; color: var(--muted);
    border: 1px solid var(--border); border-radius: 6px;
    padding: 6px 10px; cursor: pointer; font: inherit; font-size: 12px;
  }
  .team-tools button:hover:not(:disabled) { color: var(--text); border-color: var(--text); }
  .team-tools button:disabled { opacity: 0.4; cursor: not-allowed; }
```

- [ ] **Step 2: Add shuffle + randomize helpers**

Add after `function setSlotValue(...) { ... }` (~line 1226, just after its closing brace):

```javascript
  function shuffleInPlace(arr) {
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [arr[i], arr[j]] = [arr[j], arr[i]];
    }
    return arr;
  }

  // Shuffle each position row (index 0..5) independently across all teams.
  function randomizeByPosition() {
    for (let ri = 0; ri < 6; ri++) {
      const names = DRAFT.teams
        .map(t => (t.roster[ri] ?? "").trim())
        .filter(Boolean);
      shuffleInPlace(names);
      let k = 0;
      DRAFT.teams.forEach(t => {
        const had = (t.roster[ri] ?? "").trim();
        t.roster[ri] = had ? (names[k++] ?? "") : "";
      });
    }
  }

  // Collect all players, shuffle, refill slots team-by-team, top to bottom.
  function randomizeFully() {
    const all = [];
    DRAFT.teams.forEach(t => {
      for (let ri = 0; ri < 6; ri++) {
        const n = (t.roster[ri] ?? "").trim();
        if (n) all.push(n);
      }
    });
    shuffleInPlace(all);
    let k = 0;
    DRAFT.teams.forEach(t => {
      for (let ri = 0; ri < 6; ri++) {
        t.roster[ri] = k < all.length ? all[k++] : "";
      }
    });
  }
```

Note on by-position: it preserves the *count and location* of filled slots per row (a blank stays blank), only reassigning who fills them. Fully-random compacts all names to the front of the team list.

- [ ] **Step 3: Add the buttons to the Teams section**

In `renderEditor`, immediately after `body.appendChild(teamsSec);` is too late (buttons belong inside the section). Instead, right before `body.appendChild(teamsSec);` (~line 1743), append a tools row to `teamsSec`:

```javascript
    const teamTools = el("div", { class: "team-tools" },
      el("button", {
        onclick: () => { randomizeByPosition(); renderEditor(); },
      }, "🎲 Randomize by position"),
      el("button", {
        onclick: () => { randomizeFully(); renderEditor(); },
      }, "🎲 Randomize fully"),
    );
    teamsSec.appendChild(teamTools);
```

- [ ] **Step 4: Verify by-position in browser**

Open in browser, open editor, expand "Teams & Rosters". Note the row-1 (`S`) names across teams. Click "🎲 Randomize by position". Expected: the set of `S` names is the same as before but redistributed; no name jumps to a different position row; blank slots stay blank. Repeat clicks reshuffle. No console errors.

- [ ] **Step 5: Verify fully-random in browser**

Click "🎲 Randomize fully". Expected: all players redistributed across all teams and positions; total set of names unchanged; names compact toward the top slots. Click Save, then reopen editor — the randomized rosters persist.

- [ ] **Step 6: Commit**

```bash
git add volleyball-opengym.html
git commit -m "Add by-position and fully-random team shuffles"
```

---

### Task 5: Dynamic team count (2–6) with add/remove

**Files:**
- Modify: `volleyball-opengym.html` (dynamic grid in `renderTeams` ~line 1442; add-team helper defaults; per-team remove button + add-team button in `renderEditor` teams section ~lines 1722-1743)

**Interfaces:**
- Consumes: `DRAFT.teams`, `COLOR_PRESETS` (Task 3), `renderEditor()`.
- Produces: functions `addTeam()`, `removeTeam(index)`.

- [ ] **Step 1: Make the main grid dynamic**

In `renderTeams`, replace the section-creation line (~line 1442):

```javascript
    const wrap = el("section", { class: "teams" });
```

with:

```javascript
    const wrap = el("section", { class: "teams",
      style: { "grid-template-columns": `repeat(${Math.max(CONFIG.teams.length, 1)}, 1fr)` } });
```

- [ ] **Step 2: Verify grid adapts**

Open in browser. In console run: `CONFIG.teams.length` (expect 4). Temporarily test render with fewer/more by editing later; for now expect the 4 teams to fill the row evenly (unchanged look). No console errors.

- [ ] **Step 3: Add addTeam / removeTeam helpers**

Add after `randomizeFully()` (from Task 4):

```javascript
  function addTeam() {
    if (DRAFT.teams.length >= 6) return;
    const idx = DRAFT.teams.length;
    DRAFT.teams.push({
      name: "Team " + (idx + 1),
      color: COLOR_PRESETS[idx % COLOR_PRESETS.length],
      roster: ["", "", "", "", "", ""],
    });
  }

  function removeTeam(index) {
    if (DRAFT.teams.length <= 2) return;
    DRAFT.teams.splice(index, 1);
  }
```

- [ ] **Step 4: Add a remove button to each team card**

In `renderEditor`, the team head currently holds `colorInput` and the name input. Add a remove button after the name input inside the `team-edit-head` (in the `card` construction from Task 3). Change the `el("div", { class: "team-edit-head" }, colorInput, el("input", {...name...}))` to include a third child:

```javascript
        el("div", { class: "team-edit-head" },
          colorInput,
          el("input", {
            type: "text",
            value: team.name,
            placeholder: "Team name",
            oninput: (e) => team.name = e.target.value,
          }),
          (() => {
            const btn = el("button", {
              class: "team-remove",
              title: "Remove team",
              onclick: () => { removeTeam(ti); renderEditor(); },
            }, "✕");
            btn.disabled = DRAFT.teams.length <= 2;
            return btn;
          })(),
        ),
```

Note: `el()` does NOT skip `null` attribute values (it calls `setAttribute("disabled", null)`, which renders `disabled="null"` — still disabled). So set `.disabled` as a property after creation, as shown. (Confirmed against the helper at line 1370.)

Add CSS after the `.team-edit-head input[type="text"]` rule (~line 643):

```css
  .team-remove {
    flex: none; background: transparent; color: var(--muted);
    border: 1px solid var(--border); border-radius: 6px;
    padding: 6px 9px; cursor: pointer; font: inherit;
  }
  .team-remove:hover:not(:disabled) { color: #f87171; border-color: #7f1d1d; }
  .team-remove:disabled { opacity: 0.4; cursor: not-allowed; }
```

Note: `el()` with a `null` attribute value should skip the attribute. Confirm in Step 6; if `el()` renders `disabled="null"`, instead build the button then conditionally `btn.disabled = DRAFT.teams.length <= 2;`.

- [ ] **Step 5: Add the "+ Add Team" button**

In the `team-tools` row from Task 4 Step 3, add an add-team button as the first child:

```javascript
    const addBtn = el("button", {
      onclick: () => { addTeam(); renderEditor(); },
    }, "+ Add Team");
    addBtn.disabled = DRAFT.teams.length >= 6;
    const teamTools = el("div", { class: "team-tools" },
      addBtn,
      el("button", {
        onclick: () => { randomizeByPosition(); renderEditor(); },
      }, "🎲 Randomize by position"),
      el("button", {
        onclick: () => { randomizeFully(); renderEditor(); },
      }, "🎲 Randomize fully"),
    );
    teamsSec.appendChild(teamTools);
```

- [ ] **Step 6: Verify add/remove in browser**

Open in browser, open editor, expand "Teams & Rosters".
- Click "+ Add Team": a new "Team 5" card appears with a preset color and 6 empty position rows. Add once more → "Team 6". The "+ Add Team" button becomes disabled at 6.
- Click a team's "✕": that team is removed; at 2 teams remaining, all "✕" buttons become disabled.
- In console after adding: `document.querySelectorAll('.team-remove[disabled]').length` — expect 0 while >2 teams.
- Click Save. Expected: main view now shows the new number of team cards, evenly spread across the row.

- [ ] **Step 7: Verify persistence and schedule adaptation**

With 5 teams saved, reload the page. Expected: 5 team cards persist. Open editor, set Schedule mode to round-robin (if not already) and Save. Expected: round-robin schedule regenerates for the current team set with no console errors. (King mode is not specially handled for non-4 counts; it operates on available/TBD slots — no crash expected.)

- [ ] **Step 8: Commit**

```bash
git add volleyball-opengym.html
git commit -m "Support dynamic 2-6 team count with add/remove"
```

---

## Self-Review

**Spec coverage:**
- Positions beside name (main + editor): Tasks 1, 2. ✓
- Custom colors (enhancement = presets; existing picker retained): Task 3. ✓
- Randomize by-position and fully: Task 4. ✓
- Dynamic team count 2–6: Task 5. ✓

**Placeholder scan:** No TBD/TODO; all code steps show full code; verification steps give concrete expected results. ✓

**Type/name consistency:** `POSITIONS` (Tasks 1,2,4), `COLOR_PRESETS` (Tasks 3,5), `shuffleInPlace`/`randomizeByPosition`/`randomizeFully` (Task 4), `addTeam`/`removeTeam` (Task 5) referenced consistently. `renderEditor()` re-render used uniformly for DRAFT edits. ✓

**`el()` helper behavior (confirmed at line 1370):** unknown keys use `setAttribute` (so `data-color` works); `null` attribute values are NOT skipped, so `disabled` is set as a property after creation in Task 5 rather than via a nullable attribute.
