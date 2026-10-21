#!/usr/bin/env python3
"""Offline, reproducible US calibration attempt from the preserved data snapshot."""
import hashlib
import json
import platform
import sys
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
    first_year = min(CONFIG['sample_start'], CONFIG['fixed_labor_reference_year'])
    raw = master[master.mapping_id.isin(selected) & master.year.ge(first_year)].copy()
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
    coverage = []
    for variable, mid in IDS.items():
        years = raw.loc[raw.mapping_id.eq(mid) & raw.value.notna(), 'year']
        coverage.append(dict(variable=variable, mapping_id=mid, first_year=int(years.min()),
                             latest_year=int(years.max()), required_for_fit=variable != 'D'))
    coverage.append(dict(variable='deflator', mapping_id='GDPDEF_annual_mean',
                         first_year=int(price.index.min()), latest_year=int(price.index.max()), required_for_fit=True))
    pd.DataFrame(coverage).to_csv(OUT/'input_coverage.csv', index=False)
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
                 HERE/'calibration.py',HERE/'run_calibration.py',HERE/'plot_results.py',HERE/'report_results.py',
                 HERE/'test_calibration.py',HERE/'reference_conversation.md',HERE/'rho_selection.md']:
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
    p=pd.DataFrame({k:wide[v] for k,v in ids.items()})
    # Untargeted cash flow must not shorten the production fitting sample.
    p=p.join(price.rename('deflator')).dropna(subset=['Y','Q','COMP','H','L','premium','deflator'])
    # ONE fixed unit conversion; no per-year population or GDP normalization.
    for c in ['Y','Q','COMP','D']:
        p[c]=p[c]/1e6/p.deflator   # million nominal USD -> trillion 2017 USD
    for c in ['H','L']:
        p[c]=p[c]/1e6             # persons -> million persons
    if labor=='fixed':
        reference=CONFIG['fixed_labor_reference_year']
        p['H']=float(p.loc[reference,'H'])
        p['L']=float(p.loc[reference,'L'])
    p['wL']=p.COMP/(p.premium*p.H+p.L)
    p['wH']=p.premium*p.wL
    p=p.reset_index()
    return p


def window(p,start=None,end=None):
    start=CONFIG['sample_start'] if start is None else start
    end=(CONFIG['sample_end'] or int(p.year.max())) if end is None else end
    return p[p.year.between(start,end)].reset_index(drop=True)


def fitting_sample(p):
    selected=window(p)
    end=CONFIG['sample_end'] or int(p.year.max())
    expected=list(range(CONFIG['sample_start'],end+1))
    if selected.year.tolist()!=expected or len(selected)<4:
        raise ValueError('Fitting sample must contain every calendar year from sample_start to its resolved end')
    return selected


def validate_config():
    if CONFIG['require_rho_above_one'] and any(r <= 1 for r in [CONFIG['baseline_rho']]+CONFIG['external_rhos']):
        raise ValueError('The requested model class requires every executed rho > 1')
    if not 0 < CONFIG['alpha'] < 1 or any(w <= 0 for w in CONFIG['joint_residual_weights']):
        raise ValueError('Invalid alpha or residual weights')
    if CONFIG['N0'] != 1 or CONFIG['period_years'] != 1:
        raise ValueError('This annual implementation uses N0=1; other conventions require an explicit transformation')
    if any(mu <= 1 for mu in [CONFIG['baseline_markup']]+CONFIG['external_markups']+CONFIG['diagnostic_markups_outside_candidate_set']):
        raise ValueError('Markups must exceed one')


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



def main():
    validate_config()
    OUT.mkdir(exist_ok=True)
    wide,price,pairs=load_data()
    pair=pairs.loc[pairs.pair_id.eq(CONFIG['baseline_pair'])].iloc[0]
    baseline=fitting_sample(panel_for(wide,price,pair,CONFIG['baseline_scope']))
    start,end=int(baseline.year.min()),int(baseline.year.max())
    baseline.to_csv(OUT/'baseline_panel.csv',index=False)
    theta,rho=1/CONFIG['baseline_markup'],CONFIG['baseline_rho']
    alloc=allocation(baseline,theta)
    alloc.to_csv(OUT/'baseline_allocation.csv',index=False)
    base=feasibility_summary(baseline,theta)
    sample=dict(requested_start=start,requested_end=CONFIG['sample_end'],resolved_end=end,
                n_years=len(baseline),holdout_years=[],
                end_rule=CONFIG['sample_end_rule'],data_vintage='preserved September 2026 snapshot')
    save_json(OUT/'sample_selection.json',sample)
    sourcegrid=[]
    for _,source_pair in pairs.iterrows():
        for scope in ['TOTAL','NFC']:
            p=window(panel_for(wide,price,source_pair,scope),start,end)
            for mu in CONFIG['external_markups']:
                sourcegrid.append(feasibility_summary(p,1/mu,pair=source_pair.pair_id,scope=scope,
                                  complete_fit_window=bool(p.year.tolist()==baseline.year.tolist())))
    sourcegrid=pd.DataFrame(sourcegrid)
    sourcegrid.to_csv(OUT/'source_feasibility.csv',index=False)
    weights=tuple(CONFIG['joint_residual_weights'])
    external,specs=[],[]
    for labor in ['observed','fixed']:
        p=window(panel_for(wide,price,pair,CONFIG['baseline_scope'],labor),start,end)
        scenario=labor if labor=='observed' else f"fixed{CONFIG['fixed_labor_reference_year']}"
        for mu in CONFIG['external_markups']:
            for candidate_rho in CONFIG['external_rhos']:
                result=feasibility_summary(p,1/mu,scenario=scenario,rho=candidate_rho)
                external.append(result)
                if result['status']=='feasible':
                    specs.append((f'mu{mu:g}_rho{candidate_rho:g}_{scenario}',mu,candidate_rho,labor,weights,
                                  'external_candidate_conditional_fit'))
    external=pd.DataFrame(external)
    external.to_csv(OUT/'external_grid.csv',index=False)
    if alloc.valid_P2.all():
        specs.append(('baseline',CONFIG['baseline_markup'],rho,'observed',weights,'baseline_conditional_fit'))
    p3={'ratio_OLS':p3_diagnostic(baseline)}
    # Original-unit P3 restriction with omega=1/Q^2, matching P2 scaling.
    xx=np.c_[baseline.wH/baseline.Q,-(baseline.Y-baseline.wL*baseline.L)/baseline.Q]
    yy=(baseline.Q-baseline.wH*baseline.H)/baseline.Q
    bb=np.linalg.lstsq(xx,yy,rcond=None)[0]
    p3['relative_Q_WLS']=dict(a=float(1/bb[0]),theta=float(bb[1]),intercept_1_over_a=float(bb[0]),
                             relative_rmse=float(np.sqrt(np.mean((yy-xx@bb)**2))),
                             admissible=bool(bb[0]>0 and 0<bb[1]<1 and allocation(baseline,bb[1]).valid_P2.all()))
    save_json(OUT/'p3_diagnostic.json',p3)
    diagnostic_role='outside_candidate_set_diagnostic_NOT_accepted_calibration'
    for mu in CONFIG['diagnostic_markups_outside_candidate_set']:
        specs.append((f'mu{mu:g}_rho{rho:g}_observed',mu,rho,'observed',weights,diagnostic_role))
    central_mu=CONFIG['central_diagnostic_markup']
    central_id=f'mu{central_mu:g}_rho{rho:g}_observed'
    specs.append((f'mu{central_mu:g}_rho{rho:g}_fixed{CONFIG["fixed_labor_reference_year"]}',
                  central_mu,rho,'fixed',weights,diagnostic_role))
    for multiplier in CONFIG['entry_weight_sensitivities']:
        adjusted=(weights[0]*multiplier,weights[1],weights[2])
        specs.append((f'mu{central_mu:g}_rho{rho:g}_entryweight{multiplier:g}',
                      central_mu,rho,'observed',adjusted,diagnostic_role))
    rows,seqs,paths,metrics,scenario_status=[],[],[],[],[]
    baseline_fit=None
    for name,mu,fit_rho,labor,fit_weights,role in specs:
        p=window(panel_for(wide,price,pair,CONFIG['baseline_scope'],labor),start,end)
        fitp=allocation(p,1/mu)
        if not fitp.valid_P2.all():
            scenario_status.append(dict(run_id=name,status='rejected_P1_or_P2',role=role))
            continue
        par,seq,profile=joint_fit(fitp,1/mu,fit_rho,alpha=CONFIG['alpha'],weights=fit_weights)
        primitive_ok=bool(fit_rho>1 and par['a']>0 and par['xi_gt_nu_ge_zero'])
        scenario=labor if labor=='observed' else f"fixed{CONFIG['fixed_labor_reference_year']}"
        labels=dict(run_id=name,role=role,scenario=scenario,markup=mu,theta=1/mu,rho=fit_rho,
                    sample_start=start,sample_end=end,alpha=CONFIG['alpha'],N0=CONFIG['N0'],
                    entry_weight=fit_weights[0],CX_weight=fit_weights[1],CL_weight=fit_weights[2],
                    meets_production_parameter_restrictions=primitive_ok)
        rows.append(dict(labels,**par))
        seqs.append(dict(labels,**seq))
        scenario_status.append(dict(run_id=name,status='fitted',role=role,
                                    meets_production_parameter_restrictions=primitive_ok))
        pred=fitted_path(fitp,1/mu,fit_rho,par,alpha=CONFIG['alpha'])
        pred['run_id']=name
        pred['is_fit_year']=True
        paths.append(pred)
        row=dict(run_id=name,subset='fit',n_years=len(pred),start=start,end=end)
        for target,fitted in [('Y','Y_fit'),('wH','wH_fit'),('wL','wL_fit'),('Q','Q_free_entry_fit'),
                              ('Q_production','Q_production_fit')]:
            observed=pred.Q if target=='Q_production' else pred[target]
            row[target+'_relative_rmse']=float(np.sqrt(np.mean(((pred[fitted]-observed)/observed)**2)))
        valid_cash=pred.D.notna() & pred.D.ne(0)
        row['FCF_check_n_years']=int(valid_cash.sum())
        row['untargeted_FCF_relative_rmse']=float(np.sqrt(np.mean(
            ((pred.loc[valid_cash,'net_cashflow_fit']-pred.loc[valid_cash,'D'])/pred.loc[valid_cash,'D'])**2))) if valid_cash.any() else None
        metrics.append(row)
        if name==central_id:
            profile.to_csv(OUT/'joint_a_profile.csv',index=False)
        if name=='baseline':
            baseline_fit=par
    conditional=pd.DataFrame(rows)
    conditional.to_csv(OUT/'conditional_parameters.csv',index=False)
    pd.DataFrame(seqs).to_csv(OUT/'conditional_sequential.csv',index=False)
    allpaths=pd.concat(paths,ignore_index=True) if paths else pd.DataFrame(columns=['year','run_id'])
    allpaths.to_csv(OUT/'conditional_paths.csv',index=False)
    pd.DataFrame(metrics).to_csv(OUT/'fit_metrics.csv',index=False)
    pd.DataFrame(scenario_status).to_csv(OUT/'conditional_scenarios.csv',index=False)
    if not alloc.valid_P1.all():
        status_name='REJECTED_P1'
        reason=f'{int((~alloc.valid_P1).sum())}/{len(alloc)} fitting observations fail the active-research allocation restriction'
    elif not alloc.valid_P2.all():
        status_name='REJECTED_P2'
        reason='Some fitting observations have Q <= I'
    elif not baseline_fit['xi_gt_nu_ge_zero']:
        status_name='REJECTED_PRIMITIVE_RESTRICTIONS'
        reason='Unrestricted baseline fit violates xi > nu >= 0'
    else:
        status_name='CONDITIONAL_PRODUCTION_FIT'
        reason='P1/P2 and parameter sign/order restrictions pass; conditional fit is not GE validation'
    accepted=baseline_fit if status_name=='CONDITIONAL_PRODUCTION_FIT' else {}
    parameters={target:accepted.get(key) for target,key in
                [('a_US','a'),('xi_u','xi'),('nu_u','nu'),('A_X_US_u','AX'),('A_L_US_u','AL')]}
    status=dict(status=status_name,scope=CONFIG['scope'],parameters=parameters,
                fixed_external=dict(theta_US=theta,rho_US=rho,alpha_US=CONFIG['alpha']),
                sample=sample,baseline_diagnostics=base,reason=reason,
                conditional_experiments='Higher-markup diagnostics are not accepted estimates',GE_solved=False)
    save_json(OUT/'calibration_status.json',status)
    checks={
        'US_only':True,'primary_years_consecutive':bool(np.all(np.diff(baseline.year)==1)),
        'primary_n_years':len(baseline),'all_available_years_used_for_fit':CONFIG['sample_end'] is None,
        'no_holdout_in_current_run':True,'all_executed_rhos_above_one':bool(external.rho.gt(1).all()),
        'compensation_bridge_max_abs_error':float(np.max(abs(baseline.wH*baseline.H+baseline.wL*baseline.L-baseline.COMP))),
        'all_primary_dates_preserved':baseline.year.tolist()==list(range(start,end+1)),
        'baseline_rejected_all_dates':bool(not alloc.valid_P1.any()),
        'all_external_candidates_rejected':bool(external.status.eq('rejected_P1_or_P2').all()),
        'all_conditional_optimizers_interior':bool(not conditional.optimizer_at_search_boundary.any()) if rows else None,
        'all_conditional_outputs_finite':bool(np.isfinite(conditional.select_dtypes(include=[np.number]).values).all()) if rows else None,
        'verified_small_raw_hashes_match_registry':True,
        'large_CPS_microdata_hashes':'upstream registry retained; not rehashed or reaggregated',
        'Python':platform.python_version(),'NumPy':np.__version__,'pandas':pd.__version__,
        'python_executable':sys.executable,'empirical_acceptance_status':status_name,'GE_solved':False,
    }
    save_json(OUT/'validation.json',checks)
    from report_results import build_report
    build_report(HERE,CONFIG,status,external,conditional,p3,sourcegrid)
    from plot_results import plot_results
    plot_results(OUT,CONFIG)
    print(json.dumps(dict(status=status_name,baseline=base,conditional_runs=len(rows),
                         source_configurations=len(sourcegrid),rho=rho,sample=sample),indent=2))


if __name__=='__main__':
    main()
