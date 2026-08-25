README ⮕ | [Introduction](Introduction.md) | [Datasets](Datasets.md) | [Tasks](Tasks.md) | [Task 1 Guidance](Task-download.md) | [Task 2A Guidance](Task-greedy.md) | [Task 2B Guidance](Task-classify.md) | [Notebook](nids-irr-rpki-whois.ipynb)

### Network Infrastructure Data Science (NIDS) Module

---

# Regional Internet Registry, IRR, and RPKI

## Learning Objectives

The goal of this assignment is to understand how Regional Internet Registries (RIRs), Internet Routing Registry (IRR) databases, and the Resource Public Key Infrastructure (RPKI) describe Internet number resources and routing authorization. Students will compare IRR route objects, RPKI Route Origin Authorizations (ROAs), and observed BGP prefix-origin pairs to understand how these data sources agree, disagree, and expose different parts of operational reality.

By the end of this assignment, students will be able to:

- explain the roles of the five RIRs: ARIN, RIPE NCC, APNIC, LACNIC, and AFRINIC
- distinguish address registration, address delegation, and BGP origination
- describe the IRR as a collection of distributed routing-policy databases
- identify common IRR object types, including `route` and `route6`
- distinguish authoritative RIR-operated IRR databases from non-authoritative IRR databases such as RADB
- explain how RPKI ROAs and validated ROA payloads (VRPs) authorize BGP prefix-origin pairs
- classify BGP announcements as RPKI-valid, RPKI-invalid, or RPKI-not-found
- compare IRR, RPKI, and BGP data to identify stale, missing, inconsistent, or suspicious routing records

## Slides

- [ETP week 03 IRR/RPKI](slides/ETP-Week-03-Registries.pptx)

## Overview

This module assumes you have completed nids-asn-introduction and nids-bgp-control-plane. Familiarity with ASNs, BGP prefix origination, and the Routeviews prefix-to-AS dataset is assumed.

Start by reading **Introduction** to get the background needed to understand RIRs, IRR databases, RPKI, and observed BGP routing data. **Datasets** explains each dataset and how to access it. **Tasks** describes the analysis steps and deliverables.

- step 1 [read the introduction](Introduction.md)
- step 2 [read dataset overviews](Datasets.md)
- step 3 [review the tasks](Tasks.md)
  - before Task 1, follow [Task-download.md](Task-download.md) to download the data you'll need to `data/`
  - before Task 2A, read [Task 2A Guidance](Task-greedy.md) for the greedy coverage algorithm and a worked example
  - before Task 2B, read [Task 2B Guidance](Task-classify.md) for classifier decision trees and worked examples
- step 4 install dependencies and run `nids-irr-rpki-whois.ipynb` locally

  ```bash
  pip install jupyter pandas numpy matplotlib tqdm py-radix
  jupyter notebook nids-irr-rpki-whois.ipynb
  ```

  - complete each task by replacing the `# YOUR CODE HERE` sections
  - answer all written questions

- step 5 save your completed notebook and replace the starter notebook ⬅ deliverable
- step 6 commit and push to GitHub

### Directory Structure

    nids-irr-rpki-whois
    ├- Introduction.md                 # Introduction and background
    ├- Datasets.md                     # Dataset overview and download instructions
    ├- Tasks.md                        # Task checklist and instructions
    ├- Task-download.md                # Task 1 guidance: download IRR/RPKI/prefix2as data locally
    ├- Task-greedy.md                  # Task 2A guidance: greedy coverage ordering
    ├- Task-classify.md                # Task 2B guidance: classifier decision trees and worked examples
    ├- download-data.sh                # Downloads all required data into data/
    ├- data/                           # Downloaded data (populated by download-data.sh, not committed)
    ├- cache_nids/                     # Parsed per-day caches (created at runtime, not committed)
    ├- nids-irr-rpki-whois.ipynb   ⬅  # Complete / Commit / Push

### Readings

- Du et al., _IRR Hygiene in the RPKI Era_, PAM 2022.
- Du et al., _IRRegularities in the Internet Routing Registry_, IMC 2023.
- ICANN SSAC 121 routing-security briefing.
- Testart and Clark, _Internet Routing Registries, Data Governance, and Security_, 2017.

### Glossary

- **RIR (Regional Internet Registry)**: An organization that allocates and registers Internet number resources within a geographic service region. The five RIRs are ARIN, RIPE NCC, APNIC, LACNIC, and AFRINIC.
- **BGP (Border Gateway Protocol)**: The interdomain routing protocol used by ASes to announce reachability to IP prefixes.
- **ASN (Autonomous System Number)**: A globally unique number used to identify an AS in BGP and registry data.
- **BGP prefix-origin pair**: A pair consisting of an IP prefix and the AS observed originating that prefix in BGP.
- **IRR (Internet Routing Registry)**: A collection of distributed routing-policy databases used by networks to publish routing information and support construction of BGP route filters.
- **RPSL (Routing Policy Specification Language)**: The language used to represent routing-policy objects in IRR databases.
- **Authoritative IRR database**: An IRR database operated by an RIR that validates routing records against the RIR's resource-registration data.
- **Non-authoritative IRR database**: An IRR database that is not operated by an RIR. RADB is a widely used example.
- **RADB (Routing Assets Database)**: A large non-authoritative IRR database operated by Merit Network.
- **route / route6 object**: An IRR object that associates an IPv4 or IPv6 prefix with an origin AS.
- **RPKI (Resource Public Key Infrastructure)**: A cryptographic infrastructure used to verify authorization over IP address and AS number resources.
- **ROA (Route Origin Authorization)**: An RPKI object that authorizes an AS to originate a prefix up to a specified maximum prefix length.
- **VRP (Validated ROA Payload)**: A validated tuple derived from ROAs, usually consisting of prefix, maximum length, origin AS, and trust anchor.
- **ROV (Route Origin Validation)**: The process of checking a BGP route announcement against RPKI VRPs.
- **RPKI-valid**: A BGP announcement whose prefix and origin AS are authorized by a covering VRP and whose prefix length does not exceed the VRP maximum length.
- **RPKI-invalid**: A BGP announcement that is covered by a VRP but has an unauthorized origin AS or an unauthorized prefix length.
- **RPKI-not-found**: A BGP announcement for which no covering VRP exists.
- **py-radix (Radix)**: A Python prefix trie library used in this notebook for longest-prefix-match lookups. The `tree.search_covering(prefix)` method returns all stored prefixes that are covering supernets of or equal to the query prefix.
- **Trust anchor (TA)**: The top-level RPKI certificate for an RIR. Each VRP carries the `trust_anchor` of the RIR whose archive validated it (`afrinic`, `ripencc`, `arin`, `lacnic`, or `apnic`).

README ⮕ | [Introduction](Introduction.md) | [Datasets](Datasets.md) | [Tasks](Tasks.md) | [Task 1 Guidance](Task-download.md) | [Task 2A Guidance](Task-greedy.md) | [Task 2B Guidance](Task-classify.md) | [Notebook](nids-irr-rpki-whois.ipynb)
