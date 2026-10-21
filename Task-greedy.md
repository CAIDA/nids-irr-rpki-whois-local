[README](README.md) | [Introduction](Introduction.md) | [Datasets](Datasets.md) | [Tasks](Tasks.md) | [Task 1 Guide](Task-download.md) | Task 2A Guide ⮕ | [Task 2B Guide](Task-classify.md) | [Notebook](nids-irr-rpki-whois.ipynb)

# Task 2A Guidance: Greedy IRR Coverage Ordering

This page prepares you to implement the greedy step inside `greedy_irr_coverage` required in [Task 2A](Tasks.md).

## What the greedy algorithm does

Many IRR databases overlap: the same IPv4 prefix is often registered in more than one of them. We want to order the databases so that each one is credited only with what it adds **on top of** the databases already chosen. That tells you which databases carry unique coverage and which are largely redundant.

The greedy rule is: **repeatedly pick the database that contributes the most not-yet-covered IPv4 prefixes.** Add its prefixes (and origins) to a running "covered" set, record how much it contributed, and repeat with the databases that remain. This is the classic greedy approximation to maximum set coverage — at each step you take the locally best choice without backtracking.

The ordering is driven by **prefixes**. Origins are tracked alongside for reporting, but they do not influence which database is picked.

## The data structures

The scaffolding builds these before the loop, so you only write the greedy step:

| Name | Meaning |
|---|---|
| `source_prefixes[src]` | the set of unique IPv4 prefixes in database `src` |
| `source_origins[src]` | the set of unique origin ASes in database `src` |
| `covered_prefixes` | every prefix already covered by databases chosen so far (starts empty) |
| `covered_origins` | every origin already covered by databases chosen so far (starts empty) |
| `remaining` | the set of database names not yet chosen |

Each iteration of `while remaining:` chooses exactly one database.

## The greedy step

Inside the loop, your job is to:

1. **Score each remaining database** by how many *new* prefixes it would add. For a candidate `s`, that count is `len(source_prefixes[s] - covered_prefixes)` — the prefixes it has that are not yet covered.
2. **Pick the best one.** Use `max(remaining, key=...)` with that score as the key to get `best_src`.
3. **Compute its contribution:**
   - `new_prefixes = source_prefixes[best_src] - covered_prefixes`
   - `new_origins  = source_origins[best_src]  - covered_origins`
4. **Stop early if there is nothing new.** If `new_prefixes` is empty, every remaining database is fully redundant, so `break` out of the loop.
5. **Update the running state:**
   - `covered_prefixes |= new_prefixes`
   - `covered_origins  |= new_origins`
   - `remaining.remove(best_src)`

The bookkeeping below the student region reads `best_src`, `new_prefixes`, and `new_origins` to build the output row, so make sure those three variables exist before the loop falls through to it.

## Worked example

Suppose the day has three databases with these IPv4 prefix sets (numbers invented for illustration):

| database | prefixes | origins |
|---|---|---|
| radb | `{p1, p2, p3, p4, p5}` | `{o1, o2, o3}` |
| nttcom | `{p4, p5, p6, p7}` | `{o3, o4}` |
| arin | `{p1, p2, p8}` | `{o1, o5}` |

**Round 1** — `covered_prefixes` is empty, so new = full size: radb 5, nttcom 4, arin 3. Pick **radb**.
- `new_prefixes = {p1, p2, p3, p4, p5}` (5), `new_origins = {o1, o2, o3}` (3)
- covered_prefixes → `{p1..p5}`, covered_origins → `{o1, o2, o3}`

**Round 2** — remaining `{nttcom, arin}`. nttcom adds `{p6, p7}` (2); arin adds `{p8}` (1). Pick **nttcom**.
- `new_prefixes = {p6, p7}` (2), `new_origins = {o4}` (1)
- covered_prefixes → `{p1..p7}`, covered_origins → `{o1..o4}`

**Round 3** — remaining `{arin}`. arin adds `{p8}` (1). Pick **arin**.
- `new_prefixes = {p8}` (1), `new_origins = {o5}` (1)
- covered_prefixes → `{p1..p8}`, covered_origins → `{o1..o5}`

Resulting table:

| source | irr_prefixes | irr_origins | new_prefixes | new_origins |
|---|---|---|---|---|
| radb | 5 | 3 | 5 | 3 |
| nttcom | 4 | 2 | 2 (+40.0%) | 1 (+33.3%) |
| arin | 3 | 2 | 1 (+14.3%) | 1 (+25.0%) |

Note how `irr_prefixes` (radb 5, nttcom 4) is the database's own total, while `new_prefixes` (radb 5, nttcom 2) is only what it added beyond the databases picked before it.

## Reading the output

- `irr_prefixes` / `irr_origins` — the database's own totals (`len(source_prefixes[best_src])` / `len(source_origins[best_src])`), independent of order.
- `new_prefixes` / `new_origins` — the marginal contribution given the databases already chosen. The first chosen database has no prior coverage, so its `new_*` equals its total and shows no percentage. Later rows show `(+x%)`, the contribution as a percentage of coverage accumulated **before** this database was added (`prev_p` / `prev_o`).

## Common pitfalls

**Scoring against the wrong set.** Score each candidate by its prefixes not yet covered — `source_prefixes[s] - covered_prefixes` — not by its total size. Ranking by `len(source_prefixes[s])` ignores overlap and gives the wrong order.

**Forgetting to update `remaining`.** You must `remaining.remove(best_src)` every iteration. If you don't, `while remaining:` never terminates and the loop spins forever.

**Updating `covered_*` before reading `prev_*`.** The scaffolding captures `prev_p` / `prev_o` at the top of the loop, before your code runs, precisely so the percentage reflects coverage *before* this database. Do your `covered_prefixes |= new_prefixes` update inside the student region; don't move the `prev_*` capture.

**Not breaking on zero new prefixes.** Once the best remaining database adds no new prefixes, all remaining databases are redundant. `break` instead of appending empty rows — and it also avoids a divide-by-something-meaningless contribution.

**Ranking by origins.** The greedy choice is by prefixes. Origins are computed and reported for the chosen database, but they should not decide `best_src`.

[README](README.md) | [Introduction](Introduction.md) | [Datasets](Datasets.md) | [Tasks](Tasks.md) | [Task 1 Guide](Task-download.md) | Task 2A Guide ⮕ | [Task 2B Guide](Task-classify.md) | [Notebook](nids-irr-rpki-whois.ipynb)
