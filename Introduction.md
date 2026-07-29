[README](README.md) | Introduction ⮕ | [Datasets](Datasets.md) | [Tasks](Tasks.md) | [Task 1 Guidance](Task-download.md) | [Task 2A Guidance](Task-greedy.md) | [Task 2B Guidance](Task-classify.md) | [Notebook](nids-irr-rpki-whois.ipynb)

# Introduction and Background

### Reading

- Du et al., _IRR Hygiene in the RPKI Era_, PAM 2022.
- Du et al., _IRRegularities in the Internet Routing Registry_, IMC 2023.
- ICANN SSAC 121 routing-security briefing.

### Prerequisite NIDS Assignments

- [How the Internet assigns and uses Autonomous Systems (ASes)](https://github.com/CAIDA/nids-asn-introduction)
- [Understanding the BGP Control Plane](https://github.com/CAIDA/nids-bgp-control-plane)

## Introduction

The Internet routing system depends on multiple databases that describe different parts of routing authority. In this assignment, you will study three important sources of routing and registration data: Regional Internet Registry (RIR) WHOIS/RDAP records, Internet Routing Registry (IRR) records, and Resource Public Key Infrastructure (RPKI) Route Origin Authorizations (ROAs). You will compare these data sources with observed BGP prefix-origin pairs to understand where registry data agrees with routing behavior, where it disagrees, and why those disagreements matter for routing security.

This module builds on nids-asn-introduction and nids-bgp-control-plane. You should already be familiar with: Autonomous System Numbers (ASNs) and how ASes originate prefixes in BGP; the Routeviews prefix-to-AS dataset; CIDR prefix notation and longest-prefix-match semantics. This module adds two new data sources — IRR route objects and RPKI VRPs — that you will compare against the BGP prefix-origin pairs you already know.

## Regional Internet Registries and WHOIS

The five Regional Internet Registries — ARIN, RIPE NCC, APNIC, LACNIC, and AFRINIC — allocate and register Internet number resources, including IPv4 addresses, IPv6 addresses, and Autonomous System Numbers (ASNs). RIRs maintain registration databases that describe which organizations hold address space and AS numbers. These records are commonly queried through WHOIS or RDAP.

RIR WHOIS/RDAP data can help answer questions such as:

- Which organization is registered as the holder of an IP address block?
- Which AS numbers are registered to an organization?
- Which contacts or maintainers are associated with a resource?
- What status or registration metadata is attached to an address block?

However, RIR WHOIS/RDAP data does not always tell us who currently operates a prefix in BGP. The registered holder of a prefix, the organization using the prefix, and the AS originating the prefix in BGP may be different entities. For this reason, WHOIS/RDAP records should be interpreted together with observed BGP data and routing-authorization data.

A simplified WHOIS-style record for an address block may look like this:

```text
inetnum:        203.0.113.0 - 203.0.113.255
netname:        EXAMPLE-NET
descr:          Example Network
country:        US
mnt-by:         EXAMPLE-MNT
status:         ASSIGNED
source:         RIPE
```

WHOIS records are useful, but they should not be treated as a complete description of operational routing. They describe registration and administration, while BGP describes what is actually routed.

## Internet Routing Registry

The Internet Routing Registry (IRR) is a collection of distributed routing-policy databases. Network operators use the Routing Policy Specification Language (RPSL) to register routing information in one or more IRR databases. Other operators can then use IRR data to build BGP route filters.

The IRR is not one single database. It is an ecosystem of databases operated by different organizations, including RIRs, commercial networks, non-profit organizations, and other routing registries. Examples include RADB, RIPE, APNIC, AFRINIC, ARIN, NTTCOM, ALTDB, and others.

Some IRR databases are authoritative for the resources they cover. For example, RIR-operated IRR databases can validate route objects against the RIR's own resource-registration data. Other IRR databases, such as RADB, are non-authoritative for many of the resources registered in them. These databases can still be widely used operationally, but their records may be stale, duplicated, weakly validated, or inconsistent with other sources.

Common IRR object types include:

- `route`: maps an IPv4 prefix to an origin AS
- `route6`: maps an IPv6 prefix to an origin AS
- `aut-num`: describes an Autonomous System and may include routing-policy information
- `as-set`: groups ASes or other AS sets, often for customer or peer filtering
- `mntner`: stores authentication and maintainer information used to create or modify IRR records

A RADB-style `route` object may look like this:

```text
route:          35.228.224.0/19
descr:          Google
origin:         AS15169
mnt-by:         MAINT-AS15169
changed:        noc@google.com 20180316
source:         RADB
```

This object says that AS15169 is registered in RADB as an origin for prefix `35.228.224.0/19`. Network operators may use this information to decide whether to accept a BGP announcement for that prefix from that AS.

IRR data is important because many networks still use IRR-based filters. However, IRR data quality varies across databases. A route object may remain in the IRR after the prefix changes origin AS, after the address space changes hands, or after the operator stops using the prefix. In some cases, attackers have created false IRR records to make unauthorized BGP announcements look legitimate to upstream providers. Such a mismatch between IRR records and observed routing does not by itself prove that a record is malicious, but it is a signal that the prefix-origin information needs further investigation.

### IRR Lookup Semantics

IRR route objects do not have a `maxLength` field. For a BGP announcement to be considered IRR-valid, there must be a route object with the exact same prefix and the same origin AS. A route object for a covering (less-specific) prefix with the matching origin AS produces `invalid_length`, not `valid`. This makes IRR stricter than RPKI on prefix matching, even though IRR databases are less rigorously verified.

## RPKI and Route Origin Authorization

The Resource Public Key Infrastructure (RPKI) provides a cryptographic way for address holders to authorize which ASes may originate their prefixes in BGP. The most important RPKI object for this assignment is the Route Origin Authorization (ROA).

A ROA authorizes an AS to originate a prefix up to a maximum prefix length. A simplified ROA can be represented as:

```text
prefix:       137.110.0.0/16
asn:          AS7377
maxLength:    20
```

This ROA means that AS7377 is authorized to originate `137.110.0.0/16` and any subprefix no more specific than `/20`. For example:

```text
137.110.0.0/16 announced by AS7377  -> RPKI-valid
137.110.0.0/20 announced by AS7377  -> RPKI-valid
137.110.0.0/24 announced by AS7377  -> RPKI-invalid because prefix length is too specific
137.110.0.0/16 announced by AS64500 -> RPKI-invalid because origin AS does not match
```

Validated ROA Payloads (VRPs) are the validated prefix, maximum length, origin AS, and trust-anchor tuples derived from ROAs. Operators use VRPs to perform Route Origin Validation (ROV), which classifies BGP announcements into three categories:

- **RPKI-valid**: the prefix and origin AS are authorized by a covering VRP, and the prefix length is allowed
- **RPKI-invalid**: the prefix is covered by a VRP, but the origin AS or prefix length is not authorized
- **RPKI-not-found**: no covering VRP exists

The notebook uses a four-class scheme that splits `RPKI-invalid` into two sub-categories and adds explicit priority ordering:

| Outcome          | Condition                                                                                     |
| ---------------- | --------------------------------------------------------------------------------------------- |
| `valid`          | At least one covering VRP exists with matching origin AS and prefix_length ≤ max_length       |
| `invalid_length` | A covering VRP with matching origin AS exists, but prefix_length > max_length for all of them |
| `invalid_asn`    | Covering VRPs exist, but none have the matching origin AS                                     |
| `not_found`      | No covering VRP exists                                                                        |

Check in priority order — `valid` short-circuits: once you find one VRP that grants validity, return immediately without checking others.

RPKI changes the trust model because ROAs are cryptographically tied to the RIR resource hierarchy. However, RPKI does not describe all routing policy, and not all routed prefixes have ROAs. In practice, IRR and RPKI operate in parallel.

## Radix Trees and Prefix Lookups

The notebook uses the `py-radix` library to build prefix tries over VRP and IRR data. These tries support efficient `search_covering(prefix)` queries.

`search_covering(prefix)` returns all nodes in the trie whose stored prefix is the same size as or less-specific than the query prefix. If you call `search_covering('10.1.0.0/24')`, you get back entries for `10.0.0.0/8`, `10.1.0.0/16`, and `10.1.0.0/24` if they exist — any prefix that is a covering supernet of or equal to your query.

This is the opposite direction from Pytricia's `children()` call in nids-bgp-control-plane, which returns more-specific subnets. Here you look _up_ toward covering supernets to find all VRPs or IRR records that could apply to an observed BGP announcement.

In the longitudinal analysis (Task 3), you will compare IRR route objects against RPKI VRPs across monthly snapshots from January through June 2023 to measure how often the two systems agree or disagree about prefix-origin authorization, and how that disagreement changes over time.

For this assignment, you will explore the following datasets:

- **RIR WHOIS/RDAP data** — Registration records describing address blocks, AS numbers, organizations, contacts, and maintainers.
- **IRR mirror snapshots** — Route-policy records from RADB and other IRR databases, including `route`, `route6`, `aut-num`, `as-set`, and `mntner` objects.
- **RPKI VRP archives** — Validated ROA payloads used to determine whether observed BGP prefix-origin pairs are RPKI-valid, RPKI-invalid, or RPKI-not-found.
- **BGP prefix-to-AS tables** — Observed prefix-origin pairs derived from Routeviews and RIPE RIS routing data.

#### Optional Reading

- [CAIDA Routeviews Prefix-to-AS Dataset](https://catalog.caida.org/dataset/routeviews_prefix2as)
- [CAIDA AS Organizations Dataset](https://catalog.caida.org/dataset/as_organizations)
- [MANRS Observatory](https://www.manrs.org/netops/observatory/)
- [RPKI Documentation](https://rpki.readthedocs.io/)
- [Routinator](https://github.com/NLnetLabs/routinator)
- [RADB](https://www.radb.net/)
- [RIPE Database Documentation](https://docs.db.ripe.net/)

[README](README.md) | Introduction ⮕ | [Datasets](Datasets.md) | [Tasks](Tasks.md) | [Task 1 Guidance](Task-download.md) | [Task 2A Guidance](Task-greedy.md) | [Task 2B Guidance](Task-classify.md) | [Notebook](nids-irr-rpki-whois.ipynb)
