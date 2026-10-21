"""Curl fallback for the same narrow public-data audit; bounded downloads."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from datetime import datetime, timezone
import subprocess, csv, io, json, hashlib
from probe_fred import BASE, RAW, SERIES

EXTRA = ['BOGZ1FR263081005Q', 'BOGZ1FV263081005Q', 'BOGZ1FV263181105Q',
         'BOGZ1FU106121001A', 'BOGZ1FU796121001A']
def fetch(series):
    url=f'https://fred.stlouisfed.org/graph/fredgraph.csv?id={series}&cosd=2024-01-01'
    info=dict(series_id=series,url=url,retrieved_at=datetime.now(timezone.utc).isoformat(),route='official FRED graph CSV via curl')
    r=subprocess.run(['curl','--location','--fail','--silent','--show-error','--connect-timeout','10','--max-time','25',url],capture_output=True,timeout=30)
    info['returncode']=r.returncode
    if r.returncode:
        info.update(status='failed',error=r.stderr.decode(errors='replace'))
        return info
    path=RAW/f'fred_{series}_from_2024_curl.csv'
    path.write_bytes(r.stdout)
    info.update(raw_file=str(path.relative_to(BASE)),sha256=hashlib.sha256(r.stdout).hexdigest(),bytes=len(r.stdout))
    try:
        reader=csv.DictReader(io.StringIO(r.stdout.decode('utf-8-sig')))
        assert series in reader.fieldnames, reader.fieldnames
        rows=list(reader)
        valid=[r for r in rows if r[series] not in ('','.','NA')]
        dates=[r['observation_date'] for r in rows]
        info.update(status='verified_exact_series',saved_rows=len(rows),valid_rows=len(valid),first_saved_date=valid[0]['observation_date'],last_saved_date=valid[-1]['observation_date'],latest_value=float(valid[-1][series]),unique_dates=len(set(dates))==len(dates),sorted_dates=dates==sorted(dates))
    except Exception as exc:
        info.update(status='parse_failed',error=repr(exc))
    return info

if __name__=='__main__':
    series=[s for s in SERIES if s not in ['BOGZ1FU106121075Q','BOGZ1FU796121075Q']]+EXTRA
    with ThreadPoolExecutor(max_workers=4) as p:
        result=list(p.map(fetch,series))
    (BASE/'fred_curl_probe_log.json').write_text(json.dumps(result,indent=2)+'\n')
    for r in result: print(r['series_id'],r['status'],r.get('last_saved_date',''),r.get('latest_value',''),r.get('error',''))
