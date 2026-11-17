"""Independent numerical checks for the HKT substitutes branch.

All parameter choices are illustrative, not calibrated or empirical estimates.
Run with a Python environment containing numpy and matplotlib.
"""
from pathlib import Path
import hashlib
import json
import math

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
SOURCE = ROOT / "Codes/Reference/Hirano et al. - General-Purpose Technologies and Stock Market Bubbles.pdf"
P = dict(alpha=.5, beta=.5, sigma=2., rho=.5, a=.2, H=1., L=1.,
         AX=.01, AL=1., xi=.2, lam=.7, b=.1, pi=.95, gamma=.5, n0=1.)


def constants(p):
    K = p['beta'] * p['sigma'] * (1-p['alpha']) / ((p['sigma']-1)*p['alpha'])
    K *= (p['AX']*p['H']/(p['AL']*p['L'])) ** (p['rho']-1)
    c = 1/(p['a']*p['H']) + 1-p['beta']
    kappa = (p['xi']-p['lam'])*(p['rho']-1)
    return K, c, kappa, kappa/p['rho']


def equilibrium(logn, p, balanced=False):
    K, c, kappa, r = constants(p)
    xi, lam = (p['b'], p['b']) if balanced else (p['xi'], p['lam'])
    kz = 0 if balanced else kappa
    logKn = math.log(K) + kz*logn
    innovates = math.log(c-1) < logKn if c > 1 else True
    if innovates:
        low = min(-1., (math.log(c)-logKn)/p['rho']-10.)
        def residual(logphi):
            return math.exp(logphi) + math.exp(logKn+p['rho']*logphi)-c
        high = 0.
        for _ in range(180):
            mid = (low+high)/2
            if residual(mid) > 0:
                high = mid
            else:
                low = mid
        logphi = (low+high)/2
    else:
        logphi = 0.
    phi = math.exp(logphi)
    logU = math.log(p['AX']*p['H']) + xi*logn + logphi
    logV = math.log(p['AL']*p['L']) + lam*logn
    logY = np.logaddexp(math.log(p['alpha'])+(1-p['rho'])*logU,
                       math.log(1-p['alpha'])+(1-p['rho'])*logV)/(1-p['rho'])
    logwH = (math.log((p['sigma']-1)/p['sigma']*p['alpha'])
             + p['rho']*logY + (1-p['rho'])*(math.log(p['AX'])+xi*logn)
             - p['rho']*(math.log(p['H'])+logphi))
    logwL = (math.log(1-p['alpha']) + p['rho']*logY
             + (1-p['rho'])*(math.log(p['AL'])+lam*logn)-p['rho']*math.log(p['L']))
    logD = logwH + math.log(p['H']/(p['sigma']-1)) + logphi-logn
    if innovates:
        logQ = logwH-math.log(p['a'])-logn
    else:
        logQ = math.log(p['beta']) + np.logaddexp(math.log(p['H'])+logwH,
                                                math.log(p['L'])+logwL)-logn
    logG = math.log1p(p['a']*p['H']*(1-phi))
    yield_ = math.exp(logD-logQ)
    return dict(logn=logn, phi=phi, logphi=logphi, logY=float(logY),
                logwH=float(logwH), logwL=float(logwL), logQ=float(logQ),
                logD=float(logD), logPi=float(np.logaddexp(logQ, logD)),
                logG=logG, yield_=yield_, innovates=innovates)


checks = []


def check(name, error, tolerance):
    error = float(error)
    checks.append(dict(name=name, absolute_error=error, tolerance=tolerance,
                       passed=bool(error <= tolerance)))


K, c, kappa, r = constants(P)
Gu = 1+P['a']*P['H']
Cphi = (c/K)**(1/P['rho'])
CY = (1-P['alpha'])**(1/(1-P['rho']))*P['AL']*P['L']
CH = P['beta']*CY/(P['H']*c)
CL = CY/P['L']
CQ = CH/P['a']
CD = CH*P['H']*Cphi/(P['sigma']-1)
T = 800
u, b = [], []
logn = math.log(P['n0'])
for t in range(T+1):
    row = equilibrium(logn, P)
    u.append(row)
    b.append(equilibrium(logn, P, balanced=True))
    logn += row['logG']

# Each row is solved from the occupational/asset-clearing equation. Wages and
# dividends are computed separately from the original CES marginal products.
stock_err, yield_err, wage_err, goods_err, implicit_err = [], [], [], [], []
for row in u:
    saving = math.log(P['beta']) + np.logaddexp(math.log(P['H'])+row['logwH'],
                                              math.log(P['L'])+row['logwL'])
    stock_err.append(abs(math.expm1(row['logQ']+row['logn']+row['logG']-saving)))
    yield_err.append(abs(math.expm1(row['logD']-row['logQ']
                                   -math.log(P['a']*P['H']/(P['sigma']-1))-row['logphi'])))
    wage_err.append(abs(math.expm1(row['logwH']-row['logwL']
                                  -math.log(P['beta']*P['L']/(P['H']*(c-row['phi']))))))
    logprodH = math.log(P['H'])+row['logphi']+row['logwH']
    loglaborL = math.log(P['L'])+row['logwL']
    logdiv = row['logn']+row['logD']
    goods_err.append(abs(math.expm1(np.logaddexp(np.logaddexp(logprodH, loglaborL),logdiv)-row['logY'])))
for t in [0, 10, 30, 60]:
    row = u[t]
    h = 1e-4
    numerical = (equilibrium(row['logn']+h, P)['logphi']-
                 equilibrium(row['logn']-h, P)['logphi'])/(2*h)
    exact = -kappa*(c-row['phi'])/(P['rho']*c+(1-P['rho'])*row['phi'])
    implicit_err.append(abs(numerical-exact))
check('stock market clears with n_(t+1), not n_t', max(stock_err), 3e-12)
check('dividend yield from independent CES wage/dividend formulas', max(yield_err), 3e-12)
check('exact skill premium identity', max(wage_err), 3e-12)
check('final-output factor payments plus monopoly profits', max(goods_err), 3e-12)
check('implicit labor-share derivative vs central difference', max(implicit_err), 1e-8)
check('production employment falls strictly', max(0., max(np.diff([x['phi'] for x in u]))), 0.)
check('skill premium falls strictly', max(0., max(np.diff([x['logwH']-x['logwL'] for x in u[:200]]))), 0.)

row = u[-1]
for name, observed, expected in [
    ('phi asymptotic coefficient', row['logphi']+r*row['logn'], math.log(Cphi)),
    ('Y asymptotic coefficient', row['logY']-P['lam']*row['logn'], math.log(CY)),
    ('wH asymptotic coefficient', row['logwH']-P['lam']*row['logn'], math.log(CH)),
    ('wL asymptotic coefficient', row['logwL']-P['lam']*row['logn'], math.log(CL)),
    ('Q asymptotic coefficient', row['logQ']-(P['lam']-1)*row['logn'], math.log(CQ)),
    ('D asymptotic coefficient', row['logD']-(P['lam']-1-r)*row['logn'], math.log(CD)),
    ('incumbent capitalization/output limit', row['logn']+row['logQ']-row['logY'],
     math.log(P['beta']/(1+P['a']*P['H']*(1-P['beta'])))),
]:
    check(name, abs(observed-expected), 3e-12)

# Exact finite products from the SDF. Their infinite-product remainder is bounded
# analytically using geometric lower growth bounds and CES lower output bounds.
def product_tail(p, u, b):
    terms = np.array([x['yield_']+(1-p['pi'])/p['pi']*(1+x['yield_'])
                      *math.exp((1-p['gamma'])*(y['logPi']-x['logPi']))
                      for x,y in zip(u,b)])
    logs = np.log1p(terms)
    upper = np.exp(-(np.cumsum(logs[::-1])[::-1]-logs))
    return terms, logs, upper

terms, logs, bubble_upper = product_tail(P, u, b)
gap = P['lam']-P['b']
delta = gap*(1-P['gamma'])
Cy = P['a']*P['H']/(P['sigma']-1)*Cphi
CbPi = math.exp(b[0]['logPi']-(P['b']-1)*b[0]['logn'])
Cr = CbPi/CQ
gT = math.exp(u[-1]['logG'])
tail_bound = (Cy*math.exp(-r*row['logn'])/math.expm1(r*math.log(gT))
              +(1-P['pi'])/P['pi']*(1+Cy*math.exp(-r*row['logn']))
              *Cr**(1-P['gamma'])*math.exp(-delta*row['logn'])/math.expm1(delta*math.log(gT)))
check('analytic upper bound on omitted infinite-product log tail', tail_bound, 1e-16)

# Match the per-period product with direct state-price evaluation.
direct_errors = []
for t in range(100):
    nxt, sw = u[t+1], b[t+1]
    logden = np.logaddexp(math.log(P['pi'])+(1-P['gamma'])*nxt['logPi'],
                         math.log1p(-P['pi'])+(1-P['gamma'])*sw['logPi'])
    logmuu = u[t]['logQ']-P['gamma']*nxt['logPi']-logden
    normalized = math.log(P['pi'])+logmuu+nxt['logQ']-u[t]['logQ']
    direct_errors.append(abs(normalized+logs[t+1]))
check('bubble-product factors vs direct stochastic discount factors', max(direct_errors), 1e-12)

# Check no-innovation b, zero-innovation u, and the equal-growth no-bubble case.
pnob = dict(P, AX=1., n0=10000.)
unob = equilibrium(math.log(pnob['n0']), pnob)
bnob = equilibrium(math.log(pnob['n0']), pnob, balanced=True)
assert unob['innovates'] and not bnob['innovates']
check('b no-innovation corner uses market-clearing stock price',
      abs(bnob['logQ']-(math.log(pnob['beta'])+
          np.logaddexp(math.log(pnob['H'])+bnob['logwH'], math.log(pnob['L'])+bnob['logwL'])-bnob['logn'])), 1e-12)
pno = dict(P, AX=1.)
uno = equilibrium(0., pno)
assert not uno['innovates'] and uno['phi'] == 1 and uno['logG'] == 0

# A grid covers both sides of rho=1, the two signs of xi-lambda, and small rho.
grid_errors = []
grid_cases = 0
for rho in [.2, .5, .9, 1.2, 2.]:
    for xi, lam in [(.2,.7),(.7,.2)]:
        pg = dict(P, rho=rho, xi=xi, lam=lam, a=2., AX=1.)
        kg, cg, kappag, rg = constants(pg)
        for ln in [0.,2.,8.]:
            v = equilibrium(ln, pg)
            saving = math.log(pg['beta'])+np.logaddexp(math.log(pg['H'])+v['logwH'],math.log(pg['L'])+v['logwL'])
            grid_errors.append(abs(math.expm1(v['logQ']+v['logn']+v['logG']-saving)))
            grid_cases += 1
check('CES and stock-clearing identities across 30 parameter/state cases',max(grid_errors),1e-11)

selected = []
for t in [0,10,20,40,80,160,800]:
    x=u[t]
    selected.append(dict(t=t, n=math.exp(x['logn']), phi=x['phi'],
                         price_dividend=1/x['yield_'], Q_relative=math.exp(x['logQ']-u[0]['logQ']),
                         D_relative=math.exp(x['logD']-u[0]['logD']),
                         skill_premium=math.exp(x['logwH']-x['logwL']),
                         bubble_fraction_truncated_upper=float(bubble_upper[t])))

plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.spines.top':False,
                     'axes.spines.right':False,'axes.labelcolor':'#223248','text.color':'#223248'})
fig, axs=plt.subplots(2,2,figsize=(10,7),constrained_layout=True)
tt=np.arange(101)
blue,orange='#165D91','#C45A2A'
axs[0,0].plot(tt,[u[t]['phi'] for t in tt],color=blue,label='State u: production share')
axs[0,0].axhline(b[0]['phi'],color=orange,ls='--',label='State b: production share')
axs[0,0].set(title='(a) Skilled labor moves into R&D',ylabel='Production employment / H')
axs[0,0].legend(frameon=False,fontsize=9)
axs[0,1].plot(tt,[u[t]['logQ']-u[0]['logQ'] for t in tt],color=blue,label='log(Q / Q0)')
axs[0,1].plot(tt,[u[t]['logD']-u[0]['logD'] for t in tt],color=orange,label='log(D / D0)')
axs[0,1].set(title='(b) A bubble need not raise the per-share price',ylabel='Log change from date 0')
axs[0,1].legend(frameon=False)
axs[1,0].plot(tt,bubble_upper[tt],color=blue)
axs[1,0].set(title='(c) The bubble fraction approaches one',ylabel='B / Q',ylim=(0,1.03))
prem=np.array([math.exp(u[t]['logwH']-u[t]['logwL']) for t in tt])
axs[1,1].plot(tt,prem/prem[0],color=blue)
axs[1,1].axhline((P['beta']*P['L']/(P['H']*c))/prem[0],color=orange,ls='--',label='Asymptotic limit')
axs[1,1].set(title='(d) The skill premium declines along equilibrium',ylabel='(wH / wL) relative to date 0')
axs[1,1].legend(frameon=False)
for ax in axs.flat:
    ax.set_xlabel('Date, conditional on remaining in state u')
    ax.grid(alpha=.18)
fig.suptitle('HKT with xi_u < lambda_u and 0 < rho < 1\nIllustrative parameters; not a calibration',fontsize=14)
fig.savefig(OUT/'illustrative_paths.png',dpi=220)
plt.close(fig)

result=dict(parameters=P, constants=dict(K=K,c=c,kappa=kappa,r=r,Cphi=Cphi,CY=CY,CH=CH,CL=CL,CQ=CQ,CD=CD,Gu=Gu),
            checks=checks,all_passed=all(x['passed'] for x in checks),
            bubble_tail=dict(T=T,omitted_log_tail_upper_bound=tail_bound,
                             bound='For t <= T: Bupper_t * exp(-tail_bound) <= B_t/Q_t <= Bupper_t. The date-T upper value is 1 by truncation.'),
            selected_conditional_path=selected,grid_cases=grid_cases,
            source=dict(path=str(SOURCE),sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                        paper_date='2026-08-16',local_pdf_pages=60,
                        analysis_date='2026-11-17',status='Illustrative checks, not empirical or calibrated results'))
(OUT/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['constants','all_passed','bubble_tail','selected_conditional_path']},indent=2))
assert result['all_passed'], [x for x in checks if not x['passed']]
