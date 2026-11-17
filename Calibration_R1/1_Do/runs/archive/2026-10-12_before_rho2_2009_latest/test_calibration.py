"""Meaningful end-to-end checks: known model recovery, units, timing and rejection."""
import json
from pathlib import Path
import numpy as np
import pandas as pd
from calibration import allocation, joint_fit, fitted_path, sequential, log_knowledge, p3_diagnostic


def synthetic():
    theta,rho,alpha=.4,2/3,.5
    truth=dict(a=.07,xi=.8,nu=.25,AX=1.3,AL=.9)
    rows=[]
    n=1.
    for t in range(24):
        h=2.+.02*t
        l=3.+.03*np.cos(t/3)
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


def main():
    raw,theta,rho,truth=synthetic()
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
    result=dict(status='PASS',synthetic_relative_parameter_errors=errors,
                tests=['known_parameter_sequential_and_joint_recovery','labor_and_money_unit_invariance',
                       'post_entry_knowledge_timing','infeasible_observation_rejects_complete_fit','rank_deficient_P3_rejected'],
                meaning='Numerical implementation checks, not empirical model validation')
    dest=Path(__file__).resolve().parent/'results'
    dest.mkdir(exist_ok=True)
    (dest/'synthetic_tests.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))


if __name__=='__main__':
    main()
