"""Build presentation evidence from saved calibration outputs, without refitting."""
import hashlib
import json
from pathlib import Path
import argparse
import numpy as np
import pandas as pd

DO=Path(__file__).resolve().parent.parent
ROOT=DO.parents[2]
from calibration import ces_coefficients, fitted_path


def main(run):
    DO=Path(run).resolve()
    HERE=DO/'slides'
    config=json.loads((DO/'config.json').read_text())
    status=json.loads((DO/'results/calibration_status.json').read_text())
    run=config['central_run_id']
    base=pd.read_csv(DO/'results/baseline_allocation.csv')
    paths=pd.read_csv(DO/'results/conditional_paths.csv')
    p=paths[paths.run_id.eq(run)].reset_index(drop=True)
    if (list(p.year)!=list(range(2009,2025)) or config['baseline_rho']!=2
            or config['central_diagnostic_markup']!=3.5 or config['alpha']!=0.5 or config['N0']!=1):
        raise ValueError('This dated deck requires the 2009–2024, rho=2, mu=3.5, alpha=.5, N0=1 run')
    pars=pd.read_csv(DO/'results/conditional_parameters.csv')
    joint=pars[pars.run_id.eq(run)].iloc[0].to_dict()
    seqs=pd.read_csv(DO/'results/conditional_sequential.csv')
    seq=seqs[seqs.run_id.eq(run)].iloc[0].to_dict()
    metrics=pd.read_csv(DO/'results/fit_metrics.csv')
    metric=metrics[metrics.run_id.eq(run) & metrics.subset.eq('fit')].iloc[0].to_dict()
    diagnosis=json.loads((DO/'results/diagnosis.json').read_text())
    assert diagnosis['sample']==[int(p.year.min()),int(p.year.max())]
    assert diagnosis['rho']==config['baseline_rho']
    for key in ['a','xi','nu','AX','AL']:
        assert np.isclose(diagnosis['central_parameters'][key],joint[key],rtol=1e-5)
    cx,cl=ces_coefficients(p,joint['theta'],joint['rho'])
    gq=p.G_Q_diagnostic.to_numpy()
    lognq=np.r_[0.,np.cumsum(np.log(gq[:-1]))]
    z=(1-joint['rho'])*np.log(gq[:-1])
    for key,coeff in [('xi',cx),('nu',cl)]:
        np.testing.assert_allclose(seq[key],z@np.diff(coeff)/(z@z),rtol=1e-12)
    additions={
        'CX':np.exp(cx),'CL':np.exp(cl),'N_Q':np.exp(lognq),
        'Q_sequential_fit':p.I+p.wH/seq['a'],
        'growth_Q_percent':100*(gq-1),'growth_a_percent':100*(p.G_a-1),
        'AX_scale_sequential':p.AX_inverted/np.exp(lognq)**seq['xi'],
        'AL_scale_sequential':p.AL_inverted/np.exp(lognq)**seq['nu'],
        'log_AX':np.log(p.AX_inverted),'log_AL':np.log(p.AL_inverted),
        'log_AX_joint':np.log(p.AX_fit),'log_AL_joint':np.log(p.AL_fit),
        'log_N_joint':np.log(p.N),
        'log_premium_change':np.log(p.premium/p.premium.iloc[0]),
        'rho_log_XL_change':joint['rho']*np.log((p.X/p.L)/(p.X/p.L).iloc[0]),
        'log_relative_A_change':np.log((p.AX_inverted/p.AL_inverted)/(p.AX_inverted/p.AL_inverted).iloc[0]),
        'P3_x':(p.Y-p.wL*p.L)/p.wH,'P3_y':p.Q/p.wH-p.H,
    }
    for key,value in additions.items():p[key]=value
    growth=pd.DataFrame({'year':p.year.to_numpy()[:-1],'delta_log_CX':np.diff(cx),
                         'delta_log_CL':np.diff(cl),'fit_CX':z*seq['xi'],'fit_CL':z*seq['nu']})
    constrained=diagnosis['constrained']
    cpath=fitted_path(p,joint['theta'],joint['rho'],constrained,alpha=config['alpha'])
    for key in ['AX_fit','AL_fit','Y_fit','wH_fit','wL_fit']:
        p['constrained_'+key]=cpath[key]
    p3=json.loads((DO/'results/p3_diagnostic.json').read_text())
    p['P3_fit']=p3['ratio_OLS']['intercept']-p3['ratio_OLS']['theta']*p.P3_x
    build=HERE/'.build'; build.mkdir(exist_ok=True)
    p.to_csv(build/'slide_series.csv',index=False)
    growth.to_csv(build/'slide_growth.csv',index=False)
    source_paths=[DO/'config.json', *sorted((DO/'results').glob('*.csv')),
                  *sorted((DO/'results').glob('*.json')),
                  *sorted((DO.parent.parent/'shared').glob('*.py')),
                  DO.parent.parent/'shared/references/rho_selection.md',
                  ROOT/'AI_drafting/V6_production.tex',
                  DO.parent/'01_observed_labor/results/conditional_parameters.csv']
    manifest={str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in source_paths}
    data=dict(config=config,status=status,base=base.to_dict('list'),series=p.to_dict('list'),
              growth=growth.to_dict('list'),joint=joint,sequential=seq,metrics=metric,diagnosis=diagnosis,p3=p3,
              comparison=pd.read_csv(DO/'results/run_comparison.csv').to_dict('records'),
              provenance=manifest)
    (build/'slide_data.json').write_text(json.dumps(data,ensure_ascii=False,allow_nan=False,indent=2)+'\n')
    print(json.dumps({'sample':[int(p.year.min()),int(p.year.max())],'n_years':len(p),
                      'N_Q_end':p.N_Q.iloc[-1],'N_joint_end':p.N.iloc[-1],
                      'sequential':{k:seq[k] for k in ['a','xi','nu','AX','AL']},
                      'joint':{k:joint[k] for k in ['a','xi','nu','AX','AL']}}))


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--run',required=True,type=Path)
    main(parser.parse_args().run)
