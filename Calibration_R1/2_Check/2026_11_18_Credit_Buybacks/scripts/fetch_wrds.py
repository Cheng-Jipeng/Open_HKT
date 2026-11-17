"""Compustat pulls for the credit and buyback check (2026-11-18).

1. comp.funda, all US-incorporated USD filers, fiscal 1989-2026: payout (dividends, repurchases, issuance),
   debt (stocks and gross flows), cash, investment, R&D and market value.
2. comp.fundq for eight AI-related firms, 2014Q1 onward, to see 2025-26, which the annual file does not yet cover.

Direct PostgreSQL route (wrds-pgdata), credentials from ~/.pgpass (never stored here). Run from this folder:
  WRDS_USER=$(cut -d: -f4 ~/.pgpass | head -1) uv run --no-project --python 3.12 --with wrds --with pandas python -I fetch_wrds.py
Writes ../data/raw/wrds/{funda_us_1989_2026,company_us,fundq_ai_firms}.csv.gz and manifest.json. Never overwrites.
"""
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import wrds

OUT = Path(__file__).resolve().parent.parent / "data" / "raw" / "wrds"
OUT.mkdir(parents=True, exist_ok=True)
FILES = {k: OUT / f"{k}.csv.gz" for k in ("funda_us_1989_2026", "company_us", "fundq_ai_firms")}
for f in [*FILES.values(), OUT / "manifest.json"]:
    if f.exists():
        sys.exit(f"refusing to overwrite {f}")

AI_FIRMS = {"001690": "AAPL", "012141": "MSFT", "012142": "ORCL", "051139": "CRWV",
            "064768": "AMZN", "117768": "NVDA", "160329": "GOOGL", "170617": "META"}

SQL = {
    "funda_us_1989_2026": """
select gvkey, tic, conm, fyear, datadate, fyr, fic, curcd, exchg, sich,
       at, sale, ib, ni, oancf, ivncf, fincf, capx, xrd, aqc, dp,
       dvc, dvt, prstkc, sstk,
       dltt, dlc, dltis, dltr, dlcch, dclo, xint, che, lt, ceq,
       llot, lloo, mrct,
       csho, prcc_f, mkvalt
from comp.funda
where fyear between 1989 and 2026
  and indfmt='INDL' and datafmt='STD' and popsrc='D' and consol='C'
  and fic='USA' and curcd='USD'
""",
    "company_us": "select gvkey, conm, sic, naics, ipodate, dldte, dlrsn, loc, fic from comp.company",
    "fundq_ai_firms": f"""
select gvkey, tic, conm, datadate, fyearq, fqtr, fyr, rdq,
       atq, saleq, ibq, xrdq, xintq, dlttq, dlcq, cheq, ltq, cshoq, prccq, mkvaltq,
       oancfy, capxy, prstkcy, sstky, dvy, dltisy, dltry, aqcy
from comp.fundq
where gvkey in ({",".join(f"'{g}'" for g in AI_FIRMS)})
  and datadate >= '2014-01-01'
  and indfmt='INDL' and datafmt='STD' and popsrc='D' and consol='C'
""",
}

t0 = time.time()
db = wrds.Connection(wrds_username=os.environ["WRDS_USER"], verbose=False)
rows = {}
for k, q in SQL.items():
    d = db.raw_sql(q)
    d.to_csv(FILES[k], index=False, compression="gzip")
    rows[k] = int(len(d))
    print(k, len(d))
db.close()
man = {
    "retrieved_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    "route": "direct PostgreSQL to wrds-pgdata.wharton.upenn.edu:9737 via the wrds Python package; credentials from ~/.pgpass (not stored here)",
    "queries": {k: " ".join(q.split()) for k, q in SQL.items()},
    "rows": rows,
    "ai_firms": AI_FIRMS,
    "seconds": round(time.time() - t0, 1),
    "units": "Compustat USD millions; csho/cshoq in millions of shares; prcc in USD per share. fundq *y items are fiscal year-to-date.",
    "license": "WRDS/Compustat extract for this project's research use only; do not redistribute",
}
(OUT / "manifest.json").write_text(json.dumps(man, indent=2))
