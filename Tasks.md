[README](README.md) | [Introduction](Introduction.md) | [Datasets](Datasets.md) | Tasks ⮕ | [Task 1 Guidance](Task-download.md) | [Task 2A Guidance](Task-greedy.md) | [Task 2B Guidance](Task-classify.md) | [Notebook](nids-irr-rpki-whois.ipynb)

# Tasks

Complete the tasks below in order. Tasks 2 and 3 are completed inside [nids-irr-rpki-whois.ipynb](nids-irr-rpki-whois.ipynb). Implement the required code, run the analyses, and answer the questions in the markdown cells that follow.

There are three written questions (Q1-Q3). Q1 covers the one-day IRR exploration (Task 2A). Q2 covers classification (Task 2B). Q3 covers the longitudinal analysis (Task 3). Answer each question in the corresponding notebook markdown cell.

### What is scaffolded vs. what you implement

| Task                                       | Status                                                                                                      |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| Task 2A — `greedy_irr_coverage`            | Implement the greedy selection step inside `greedy_irr_coverage`; answer Q1                                 |
| Task 2B — classifier functions             | Implement `classify_rpki`, `classify_irr`, `classify_irr_rpki_consistency`, and the per-source summary loop; answer Q2 |
| Task 3 — `daily_irr_rpki_consistency`     | Implement this function, answer Q3                                                                          |

## Task 1: Download the data and run the notebook locally

Follow [Task-download.md](Task-download.md) to run `./download-data.sh` and
populate `data/`, then install the notebook's Python dependencies. Then
launch Jupyter locally and run the setup cells followed by the sample-date
cells (Task 2).

### Implementation Tips

- Start with smaller date ranges when writing or debugging Task 3 code. For example, test one week or one month first, then scale up.
- Use the cache directory aggressively. The notebook is designed so expensive daily parsing steps write intermediate files that later cells can reuse.
- Use multiprocessing only for independent per-snapshot work, such as reading one day's raw IRR or RPKI data and writing a cached daily file.
- Keep each multiprocessing worker self-contained: the worker should take only a date string, fetch that day's raw inputs, and write its own cached output.
- If a long-running cell is interrupted, rerunning it should be faster once cached daily files already exist.

## Task 2: One-Day Exploratory Analysis of IRR, RPKI, and BGP

In this task, you will perform a small-scale exploratory analysis using one day of IRR snapshots, one day of RPKI VRP data, and one Routeviews prefix-to-AS table. Use a single-day snapshot from 2023-03-01. The goal is to understand what each data source contains before moving to the larger longitudinal analysis.

As a rough sanity check on the sample date, expect on the order of ~2 million IRR route objects, ~400,000 RPKI VRPs, and ~1 million observed BGP prefix-origin pairs. These are order-of-magnitude targets, not exact values.

### Part A: Explore IRR database snapshots

Before implementing the greedy step, read [Task 2A Guidance](Task-greedy.md) for the algorithm and a worked example.

Start with one day of IRR route-object data. Use a greedy approach to find the ordering of IRR databases that maximizes cumulative unique IPv4 prefix coverage: repeatedly pick the database that adds the most not-yet-covered prefixes, then record how much each database contributes on top of the databases already chosen before it.

For each IRR database (in greedy order), compute:

- the number of unique IPv4 prefixes in that IRR database
- the number of unique origin ASes in that IRR database
- the number of new prefixes it contributes that are not already covered by databases chosen before it
- the number of new origin ASes it contributes that are not already covered by databases chosen before it

Your notebook should generate a table like (the `new_*` columns also show each contribution as a percentage of the coverage accumulated so far):

| source | irr_prefixes | irr_origins | new_prefixes | new_origins |
| ------ | ------------ | ----------- | ------------ | ----------- |
| radb   | ...          | ...         | ...          | ...         |
| nttcom | ...          | ...         | ...          | ...         |
| arin   | ...          | ...         | ...          | ...         |

Answer the following question in the notebook:

- [ ] Q1: Which IRR databases contain the largest number of unique prefixes and prefix-origin pairs? What does this suggest about the role of large non-authoritative databases such as RADB compared with RIR-operated IRR databases?

### Part B: Classify BGP prefix-origin pairs using IRR and RPKI

Before implementing the classifier functions, read [Task 2B Guidance](Task-classify.md) for decision trees and worked examples.

Finally, use the Routeviews prefix-to-AS table for the selected day. Treat each row as an observed BGP prefix-origin pair. If a prefix has multiple origin ASes, treat each origin AS as a separate prefix-origin pair.

For this part, compare the same BGP snapshot separately against each IRR database.

For each BGP prefix-origin pair, determine its IRR status:

| IRR status       | Definition                                                                                    |
| ---------------- | --------------------------------------------------------------------------------------------- |
| `valid`          | a covering IRR route object exists with the same origin AS and the exact same prefix          |
| `invalid_asn`    | a covering IRR route object exists, but it has a different origin AS                          |
| `invalid_length` | a covering IRR route object exists for the same origin AS, but with a different prefix length |
| `not_found`      | no covering IRR route object exists                                                           |

For each BGP prefix-origin pair, determine its RPKI status:

| RPKI status      | Definition                                                                                                  |
| ---------------- | ----------------------------------------------------------------------------------------------------------- |
| `valid`          | a covering VRP authorizes the origin AS and prefix length                                                   |
| `invalid_asn`    | a covering VRP exists, but it authorizes a different origin AS                                              |
| `invalid_length` | a covering VRP exists for the same origin AS, but the observed prefix length exceeds the VRP maximum length |
| `not_found`      | no covering VRP exists                                                                                      |

Your notebook should compute:

- for each IRR database, the fraction of observed BGP prefix-origin pairs that are IRR-`valid`
- for each IRR database, the fraction of observed BGP prefix-origin pairs that are RPKI-`valid`

Your notebook should generate a summary table like:

| source | irr_valid_fraction | rpki_valid_fraction |
| ------ | ------------------ | ------------------- |
| radb   | ...                | ...                 |
| nttcom | ...                | ...                 |
| arin   | ...                | ...                 |

Answer the following question in the notebook:

- [ ] Q2: For the selected Routeviews snapshot, what fraction of observed BGP prefix-origin pairs are IRR-valid in each IRR database and what fraction are RPKI-valid? How often do you see `invalid_asn` versus `invalid_length`, and what do those differences suggest about the relationship between IRR filtering and RPKI-based validation?

## Task 3: Longitudinal IRR and RPKI Analysis for January–June 2023

In this task, you will scale the analysis to the first six months of 2023 (January-June). You will compare IRR route objects and RPKI VRPs over time to see where the two routing-authorization systems agree and disagree.

The goal is to understand how IRR and RPKI differ as routing-authorization systems. IRR records may be stale, duplicated, or inconsistently maintained across databases. RPKI VRPs are cryptographically validated, but they can still appear, disappear, or change as operators update ROAs.

Use one snapshot per month for January through June 2023, for a total of 6 snapshots. There is no 2023-04-01 snapshot in the IRR archive, so the April snapshot is dated **2023-04-03** instead — RPKI is compared against that same date for April, so the analysis stays consistent.

For each monthly snapshot, compare IRR prefix-origin pairs against the RPKI VRPs from the same date.

For this analysis, treat each IRR tuple below as one IRR prefix-origin pair:

```text
source, prefix, origin
```

For each IRR prefix-origin pair, determine its RPKI consistency:

| IRR-RPKI status       | Definition                                                                                             |
| --------------------- | ------------------------------------------------------------------------------------------------------ |
| `consistent`          | the IRR prefix-origin pair is authorized by a covering VRP                                             |
| `inconsistent_asn`    | a covering VRP exists, but it authorizes a different origin AS                                         |
| `inconsistent_length` | a covering VRP exists for the same origin AS, but the IRR prefix length exceeds the VRP maximum length |
| `not_in_rpki`         | no covering VRP exists                                                                                 |

For each monthly snapshot, compute:

- number of IRR prefix-origin pairs
- number and fraction that are `consistent`
- number and fraction with `inconsistent_asn`
- number and fraction with `inconsistent_length`
- number and fraction that are `not_in_rpki`

Your notebook should generate a monthly time-series table like:

| date | irr_pairs | consistent | inconsistent_asn | inconsistent_length | not_in_rpki | disagreement_fraction |
| ---- | --------- | ---------- | ---------------- | ------------------- | ----------- | --------------------- |
| ...  | ...       | ...        | ...              | ...                 | ...         | ...                   |

Define `disagreement_fraction` as:

```text
(inconsistent_asn + inconsistent_length) / (consistent + inconsistent_asn + inconsistent_length)
```

The denominator is all IRR pairs for which at least one covering VRP exists (equivalent to `irr_pairs - not_in_rpki`).

Answer the following question in the notebook:

- [ ] Q3: Quantify IRR and RPKI disagreement over the six-month period in 2023 using monthly snapshots. Does disagreement remain stable, increase, decrease, or show sudden spikes? Identify one visible trend or anomaly and explain what might cause it. Which IRR databases contributed to this change? What factors might have contributed to this change (e.g. real-world events)?

[README](README.md) | [Introduction](Introduction.md) | [Datasets](Datasets.md) | Tasks ⮕ | [Task 1 Guidance](Task-download.md) | [Task 2A Guidance](Task-greedy.md) | [Task 2B Guidance](Task-classify.md) | [Notebook](nids-irr-rpki-whois.ipynb)
