"""Reproducible equation/mapping diagnosis, without changing the main calibration."""
import hashlib
import json
from pathlib import Path
import sys
import numpy as np
import pandas as pd

HERE=Path(__file__).resolve().parent
DO=HERE.parent
ROOT=DO.parents[2]
DATA=ROOT/'Empirical_Data/Variable_mappings/Empirical_Mapping_Annual'
OUT=HERE/'results'
sys.path.insert(0,str(DO))
from calibration import allocation, joint_fit, fitted_path, log_knowledge, ces_coefficients, golden_minimize
from run_calibration import panel_for, IDS, NFC, CONFIG


def slope(y,k):
    return float(np.linalg.lstsq(np.c_[np.ones(len(k)),k],np.asarray(y),rcond=None)[0][1])


def rebridge(p):
    p=p.copy()
    p['wL']=p.COMP/(p.premium*p.H+p.L)
    p['wH']=p.premium*p.wL
    return p


def fit(p,mu=3.5,rho=2.):
    z=allocation(p.reset_index(drop=True),1/mu)
    par,seq,_=joint_fit(z,1/mu,rho,alpha=CONFIG['alpha'])
    return z,par,seq


def cone_fit(p,theta,rho,unrestricted):
    """Profile the CLOSED cone xi>=nu>=0; strict ordering has no attained boundary fit."""
    cx,cl=ces_coefficients(p,theta,rho)
    yx=(cx-np.log(CONFIG['alpha']))/(1-rho)
    yl=(cl-np.log(1-CONFIG['alpha']))/(1-rho)
    def at(loga,details=False):
        a=np.exp(loga); k,_=log_knowledge(p,a); kc=k-k.mean()
        sx=slope(yx,k); sl=slope(yl,k)
        candidates=[(max(0.,sx),0.),(max(0.,(sx+sl)/2),)*2,(0.,0.)]
        if sx>=sl>=0: candidates.append((sx,sl))
        def technology_loss(pair):
            x,n=pair
            return (1-rho)**2*(np.mean((yx-yx.mean()-x*kc)**2)+np.mean((yl-yl.mean()-n*kc)**2))
        xi,nu=min(candidates,key=technology_loss)
        ix=yx.mean()-xi*k.mean(); il=yl.mean()-nu*k.mean()
        ra=(p.Q-p.I-p.wH/a)/p.Q
        rx=(1-rho)*(yx-ix-xi*k); rl=(1-rho)*(yl-il-nu*k)
        obj=float(np.mean(ra**2)+np.mean(rx**2)+np.mean(rl**2))
        if details:
            return dict(a=float(a),xi=float(xi),nu=float(nu),AX=float(np.exp(ix)),AL=float(np.exp(il)),
                        objective=obj,free_entry_relative_rmse=float(np.sqrt(np.mean(ra**2))),
                        log_CX_rmse=float(np.sqrt(np.mean(rx**2))),log_CL_rmse=float(np.sqrt(np.mean(rl**2))))
        return obj
    grid=np.linspace(np.log(unrestricted['a'])-8,np.log(unrestricted['a'])+8,257)
    values=np.array([at(v) for v in grid])
    candidates=[(grid[0],values[0]),(grid[-1],values[-1])]
    for i in range(1,len(grid)-1):
        if values[i]<=min(values[i-1],values[i+1]):
            x=golden_minimize(at,grid[i-1],grid[i+1]); candidates.append((x,at(x)))
    best=min(candidates,key=lambda x:x[1])[0]
    result=at(best,True)
    result.update(constraint='xi >= nu >= 0; closure of the strict restriction',
                  at_equal_spillover_boundary=bool(abs(result['xi']-result['nu'])<1e-9),
                  at_a_search_boundary=bool(abs(best-grid[0])<1e-6 or abs(best-grid[-1])<1e-6),
                  meaning='Lower-bound fit cost; equality is not an admissible unbalanced-growth calibration')
    return result


def main():
    OUT.mkdir(exist_ok=True)
    base=pd.read_csv(DO/'results/baseline_panel.csv')
    mu,rho=CONFIG['central_diagnostic_markup'],CONFIG['baseline_rho']
    if rho!=2 or CONFIG['joint_residual_weights']!=[1.,1.,1.]:
        raise ValueError('This diagnosis uses rho=2 closed forms and equal objective-block weights')
    z,par,seq=fit(base,mu,rho)
    k,_=log_knowledge(z,par['a'])
    cx,cl=ces_coefficients(z,1/mu,rho)
    ax=np.exp((cx-np.log(CONFIG['alpha']))/(1-rho))
    al=np.exp((cl-np.log(1-CONFIG['alpha']))/(1-rho))
    sL=z.BL/z.Y
    contrast=np.log(z.wH/z.wL)+rho*np.log(z.X/z.L)
    gap=slope(contrast,k)/(1-rho)
    np.testing.assert_allclose(gap,par['xi']-par['nu'],atol=1e-11)
    np.testing.assert_allclose(ax,CONFIG['alpha']*z.wH*mu/(1-sL)**2,rtol=1e-12)
    np.testing.assert_allclose(al,(1-CONFIG['alpha'])*z.Y**2/(z.wL*z.L**2),rtol=1e-12)
    # Static CES recovered from wage FOCs must reproduce output and wages.
    ycheck=(CONFIG['alpha']*(ax*z.X)**(1-rho)+(1-CONFIG['alpha'])*(al*z.L)**(1-rho))**(1/(1-rho))
    np.testing.assert_allclose(ycheck,z.Y,rtol=1e-12)
    np.testing.assert_allclose((1/mu)*CONFIG['alpha']*ax**(1-rho)*(ycheck/z.X)**rho,z.wH,rtol=1e-12)
    np.testing.assert_allclose((1-CONFIG['alpha'])*al**(1-rho)*(ycheck/z.L)**rho,z.wL,rtol=1e-12)
    terms=[('xi','real skilled wage',slope(np.log(z.wH),k)),
           ('xi','unskilled output share',-2*slope(np.log(1-sL),k)),
           ('nu','real output',2*slope(np.log(z.Y),k)),
           ('nu','real unskilled wage',-slope(np.log(z.wL),k)),
           ('nu','unskilled quantity',-2*slope(np.log(z.L),k)),
           ('xi_minus_nu','skill premium',-slope(np.log(z.wH/z.wL),k)),
           ('xi_minus_nu','relative production input',-2*slope(np.log(z.X/z.L),k))]
    contributions=pd.DataFrame(terms,columns=['parameter','component','contribution'])
    contributions.to_csv(OUT/'slope_decomposition.csv',index=False)
    annual=z[['year','Y','COMP','H','L','wH','wL','X','phi','I','Q']].copy()
    annual['logN']=k; annual['AX_inverted']=ax; annual['AL_inverted']=al
    annual['unskilled_output_share']=sL; annual['X_over_L']=z.X/z.L
    annual['relative_wage_contrast']=contrast
    annual['log_relative_technology']=np.log(ax/al)
    annual.to_csv(OUT/'annual_mechanism.csv',index=False)
    endpoints=[]
    for name,values in [('H',z.H),('L',z.L),('Y',z.Y),('COMP',z.COMP),('wH',z.wH),('wL',z.wL),
                        ('premium',z.wH/z.wL),('X_over_L',z.X/z.L),('AX_inverted',ax),('AL_inverted',al)]:
        v=np.asarray(values)
        endpoints.append(dict(variable=name,first=float(v[0]),last=float(v[-1]),
                              log_change=float(np.log(v[-1]/v[0])),percent_change=float(100*(v[-1]/v[0]-1))))
    pd.DataFrame(endpoints).to_csv(OUT/'endpoint_changes.csv',index=False)
    master=pd.read_csv(DATA/'data_final/empirical_moments_us_annual.csv')
    extra=['WHWL_US_CPS_RAW_MEAN_HOURLY_COLLEGE_NONCOLLEGE',
           'H_US_COLLEGE_EQUIV_FTE_OBSERVED_HOURS','L_US_NONCOLLEGE_FTE_OBSERVED_HOURS',
           'NOS_US_AHP_TOTAL_CORP','Y_US_REAL_CORP_GVA']
    selected=master[master.mapping_id.isin(set(IDS.values())|set(NFC.values())|set(extra)) & master.year.ge(2007)].copy()
    assert selected.country_or_region.eq('US').all()
    assert not selected.duplicated(['mapping_id','year']).any()
    selected.to_csv(OUT/'selected_input_observations.csv',index=False)
    wide=selected.pivot(index='year',columns='mapping_id',values='value')
    price=pd.read_csv(DO/'results/annual_deflator.csv',index_col='year').iloc[:,0]
    allp=panel_for(wide,price)
    def values(mid,p): return wide.loc[p.year,mid].to_numpy()
    cases=[('current_mapping',base,'Original conditional inputs'),
           ('through_2022',base[base.year.le(2022)].copy(),'Exclude disclosure-transition years; not a topcode correction')]
    fixed=allp.copy()
    for c in ['H','L']: fixed[c]=float(allp.loc[allp.year.eq(2007),c].iloc[0])
    cases.append(('fixed_HL_2007',rebridge(fixed),'Fixed-endowment counterfactual, same observed premium and compensation'))
    raw=base.copy();raw.premium=values(extra[0],raw)
    cases.append(('raw_hourly_premium',rebridge(raw),'Unadjusted mean hourly premium; same headcounts'))
    fte=base.copy();fte.H=values(extra[1],fte)/1e6;fte.L=values(extra[2],fte)/1e6
    cases.append(('observed_hours_FTE',rebridge(fte),'Observed-hours FTE; adjusted premium retained; incomplete hours coverage'))
    rawfte=fte.copy();rawfte.premium=values(extra[0],rawfte)
    cases.append(('raw_premium_FTE',rebridge(rawfte),'Joint raw-premium/FTE proxy; not matched annual compensation bills'))
    frozen=base.copy();frozen.premium=float(base.premium.iloc[0])
    cases.append(('fixed_premium_2009',rebridge(frozen),'Counterfactual isolating premium changes'))
    nfc=panel_for(wide,price,scope='NFC')
    cases.append(('NFC_macro_same_labor',nfc,'NFC macro accounts; broad private labor still imperfectly matched'))
    net=base.copy();net.Y=net.COMP+values('NOS_US_AHP_TOTAL_CORP',net)/1e6/net.deflator
    cases.append(('net_factor_cost_output',net,'CFC/tax deduction only; no independently derived CES for net output'))
    alternative=base.copy()
    newprice=values(IDS['Y'],alternative)/values('Y_US_REAL_CORP_GVA',alternative)
    conversion=alternative.deflator/newprice
    for c in ['Y','Q','COMP','D']: alternative[c]*=conversion
    alternative.deflator=newprice
    cases.append(('quarterly_GVA_deflator',rebridge(alternative),'Common implicit deflator from quarterly-deflated GVA'))
    rows=[]
    for name,p,note in cases:
        p=p[p.year.between(int(base.year.min()),int(base.year.max()))].reset_index(drop=True)
        zz,pp,ss=fit(p,mu,rho)
        kk,_=log_knowledge(zz,pp['a'])
        rows.append(dict(scenario=name,n_years=len(p),first_year=int(p.year.min()),last_year=int(p.year.max()),
                         markup=mu,rho=rho,a=pp['a'],xi=pp['xi'],nu=pp['nu'],gap=pp['xi']-pp['nu'],
                         primitive_pass=pp['xi_gt_nu_ge_zero'],phi_min=float(zz.phi.min()),phi_max=float(zz.phi.max()),
                         Q_relative_rmse=pp['free_entry_relative_rmse'],
                         gap_relative_input_contribution=rho*slope(np.log(zz.X/zz.L),kk)/(1-rho),
                         gap_premium_contribution=slope(np.log(zz.wH/zz.wL),kk)/(1-rho),note=note))
    mappings=pd.DataFrame(rows);mappings.to_csv(OUT/'mapping_sensitivity.csv',index=False)
    clocks=[]
    for a in np.geomspace(par['a']/100,par['a']*100,81):
        kk,_=log_knowledge(z,a)
        clocks.append(dict(a=a,xi=slope(np.log(ax),kk),nu=slope(np.log(al),kk),gap=slope(np.log(ax/al),kk)))
    pd.DataFrame(clocks).to_csv(OUT/'knowledge_clock_sensitivity.csv',index=False)
    curvature=[]
    for rr in [1.1,1/0.7,1/0.6,2.,1/0.3]:
        _,pp,_=fit(base,mu,rr)
        curvature.append(dict(rho=rr,a=pp['a'],xi=pp['xi'],nu=pp['nu'],gap=pp['xi']-pp['nu']))
    pd.DataFrame(curvature).to_csv(OUT/'curvature_sensitivity.csv',index=False)
    constrained=cone_fit(z,1/mu,rho,par)
    constrained['unrestricted_objective']=par['objective']
    constrained['objective_ratio']=constrained['objective']/par['objective']
    assert constrained['objective']>=par['objective']-1e-10
    (OUT/'constrained_diagnostic.json').write_text(json.dumps(constrained,indent=2)+'\n')
    native_path=OUT/'native_production_fixture.csv'
    if not native_path.exists():
        raise FileNotFoundError('Run validate_native_production.jl before this diagnosis')
    native=pd.read_csv(native_path)
    native_errors={}
    for rr,g in native.groupby('rho'):
        g=g.reset_index(drop=True);t=g.iloc[0]
        zz=allocation(g,t.theta)
        pp,ss,_=joint_fit(zz,t.theta,rr,alpha=t.alpha)
        np.testing.assert_allclose(zz.X,g.X_true,rtol=1e-12)
        maximum=max(abs(pp[key]/t[key]-1) for key in ['a','xi','nu','AX','AL'])
        assert maximum<2e-5
        native_errors[str(rr)]=float(maximum)
    # Monetary units and alpha affect scales, not the relative-technology ordering.
    money=base.copy()
    for c in ['Y','Q','COMP','D','wH','wL']: money[c]*=100
    _,moneyfit,_=fit(money,mu,rho)
    np.testing.assert_allclose([moneyfit['xi'],moneyfit['nu']],[par['xi'],par['nu']],rtol=2e-5)
    alpha_fit,_,_=joint_fit(z,1/mu,rho,alpha=.3)
    np.testing.assert_allclose([alpha_fit['xi'],alpha_fit['nu']],[par['xi'],par['nu']],rtol=2e-5)
    summary=dict(status='COMPLETED_DIAGNOSIS_NOT_RECALIBRATION',sample=[int(base.year.min()),int(base.year.max())],
                 diagnostic_markup=mu,rho=rho,central_parameters={key:par[key] for key in ['a','xi','nu','AX','AL']},
                 xi_minus_nu=gap,relative_input_gap_contribution=terms[-1][2],premium_gap_contribution=terms[-2][2],
                 relative_input_fraction_of_gap=float(terms[-1][2]/gap),
                 mapping_variants=len(mappings),mapping_variants_passing=int(mappings.primitive_pass.sum()),
                 all_clock_gap_negative=bool(pd.DataFrame(clocks).gap.lt(0).all()),
                 all_rho_above_one_gap_negative=bool(pd.DataFrame(curvature).gap.lt(0).all()),
                 native_recovery_max_relative_errors=native_errors,
                 static_CES_max_relative_error=float(np.max(abs(ycheck/z.Y-1))),
                 constrained=constrained,
                 conclusion='No sign/timing/inversion error found. Current rho>1 and mapped factor trends conflict with the required spillover ordering; mapping versus structural misspecification is not uniquely identified.')
    (OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    manifest=[]
    for p in [Path(__file__),HERE/'validate_native_production.jl',native_path,
              DO/'calibration.py',DO/'config.json',DO/'run_calibration.py',
              DO/'results/baseline_panel.csv',DO/'results/annual_deflator.csv',DATA/'data_final/empirical_moments_us_annual.csv',
              DATA/'diagnostics/labor_wages_methodology.md',ROOT/'AI_drafting/V6_production.tex',
              ROOT/'Codes/Two_country_proudction_zero_nu_b/TwoCountryProductionOLG.jl']:
        manifest.append(dict(path=str(p.relative_to(ROOT)),sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
    pd.DataFrame(manifest).to_csv(OUT/'input_manifest.csv',index=False)
    print(mappings[['scenario','xi','nu','gap','primitive_pass']].to_string(index=False))
    print(json.dumps(summary,indent=2))


if __name__=='__main__':
    main()
