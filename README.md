# KiCad-git-tests

A scratch project for learning how to use **git with KiCad**. The board itself is
throwaway; the point is the workflow around it.

Everything below was worked out while setting this repo up, including the
mistakes — those are recorded at the bottom so they don't get repeated.

---

## 1. What belongs in git, and what doesn't

KiCad's real design files are text s-expressions, which git handles well. KiCad
also scatters caches, locks and binary backups through the project directory,
which git handles badly. The whole discipline is keeping the second group out.

### Tracked

| File | What it is |
|---|---|
| `*.kicad_pro` | Project settings, design rules, net classes |
| `*.kicad_sch` | Schematic — text, diffable |
| `*.kicad_pcb` | Board layout — text, diffable |
| `fp-lib-table` / `sym-lib-table` | Project-local library tables |
| `*.kicad_dru` | Custom design rules, if present |
| Custom `*.kicad_sym` / `*.kicad_mod` | Project-specific symbols and footprints |

### Ignored (see `.gitignore`)

| Pattern | Why |
|---|---|
| `*.lck`, `~*.lck` | Lock file written while the project is open. Contains your hostname and username. Collaborators would fight over it. |
| `*.kicad_prl` | **Local** settings — window layout, visible layers, last zoom. Per-user, not per-project. Churns on every open and close. |
| `*-backups/` | KiCad's automatic backup zips. Binary, rewritten on every save, undiffable. The single biggest cause of a bloated KiCad repo. |
| `_autosave-*`, `*.bak`, `*-bak` | Crash-recovery leftovers |
| `fp-info-cache` | Generated footprint cache |
| `*.net` | Netlists — regenerated from the schematic on demand |
| `gerbers/`, `*.gbr`, `*.drl`, `*.pos`, … | Fabrication output. Derived artifacts; regenerate them from a tagged commit instead. |

The rule of thumb: **if KiCad can regenerate it, don't commit it.** The exception
worth considering is fabrication output for a revision you actually ordered —
some people commit those deliberately, tagged, as a record of what was built.

`.gitattributes` marks the KiCad formats as text with LF endings so git never
misdetects one as binary and refuses to diff it, and marks zips and STEP files as
genuinely binary.

---

## 2. Three habits specific to KiCad

### Close KiCad — or at least save — before committing

KiCad holds edits in memory and writes on save. Committing mid-edit captures a
half-state that doesn't match what's on your screen. Closing also clears the
lock file.

### Commit the schematic and the layout together

`.kicad_sch` and `.kicad_pcb` share net and footprint identity. A commit with a
schematic change but no corresponding layout update is a broken state you cannot
cleanly return to. One logical change = one commit spanning both files.

### Do not expect merges to work on `.kicad_pcb`

This is the big one, and it surprises anyone arriving from software git.

Because the files are text, git **will** happily merge two divergent layouts —
and can produce a syntactically valid file with nonsense geometry: overlapping
footprints, traces to nowhere, silently dropped zones. That is strictly worse
than a conflict, because nothing warns you.

So:

- Branch freely for **schematic** experiments.
- Keep **layout** work linear — one person, one branch at a time.
- If layout diverges, redo it rather than merging it.

Version control here is excellent for history, review and rollback. It is *not*
reliable for parallel layout editing.

---

## 3. Everyday workflow

```bash
# after saving and closing KiCad
git status                 # confirm only design files changed
git diff                   # review — kicad files are readable text
git add -A
git commit -m "Add 3V3 regulator and decoupling"
git push
```

Tag revisions you actually send to fabrication:

```bash
git tag -a rev-a -m "Sent to JLCPCB 2026-09-12"
git push --tags
```

A tag is what makes "which files did we build?" answerable a year later.

---

## 4. How this repo was set up

```bash
cd ~/KiCad/projects/KiCad-git-tests
git init
git branch -m master main                      # match GitHub's default
# ... create .gitignore and .gitattributes ...
git add .
git commit -m "Initial commit"
git remote add origin git@github.com:Alex-Hermeling/KiCad-git-tests.git
git push -u origin main
```

