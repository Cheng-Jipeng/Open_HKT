"""Download the Fed Z.1 / NIPA series used for the credit and buyback check from FRED.

Run from this folder:
  uv run --no-project --python 3.12 python -I fetch_fred.py
Writes ../data/raw/fred/<ID>.csv (FRED fredgraph.csv, unmodified) and ../data/raw/fred/_metadata.csv
(title, units, frequency, last observation, retrieval date). Existing files are kept unless --refresh is passed.
"""
import csv
import html
import re
import subprocess
import sys
import time
from datetime import date
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "data" / "raw" / "fred"
OUT.mkdir(parents=True, exist_ok=True)
REFRESH = "--refresh" in sys.argv

# id: role (all NFC = Z.1 nonfinancial corporate business unless stated)
SERIES = {
    # ---- balance sheet, levels (B.103 / L.103), end of quarter
    "BOGZ1LM102010405Q": "Q_NFC: market value estimate of nonfinancial assets (AHP enterprise value)",
    "NCBEILQ027S": "E_NFC: corporate equities, liability, market value",
    "TLBSNNCB": "total liabilities (excl. equity)",
    "TFAABSNNCB": "total financial assets",
    "BCNSDODNS": "debt securities and loans, liability",
    "NCBDBIQ027S": "debt securities, liability",
    "BOGZ1FL103167205Q": "private credit loans, liability",
    "BOGZ1LM102010005Q": "K_NFC: nonfinancial assets (real estate at market value, other at current cost)",
    "BOGZ1FL105035023Q": "residential real estate at market value",
    "BOGZ1FL105035033Q": "nonresidential real estate at market value",
    "BOGZ1LM105015205Q": "equipment, current cost",
    "BOGZ1LM105013765Q": "intellectual property products, current cost",
    "BOGZ1LM105020015Q": "inventories",
    "BOGZ1LM102090005Q": "net worth, market value",
    "BOGZ1LM103192105Q": "foreign direct investment in U.S., liability, market value (enters Q)",
    "BOGZ1LM792010405Q": "financial business: market value estimate of nonfinancial assets (for the NFC share of AHP Q)",
    # ---- flows (F.103 / S.5), quarterly NSA flows (FU) are summed over Q1-Q4
    "BOGZ1FU104104005Q": "net borrowing: debt securities and loans, transactions",
    "BOGZ1FU103164103Q": "net equity issuance: corporate equities, liability, transactions (negative = net buybacks)",
    "BOGZ1FU106121075Q": "net dividends paid",
    "BOGZ1FU106121001A": "dividends paid (gross), annual",
    "BOGZ1FU105050005Q": "capital expenditures",
    "BOGZ1FU105050985Q": "net capital formation",
    "BOGZ1FU104090005Q": "net acquisition of financial assets",
    "BOGZ1FU104190005Q": "net increase in total liabilities",
    "BOGZ1FU103192005Q": "foreign direct investment in U.S., liability, transactions",
    "BOGZ1FU106130003Q": "net interest and miscellaneous payments",
    "BOGZ1FU106402101Q": "net operating surplus",
    "BOGZ1FU106220001Q": "taxes on corporate income",
    "BOGZ1FU106902501Q": "gross value added",
    "BOGZ1FU106025005Q": "compensation of employees paid",
}
# The FCF decomposition uses the full Z.1 table S.5.a (S11.1.i.a) instead: see fetch_z1.py.


def get(url: str) -> bytes:
    # curl rather than urllib: urllib reads from fred.stlouisfed.org time out on this machine (2026-11-18)
    for k in range(4):
        r = subprocess.run(["curl", "-sS", "--fail", "--max-time", "90", url], capture_output=True)
        if r.returncode == 0 and r.stdout:
            return r.stdout
        if k == 3:
            raise RuntimeError(f"{url}: {r.stderr.decode()[:200]}")
        time.sleep(2 + 3 * k)


meta_rows = []
for sid, role in SERIES.items():
    f = OUT / f"{sid}.csv"
    if REFRESH or not f.exists():
        f.write_bytes(get(f"https://fred.stlouisfed.org/graph/fredgraph.csv?id={sid}"))
    page = get(f"https://fred.stlouisfed.org/series/{sid}").decode("utf-8", "ignore")
    title = re.search(r"<title>(.*?)\|", page, re.S)
    title = html.unescape(title.group(1)).strip() if title else ""
    text = re.sub(r"\s+", " ", html.unescape(re.sub("<.*?>", " ", page)))
    units = re.search(r"Units:\s*(.*?)\s*Frequency:", text)
    units = units.group(1).replace(" ,", ",").strip() if units else ""
    rows = [r for r in csv.reader(f.read_text().splitlines())][1:]
    rows = [r for r in rows if len(r) == 2 and r[1] not in ("", ".")]
    meta_rows.append(dict(id=sid, role=role, title=title, units=units, first=rows[0][0], last=rows[-1][0],
                          n=len(rows), retrieved=date.today().isoformat()))
    print(f"{sid:22s} {rows[0][0]} .. {rows[-1][0]}  {title[:80]}  [{units}]")

with open(OUT / "_metadata.csv", "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=list(meta_rows[0]))
    w.writeheader()
    w.writerows(meta_rows)
