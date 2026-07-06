[README](README.md) | [Introduction](Introduction.md) | [Datasets](Datasets.md) | [Tasks](Tasks.md) | [Task 1 Guidance](Task-download.md) | [Task 2A Guidance](Task-greedy.md) | Task 2B Guidance ⮕ | [Notebook](nids-irr-rpki-whois.ipynb)

# Task 2B Guidance: Classifying Prefix-Origin Pairs

This page prepares you to implement the three classifier functions required in [Task 2B](Tasks.md): `classify_rpki`, `classify_irr`, and `classify_irr_rpki_consistency`.

## How `covering_vrps` and `covering_irr_records` work

Both helper functions are built on `py-radix`'s `search_covering(prefix)` method. This method returns all nodes in the trie whose stored prefix is the same size as or less-specific than the query prefix — it looks **up** toward covering supernets, not down toward more-specific subnets.

If you call `search_covering('10.1.0.0/24')`, you get back any trie entry for `10.0.0.0/8`, `10.1.0.0/16`, or `10.1.0.0/24` — any prefix that covers your query.

This is the **opposite direction** from Pytricia's `children()` call in nids-bgp-control-plane, which returns more-specific subnets. Here you look up to find all VRPs or IRR records that could apply to an observed BGP announcement.

## RPKI classification

For each BGP prefix-origin pair, `classify_rpki` checks all covering VRPs and returns one of four outcomes.

| Outcome | Condition |
|---|---|
| `valid` | At least one covering VRP exists with matching origin AS **and** prefix_length ≤ VRP max_length |
| `invalid_length` | A covering VRP with matching origin AS exists, but prefix_length > max_length for all of them |
| `invalid_asn` | Covering VRPs exist, but none have the matching origin AS |
| `not_found` | No covering VRP exists |

**Check in this priority order.** Return `valid` as soon as you find one qualifying VRP — do not continue checking. Only return `invalid_length` if you have found a VRP with a matching AS but the length fails. Only return `invalid_asn` if VRPs exist but none match the origin AS.

### Worked example

ROA from Introduction.md: `137.110.0.0/16, maxLength=20, AS7377`

| BGP announcement | Outcome | Reason |
|---|---|---|
| `137.110.0.0/16 from AS7377` | `valid` | Covering VRP: AS matches, 16 ≤ 20 |
| `137.110.0.0/20 from AS7377` | `valid` | Covering VRP: AS matches, 20 ≤ 20 |
| `137.110.0.0/24 from AS7377` | `invalid_length` | Covering VRP: AS matches, but 24 > 20 |
| `137.110.0.0/16 from AS64500` | `invalid_asn` | Covering VRP exists, AS 64500 ≠ 7377 |
| `8.8.8.0/24 from AS15169` | `not_found` | No covering VRP |

## IRR classification

IRR route objects do not have a `maxLength` field. For a BGP announcement to be `valid`, there must be a route object with the **exact same prefix** and the same origin AS. A covering (less-specific) record with a matching AS produces `invalid_length`, not `valid`.

| Outcome | Condition |
|---|---|
| `valid` | A covering IRR record exists with the exact same prefix **and** matching origin AS |
| `invalid_length` | A covering IRR record exists with matching origin AS but a different (less-specific) prefix |
| `invalid_asn` | Covering IRR records exist, but none have the matching origin AS |
| `not_found` | No covering IRR record exists |

Same priority order as RPKI: valid → invalid_length → invalid_asn → not_found.

### Worked example

IRR has `35.228.0.0/16 origin AS15169`.

| BGP announcement | Outcome | Reason |
|---|---|---|
| `35.228.0.0/16 from AS15169` | `valid` | Exact prefix match, AS matches |
| `35.228.224.0/19 from AS15169` | `invalid_length` | Covering record (/16 covers /19), AS matches, but prefix differs |
| `35.228.224.0/19 from AS64500` | `invalid_asn` | Covering record exists, AS 64500 ≠ 15169 |
| `192.0.2.0/24 from AS15169` | `not_found` | No covering IRR record |

## IRR/RPKI consistency (Task 3)

`classify_irr_rpki_consistency` is applied to **IRR records**, not BGP announcements. It asks: "Is this IRR route object consistent with what RPKI authorizes?" The structure is identical to `classify_rpki`, but the input prefix and origin come from the IRR record itself.

| Outcome | Meaning |
|---|---|
| `consistent` | A covering VRP exists with matching origin AS and IRR prefix_length ≤ max_length |
| `inconsistent_length` | A covering VRP with matching AS exists, but the IRR prefix is more specific than max_length |
| `inconsistent_asn` | Covering VRPs exist, but none match the IRR origin AS |
| `not_in_rpki` | No covering VRP exists for this IRR prefix |

`not_in_rpki` is **not the same** as `not_found` from Task 2B. The label differs because the absence of RPKI coverage for an IRR record is a distinct situation from a BGP route with no RPKI coverage — many legitimate IRR records describe prefixes that simply have not been registered in RPKI yet.

## Common pitfalls

**`AS` prefix in origin field.** The scaffolding's `normalize_asn()` strips `AS15169` → `15169`. If you call a classifier with a raw field value that has not been normalized, the ASN comparison will silently fail and everything will return `invalid_asn` or `not_found`. Verify your inputs are already normalized integers before testing.

**Returning `invalid_asn` when `invalid_length` is correct.** First check whether any covering VRP or IRR record has the matching origin AS. If yes and the length condition fails, the result is `invalid_length`. Only return `invalid_asn` when no covering candidate matches the origin AS at all.

**Not short-circuiting on `valid`.** As soon as you find one VRP or IRR record that grants validity, return immediately. Do not continue iterating — the priority order only matters when no valid candidate exists.

[README](README.md) | [Introduction](Introduction.md) | [Datasets](Datasets.md) | [Tasks](Tasks.md) | [Task 1 Guidance](Task-download.md) | [Task 2A Guidance](Task-greedy.md) | Task 2B Guidance ⮕ | [Notebook](nids-irr-rpki-whois.ipynb)
