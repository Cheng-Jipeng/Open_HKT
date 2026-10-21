"""Verify saved AHP mappings and a bounded, separately dated dividend probe.

Offline by default; --download refreshes only this revision's three raw samples.
No model solve and no changes to Empirical_Data or the calibration notebooks.
"""
from pathlib import Path
from datetime import datetime, timezone
from concurrent.futures import ThreadPoolExecutor
import argparse
import hashlib
import json
import subprocess
import pandas as pd

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
EMP = ROOT / 'Codes/Empirical_Data'
ANNUAL = EMP / 'Variable_mappings/Empirical_Mapping_Annual'
SERIES = ['B3375C1Q027SBEA', 'ROWEISQ027S', 'BOGZ1FR263181105Q']


def fetch(code):
    url = f'https://fred.stlouisfed.org/graph/fredgraph.csv?id={code}&cosd=2023-10-01'
    p = subprocess.run(['curl', '-L', '-f', '-sS', '--connect-timeout', '10',
                        '--max-time', '35', url], capture_output=True, timeout=40)
    receipt = dict(series_id=code, url=url, retrieved_at=datetime.now(timezone.utc).isoformat(),
                   returncode=p.returncode, source_url=f'https://fred.stlouisfed.org/series/{code}')
    if p.returncode:
        return {**receipt, 'error': p.stderr.decode(errors='replace')}
    path = HERE / 'raw' / f'{code}.csv'
    path.write_bytes(p.stdout)
    d = pd.read_csv(path)
    assert list(d.columns) == ['observation_date', code]
    assert d.observation_date.is_unique and d.observation_date.is_monotonic_increasing
    return {**receipt, 'file': str(path.relative_to(HERE)), 'rows': len(d),
            'last_date': d.observation_date.iloc[-1], 'last_value': float(d[code].iloc[-1]),
            'sha256': hashlib.sha256(p.stdout).hexdigest()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--download', action='store_true')
    args = parser.parse_args()
    if args.download:
        with ThreadPoolExecutor(max_workers=3) as pool:
            receipts = list(pool.map(fetch, SERIES))
        (HERE / 'query_log.json').write_text(json.dumps(receipts, indent=2) + '\n')
        print(json.dumps(receipts, indent=2))

    raw = pd.read_csv(EMP / 'AHP_NFA/fred_ahp_nfa_raw.csv', parse_dates=['date']).set_index('date')
    data = pd.read_csv(EMP / 'AHP_NFA/ahp_us_nfa_decomposition_latest.csv', parse_dates=['date']).set_index('date')
    raw = raw.reindex(data.index)
    tests = {
        'nfa_source': data.nfa_us_musd + raw.ROWNETQ027S,
        'asset_va_source': data.gain_us_held_row_equity_musd - raw.BOGZ1FR263181105Q,
        'liability_gain_source': data.gain_foreign_held_us_equity_musd - raw.BOGZ1FR263081115Q,
        'ca_source': data.current_account_us_musd + raw.RWLBACQ027S / 4,
        'equity_va_sum': data.net_equity_valuation_musd - data.gain_us_held_row_equity_musd + data.gain_foreign_held_us_equity_musd,
        'ca_closing_flow': data.delta_bond_ca_closing_musd - data.current_account_us_musd + data.net_equity_purchases_musd,
        'closure_by_construction': data.delta_nfa_musd - data.current_account_us_musd - data.total_valuation_us_musd - data.ahp_residual_musd,
    }
    errors = {k: float(v.abs().max()) for k, v in tests.items()}
    assert max(errors.values()) < 1e-7
    terms = ['delta_nfa_musd', 'net_equity_valuation_musd', 'current_account_us_musd',
             'gain_us_held_row_equity_musd', 'gain_foreign_held_us_equity_musd',
             'non_equity_valuation_musd', 'ahp_residual_musd']
    w = data.loc['2008-01-01':'2023-09-30']
    moments = pd.DataFrame({'term': terms, 'total_musd': [w[t].sum() for t in terms]})
    moments['over_endpoint_gva'] = moments.total_musd / w.gva_corporate_saar_musd.iloc[-1]
    moments.to_csv(HERE / 'verified_2008_2023_moments.csv', index=False)

    corp = pd.read_csv(ANNUAL / 'data_intermediate/us_corporate_external_raw_components_quarterly.csv', parse_dates=['date']).set_index('date')
    q = corp.loc['1990-01-01':'2025-12-31']
    annual = pd.read_csv(ANNUAL / 'data_intermediate/us_corporate_external_corporate.csv')
    constructed = {
        'Y_US_AHP_TOTAL_CORP_GVA': q.BOGZ1FU106902501Q + q.BOGZ1FU796902505Q,
        'COMP_US_AHP_TOTAL_CORP': q.BOGZ1FU106025005Q + q.BOGZ1FU796025005Q,
        'D_US_AHP_FCF_TOTAL_CORP': q.BOGZ1FU106402101Q + q.BOGZ1FU796402101Q - q.BOGZ1FU106220001Q - q.BOGZ1FU796220001Q - q.BOGZ1FU105050985Q - q.BOGZ1FU795015085Q,
        'Q_US_AHP_ENTERPRISE_VALUE_TOTAL_CORP': q.BOGZ1LM102010405Q + q.BOGZ1LM792010405Q,
    }
    corp_checks = {}
    for mapping, s in constructed.items():
        a = s.groupby(s.index.year).last() if mapping.startswith('Q_') else s.groupby(s.index.year).sum(min_count=4)
        observed = annual[annual.mapping_id == mapping].set_index('year').value
        comparison = pd.concat([a.rename('reconstructed'), observed.rename('saved')], axis=1).dropna()
        err = float((comparison.reconstructed - comparison.saved).abs().max())
        assert err < 1e-6, (mapping, err)
        corp_checks[mapping] = {'years': len(comparison), 'max_error_musd': err}

    dividend = {}
    if all((HERE / 'raw' / f'{s}.csv').exists() for s in SERIES):
        pieces = [pd.read_csv(HERE / 'raw' / f'{s}.csv', parse_dates=['observation_date']).set_index('observation_date') for s in SERIES]
        p = pd.concat(pieces, axis=1).sort_index()
        p['cash_dividends_quarter_musd'] = p.B3375C1Q027SBEA * 1000 / 4
        p['opening_equity_plus_revaluation_musd'] = p.ROWEISQ027S.shift() + p.BOGZ1FR263181105Q
        p['cash_yield_current_price_quarter'] = p.cash_dividends_quarter_musd / p.opening_equity_plus_revaluation_musd
        p['cash_yield_current_price_saar'] = 4 * p.cash_yield_current_price_quarter
        p = p.dropna()
        assert (p.opening_equity_plus_revaluation_musd > 0).all()
        p.to_csv(HERE / 'ahp_foreign_dividend_yield_probe.csv')
        dividend = dict(rows=len(p), first=str(p.index.min().date()), last=str(p.index.max().date()),
                        last_saar_cash_yield=float(p.cash_yield_current_price_saar.iloc[-1]),
                        status='AHP monetary-yield construction; instrument, currency and payout correspondence remain explicit conditions. Not a pure-price or total-return estimate.')
    report = dict(checked_at=datetime.now(timezone.utc).isoformat(), ahp_observations=len(data),
                  external_max_errors_musd=errors, corporate_checks=corp_checks,
                  dividend_probe=dividend,
                  caveats=['Residual closure is algebraic, not independent model validation.',
                           'Saved AHP_NFA and corporate mappings retain separate existing vintages.',
                           'Historical paper table numbers and present series labels need vintage checks.'])
    (HERE / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
