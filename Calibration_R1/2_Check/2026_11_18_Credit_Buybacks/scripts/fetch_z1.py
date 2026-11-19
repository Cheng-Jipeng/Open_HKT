"""Download Z.1 table S.5.a (new name S11.1.i.a), nonfinancial corporate business integrated accounts, annual.

Used for the FCF decomposition: every line from net operating surplus to the financial account, so that
NOS - T - NCF closes exactly (property income, transfers, capital transfers, statistical discrepancy).
Source: the Fed's full CSV release, https://www.federalreserve.gov/releases/z1/current/z1_csv_files.zip.
Only csv/S11_1_i_a.csv and data_dictionary/S11_1_i_a.txt are kept; the zip is deleted.

Run from this folder:
  uv run --no-project --python 3.12 python -I fetch_z1.py
Writes ../data/raw/fed_z1/{S11_1_i_a.csv, S11_1_i_a_dictionary.txt, manifest.json}. Never overwrites.
"""
import json
import subprocess
import sys
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path

URL = "https://www.federalreserve.gov/releases/z1/current/z1_csv_files.zip"
OUT = Path(__file__).resolve().parent.parent / "data" / "raw" / "fed_z1"
OUT.mkdir(parents=True, exist_ok=True)
KEEP = {"csv/S11_1_i_a.csv": "S11_1_i_a.csv", "data_dictionary/S11_1_i_a.txt": "S11_1_i_a_dictionary.txt"}
for name in [*KEEP.values(), "manifest.json"]:
    if (OUT / name).exists():
        sys.exit(f"refusing to overwrite {OUT / name}")

with tempfile.TemporaryDirectory() as tmp:
    zp = Path(tmp) / "z1.zip"
    # curl, as in fetch_fred.py
    subprocess.run(["curl", "-sS", "--fail", "-L", "--max-time", "300", "-o", str(zp), URL], check=True)
    with zipfile.ZipFile(zp) as zf:
        dates = {}
        for src, dst in KEEP.items():
            info = zf.getinfo(src)
            (OUT / dst).write_bytes(zf.read(info))
            dates[dst] = "%04d-%02d-%02d" % info.date_time[:3]

man = {
    "retrieved_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    "source": URL,
    "table": "S11.1.i.a (old name S.5.a), Nonfinancial corporate business, integrated macroeconomic accounts, annual",
    "file_dates_in_zip": dates,
    "units": "millions of USD, transactions, not seasonally adjusted (annual)",
    "note": "column names are Z.1 series codes with suffix .A; some codes appear twice (subtotal lines repeated in the table)",
}
(OUT / "manifest.json").write_text(json.dumps(man, indent=2))
print(json.dumps(man, indent=2))
