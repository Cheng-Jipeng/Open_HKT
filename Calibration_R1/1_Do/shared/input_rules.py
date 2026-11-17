"""Declare which observed series proxy fixed primitives and which are targets."""
import numpy as np
import pandas as pd


def prepare_panel(observed, config):
    """Select the common sample, then fix H,L, then recompute both wages.

    The mean is over annual population levels, separately for each skill group.
    Neither mean(H/L) nor a 2007 reference level is used. Y,Q,C and the premium
    remain observed targets for endogenous objects; the deflator is a measurement
    transformation, not a model exogenous process.
    """
    first, last = config['sample_start'], config['sample_end']
    p = observed.loc[observed.year.between(first, last)].copy().sort_values('year').reset_index(drop=True)
    if p.year.tolist() != list(range(first, last+1)):
        raise ValueError('Every fitting year must occur exactly once before averaging labor')
    required = ['Y', 'Q', 'COMP', 'premium', 'H', 'L']
    if not np.isfinite(p[required]).all().all() or not p[required].gt(0).all().all():
        raise ValueError('Missing, nonfinite or nonpositive fitting input')
    for key in ['H', 'L', 'wH', 'wL']:
        p[key+'_observed'] = p[key]
    if config['baseline_labor_treatment'] == 'sample_mean_2009_2024':
        for key in ['H', 'L']:
            p[key] = float(p[key].mean())
    elif config['baseline_labor_treatment'] == 'skilled_normalized_annual_ratio':
        # Run 3: H=1 at every date; L_t keeps the observed annual L_t/H_t ratio.
        p['L'] = p.L_observed / p.H_observed
        p['H'] = 1.0
    elif config['baseline_labor_treatment'] != 'observed_annual_endowments':
        raise ValueError('Unsupported labor treatment')
    p['wL'] = p.COMP / (p.premium*p.H + p.L)
    p['wH'] = p.premium * p.wL
    np.testing.assert_allclose(p.wH*p.H+p.wL*p.L, p.COMP, rtol=1e-13)
    np.testing.assert_allclose(p.wH/p.wL, p.premium, rtol=1e-13)
    if config.get('constant_exogenous') and (p.H.nunique()!=1 or p.L.nunique()!=1):
        raise ValueError('Constant-exogenous rule violated by labor inputs')
    return p


def validate_config(config):
    for key in ['baseline_rho', 'baseline_markup', 'central_diagnostic_markup', 'alpha', 'N0', 'period_years']:
        if not np.isscalar(config[key]) or not np.isfinite(config[key]):
            raise ValueError('Primitive assignments must be finite scalars: '+key)
    if any(x <= 1 for x in [config['baseline_rho']]+config['external_rhos']):
        raise ValueError('All executed curvature parameters must satisfy rho > 1')
    if any(x <= 1 for x in [config['baseline_markup']]+config['external_markups']+config['diagnostic_markups_outside_candidate_set']):
        raise ValueError('All executed markups must exceed one')
    if not 0 < config['alpha'] < 1 or config['N0'] != 1 or config['period_years'] != 1:
        raise ValueError('This workflow uses alpha in (0,1), N0=1 and annual periods')
    if config['joint_residual_weights'] != [1., 1., 1.]:
        raise ValueError('The associated closed-cone diagnostic uses equal residual-block weights')
