"""Read-only, narrow official FRED feasibility probes; preserves response bodies."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.request import urlopen, Request
from datetime import datetime, timezone
import csv, io, json, hashlib

BASE = Path(__file__).resolve().parent
RAW = BASE / 'raw'
RAW.mkdir(parents=True, exist_ok=True)
SERIES = [
 'ROWEISQ027S', 'ROWEINQ027S', 'ROWTLEQ027S', 'ROWTASQ027S', 'ROWNETQ027S',
 'RWLBACQ027S', 'RWNEOWQ027S', 'BOGZ1FR263181105Q', 'BOGZ1FR263081115Q',
 'BOGZ1FU263181105Q', 'BOGZ1FU263081005Q', 'ROWTSEQ027S', 'TB3MS',
 'BOGZ1LM102010405Q', 'BOGZ1LM792010405Q', 'BOGZ1FU106121075Q',
 'BOGZ1FU796121075Q', 'BOGZ1FL263164100Q'
]

def fetch(series):
    url = f'https://fred.stlouisfed.org/graph/fredgraph.csv?id={series}&cosd=2024-01-01'
    info = dict(series_id=series, url=url, retrieved_at=datetime.now(timezone.utc).isoformat())
    try:
        with urlopen(Request(url, headers={'User-Agent':'Mozilla/5.0'}), timeout=40) as response:
            body = response.read()
            info.update(http_status=response.status, content_type=response.headers.get('content-type'))
        path = RAW / f'fred_{series}_from_2024.csv'
        path.write_bytes(body)
        info.update(raw_file=str(path.relative_to(BASE)), sha256=hashlib.sha256(body).hexdigest(), bytes=len(body))
        reader = csv.DictReader(io.StringIO(body.decode('utf-8-sig')))
        assert series in reader.fieldnames, ('wrong identifier', reader.fieldnames)
        rows = list(reader)
        valid = [r for r in rows if r[series] not in ('', '.', 'NA')]
        dates = [r['observation_date'] for r in rows]
        info.update(status='verified_exact_series', saved_rows=len(rows), valid_rows=len(valid),
                    first_saved_date=valid[0]['observation_date'], last_saved_date=valid[-1]['observation_date'],
                    latest_value=float(valid[-1][series]), unique_dates=len(set(dates))==len(dates), sorted_dates=dates==sorted(dates))
    except Exception as exc:
        info.update(status='failed', error=f'{type(exc).__name__}: {exc}')
    return info

if __name__ == '__main__':
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(fetch, SERIES))
    (BASE/'fred_probe_log.json').write_text(json.dumps(results,indent=2)+'\n')
    for r in results:
        print(r['series_id'], r['status'], r.get('last_saved_date',''), r.get('latest_value',''), r.get('error',''))
