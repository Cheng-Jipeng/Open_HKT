"""Run-specific calibration with frozen inputs and explicit exogenous-variable rules."""
import argparse
import hashlib
import json
import platform
from pathlib import Path
import sys
import numpy as np
import pandas as pd
from calibration import allocation, joint_fit, fitted_path, p3_diagnostic, log_knowledge, ces_coefficients
from input_rules import prepare_panel, validate_config
from diagnostics import slope, cone_fit

DO = Path(__file__).resolve().parent.parent
ROOT = DO.parents[2]


def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(path, value): path.write_text(json.dumps(value,indent=2,allow_nan=False)+'\n')


def feasibility(p, mu):
    z=allocation(p,1/mu)
    return dict(markup=mu,theta=1/mu,n_years=len(p),n_P1_valid=int(z.valid_P1.sum()),n_P2_valid=int(z.valid_P2.sum()),
                phi_min=float(z.phi.min()),phi_max=float(z.phi.max()),I_min=float(z.I.min()),I_max=float(z.I.max()),
                markup_floor_exclusive=float(z.markup_floor.max()),binding_year=int(z.loc[z.markup_floor.idxmax(),'year']),
                status='feasible' if z.valid_P2.all() else 'rejected_P1_or_P2')


def fit_metrics(p):
    ans={}
    for key,target in [('Y','Y_fit'),('wH','wH_fit'),('wL','wL_fit'),('Q','Q_free_entry_fit')]:
        ans[key+'_relative_rmse']=float(np.sqrt(np.mean(((p[target]-p[key])/p[key])**2)))
    valid=p.D.notna() & p.D.ne(0)
    ans['untargeted_FCF_relative_rmse']=float(np.sqrt(np.mean(((p.loc[valid,'net_cashflow_fit']-p.loc[valid,'D'])/p.loc[valid,'D'])**2)))
    return ans


def main(run):
    run=Path(run).resolve();out=run/'results';out.mkdir(parents=True,exist_ok=True)
    c=json.loads((run/'config.json').read_text());validate_config(c)
    input_path=run/c['input_panel'];observed=pd.read_csv(input_path)
    reference=(run/c['comparison_run']).resolve()
    if sha(input_path)!=sha(reference/'results/baseline_panel.csv'):
        raise ValueError('Run 2 input differs from the preserved run 1 fitting panel')
    p=prepare_panel(observed,c)
    p.to_csv(out/'baseline_panel.csv',index=False)
    # Check immediate empirical sources from the earlier run; exclude its changed code paths.
    verified=[]
    old_manifest=pd.read_csv(reference/'results/input_manifest.csv')
    for _,row in old_manifest.iterrows():
        path=ROOT/row.path
        if str(row.path).startswith('Empirical_Data/') and row.hash_status=='verified_this_run':
            if sha(path)!=row.sha256:raise ValueError('Preserved empirical source changed: '+str(path))
            verified.append(dict(path=row.path,sha256=row.sha256,role='empirical source reverified'))
    base=allocation(p,1/c['baseline_markup']);base.to_csv(out/'baseline_allocation.csv',index=False)
    normalized=c['baseline_labor_treatment']=='skilled_normalized_annual_ratio'
    suffix=c.get('run_suffix','sample_mean')
    if normalized:
        # H is the numeraire labor unit; L is the annual observed L/H ratio (time varying).
        means={'H':1.0,'L':float(p.L.mean())}
        labor=pd.DataFrame([dict(variable='H',mean=1.0,unit='normalized to one at every date',first_year=2009,last_year=2024,n=16,observed_min=1.0,observed_max=1.0),
                            dict(variable='L',mean=float(p.L.mean()),unit='observed L_t/H_t, unskilled per skilled worker',first_year=2009,last_year=2024,n=16,
                                 observed_min=float(p.L.min()),observed_max=float(p.L.max()))])
        exo=[dict(object='H',role='exogenous labor endowment',treatment='normalized to one at every date',constant=True,value=1.0),
             dict(object='L',role='exogenous labor endowment',treatment='annual observed ratio L_t/H_t (relative endowment)',constant=False,value='baseline_panel.csv')]
    else:
        means={k:float(p[k].iloc[0]) for k in ['H','L']}
        labor=pd.DataFrame([dict(variable=k,mean=float(observed[k].mean()),unit='million persons',
                            first_year=2009,last_year=2024,n=16,observed_min=float(observed[k].min()),observed_max=float(observed[k].max())) for k in ['H','L']])
        exo=[dict(object=k,role='exogenous labor endowment',treatment='unweighted 2009-2024 mean',constant=True,value=v) for k,v in means.items()]
    labor.to_csv(out/'labor_constants.csv',index=False)
    for key in ['baseline_markup','baseline_rho','alpha','N0','period_years']:
        exo.append(dict(object=key,role='external parameter or normalization',treatment='single scalar throughout the sample',constant=True,value=c[key]))
    exo+= [dict(object='z',role='exogenous regime',treatment='u at every fitting date; no transition estimation',constant=True,value='u'),
           dict(object='a, xi, nu, AXbar, ALbar',role='internally calibrated primitives',treatment='one scalar per parameter per scenario',constant=True,value='see conditional_parameters.csv'),
           dict(object='Y, Q, COMP, premium, wH, wL',role='empirical counterparts of endogenous outcomes',treatment='retain annual observations; rebridge wages with '+('normalized H=1 and L=L_t/H_t' if normalized else 'constant H,L'),constant=False,value='observed targets'),
           dict(object='N, X, phi, I, AX, AL',role='endogenous states, allocations or technology paths',treatment='inferred or fitted annually under fixed primitives',constant=False,value='conditional_paths.csv'),
           dict(object='GDPDEF',role='measurement conversion, not a model primitive',treatment='retain annual deflator to express every monetary target in 2017 USD',constant=False,value='preserved transformation'),
           dict(object='RoW, finance, regime-b and transition parameters',role='outside this production calibration',treatment='not assigned or estimated in this run',constant=None,value='not calibrated')]
    pd.DataFrame(exo).to_csv(out/'variable_roles.csv',index=False)
    sample=dict(sample_start=2009,sample_end=2024,n_years=16,holdout_years=[],data_vintage='preserved September 2026 snapshot',
                averaging_rule=c['labor_mean_rule'],labor_constants=means)
    save(out/'sample_selection.json',sample)
    external=pd.DataFrame([dict(feasibility(p,mu),rho=rho) for mu in c['external_markups'] for rho in c['external_rhos']])
    external.to_csv(out/'external_grid.csv',index=False)
    specs=[(mu,c['baseline_rho'],tuple(c['joint_residual_weights']),f'mu{mu:g}_rho{c["baseline_rho"]:g}_{suffix}',
            'outside_candidate_set_diagnostic_NOT_accepted_calibration') for mu in c['diagnostic_markups_outside_candidate_set']]
    for multiplier in c['entry_weight_sensitivities']:
        specs.append((c['central_diagnostic_markup'],c['baseline_rho'],(multiplier,1.,1.),f'mu3.5_rho2_{suffix}_entryweight{multiplier:g}',
                      'objective_weight_sensitivity_NOT_accepted_calibration'))
    for row in external.itertuples():
        if row.status=='feasible':specs.append((row.markup,row.rho,(1.,1.,1.),f'external_mu{row.markup:g}_rho{row.rho:g}', 'external_candidate_conditional_fit'))
    if base.valid_P2.all():specs.append((c['baseline_markup'],c['baseline_rho'],(1.,1.,1.),'baseline','baseline_conditional_fit'))
    rows=[];seqs=[];paths=[];metrics=[];statuses=[];central=None
    for mu,rho,weights,run_id,role in specs:
        z=allocation(p,1/mu)
        if not z.valid_P2.all():
            statuses.append(dict(run_id=run_id,status='rejected_P1_or_P2',role=role));continue
        par,seq,profile=joint_fit(z,1/mu,rho,alpha=c['alpha'],weights=weights)
        labels=dict(run_id=run_id,role=role,scenario=c['baseline_labor_treatment'],markup=mu,theta=1/mu,rho=rho,
                    alpha=c['alpha'],N0=c['N0'],H=means['H'],L=means['L'],sample_start=2009,sample_end=2024,
                    entry_weight=weights[0],CX_weight=weights[1],CL_weight=weights[2],
                    meets_production_parameter_restrictions=bool(par['xi']>par['nu']>0))
        rows.append(dict(labels,**par));seqs.append(dict(labels,**seq))
        pred=fitted_path(z,1/mu,rho,par,alpha=c['alpha']);pred['run_id']=run_id;paths.append(pred)
        metrics.append(dict(run_id=run_id,subset='fit',**fit_metrics(pred)))
        statuses.append(dict(run_id=run_id,status='fitted',role=role,primitive_screen=labels['meets_production_parameter_restrictions']))
        if run_id==c['central_run_id']:
            central=(z,par,seq,pred);profile.to_csv(out/'joint_a_profile.csv',index=False)
    pd.DataFrame(rows).to_csv(out/'conditional_parameters.csv',index=False)
    pd.DataFrame(seqs).to_csv(out/'conditional_sequential.csv',index=False)
    pd.concat(paths,ignore_index=True).to_csv(out/'conditional_paths.csv',index=False)
    pd.DataFrame(metrics).to_csv(out/'fit_metrics.csv',index=False)
    pd.DataFrame(statuses).to_csv(out/'conditional_scenarios.csv',index=False)
    if central is None:raise ValueError('Central diagnostic not feasible; reporting must be revised')
    z,j,s,path=central;rho=c['baseline_rho'];theta=1/c['central_diagnostic_markup']
    k,_=log_knowledge(z,j['a']);cx,cl=ces_coefficients(z,theta,rho)
    ax=np.exp((cx-np.log(c['alpha']))/(1-rho));al=np.exp((cl-np.log(1-c['alpha']))/(1-rho))
    yc=(c['alpha']*(ax*z.X)**(1-rho)+(1-c['alpha'])*(al*z.L)**(1-rho))**(1/(1-rho))
    np.testing.assert_allclose(yc,z.Y,rtol=1e-12)
    terms={'premium':slope(np.log(z.premium),k)/(1-rho),'relative_input':rho*slope(np.log(z.X/z.L),k)/(1-rho)}
    np.testing.assert_allclose(sum(terms.values()),j['xi']-j['nu'],atol=1e-11)
    con=cone_fit(z,theta,rho,j,alpha=c['alpha']);con['objective_ratio']=con['objective']/j['objective']
    assert con['objective']>=j['objective']-1e-10
    fitted_path(z,theta,rho,con,alpha=c['alpha']).to_csv(out/'constrained_paths.csv',index=False)
    mechanism=z.copy();mechanism['logN']=k;mechanism['AX_inverted']=ax;mechanism['AL_inverted']=al
    mechanism['X_over_L']=z.X/z.L;mechanism.to_csv(out/'annual_mechanism.csv',index=False)
    diagnosis=dict(sample=[2009,2024],rho=rho,diagnostic_markup=1/theta,central_parameters=j,
                   xi_minus_nu=j['xi']-j['nu'],premium_gap_contribution=terms['premium'],relative_input_gap_contribution=terms['relative_input'],
                   constrained=con,static_CES_max_relative_error=float(np.max(abs(yc/z.Y-1))))
    save(out/'diagnosis.json',diagnosis)
    p3={'ratio_OLS':p3_diagnostic(p)}
    xx=np.c_[p.wH/p.Q,-(p.Y-p.wL*p.L)/p.Q];yy=(p.Q-p.wH*p.H)/p.Q;bb=np.linalg.lstsq(xx,yy,rcond=None)[0]
    p3['relative_Q_WLS']=dict(a=float(1/bb[0]),theta=float(bb[1]),admissible=bool(bb[0]>0 and 0<bb[1]<1 and allocation(p,bb[1]).valid_P2.all()))
    save(out/'p3_diagnostic.json',p3)
    baseline_status='REJECTED_P1' if not base.valid_P1.all() else ('REJECTED_P2' if not base.valid_P2.all() else 'SEE_BASELINE_FIT')
    status=dict(status=baseline_status,baseline_diagnostics=feasibility(p,c['baseline_markup']),sample=sample,
                scope=c['scope'],accepted_baseline_parameters=None,GE_solved=False,
                central_diagnostic_primitive_screen=bool(j['xi']>j['nu']>0),central_diagnostic_parameters=j,
                reason='Baseline fails active-research allocation; higher-markup fits are diagnostic, not adopted parameters')
    save(out/'calibration_status.json',status)
    oldpars=pd.read_csv(reference/'results/conditional_parameters.csv').set_index('run_id').loc['mu3.5_rho2_observed']
    oldmetrics=pd.read_csv(reference/'results/fit_metrics.csv').set_index('run_id').loc['mu3.5_rho2_observed']
    newmetrics=fit_metrics(path);oldbase=json.loads((reference/'results/calibration_status.json').read_text())['baseline_diagnostics']
    own=c.get('comparison_column','run_02')
    comparison=[{'object':key,'run_01':float(oldpars[key]),own:float(j[key])} for key in ['a','xi','nu','AX','AL','objective']]
    comparison += [{'object':'xi_minus_nu','run_01':float(oldpars.xi-oldpars.nu),own:j['xi']-j['nu']}]
    comparison += [{'object':key,'run_01':float(oldmetrics[key]),own:float(newmetrics[key])} for key in newmetrics]
    comparison += [{'object':'baseline_markup_floor','run_01':oldbase['markup_floor_exclusive'],own:float(base.markup_floor.max())}]
    comparison=pd.DataFrame(comparison)
    # Optional further saved runs, read only (never refitted or rewritten here).
    for extra in c.get('extra_comparison_runs',[]):
        other=(run/extra['path']).resolve()
        op=pd.read_csv(other/'results/conditional_parameters.csv').set_index('run_id').loc[extra['run_id']]
        om=pd.read_csv(other/'results/fit_metrics.csv').set_index('run_id').loc[extra['run_id']]
        ob=json.loads((other/'results/calibration_status.json').read_text())['baseline_diagnostics']
        values={key:float(op[key]) for key in ['a','xi','nu','AX','AL','objective']}
        values['xi_minus_nu']=float(op.xi-op.nu);values.update({key:float(om[key]) for key in newmetrics})
        values['baseline_markup_floor']=ob['markup_floor_exclusive']
        comparison.insert(comparison.columns.get_loc(own),extra['column'],comparison.object.map(values))
    comparison.to_csv(out/'run_comparison.csv',index=False)
    # Output checks are identities and scope checks, never claims of empirical validation.
    if normalized:
        rule=dict(H_constant=p.H.nunique()==1,H_equals_one=bool((p.H==1).all()),
                  L_equals_observed_ratio=bool(np.array_equal(p.L,observed.L/observed.H)),
                  relative_endowment_preserved=bool(np.allclose(p.L/p.H,observed.L/observed.H,rtol=1e-15)),
                  wage_bills_equal_observed_labor_bridge=bool(np.allclose(p.wH*p.H,observed.COMP*observed.premium*observed.H/(observed.premium*observed.H+observed.L),rtol=1e-13)),
                  all_fitted_H_constant=all(f.H.nunique()==1 for f in paths))
    else:
        rule=dict(H_constant=p.H.nunique()==1,L_constant=p.L.nunique()==1,
                  H_equals_sample_mean=bool(p.H.iloc[0]==observed.H.mean()),L_equals_sample_mean=bool(p.L.iloc[0]==observed.L.mean()),
                  all_fitted_HL_constant=all(f.H.nunique()==f.L.nunique()==1 for f in paths))
    checks=dict(**{k:v for k,v in rule.items() if not k.startswith('all_fitted')},
                compensation_bridge_max_abs_error=float(np.max(abs(p.wH*p.H+p.wL*p.L-p.COMP))),
                every_fit_year_retained=p.year.tolist()==list(range(2009,2025)),
                unchanged_targets={key:bool(np.array_equal(p[key],observed[key])) for key in ['Y','Q','COMP','premium','D','deflator']},
                all_fitted_parameters_finite=bool(np.isfinite(pd.DataFrame(rows).select_dtypes(include=[np.number])).all().all()),
                **{k:v for k,v in rule.items() if k.startswith('all_fitted')},
                all_fitted_optimizers_interior=all(not row['optimizer_at_search_boundary'] for row in rows),
                state_variable_N_not_frozen=path.N.nunique()>1,baseline_status=baseline_status,
                python=platform.python_version(),numpy=np.__version__,pandas=pd.__version__,GE_solved=False)
    save(out/'validation.json',checks)
    for f in [input_path,run/'config.json',ROOT/'AI_drafting/V6_production.tex',*sorted((DO/'shared').glob('*.py')),DO/'shared/requirements.txt']:
        verified.append(dict(path=str(f.relative_to(ROOT)),sha256=sha(f),role='run input or implementation'))
    pd.DataFrame(verified).to_csv(out/'input_manifest.csv',index=False)
    print(json.dumps(dict(status=baseline_status,constants=means,joint=j,sequential=s,metrics=newmetrics,diagnosis=diagnosis,p3=p3),indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--run',required=True,type=Path)
    args=parser.parse_args();main(args.run)
