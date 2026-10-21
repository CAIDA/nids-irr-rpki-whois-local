[README](README.md) | [Introduction](Introduction.md) | [Datasets](Datasets.md) | [Tasks](Tasks.md) | Task 1 Guide ⮕ | [Task 2A Guide](Task-greedy.md) | [Task 2B Guide](Task-classify.md) | [Notebook](nids-irr-rpki-whois.ipynb)

# Task 1: Download the Data and Run the Notebook Locally

This notebook reads all data from local files under `data/`. Complete the
steps below once to populate `data/`, then run the notebook on your own
machine. All three datasets are downloadable with plain `curl` — no NRP
account or `kubectl` access is required.

## Step 1 — Download the data

Run the provided script from this module's directory:

```bash
./download-data.sh
```

It downloads and extracts all the files listed below and is safe to re-run —
it skips anything already present and intact, and retries corrupt or missing
files. If it's interrupted, just run it again.

### What the script does

**IRR snapshots (16 sources × 6 monthly dates)** — CAIDA has packaged the
snapshots this assignment needs into a single archive:

```bash
mkdir -p data
curl -f --retry 3 -o data/irr_dumps.zip \
  "https://users.caida.org/~bhuffake/nids/irr_dumps.zip"
(cd data && unzip -oq irr_dumps.zip)
```

This extracts to `data/irr_dumps/<YYYY-MM-DD>/ftp.radb.net/radb/dbase/<source>.db.gz`.

> If `download-data.sh` reports missing IRR files after extracting the zip,
> check for an updated `irr_dumps.zip`, or see "If you have direct access to
> CAIDA's IRR archive" below.

**RPKI VRPs (5 trust anchors × 6 monthly dates)** — public archive, plain
`curl`. Note there is no 2023-04-01 IRR snapshot, so April uses 2023-04-03
for both IRR and RPKI (see [Tasks.md](Tasks.md)):

```bash
DATES="2023-01-01 2023-02-01 2023-03-01 2023-04-03 2023-05-01 2023-06-01"
TAS="afrinic ripencc arin lacnic apnic"
for d in $DATES; do
  yyyy=${d:0:4}; mm=${d:5:2}; dd=${d:8:2}
  for ta in $TAS; do
    mkdir -p "data/rpki/$ta.tal/$yyyy/$mm/$dd"
    curl -f --retry 3 -o "data/rpki/$ta.tal/$yyyy/$mm/$dd/roas.csv.xz" \
      "https://ftp.ripe.net/ripe/rpki/$ta.tal/$yyyy/$mm/$dd/roas.csv.xz"
  done
done
```

**Routeviews prefix2as (1 file, sample date only)** — public archive:

```bash
mkdir -p data/routeviews-prefix2as/2023/03
curl -f --retry 3 \
  -o data/routeviews-prefix2as/2023/03/routeviews-rv2-20230301-1200.pfx2as.gz \
  "https://publicdata.caida.org/datasets/routing/routeviews-prefix2as/2023/03/routeviews-rv2-20230301-1200.pfx2as.gz"
```

## Step 2 — Verify the download

```bash
find data -type f \( -name '*.db.gz' -o -name '*.pfx2as.gz' -o -name '*.xz' \) | wc -l   # expect 124
find data -type f \( -name '*.db.gz' -o -name '*.pfx2as.gz' \) -exec gzip -t {} +         # no output = all gzip files intact
find data -type f -name '*.xz' -exec xz -t {} +                                          # no output = all xz files intact
du -sh data
```

> The current `irr_dumps.zip` has three IRR dumps truncated at the source
> (`2023-01-01/altdb`, `2023-01-01/arin`, `2023-01-01/bell`), so the expected
> count is 124, not the full 127. `download-data.sh` treats these as
> known-missing and still reports success once everything else is present.

`radb.db.gz` is by far the largest file per date; the full download takes a
while the first time. Once `data/` is populated, install the Python
dependencies and run the notebook:

```bash
pip install jupyter pandas numpy matplotlib tqdm py-radix
jupyter notebook nids-irr-rpki-whois.ipynb
```

### If you have direct access to CAIDA's IRR archive

`copy.py` in this directory copies IRR snapshots straight from
`/data/routing/irr_dumps/` on a machine where that path is mounted (e.g. a
CAIDA-internal host). It skips files you already have, so it's a way to
back-fill anything missing from `irr_dumps.zip` without re-downloading
everything:

```bash
cd data && uv run ../copy.py
```

Most students won't have access to that path — use `download-data.sh` above
instead.

[README](README.md) | [Introduction](Introduction.md) | [Datasets](Datasets.md) | [Tasks](Tasks.md) | Task 1 Guide ⮕ | [Task 2A Guide](Task-greedy.md) | [Task 2B Guide](Task-classify.md) | [Notebook](nids-irr-rpki-whois.ipynb)
