#!/usr/bin/env python3
"""Offline, reproducible US calibration attempt from the preserved data snapshot."""
import hashlib
import json
import platform
from pathlib import Path
import numpy as np
import pandas as pd
from calibration import allocation, joint_fit, fitted_path, p3_diagnostic

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DATA = ROOT/'Empirical_Data/Variable_mappings/Empirical_Mapping_Annual'
OUT = HERE/'results'
CONFIG = json.loads((HERE/'config.json').read_text())
IDS = dict(Y='Y_US_AHP_TOTAL_CORP_GVA', Q='Q_US_AHP_ENTERPRISE_VALUE_TOTAL_CORP',
           COMP='COMP_US_AHP_TOTAL_CORP', H='H_US_COLLEGE_EQUIV', L='L_US_NONCOLLEGE',
           premium='WHWL_US_CPS_COMPOSITION_ADJ_COLLEGE_NONCOLLEGE', D='D_US_AHP_FCF_TOTAL_CORP')
NFC = dict(Y='Y_US_NFC_GVA', Q='Q_US_AHP_ENTERPRISE_VALUE_NFC', COMP='COMP_US_AHP_NFC',D='D_US_AHP_FCF_NFC')


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024), b''):
            h.update(block)
    return h.hexdigest()


def save_json(path, obj):
    path.write_text(json.dumps(obj, indent=2, allow_nan=False)+'\n')


def load_data():
    master = pd.read_csv(DATA/'data_final/empirical_moments_us_annual.csv')
    pairs = pd.read_csv(DATA/'data_intermediate/labor_wages_bridge_pairs.csv')
    pairs = pairs[pairs.exhaustive.astype(str).str.lower().eq('true')].copy()
    selected = set(IDS.values()) | set(NFC.values())
    for _, row in pairs.iterrows():
        selected.update([row.H_mapping_id,row.L_mapping_id,row.raw_wage_ratio_mapping_id])
        if pd.notna(row.adjusted_wage_ratio_mapping_id):
            selected.add(row.adjusted_wage_ratio_mapping_id)
    raw = master[master.mapping_id.isin(selected)&master.year.between(1994,2024)].copy()
    if raw.duplicated(['mapping_id','year']).any():
        raise ValueError('Ambiguous vintage in selected inputs')
    if not raw.country_or_region.eq('US').all():
        raise ValueError('Non-US observation in input')
    raw.to_csv(OUT/'selected_input_observations.csv',index=False)
    raw.drop(columns=['year','value','sample_window']).drop_duplicates().to_csv(OUT/'mapping_provenance.csv',index=False)
    wide = raw.pivot(index='year',columns='mapping_id',values='value')
    deflator = pd.read_csv(DATA/'data_raw/fed/us_corp_GDPDEF_2026-09-14.csv')
    deflator['year'] = pd.to_datetime(deflator.observation_date).dt.year
    grouped = deflator.groupby('year').GDPDEF.agg(['mean','count'])
    price = grouped.loc[grouped['count'].eq(4),'mean']/100
    price.rename('GDPDEF_annual_mean_div100').to_csv(OUT/'annual_deflator.csv')
    raw_ids = set(';'.join(raw.source_ids.dropna()).split(';')) | {'FRED_GDPDEF__20260914'}
    registry = pd.read_csv(DATA/'source_registry.csv')
    registry = registry[registry.source_id.isin(raw_ids)].drop_duplicates('source_id')
    registry.to_csv(OUT/'source_registry_selected.csv',index=False)
    # Immediate used inputs and small macro files are hashed. Preserve recorded
    # upstream microdata hashes without re-reading gigabytes not used by this run.
    manifest=[]
    for _, r in registry.iterrows():
        if pd.isna(r.local_raw_file):
            continue
        path=DATA/str(r.local_raw_file)
        if not path.is_file():
            raise FileNotFoundError(path)
        expected=r.get('checksum')
        rehash=path.stat().st_size<10*1024*1024
        sha=digest(path) if rehash else str(expected)
        if rehash and pd.notna(expected) and str(expected) and sha != str(expected):
            raise ValueError('Source checksum changed: '+str(path))
        manifest.append(dict(path=str(path.relative_to(ROOT)),sha256=sha,bytes=path.stat().st_size,
                             role='preserved source',source_id=r.source_id,
                             hash_status='verified_this_run' if rehash else 'upstream_recorded_not_rehashed'))
    for path in [DATA/'data_final/empirical_moments_us_annual.csv',
                 DATA/'data_intermediate/labor_wages_bridge_pairs.csv',HERE/'config.json',
                 HERE/'calibration.py',HERE/'run_calibration.py',HERE/'plot_results.py',HERE/'test_calibration.py',HERE/'reference_conversation.md']:
        manifest.append(dict(path=str(path.relative_to(ROOT)),sha256=digest(path),bytes=path.stat().st_size,role='run input',hash_status='verified_this_run'))
    pd.DataFrame(manifest).to_csv(OUT/'input_manifest.csv',index=False)
    return wide, price, pairs


def panel_for(wide, price, pair=None, scope='TOTAL', labor='observed'):
    ids=IDS.copy()
    if scope=='NFC':
        ids.update(NFC)
    if pair is not None:
        ids.update(H=pair.H_mapping_id,L=pair.L_mapping_id,
                   premium=pair.adjusted_wage_ratio_mapping_id if pd.notna(pair.adjusted_wage_ratio_mapping_id) else pair.raw_wage_ratio_mapping_id)
    p=pd.DataFrame({k:wide[v] for k,v in ids.items()}).dropna()
    p=p.join(price.rename('deflator')).dropna()
    # ONE fixed unit conversion; no per-year population or GDP normalization.
    for c in ['Y','Q','COMP','D']:
        p[c]=p[c]/1e6/p.deflator   # million nominal USD -> trillion 2017 USD
    for c in ['H','L']:
        p[c]=p[c]/1e6             # persons -> million persons
    if labor=='fixed2007':
        p['H']=float(p.loc[2007,'H'])
        p['L']=float(p.loc[2007,'L'])
    p['wL']=p.COMP/(p.premium*p.H+p.L)
    p['wH']=p.premium*p.wL
    p=p.reset_index()
    return p


def window(p,start=1994,end=2022):
    return p[p.year.between(start,end)].reset_index(drop=True)


def feasibility_summary(p,theta,**labels):
    z=allocation(p,theta)
    lower=max(0.,float(((z.BH-z.Q)/(z.Y-z.BL)).max()))
    upper=min(1.,float(z.theta_ceiling.min()))
    return dict(labels,theta=float(theta),markup=float(1/theta),sample_start=int(z.year.min()),sample_end=int(z.year.max()),
                n_years=len(z),n_P1_valid=int(z.valid_P1.sum()),n_P2_valid=int(z.valid_P2.sum()),
                phi_min=float(z.phi.min()),phi_max=float(z.phi.max()),I_min=float(z.I.min()),I_max=float(z.I.max()),
                theta_lower_exclusive=lower,theta_upper_exclusive=upper,markup_floor_exclusive=float(1/upper),
                binding_year=int(z.loc[z.theta_ceiling.idxmin(),'year']),
                status='feasible' if z.valid_P2.all() else 'rejected_P1_or_P2')


def md_table(rows, columns):
    out=['| '+' | '.join(columns)+' |','| '+' | '.join(['---']*len(columns))+' |']
    for r in rows:
        out.append('| '+' | '.join(str(r[c]) for c in columns)+' |')
    return '\n'.join(out)


def build_report(base, baseline, external, conditional, p3, sourcegrid, checks):
    central=conditional[(conditional.markup.eq(3.5))&(np.isclose(conditional.rho,2/3))&conditional.scenario.eq('observed')].iloc[0]
    fixed=conditional[conditional.scenario.eq('fixed2007')].iloc[0]
    temporal=pd.read_csv(OUT/'conditional_holdout.csv')
    later=temporal[(temporal.run_id.eq('mu3.5_rho0.666667_observed'))&temporal.subset.eq('holdout')].iloc[0]
    table=[]
    for _,r in conditional[conditional.scenario.eq('observed')&np.isclose(conditional.rho,2/3)].iterrows():
        table.append(dict(markup=f'{r.markup:g}',a=f'{r.a:.6g}',xi=f'{r.xi:.5g}',nu=f'{r.nu:.5g}',
                          AX=f'{r.AX:.6g}',AL=f'{r.AL:.6g}',Q_RMSE=f'{100*r.free_entry_relative_rmse:.2f}%'))
    text=f'''# US production calibration: completed attempt, baseline rejected

Run date: 12 October 2026. Scope: US annual conditional production, 1994–2022; 2023–2024 reserved for conditional temporal checks. No RoW data or fitted RoW parameters enter this run.

## Result

**The supplied empirical mappings and external markup candidates do not admit the proposed active-research calibration. No accepted five-parameter production vector is reported.** At inverse markup 1/1.61, P1 implies skilled production share **{base['phi_min']:.5f}–{base['phi_max']:.5f}**, with **{base['n_P1_valid']}/{base['n_years']}** admissible dates. Implied research payroll is negative in every year. Changing rho, a, alpha, or productivity scales cannot repair P1.

All {len(external)} baseline/fixed-labor markup–rho specifications fail before P2. The broader screen includes {len(sourcegrid)} labor-pair/sector/markup specifications; {int((sourcegrid.n_P1_valid>0).sum())} have any feasible date. Alternative sector definitions and skill splits therefore do not rescue the documented markup set.

For the preferred observed-labor panel, the common admissible inverse-markup interval is **({base['theta_lower_exclusive']:.6f}, {base['theta_upper_exclusive']:.6f})**, implying gross markup **strictly above {base['markup_floor_exclusive']:.6f}**; the upper bound binds in {base['binding_year']}. This is an endogenous accounting bound, not an externally estimated markup. The supplied candidates range from 1.10 to 1.84.

## Sources actually used

The preserved September 14, 2026 data snapshot is read offline; no historical values are refreshed. The user-supplied package is a reconstruction of AHP concepts from revised official data, **not AHP's frozen author vintage**.

| Input | Selected source and construction |
| --- | --- |
| Y | Federal Reserve/BEA integrated accounts, total nonfinancial corporate plus domestic financial business GVA; FU106902501Q + FU796902505Q; sum four unannualized quarterly flows. Mapping Y_US_AHP_TOTAL_CORP_GVA. |
| Q | Fed B.1 operating enterprise value, LM102010405Q + LM792010405Q, Q4 stock. Mapping Q_US_AHP_ENTERPRISE_VALUE_TOTAL_CORP. This is a conditional proxy for post-entry N_(t+1)q_t, not an observed entry-timing classification. |
| Total compensation | FU106025005Q + FU796025005Q, summed quarterly flows; COMP_US_AHP_TOTAL_CORP. |
| H, L | NBER CPS MORG private for-profit wage/salary workers age16+, BA+ versus exhaustive non-BA; H_US_COLLEGE_EQUIV and L_US_NONCOLLEGE. No non-US labor inputs. |
| Skill premium | WHWL_US_CPS_COMPOSITION_ADJ_COLLEGE_NONCOLLEGE: winsorized hourly means with fixed 2007 within-group age/sex/education composition. |
| Wage levels | wL=COMP/(premium H+L), wH=premium wL. Matching aggregate compensation is imposed by this bridge, not an independent success. |
| Real units | BEA GDPDEF via preserved FRED raw file, mean of four quarters, 2017=100; divide Y, Q, compensation and FCF by the same yearly index. This run-specific common numeraire differs from the package's quarterly-deflated real-GVA alternative. GDP-wide deflation is a proxy for corporate output prices. |
| Untargeted cash flow check | D_US_AHP_FCF_TOTAL_CORP, compared with fitted incumbent profits minus research payroll only in diagnostic scenarios; physical investment/tax differences prevent exact equivalence. |

Money is trillion 2017 USD; labor is million persons. Wage units are trillion USD per million workers per year. a is per million workers per annual model step. Multiplying labor by c divides a and productivity scales by c, while aH and predictions are invariant. No annual re-normalization by changing GDP or population is performed.

The baseline retains measured H_t,L_t and is therefore a conditional production extension of the fixed-endowment GE model. A separate `fixed2007` sensitivity fixes both stocks at their 2007 values and re-bridges wages using observed compensation and premium; it is a counterfactual measurement bridge, not the original observed workforce. Occupational sensitivity pairs partition their valid-occupation universe, not necessarily the whole workforce. Neither labor treatment admits the supplied markup set. Alpha=0.5 and N_1994=1 are normalizations. No b-regime scales are calibrated. Treating all fitting years as u is a maintained regime hypothesis.

## Executed sequence and safeguards

1. P1: infer X, phi and research I. Preserve every date and reject a specification if any date is infeasible; never clip phi, delete invalid dates, or insert negative-research growth into later equations.
2. P2: for feasible diagnostic specifications only, estimate constant a from weighted free-entry levels with weights 1/Q_t^2; retain datewise implied a and compare G_Q=Q/(Q-I) to G_a=1+a(H-X).
3. Construct N_t with sum of log G_s over s<t. G_t predicts growth from t to t+1. The last observed G is excluded from N at the final date.
4. Recover CES coefficients and sequential growth slopes using forward differences of log C_X and log C_L, correctly including changing L_t. Sequential G_Q paths are diagnostic, never simultaneously imposed with an inconsistent constant-a path.
5. Fit the five production parameters jointly, profiling over log a and solving the two log-CES regressions exactly at each candidate. Equal weight is placed on three mean-square blocks: (Q-I-wH/a)/Q, log C_X residual, and log C_L residual. No extra P5 residuals are added to the P4 level objective. No xi>nu or nu>=0 restriction is imposed.
6. Examine weight, window, markup, curvature and fixed-labor sensitivity, local Jacobian rank/conditioning and the profiled objective. These are diagnostics, not sampling confidence intervals. With aggregate generated inputs and incompatible mappings, precise confidence claims would be unwarranted.

The P3 unconstrained ratio-regression diagnostic also fails: theta={p3['ratio_OLS']['theta']:.6g}, a={p3['ratio_OLS']['a']:.6g}. Its weighting differs from P2. The separately saved original-unit P3 WLS uses Q^(-2) weights consistent with P2 and is also checked for admissibility. Neither is substituted for the external candidates.

## Higher-markup experiments: not accepted estimates

To show the downstream implications, the code also fits analyst-chosen markups 3.25, 3.5 and 4.0. They lie outside the supplied evidence-based candidate set and were chosen solely to enter the mathematically feasible region. They must not be quoted as the calibrated US parameter vector. At rho=2/3:

{md_table(table,['markup','a','xi','nu','AX','AL','Q_RMSE'])}

Q_RMSE is the root mean squared relative free-entry residual. AX/AL scales depend on the declared labor, money, alpha and N normalizations. For markup 3.5, the local Jacobian rank is {int(central.jacobian_rank)}/5, the column-scaled condition number is {central.column_scaled_jacobian_condition:.3g}, and the unrestricted spillovers {'satisfy' if central.xi_gt_nu_ge_zero else 'do not satisfy'} xi>nu>=0. Full numerical rank does not establish reliable empirical identification.

The labor treatment matters materially: fixing H and L at 2007 levels while preserving the observed wage premium changes the markup-3.5 estimates to a={fixed.a:.6g}, xi={fixed.xi:.5g}, nu={fixed.nu:.5g}, versus nu={central.nu:.5g} with observed annual endowments. The sign reversal rules out treating the inferred unskilled spillover as robust to the workforce mapping. Both remain experiments outside the supplied markup set. In the observed-labor example, 2023–2024 free-entry Q error is {100*later.Q_relative_rmse:.1f}%; using the jointly fitted production wage instead gives {100*later.Q_production_relative_rmse:.1f}%. This is poor valuation performance despite the smaller conditional output errors.

The two-year temporal check uses later observed X reconstructed from later Y and wages; it tests fixed production relationships conditional on those inputs. It is not an unconditional forecast or GE asset-pricing validation. Cash-flow comparisons are untargeted relative to this objective but share national-account sources. No fit to targeted Q is described as independent validation.

## What this implies for the model

This run completes the proposed empirical calibration attempt and identifies a binding contradiction at its first step. An empirically supported production vector requires a revised, justified markup/input mapping or a revised production-accounting model. GVA includes physical-capital returns, whereas the proposed two-labor production reduction has no separately measured physical-capital factor. That is a possible explanation to investigate, not a correction made here. Relabelling capitalized R&D alone cannot reverse the negative-research sign under the corresponding accounting bridge.

The reference Julia module also imposes rho_US>1 and xi_u>nu_u>=0, while the Plan's skill-substitution baseline is rho=2/3. It cannot accept these empirical scenarios unchanged. The reference solver was not modified. No two-country equilibrium, bubble condition, portfolio return, saving parameter, post-switch technology or finance parameter is claimed calibrated.

## Reproduction and files

From this Do directory: `python3 run_calibration.py`, then `python3 test_calibration.py`. Dependencies are numpy, pandas and matplotlib; no SciPy, network or credentials are required. The verified interpreter on this Mac is `/Users/jipengcheng/opt/anaconda3/bin/python3`; use that full path if `python3` resolves to a Python without these dependencies. The run overwrites only its own results/ and README.md; empirical inputs and reference code are read only. Rerunning against a changed source snapshot may alter results. Immediate processed inputs and small macro raw files are hashed in this run; upstream CPS microdata hashes are preserved from the registry but not all rehashed, and CPS microdata are not reaggregated here. The manifest distinguishes those statuses. The captured conversation and Plan sources provide the specification.

- `results/calibration_status.json`: rejected main run, null structural estimates and fixed external assumptions.
- `results/baseline_panel.csv`, `baseline_allocation.csv`: input panel, wage bridge and every P1 failure.
- `results/external_grid.csv`, `source_feasibility.csv`: complete candidate rejection ledgers.
- `results/conditional_parameters.csv`, `conditional_sequential.csv`, `conditional_paths.csv`: explicitly labelled experiments outside the supplied markup set.
- `results/conditional_holdout.csv`, `joint_a_profile.csv`: conditional temporal/untargeted checks and identification profile.
- `results/p3_diagnostic.json`, `validation.json`: alternative identification and numerical checks.
- `results/selected_input_observations.csv`, `mapping_provenance.csv`, `source_registry_selected.csv`, `input_manifest.csv`: exact sources, metadata and SHA-256 hashes.
- `results/figures/`: feasibility and conditional-fit plots, PNG and SVG.
- `data_audit.md`, `reference_audit.md`, `solver_audit.md`: independent measurement, reference and solver audits; `source_validation.csv` supplies raw-component spot checks.

Validation: {len(checks)} recorded structural/accounting checks. The synthetic recovery/failure tests are separate from economic fit; a passing numerical test does not turn the rejected empirical run into an accepted calibration.
'''
    (HERE/'README.md').write_text(text)


def main():
    OUT.mkdir(exist_ok=True)
    wide,price,pairs=load_data()
    baseline=panel_for(wide,price)
    baseline.to_csv(OUT/'baseline_panel.csv',index=False)
    primary=window(baseline)
    theta=1/CONFIG['baseline_markup']
    alloc=allocation(baseline,theta)
    alloc.to_csv(OUT/'baseline_allocation.csv',index=False)
    base=feasibility_summary(primary,theta)
    sourcegrid=[]
    for _,pair in pairs.iterrows():
        for scope in ['TOTAL','NFC']:
            p=window(panel_for(wide,price,pair,scope))
            for mu in CONFIG['external_markups']:
                sourcegrid.append(feasibility_summary(p,1/mu,pair=pair.pair_id,scope=scope))
    sourcegrid=pd.DataFrame(sourcegrid)
    sourcegrid.to_csv(OUT/'source_feasibility.csv',index=False)
    external=[]
    for labor in ['observed','fixed2007']:
        p=window(panel_for(wide,price,labor=labor))
        for mu in CONFIG['external_markups']:
            for rho in CONFIG['external_rhos']:
                external.append(feasibility_summary(p,1/mu,scenario=labor,rho=rho))
    external=pd.DataFrame(external)
    external.to_csv(OUT/'external_grid.csv',index=False)
    p3={'ratio_OLS':p3_diagnostic(primary)}
    # Original-unit P3 restriction with omega=1/Q^2, matching sequential P2 scaling.
    xx=np.c_[primary.wH/primary.Q, -(primary.Y-primary.wL*primary.L)/primary.Q]
    yy=(primary.Q-primary.wH*primary.H)/primary.Q
    bb=np.linalg.lstsq(xx,yy,rcond=None)[0]
    p3['relative_Q_WLS']=dict(a=float(1/bb[0]),theta=float(bb[1]),intercept_1_over_a=float(bb[0]),
                             relative_rmse=float(np.sqrt(np.mean((yy-xx@bb)**2))),
                             admissible=bool(bb[0]>0 and 0<bb[1]<1 and allocation(primary,bb[1]).valid_P2.all()))
    save_json(OUT/'p3_diagnostic.json',p3)
    rows,seqs,paths,holdouts=[],[],[],[]
    # Additional specifications are explicitly illustrative diagnostics, not baseline fixes.
    specs=[]
    for mu in CONFIG['diagnostic_markups_outside_candidate_set']:
        for rho in CONFIG['external_rhos']:
            specs.append((f'mu{mu:g}_rho{rho:.6g}_observed',mu,rho,'observed',1994,2022,1.))
    specs.append(('mu3.5_fixed2007',3.5,2/3,'fixed2007',1994,2022,1.))
    for start,end in [(1994,2007),(2008,2019),(2008,2022),(1994,2019),(1994,2024)]:
        specs.append((f'mu3.5_window{start}_{end}',3.5,2/3,'window',start,end,1.))
    for weight in [0.1,10.]:
        specs.append((f'mu3.5_entryweight{weight:g}',3.5,2/3,'weight',1994,2022,weight))
    for name,mu,rho,scenario,start,end,wa in specs:
        p=panel_for(wide,price,labor='fixed2007' if scenario=='fixed2007' else 'observed')
        allp=allocation(p,1/mu)
        fitp=window(allp,start,end)
        if not fitp.valid_P2.all():
            raise ValueError('Diagnostic scenario also infeasible: '+name)
        par,seq,profile=joint_fit(fitp,1/mu,rho,weights=(wa,1.,1.))
        labels=dict(run_id=name,role='outside_candidate_set_diagnostic_NOT_accepted_calibration',
                    scenario=scenario,markup=mu,theta=1/mu,rho=rho,sample_start=start,sample_end=end,
                    alpha=.5,N0=1.,entry_weight=wa)
        rows.append(dict(labels,**par))
        seqs.append(dict(labels,**seq))
        pred=fitted_path(window(allp,start,2024),1/mu,rho,par)
        pred['run_id']=name
        pred['is_fit_year']=pred.year<=end
        paths.append(pred)
        for label,part in [('fit',pred[pred.is_fit_year]),('holdout',pred[~pred.is_fit_year])]:
            if not len(part):
                continue
            row=dict(run_id=name,subset=label,n_years=len(part),start=int(part.year.min()),end=int(part.year.max()))
            for target,fitted in [('Y','Y_fit'),('wH','wH_fit'),('wL','wL_fit'),('Q','Q_free_entry_fit')]:
                row[target+'_relative_rmse']=float(np.sqrt(np.mean(((part[fitted]-part[target])/part[target])**2)))
            row['Q_production_relative_rmse']=float(np.sqrt(np.mean(((part.Q_production_fit-part.Q)/part.Q)**2)))
            row['untargeted_FCF_relative_rmse']=float(np.sqrt(np.mean(((part.net_cashflow_fit-part.D)/part.D)**2)))
            holdouts.append(row)
        if name=='mu3.5_rho0.666667_observed':
            profile.to_csv(OUT/'joint_a_profile.csv',index=False)
    conditional=pd.DataFrame(rows)
    conditional.to_csv(OUT/'conditional_parameters.csv',index=False)
    pd.DataFrame(seqs).to_csv(OUT/'conditional_sequential.csv',index=False)
    allpaths=pd.concat(paths,ignore_index=True)
    allpaths.to_csv(OUT/'conditional_paths.csv',index=False)
    pd.DataFrame(holdouts).to_csv(OUT/'conditional_holdout.csv',index=False)
    checks={
        'US_only':True,
        'primary_years_consecutive':bool(np.all(np.diff(primary.year)==1)),
        'primary_n_years':len(primary),
        'compensation_bridge_max_abs_error':float(np.max(abs(primary.wH*primary.H+primary.wL*primary.L-primary.COMP))),
        'no_clipping_all_primary_dates_preserved':len(primary)==29,
        'baseline_rejected_all_dates':bool(not allocation(primary,theta).valid_P1.any()),
        'all_external_candidates_rejected':bool(external.status.eq('rejected_P1_or_P2').all()),
        'all_conditional_optimizers_interior':bool(not conditional.optimizer_at_search_boundary.any()),
        'all_conditional_outputs_finite':bool(np.isfinite(conditional.select_dtypes(include=[np.number]).values).all()),
        'verified_small_raw_hashes_match_registry':True,
        'large_CPS_microdata_hashes':'upstream registry retained, not rehashed or reaggregated in this run',
        'Python':platform.python_version(),'NumPy':np.__version__,'pandas':pd.__version__,
        'empirical_acceptance_status':'REJECTED_P1',
        'GE_solved':False,
    }
    save_json(OUT/'validation.json',checks)
    status=dict(status='REJECTED_P1',scope=CONFIG['scope'],parameters=dict(a_US=None,xi_u=None,nu_u=None,A_X_US_u=None,A_L_US_u=None),
                fixed_external=dict(theta_US=theta,rho_US=CONFIG['baseline_rho'],alpha_US=.5),
                baseline_diagnostics=base,reason='Every primary observation implies negative research under P1',
                conditional_experiments='Not accepted estimates; markups outside supplied external candidate set',GE_solved=False)
    save_json(OUT/'calibration_status.json',status)
    build_report(base,baseline,external,conditional,p3,sourcegrid,checks)
    from plot_results import plot_results
    plot_results(OUT)
    print(json.dumps(dict(status=status['status'],baseline=base,conditional_runs=len(rows),source_configurations=len(sourcegrid)),indent=2))


if __name__=='__main__':
    main()
