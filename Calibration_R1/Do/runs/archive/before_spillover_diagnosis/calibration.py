"""V6 P1-P5 inversion and profiled joint fit; no economic clipping or GE restrictions.

Inputs have annual rows and internally consistent money/labor units. H,L may be
observed annual endowments; this explicitly relaxes the fixed-endowment GE model.
Requires only NumPy and pandas. The five-parameter joint problem is separable:
conditional on a, the two CES intercept/slope regressions solve exactly.
"""
import numpy as np
import pandas as pd


def allocation(panel, theta):
    p = panel.copy()
    for c in ['Y', 'Q', 'wH', 'wL', 'H', 'L']:
        if not np.isfinite(p[c]).all() or not (p[c] > 0).all():
            raise ValueError('Nonpositive or missing input: ' + c)
    p['BH'] = p.wH * p.H
    p['BL'] = p.wL * p.L
    p['X'] = theta * (p.Y - p.BL) / p.wH
    p['phi'] = p.X / p.H
    p['I'] = p.BH - theta * (p.Y - p.BL)
    p['theta_ceiling'] = p.BH / (p.Y - p.BL)
    p['markup_floor'] = 1 / p.theta_ceiling
    p['minimum_skilled_bill_share'] = theta * (p.Y / (p.BH + p.BL) - 1) / (1 - theta)
    p['valid_P1'] = (p.X > 0) & (p.X < p.H) & (p.I >= 0)
    p['valid_P2'] = p.valid_P1 & (p.Q > p.I)
    p['reason'] = np.select([p.X <= 0, p.X >= p.H, p.I >= p.Q],
                            ['nonpositive_X', 'X_ge_H_negative_research', 'I_ge_Q'], default='admissible')
    return p


def require_feasible(p, rho):
    if abs(rho - 1) < 1e-8:
        raise ValueError('rho=1 has a different scale identification; unsupported here')
    if not p.valid_P2.all():
        raise ValueError('P1/P2 infeasible: no clipping or date deletion permitted')
    if len(p) < 4 or not np.all(np.diff(p.year) == 1):
        raise ValueError('Need at least four consecutive annual observations')


def log_knowledge(p, a):
    logG = np.log1p(a * (p.H.to_numpy() - p.X.to_numpy()))
    return np.r_[0., np.cumsum(logG[:-1])], logG


def ces_coefficients(p, theta, rho):
    cx = np.log(p.wH.to_numpy() / theta) + rho * np.log(p.X.to_numpy() / p.Y.to_numpy())
    cl = np.log(p.wL.to_numpy()) + rho * np.log(p.L.to_numpy() / p.Y.to_numpy())
    return cx, cl


def sequential(p, theta, rho, alpha=0.5):
    require_feasible(p, rho)
    w, q, i = p.wH.to_numpy(), p.Q.to_numpy(), p.I.to_numpy()
    # WLS in b=1/a with omega_t=1/Q_t^2 (a declared scaling choice).
    b = np.sum(w * (q - i) / q**2) / np.sum(w**2 / q**2)
    a = 1 / b
    gq = q / (q - i)
    k = np.r_[0., np.cumsum(np.log(gq[:-1]))]
    cx, cl = ces_coefficients(p, theta, rho)
    z = (1 - rho) * np.log(gq[:-1])
    xi = float(z @ np.diff(cx) / (z @ z))
    nu = float(z @ np.diff(cl) / (z @ z))
    ax0 = float(np.exp((cx[0] - np.log(alpha)) / (1 - rho)))
    al0 = float(np.exp((cl[0] - np.log(1 - alpha)) / (1 - rho)))
    ax = float(np.exp(np.mean((cx - np.log(alpha)) / (1 - rho) - xi * k)))
    al = float(np.exp(np.mean((cl - np.log(1 - alpha)) / (1 - rho) - nu * k)))
    ai = w / (q - i)
    ga = 1 + a * (p.H.to_numpy() - p.X.to_numpy())
    return dict(a=a, xi=xi, nu=nu, AX=ax, AL=al, AX_initial=ax0, AL_initial=al0,
                a_implied_cv=float(np.std(ai, ddof=1) / np.mean(ai)),
                free_entry_relative_rmse=float(np.sqrt(np.mean(((q - i - w/a) / q)**2))),
                growth_gap_rmse=float(np.sqrt(np.mean((np.log(ga) - np.log(gq))**2))),
                growth_Q_path_status='diagnostic only; joint a path used for final conditional fit')


def golden_minimize(fun, lo, hi, tolerance=1e-11):
    ratio = (np.sqrt(5) - 1) / 2
    c, d = hi - ratio*(hi-lo), lo + ratio*(hi-lo)
    fc, fd = fun(c), fun(d)
    for _ in range(200):
        if hi - lo < tolerance:
            break
        if fc < fd:
            hi, d, fd = d, c, fc
            c = hi - ratio*(hi-lo)
            fc = fun(c)
        else:
            lo, c, fc = c, d, fd
            d = lo + ratio*(hi-lo)
            fd = fun(d)
    return (lo + hi) / 2


def joint_fit(p, theta, rho, alpha=0.5, weights=(1., 1., 1.)):
    require_feasible(p, rho)
    seq = sequential(p, theta, rho, alpha)
    cx, cl = ces_coefficients(p, theta, rho)
    tx, tl = cx - np.log(alpha), cl - np.log(1-alpha)
    def at(loga, details=False):
        a = np.exp(loga)
        k, _ = log_knowledge(p, a)
        design = np.c_[np.ones(len(k)), k]
        bx = np.linalg.lstsq(design, tx, rcond=None)[0]
        bl = np.linalg.lstsq(design, tl, rcond=None)[0]
        ra = (p.Q.to_numpy() - p.I.to_numpy() - p.wH.to_numpy()/a) / p.Q.to_numpy()
        rx, rl = tx - design @ bx, tl - design @ bl
        obj = weights[0]*np.mean(ra**2) + weights[1]*np.mean(rx**2) + weights[2]*np.mean(rl**2)
        if details:
            return obj, bx, bl, ra, rx, rl
        return obj
    # Coarse global scan and all interior local minima, then bracketed refinement.
    grid = np.linspace(np.log(seq['a'])-8, np.log(seq['a'])+8, 257)
    vals = np.array([at(z) for z in grid])
    candidates = [(grid[0], vals[0]), (grid[-1], vals[-1])]
    for j in range(1, len(grid)-1):
        if vals[j] <= min(vals[j-1], vals[j+1]):
            z = golden_minimize(at, grid[j-1], grid[j+1])
            candidates.append((z, at(z)))
    loga, _ = min(candidates, key=lambda z: z[1])
    obj, bx, bl, ra, rx, rl = at(loga, True)
    par = dict(a=float(np.exp(loga)), xi=float(bx[1]/(1-rho)), nu=float(bl[1]/(1-rho)),
               AX=float(np.exp(bx[0]/(1-rho))), AL=float(np.exp(bl[0]/(1-rho))))
    # Local five-parameter sensitivity; not a standard error or confidence interval.
    v = np.array([loga, par['xi'], par['nu'], np.log(par['AX']), np.log(par['AL'])])
    def residual(vv):
        k, _ = log_knowledge(p, np.exp(vv[0]))
        return np.r_[np.sqrt(weights[0])*(p.Q-p.I-p.wH/np.exp(vv[0]))/p.Q,
                     np.sqrt(weights[1])*(tx-(1-rho)*(vv[3]+vv[1]*k)),
                     np.sqrt(weights[2])*(tl-(1-rho)*(vv[4]+vv[2]*k))]
    jac = np.empty((3*len(p), 5))
    for j in range(5):
        step = 1e-5 * max(1, abs(v[j]))
        up, dn = v.copy(), v.copy()
        up[j] += step
        dn[j] -= step
        jac[:, j] = (residual(up)-residual(dn))/(2*step)
    sv = np.linalg.svd(jac, compute_uv=False)
    column_norms = np.linalg.norm(jac, axis=0)
    scaled_sv = np.linalg.svd(jac/column_norms, compute_uv=False)
    par.update(objective=float(obj), free_entry_relative_rmse=float(np.sqrt(np.mean(ra**2))),
               log_CX_rmse=float(np.sqrt(np.mean(rx**2))), log_CL_rmse=float(np.sqrt(np.mean(rl**2))),
               optimizer_at_search_boundary=bool(abs(loga-grid[0])<1e-6 or abs(loga-grid[-1])<1e-6),
               jacobian_rank=int(np.linalg.matrix_rank(jac)), jacobian_condition=float(sv[0]/sv[-1]),
               column_scaled_jacobian_condition=float(scaled_sv[0]/scaled_sv[-1]),
               xi_gt_nu_ge_zero=bool(par['xi']>par['nu']>=0))
    profile = pd.DataFrame({'a': np.exp(grid), 'objective': vals, 'objective_excess': vals-obj})
    return par, seq, profile


def fitted_path(p, theta, rho, par, alpha=0.5):
    require_feasible(p, rho)
    p = p.copy()
    k, logg = log_knowledge(p, par['a'])
    p['N'] = np.exp(k)
    p['G_a'] = np.exp(logg)
    p['G_Q_diagnostic'] = p.Q/(p.Q-p.I)
    p['a_implied'] = p.wH/(p.Q-p.I)
    p['AX_fit'] = par['AX']*p.N**par['xi']
    p['AL_fit'] = par['AL']*p.N**par['nu']
    # Conditional production at P1-inferred X, not endogenous GE allocation.
    lx = np.log(alpha)+(1-rho)*np.log(p.AX_fit*p.X)
    ll = np.log(1-alpha)+(1-rho)*np.log(p.AL_fit*p.L)
    p['Y_fit'] = np.exp(np.logaddexp(lx,ll)/(1-rho))
    p['wH_fit'] = theta*alpha*p.AX_fit**(1-rho)*(p.Y_fit/p.X)**rho
    p['wL_fit'] = (1-alpha)*p.AL_fit**(1-rho)*(p.Y_fit/p.L)**rho
    p['Q_free_entry_fit'] = p.I + p.wH/par['a']
    p['Q_production_fit'] = p.G_a*p.wH_fit/par['a']
    p['I_production_fit'] = p.wH_fit*(p.H-p.X)
    p['D_incumbent_fit'] = (1-theta)/theta*p.wH_fit*p.X
    p['net_cashflow_fit'] = p.D_incumbent_fit-p.I_production_fit
    p['relative_Q_residual'] = (p.Q-p.Q_free_entry_fit)/p.Q
    cx, cl = ces_coefficients(p,theta,rho)
    p['AX_inverted'] = np.exp((cx-np.log(alpha))/(1-rho))
    p['AL_inverted'] = np.exp((cl-np.log(1-alpha))/(1-rho))
    p['log_AX_scale_residual'] = np.log(p.AX_inverted/par['AX'])-par['xi']*k
    p['log_AL_scale_residual'] = np.log(p.AL_inverted/par['AL'])-par['nu']*k
    return p


def p3_diagnostic(p):
    x = ((p.Y-p.wL*p.L)/p.wH).to_numpy()
    y = (p.Q/p.wH-p.H).to_numpy()
    rank = int(np.linalg.matrix_rank(np.c_[np.ones(len(x)),x]))
    if rank < 2 or np.std(y) == 0:
        return dict(theta=None, a=None, intercept=None, regressor_sd=float(np.std(x)),
                    design_rank=rank, r_squared=None, admissible=False,
                    note='Unidentified: rank-deficient P3 regressor or constant response')
    slope = np.sum((x-x.mean())*(y-y.mean()))/np.sum((x-x.mean())**2)
    intercept = y.mean()-slope*x.mean()
    theta = -slope
    a = 1/intercept if intercept != 0 else np.nan
    predicted = intercept+slope*x
    return dict(theta=float(theta), a=float(a), intercept=float(intercept),
                regressor_sd=float(np.std(x)), design_rank=rank,
                r_squared=float(1-np.sum((y-predicted)**2)/np.sum((y-y.mean())**2)),
                admissible=bool(0<theta<1 and a>0 and allocation(p,theta).valid_P2.all()),
                note='Unconstrained P3 diagnostic, not a replacement externally disciplined calibration')
