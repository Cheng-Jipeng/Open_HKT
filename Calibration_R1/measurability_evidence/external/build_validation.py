"""Offline audit of saved feasibility samples; no panel estimation or overwrite."""
from pathlib import Path
import csv, json
BASE=Path(__file__).resolve().parent
log=json.loads((BASE/'fred_curl_probe_log.json').read_text())
data={}
for item in log:
    if item['status']=='verified_exact_series':
        code=item['series_id']
        data[code]={r['observation_date']:float(r[code]) for r in csv.DictReader((BASE/item['raw_file']).open()) if r[code] not in ('','.','NA')}

rows=[]
common=sorted(set(data['ROWTLEQ027S'])&set(data['ROWTASQ027S'])&set(data['ROWNETQ027S']))
for date in common:
    assets=data['ROWTLEQ027S'][date]
    liabilities=data['ROWTASQ027S'][date]
    nfa=-data['ROWNETQ027S'][date]
    legacy=data['BOGZ1FR263081115Q'][date]
    broad=data['BOGZ1FR263081005Q'][date]
    rows.append(dict(date=date,total_external_assets_musd=assets,total_external_liabilities_musd=liabilities,nfa_musd=nfa,
                     nfa_identity_residual_musd=assets-liabilities-nfa,
                     legacy_liability_equity_revaluation_musd=legacy,broad_liability_equity_revaluation_musd=broad,
                     broad_minus_legacy_revaluation_musd=broad-legacy))
with (BASE/'spot_checks.csv').open('w') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
validation=dict(verified_exact_series=sum(r['status']=='verified_exact_series' for r in log),failed_probes=[r['series_id'] for r in log if r['status']!='verified_exact_series'],
    samples_start='2024-01-01',quarterly_series_count=16,monthly_series_count=1,annual_series_count=2,
    all_verified_series_have_unique_sorted_dates=all(r['unique_dates'] and r['sorted_dates'] for r in log if r['status']=='verified_exact_series'),
    nfa_identity_max_abs_residual_musd=max(abs(r['nfa_identity_residual_musd']) for r in rows),
    latest_liability_revaluation_scope_difference_musd=rows[-1]['broad_minus_legacy_revaluation_musd'],
    openecon_requested='ROWEISQ027S',openecon_returned='BOGZ1FL263164100Q',openecon_exact_match_accepted=False,
    latest_correct_ROWEIS_minus_substitute_musd=data['ROWEISQ027S']['2026-04-01']-data['BOGZ1FL263164100Q']['2026-04-01'],
    limitation='Read-only feasibility probes from 2024 onward; no full historical panel refresh or model calibration. FRED web-index excerpts can lag live graph CSV vintages.')
(BASE/'validation.json').write_text(json.dumps(validation,indent=2)+'\n')
print(json.dumps(validation,indent=2))
