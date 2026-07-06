#!/usr/bin/env bash
# Download the IRR, RPKI, and Routeviews prefix2as files this notebook needs
# into data/. Safe to re-run: existing, intact files are skipped.
# See Task-download.md for details.
set -euo pipefail

DATA_DIR="data"
IRR_ZIP_URL="https://users.caida.org/~bhuffake/nids/irr_dumps.zip"
IRR_ZIP="$DATA_DIR/irr_dumps.zip"
RPKI_BASE="https://ftp.ripe.net/ripe/rpki"
PREFIX2AS_BASE="https://publicdata.caida.org/datasets/routing/routeviews-prefix2as"

# There is no 2023-04-01 snapshot in the IRR archive; April uses 2023-04-03
# instead for both IRR and RPKI, so the two stay directly comparable.
DATES=(2023-01-01 2023-02-01 2023-03-01 2023-04-03 2023-05-01 2023-06-01)
IRR_SOURCES=(altdb arin bboi bell canarie host jpirr level3 nestegg nttcom openface panix radb reach rgnet tc)
TRUST_ANCHORS=(afrinic ripencc arin lacnic apnic)
SAMPLE_DATE="2023-03-01"

irr_ok=0
irr_total=0
rpki_ok=0
rpki_total=0
pfx_ok=0
pfx_total=0

file_ok() {
  local path="$1"
  [[ -s "$path" ]] || return 1
  case "$path" in
    *.gz) gzip -t "$path" >/dev/null 2>&1 ;;
    *.xz) xz -t "$path" >/dev/null 2>&1 ;;
    *) true ;;
  esac
}

mkdir -p "$DATA_DIR"

# Determine whether any IRR file is missing before bothering with the zip.
irr_missing=0
for d in "${DATES[@]}"; do
  for s in "${IRR_SOURCES[@]}"; do
    irr_total=$((irr_total + 1))
    out="$DATA_DIR/irr_dumps/$d/ftp.radb.net/radb/dbase/$s.db.gz"
    if ! file_ok "$out"; then
      irr_missing=1
    fi
  done
done

if [[ "$irr_missing" == "1" ]]; then
  if [[ ! -s "$IRR_ZIP" ]] || ! unzip -tq "$IRR_ZIP" >/dev/null 2>&1; then
    echo "Downloading IRR snapshots archive..."
    rm -f "$IRR_ZIP"
    curl -f --retry 3 -o "$IRR_ZIP" "$IRR_ZIP_URL"
  fi
  echo "Extracting IRR snapshots..."
  (cd "$DATA_DIR" && unzip -oq irr_dumps.zip)
fi

irr_missing_files=()
for d in "${DATES[@]}"; do
  for s in "${IRR_SOURCES[@]}"; do
    out="$DATA_DIR/irr_dumps/$d/ftp.radb.net/radb/dbase/$s.db.gz"
    if file_ok "$out"; then
      irr_ok=$((irr_ok + 1))
    else
      irr_missing_files+=("$d/$s")
    fi
  done
done

for mm_idx in "${!DATES[@]}"; do
  d="${DATES[$mm_idx]}"
  yyyy="${d:0:4}"
  mm="${d:5:2}"
  dd="${d:8:2}"
  for ta in "${TRUST_ANCHORS[@]}"; do
    rpki_total=$((rpki_total + 1))
    dir="$DATA_DIR/rpki/$ta.tal/$yyyy/$mm/$dd"
    mkdir -p "$dir"
    out="$dir/roas.csv.xz"
    if file_ok "$out"; then
      rpki_ok=$((rpki_ok + 1))
      continue
    fi
    rm -f "$out"
    echo "Fetching RPKI $ta $d..."
    if curl -f --retry 3 -o "$out" "$RPKI_BASE/$ta.tal/$yyyy/$mm/$dd/roas.csv.xz" \
        && file_ok "$out"; then
      rpki_ok=$((rpki_ok + 1))
    else
      echo "WARNING: failed to download RPKI $ta $d" >&2
      rm -f "$out"
    fi
  done
done

pfx_total=1
sample_yyyy="${SAMPLE_DATE:0:4}"
sample_mm="${SAMPLE_DATE:5:2}"
pfx_dir="$DATA_DIR/routeviews-prefix2as/$sample_yyyy/$sample_mm"
mkdir -p "$pfx_dir"
pfx_out="$pfx_dir/routeviews-rv2-${sample_yyyy}${sample_mm}01-1200.pfx2as.gz"
if file_ok "$pfx_out"; then
  pfx_ok=1
else
  rm -f "$pfx_out"
  echo "Fetching Routeviews prefix2as $SAMPLE_DATE..."
  if curl -f --retry 3 -o "$pfx_out" \
      "$PREFIX2AS_BASE/$sample_yyyy/$sample_mm/routeviews-rv2-${sample_yyyy}${sample_mm}01-1200.pfx2as.gz" \
      && file_ok "$pfx_out"; then
    pfx_ok=1
  else
    echo "WARNING: failed to download Routeviews prefix2as $SAMPLE_DATE" >&2
    rm -f "$pfx_out"
  fi
fi

total_ok=$((irr_ok + rpki_ok + pfx_ok))
total_expected=$((irr_total + rpki_total + pfx_total))
echo
echo "IRR files:       $irr_ok/$irr_total"
echo "RPKI files:       $rpki_ok/$rpki_total"
echo "Prefix2as files:  $pfx_ok/$pfx_total"
echo "Total:            $total_ok/$total_expected"

if [[ "${#irr_missing_files[@]}" -gt 0 ]]; then
  echo >&2
  echo "Missing IRR files (not in irr_dumps.zip):" >&2
  printf '  %s\n' "${irr_missing_files[@]}" >&2
  echo "Check for an updated irr_dumps.zip download. If you have direct" >&2
  echo "access to CAIDA's IRR archive, run: cd data && uv run ../copy.py" >&2
fi

if [[ "$total_ok" != "$total_expected" ]]; then
  exit 1
fi

echo "All data downloaded successfully."
