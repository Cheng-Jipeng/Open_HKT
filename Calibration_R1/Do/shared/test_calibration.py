"""Meaningful end-to-end checks: known model recovery, units, timing and rejection."""
import json
from pathlib import Path
import numpy as np
import pandas as pd
from calibration import allocation, joint_fit, fitted_path, sequential, log_knowledge, p3_diagnostic


def synthetic(rho=2/3, fixed_labor=False):
    theta,alpha=.4,.5
    truth=dict(a=.07,xi=.8,nu=.25,AX=1.3,AL=.9)
    rows=[]
    n=1.
    for t in range(24):
        h=2. if fixed_labor else 2.+.02*t
        l=3. if fixed_labor else 3.+.03*np.cos(t/3)
        phi=.55+.05*np.sin(t/4)
        x=h*phi
        ax=truth['AX']*n**truth['xi']
        al=truth['AL']*n**truth['nu']
        y=(alpha*(ax*x)**(1-rho)+(1-alpha)*(al*l)**(1-rho))**(1/(1-rho))
        wh=theta*alpha*ax**(1-rho)*(y/x)**rho
        wl=(1-alpha)*al**(1-rho)*(y/l)**rho
        g=1+truth['a']*(h-x)
        q=g*wh/truth['a']
        rows.append(dict(year=2000+t,H=h,L=l,Y=y,wH=wh,wL=wl,Q=q,N_true=n,G_true=g,X_true=x))
        n*=g
    return pd.DataFrame(rows),theta,rho,truth


def check_recovery(rho, fixed_labor=False):
    raw,theta,rho,truth=synthetic(rho, fixed_labor)
    p=allocation(raw,theta)
    assert p.valid_P2.all()
    np.testing.assert_allclose(p.X,p.X_true,rtol=1e-13)
    fit,seq,_=joint_fit(p,theta,rho)
    errors={k:abs(fit[k]/truth[k]-1) for k in truth}
    assert max(errors.values())<2e-5,errors
    for k in ['a','xi','nu','AX','AL']:
        np.testing.assert_allclose(seq[k],truth[k],rtol=1e-10)
    pred=fitted_path(p,theta,rho,fit)
    np.testing.assert_allclose(pred.N,raw.N_true,rtol=1e-7)
    np.testing.assert_allclose(pred.Y_fit,p.Y,rtol=1e-7)
    np.testing.assert_allclose(pred.Q_free_entry_fit,p.Q,rtol=1e-7)
    # Money units and labor units must transform primitives and preserve predictions.
    c,d=100.,1000.
    scaled=raw.copy()
    for k in ['H','L']:
        scaled[k]*=c
    for k in ['Y','Q']:
        scaled[k]*=d
    for k in ['wH','wL']:
        scaled[k]*=d/c
    sc=allocation(scaled,theta)
    fs,_,_=joint_fit(sc,theta,rho)
    for k in ['xi','nu']:
        np.testing.assert_allclose(fs[k],fit[k],rtol=2e-5)
    np.testing.assert_allclose(fs['a']*c,fit['a'],rtol=2e-5)
    for k in ['AX','AL']:
        np.testing.assert_allclose(fs[k]*c/d,fit[k],rtol=2e-5)
    # Last-period entry cannot affect N at that same date (post-entry Q convention).
    k0,_=log_knowledge(p,truth['a'])
    changed=p.copy()
    changed.loc[len(p)-1,'X']*=.5
    k1,g1=log_knowledge(changed,truth['a'])
    np.testing.assert_array_equal(k0,k1)
    assert np.exp(g1[-1])!=raw.G_true.iloc[-1]
    # An invalid date must reject the whole fit rather than disappear or be clipped.
    invalid=raw.copy()
    invalid.loc[7,'Y']*=20
    bad=allocation(invalid,theta)
    assert len(bad)==len(p) and not bad.valid_P1.iloc[7] and bad.phi.iloc[7]>1
    for fun in [joint_fit,sequential]:
        try:
            fun(bad,theta,rho)
        except ValueError as e:
            assert 'infeasible' in str(e)
        else:
            raise AssertionError('Invalid allocation was accepted')
    flat=pd.concat([raw.iloc[[0]]]*5,ignore_index=True)
    unidentified=p3_diagnostic(flat)
    assert not unidentified['admissible'] and unidentified['theta'] is None
    json.dumps(unidentified,allow_nan=False)
    return errors


def check_sample_and_config():
    from input_rules import prepare_panel, validate_config
    run=Path(__file__).resolve().parent.parent/'runs/02_fixed_mean_labor'
    config=json.loads((run/'config.json').read_text())
    validate_config(config)
    raw=pd.read_csv(run/config['input_panel'])
    p=prepare_panel(raw,config)
    for key in ['H','L']:
        np.testing.assert_allclose(p[key],np.full(16,raw[key].sum()/16),rtol=1e-14)
    np.testing.assert_allclose(p.wH*p.H+p.wL*p.L,raw.COMP,rtol=1e-14)
    np.testing.assert_allclose(p.wH/p.wL,raw.premium,rtol=1e-14)
    assert p.premium.nunique()>1 and p.Y.nunique()>1
    # Out-of-window labor observations must never enter the fitting-period mean.
    extra=raw.iloc[[0]].copy();extra['year']=2008;extra[['H','L']]=1e9
    with_extra=prepare_panel(pd.concat([extra,raw],ignore_index=True),config)
    np.testing.assert_array_equal(p.H,with_extra.H)
    np.testing.assert_array_equal(p.L,with_extra.L)
    # Preserve optional cash-flow missingness; reject gaps in required fit years.
    optional=raw.copy();optional.loc[15,'D']=np.nan
    assert pd.isna(prepare_panel(optional,config).D.iloc[15])
    for bad in [raw[raw.year.ne(2013)],pd.concat([raw,raw.iloc[[0]]])]:
        try:prepare_panel(bad,config)
        except ValueError:pass
        else:raise AssertionError('Missing or duplicate fitting year accepted')
    for bad in [dict(config,external_rhos=[2/3]),dict(config,baseline_rho=[2.]*16)]:
        try:validate_config(bad)
        except ValueError:pass
        else:raise AssertionError('Invalid primitive configuration accepted')
    try:prepare_panel(raw,dict(config,baseline_labor_treatment='observed_annual_endowments'))
    except ValueError:pass
    else:raise AssertionError('Time-varying labor accepted under the constant-exogenous rule')
    # Reproduce the first run central estimates with the unchanged core equations.
    first=run.parent/'01_observed_labor'
    reference=pd.read_csv(first/'results/conditional_parameters.csv').set_index('run_id').loc['mu3.5_rho2_observed']
    fit,_,_=joint_fit(allocation(raw,1/3.5),1/3.5,2.,alpha=.5)
    for key in ['a','xi','nu','AX','AL','objective']:
        np.testing.assert_allclose(fit[key],reference[key],rtol=2e-6,atol=1e-9)
    hashes=json.loads((first/'preservation_manifest.json').read_text())
    import hashlib
    for relative,digest in hashes.items():
        assert hashlib.sha256((first/relative).read_bytes()).hexdigest()==digest,relative
    return len(hashes)


def main(output):
    errors={str(rho):check_recovery(rho) for rho in [2/3,2.]}
    errors['rho2_fixed_labor']=check_recovery(2.,True)
    preserved=check_sample_and_config()
    result=dict(status='PASS',synthetic_relative_parameter_errors=errors,
                preserved_run1_files_verified=preserved,
                tests=['known_parameter_sequential_and_joint_recovery_with_fixed_and_variable_labor',
                       'labor_and_money_unit_invariance','post_entry_knowledge_timing',
                       'infeasible_observation_rejects_complete_fit','rank_deficient_P3_rejected',
                       'separate_fitting_window_means_only','compensation_and_premium_preserved',
                       'endogenous_targets_remain_time_varying','optional_cashflow_missingness_preserved',
                       'missing_or_duplicate_calendar_year_rejected','nonconstant_exogenous_rule_rejected',
                       'model_incompatible_rho_and_nonscalar_primitive_rejected',
                       'run1_central_estimates_reproduced','run1_artifacts_byte_identical'],
                meaning='Numerical implementation and preservation checks, not empirical model validation')
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True)
    main(parser.parse_args().output)
