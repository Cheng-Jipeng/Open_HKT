"""Pull the Compustat North America annual fundamentals needed for the incumbent-cohort payout test.

Direct PostgreSQL route (wrds-pgdata, credentials from ~/.pgpass; the WRDS MCP timed out on 2026-11-13).
Run from this folder:
  WRDS_USER=$(cut -d: -f4 ~/.pgpass) uv run --no-project --python 3.12 --with wrds --with pandas python -I fetch_wrds.py
Writes ../data/wrds/funda_us_1989_2024.csv.gz, company_us.csv.gz and manifest.json. Never overwrites.
"""
import json, os, sys, time
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
import wrds

OUT = Path(__file__).resolve().parent.parent / "data" / "wrds"
OUT.mkdir(parents=True, exist_ok=True)
F_FUNDA, F_COMP, F_MAN = OUT / "funda_us_1989_2024.csv.gz", OUT / "company_us.csv.gz", OUT / "manifest.json"
for f in (F_FUNDA, F_COMP, F_MAN):
    if f.exists():
        sys.exit(f"refusing to overwrite {f}")

SQL_FUNDA = """
select gvkey, fyear, datadate, fic, curcd, exchg, at, sale, ni, oancf, capx, xrd,
       dvc, dvt, dv, prstkc, sstk, csho, prcc_f, mkvalt
from comp.funda
where fyear between 1989 and 2024
  and indfmt='INDL' and datafmt='STD' and popsrc='D' and consol='C'
  and fic='USA' and curcd='USD'
"""
SQL_COMP = "select gvkey, conm, sic, ipodate, dldte, dlrsn, loc, fic from comp.company"

t0 = time.time()
db = wrds.Connection(wrds_username=os.environ["WRDS_USER"], verbose=False)
funda = db.raw_sql(SQL_FUNDA)
comp = db.raw_sql(SQL_COMP)
db.close()
funda.to_csv(F_FUNDA, index=False, compression="gzip")
comp.to_csv(F_COMP, index=False, compression="gzip")
man = {
    "retrieved_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    "route": "direct PostgreSQL to wrds-pgdata.wharton.upenn.edu:9737 via the wrds Python package; credentials from ~/.pgpass (not stored here)",
    "tables": {"comp.funda": SQL_FUNDA.strip(), "comp.company": SQL_COMP},
    "rows": {"funda": int(len(funda)), "company": int(len(comp))},
    "fyear_range": [int(funda.fyear.min()), int(funda.fyear.max())],
    "seconds": round(time.time() - t0, 1),
    "units": "Compustat USD millions; csho in millions of shares; prcc_f USD per share",
    "license": "WRDS/Compustat extract for this project's research use only; do not redistribute",
}
F_MAN.write_text(json.dumps(man, indent=2))
print(json.dumps({k: man[k] for k in ("rows", "fyear_range", "seconds")}))
