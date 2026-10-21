"""Synthetic formula checks only: not economic data and not an equilibrium fit."""
import json, math
from pathlib import Path

beta, gamma, pi = .5, .6, .7
theta_star, rf, rp_u, rp_b = .15, .95, 1.2, .8
r_u=(1-theta_star)*rp_u+theta_star*rf
r_b=(1-theta_star)*rp_b+theta_star*rf
den=pi*r_u**(1-gamma)+(1-pi)*r_b**(1-gamma)
tu=r_u**(-gamma)/den
tb=r_b**(-gamma)/den
et=pi*tu+(1-pi)*tb
etrp=pi*tu*rp_u+(1-pi)*tb*rp_b
chi=beta*theta_star*(etrp-rf*et)
rfw=etrp/et
sstar=(beta+chi)/(1+chi)
estar=100.
astar=sstar*estar
bstar=theta_star*astar
j=(bstar/estar)*(1-rf/rfw)
chi_price=j/(1-j)

qu, ea, el=60.,20.,10.
s=qu-el+ea
ss=(1-theta_star)*astar
qw=ss+ea-el
b=-bstar
a=s+b
e=a/beta
nfa=ea-el+b
w=(qu-el)/s
ws=el/ss
q=qu+qw
saved={
 "chi_from_return_FOC":chi,
 "chi_from_price_spread":chi_price,
 "chi_from_saving":(astar/estar-beta)/(1-astar/estar),
 "beta_from_positions":(qu-el+ea+b)/e,
 "beta_from_NFA":(qu+nfa)/e,
 "beta_from_world_Q_given_chi":(q-chi*estar/(1+chi))/(e+estar/(1+chi)),
 "assets_US":a, "assets_ROW":astar,
 "US_assets_from_NFA":qu+nfa,
 "ROW_assets_from_NFA":qw-nfa,
 "equity_S_from_weights":(qu-ws*q)/(w-ws),
 "equity_S":s,
}
wq=(rfw-rp_b)/(rp_u-rp_b)
gamma_shadow=(math.log(pi/(1-pi))-math.log(wq/(1-wq)))/math.log(r_u/r_b)
hu=beta*(rf-rp_u)+(chi/theta_star)*r_u
hb=beta*(rf-rp_b)+(chi/theta_star)*r_b
gamma_no_shadow=math.log(-pi*hu/((1-pi)*hb))/math.log(r_u/r_b)
pi_recovered=-r_b**(-gamma)*hb/(r_u**(-gamma)*hu-r_b**(-gamma)*hb)
theta0=(1-math.sqrt(5))/2
saved.update(gamma_shadow=gamma_shadow,gamma_without_shadow=gamma_no_shadow,
             pi_recovered=pi_recovered,theta_degeneracy=theta0,
             upsilon_prime_at_degeneracy=1/(1-theta0)+theta0)
checks=[
 abs(chi_price-chi)<1e-12,
 abs(saved["chi_from_saving"]-chi)<1e-12,
 abs(saved["beta_from_positions"]-beta)<1e-12,
 abs(saved["beta_from_NFA"]-beta)<1e-12,
 abs(saved["beta_from_world_Q_given_chi"]-beta)<1e-12,
 abs(saved["ROW_assets_from_NFA"]-astar)<1e-12,
 abs(saved["equity_S_from_weights"]-s)<1e-12,
 abs(gamma_shadow-gamma)<1e-12,
 abs(gamma_no_shadow-gamma)<1e-12,
 abs(pi_recovered-pi)<1e-12,
 abs(saved["upsilon_prime_at_degeneracy"])<1e-12,
]
assert all(checks)
out={"test_type":"synthetic_algebra_only_not_data_not_complete_equilibrium",
     "passed":len(checks),"failed":0,"max_tolerance":1e-12,"values":saved}
Path(__file__).with_name("preference_finance_formula_checks.json").write_text(
 json.dumps(out,indent=2)+"\n")
print(json.dumps({"passed":len(checks),"failed":0,"test_type":out["test_type"]}))

