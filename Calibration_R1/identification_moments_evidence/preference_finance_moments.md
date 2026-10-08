# Primitive identifying moments: preferences, portfolio frictions and regime persistence

Date: 29 September 2026. Scope: M01–M07 only. This is an algebra/identification audit of the current manuscript and implemented zero-exponent solver, not an estimate, an empirical identification claim, or a model modification.

## 1. Source authority and independent equation count

- Parameter definitions: Codes/Calibration_R1/V6_parameter_calibration_groups.tex:57,72–74,96–103.
- Manuscript: AI_drafting/V6_production.tex:530–652 (US budgets/saving/portfolio FOCs), 738–890 (RoW), 894–951 (clearing), 1198–1265 (five portfolio conditions including boundary inequalities), 1340–1345 (regime transition law).
- Code: Codes/Two_country_proudction_zero_nu_b/TwoCountryProductionOLG.jl:254–267 (production inputs/valuation), 882–963 (unbalanced branch), 466–515 (deterministic absorbing branch), 183–188 (imposed bond-cost function), 1816–1820 (NFA identity).
- Existing measurement conventions: V6_calibration_measurability.tex:118–155. Current-state source lines were re-read for this memo.

The parsimonious structural basis is: TWO saving equations, FIVE portfolio FOCs (at interior equity positions), and ONE transition law. Market clearing/budget accounting maps measured positions into those equations. It must not be counted again as an independent behavioral restriction when the corresponding constructed wealth/portfolio series already use the same identity. In the code, saving is substituted out; the seven residuals are TWO equity-value-clearing residuals plus FIVE portfolio residuals. Seven equilibrium equations do not mean seven independent identifying data moments.

Use D for directly constructed empirical quantities under an explicit perimeter; I for quantities requiring an additional mapping, estimated conditional distribution or model inversion; U for an unavailable/structurally unobserved counterpart in the current empirical package. These classify moment inputs/routes, not the structural parameters themselves. A D accounting statistic does not make its inferred preference parameter directly observed.

## 2. Small primitive stock/income/return dictionary

Suppress t. Write Q_U and Q_W for POST-ISSUANCE aggregate capitalizations, E_A=q_W n_W for US foreign equity assets, E_L=q_U n_U* for foreign equity in the US, and b for the US net position in the single safe bond (negative under chi>0). All values use the same price date, currency, residence and asset universe. Define E=E_A−E_L and Q=Q_U+Q_W.

| Input | Current measurement and exact-model qualification |
|---|---|
| E_A,E_L,NFA | D under the adopted AHP/IMA perimeter; they do not require observing claim counts. |
| Q_U | D accounting candidate (AHP operating-asset value or a declared equity-value alternative); timing/issuance and investor-universe mapping are maintained conditions. |
| Q_W | Covered-country values exist, but the full RoW aggregate needed here remains I/U; do not replace it silently with AHP E_A. |
| b_NE=NFA−E_A+E_L | D residual. Its interpretation as one same-numeraire, riskless, zero-net-supply claim is I; a broad non-equity balance is not automatically b. |
| e,e* | D matched compensation candidates; literal young-cohort, lifetime-period and production/R&D income mappings remain I, especially for full RoW. e is not GDP. |
| C_y,C_y* or cohort acquisition A,A* | Potential household/cohort data routes; no exact matched series is supplied by the existing aggregate mapping. I/U. |
| Realized country equity total returns R_U,R_W | D with a consistent holder/issuer, payout, FX and return period; V6 per-variety mapping is I if issuance/payout adjustments remain unresolved. No need to estimate absolute N or q if matched total returns are available. |
| R_f | Named nominal bills are D; V6 requires an ex-ante riskless real payoff in the common consumption numeraire and model period, so this mapping is I. Ex-post CPI deflation does not create that payoff. |
| R_f^W | U as currently mapped: the RoW bond has zero net supply and its yield is a shadow price. A foreign sovereign yield includes currency/default/liquidity differences and is not automatically its counterpart. |
| z_t and state-conditioned payoff branches | U in the current data mapping. A documented classifier or empirical conditional-return model could produce I inputs; a chosen 2008 switch is not an observed technology state. |
| E_t[nonlinear return functions] | I if credibly estimated; U if essential counterfactual branch payoffs are unavailable. Never D merely because individual realized returns are observed. |

Exact accounting reconstruction, using stock and bond clearing:

S = Q_U−E_L+E_A = Q_U+E,
S* = Q_W−E_A+E_L = Q_W−E,
A = S+b = Q_U+NFA,
A* = S*−b = Q_W−NFA,
A+A* = Q.

Then omega=(Q_U−E_L)/S, omega*=E_L/S*, theta=b/A, theta*=−b/A*, theta_W*=0. Validity requires A,A*,S,S*>0; with chi>0, b<0, theta<0 and 0<theta*<1. There is no need to observe N or claim counts for this construction. Q_W is unnecessary for US omega and A, but necessary for the corresponding RoW reconstruction unless a different denominator is independently supplied.

Alternative *measurement routes*, not extra equations:
- Given both equity weights, S=(Q_U−omega*Q)/(omega−omega*), S*=Q−S. This is singular when omega=omega* and weak near equality.
- Given E_A and omega, S=E_A/(1−omega); given E_L and omega*, S*=E_L/omega*. Avoid the zero-denominator corners.
- Given A and theta, S=(1−theta)A; given b and theta, A=b/theta. These do not create new identifying information if the shares were first constructed from the same positions.

Code reconstruction uses A=beta e and A*=((beta+chi)/(1+chi))e*, then theta=−theta* A*/A, S=(1−theta)A and S*=(1−theta*)A* (892–896). For calibration, replacing observed A with this parameter-dependent A before claiming to “measure” beta would be circular. Also e is computed from wages (265), while q=w_H/(aN) is imposed by free entry (263); a model-generated Q is not an independent market-cap observation.

## 3. M01 beta: two independent-data routes and their equivalent forms

### B1. Country/cohort saving or consumption route

beta = A/e = 1−C_y/e
     = (Q_U+NFA)/e
     = (Q_U−E_L+E_A+b)/e.

Alternatively, at the common-share type level, beta=A_H/w_H=A_L/w_L=1−c_y,H/w_H=1−c_y,L/w_L. Type-level observations give additional evidence/testing of homogeneity; aggregating them does not create an extra equation. These formulas are exact conditional on the V6 cohort, period and asset scope. They do NOT require gamma or a return expectation. They do NOT license equating national saving/DPI or all-age household wealth/current-year compensation with beta.

The observed annual ratio (Q_U+NFA)/e can be D arithmetic and still have an I/unresolved structural mapping. The existing script Codes/Empirical_Data/Variable_mappings/Empirical_Mapping_Annual/scripts/09b_implied_beta.py:41–65 explicitly constructs this diagnostic, verifies the position identity, and labels the cohort/scope problem. No existing reported result is reused as an estimate here.

### B2. World-capitalization route, eliminating both countries' saving assets

Let s_W=A*/e*=(beta+chi)/(1+chi). Then

Q = beta e + s_W e*.

If chi is externally fixed:
beta = [Q−chi e*/(1+chi)]/[e+e*/(1+chi)].

If beta is known:
s_W=(Q−beta e)/e*,
chi=[Q−beta(e+e*)]/[e*−Q+beta e].

If both beta and chi are unknown but constant across observations, regress/fit Q_t=beta e_t+s_W e_t* as TWO coefficients. The design [e_t,e_t*] must have column rank two (variation in the income ratio, not just common scale growth). Recover chi=(s_W−beta)/(1−s_W). A single world-cap snapshot identifies only one combination; proportional country incomes across the sample retain that underidentification. The same cohort and full-RoW problems remain. This is an alternative data route to B1 plus the RoW saving route below; it is not an extra independent equation after both are imposed.

For statistical estimation with noisy data, structural rank alone is insufficient: endogenous measurement errors, common trends and the admissible coefficient region require explicit treatment. Required model consistency is 0<beta<s_W<1 for chi>0. Do not clip an incompatible inferred ratio into this region.

## 4. M05 chi: three economically different evidence channels

### C1. RoW saving/consumption channel

With s_W=A*/e*,

chi=(s_W−beta)/(1−s_W)
   =(A*−beta e*)/(e*−A*)
   =(1−beta)e*/C_y*−1.

Use A*=Q_W−NFA, or A*=Q−beta e, or an independently matched cohort asset-acquisition measure. With both saving fractions independently measured, chi=(s_W−s_U)/(1−s_W), where s_U=beta. Equivalently chi=(C_y/e)/(C_y*/e*)−1. These are one saving equation in alternative measured coordinates. No return distribution is needed. The route is I until full RoW/cohort counterparts exist. It becomes ill-conditioned as s_W approaches one.

### C2. Safe-price spread plus holdings channel: eliminates gamma AND beta

The manuscript's bond-price equations (886–888) give

q_f−q_W = [chi/(1+chi)] e*/B_US*.

Since b*=q_f B_US*, q_f=1/R_f and q_W=1/R_f^W, define

j = (q_f−q_W) B_US*/e*
  = (b*/e*) [1−R_f/R_f^W].

Then chi=j/(1−j). This is the cleanest algebraic inversion using a matched convenience spread and holdings/income; 0<j<1 is required. It does not need beta, gamma, equity returns or N. A spread alone is insufficient: the foreign safe-claim level relative to RoW income is indispensable. This is **U in the present mapping** because R_f^W lacks a verified empirical counterpart. If that counterpart were supplied, the rate/claim/cohort conversions would still be I.

This is a combination of BOTH RoW bond FOCs, saving separation and normalization, not a third independent RoW Euler equation. Holding this inversion together with both FOCs and the saving equation does not add rank.

### C3. Risk-weighted US-bond demand, without observing R_f^W

Define r*=R_A*=(1−theta*)R_p*+theta*R_f and
T*=r*^(−gamma)/E_t[r*^(1−gamma)].
The US-bond FOC (863–866; code963) gives

chi = beta theta* E_t[T*(R_p*−R_f)].

This route needs beta, reconstructed shares and the conditional return distribution; it does not need the shadow RoW rate. Its status is I/U rather than D. Physical expected excess returns alone do not supply the risk-weighted expectation. With chi recovered by C1, C3 is an independent RETURN restriction that can help identify/test gamma and/or pi; that is more informative than treating another rearrangement of C1 as another chi moment.

## 5. A compact complete basis for the FIVE portfolio conditions

Define dR=R_U−R_W; R_p=omega R_U+(1−omega)R_W; R_p*=omega*R_U+(1−omega*)R_W;
r=R_A=(1−theta)R_p+theta R_f; r*=R_A* as above;
T=r^(−gamma)/E_t[r^(1−gamma)] and T* as above.

1. US equity: beta(1−theta) E_t[T dR] = kappa(omega−omega_bar).
2. US safe share: beta E_t[T(R_f−R_p)] = eta Upsilon'(theta).
3. RoW equity: beta(1−theta*) E_t[T* dR] = kappa(omega*−omega_bar*).
4. RoW benchmark bond: E_t[T*(R_f^W−R_p*)] = 0.
5. RoW US bond: beta E_t[T*(R_f−R_p*)] + chi/theta* = 0.

Important code notation: K_u,K_b at941–942 are the US T values; M_u,M_b at945–946 are the NORMALIZED RoW T* values, not the manuscript's undistorted M*=(beta/(beta+chi))T*. Replacing one by the other without the scaling factor corrupts chi/kappa inferences.

Equivalent empirical GMM form: cross-multiply each conditional denominator, which is positive. For example the US equity residual can be written

E_t[ beta(1−theta)r^(−gamma)dR
     −kappa(omega−omega_bar)r^(1−gamma) ]=0,

and the RoW US-bond residual as

E_t[ beta r*^(−gamma)(R_f−R_p*)
     +(chi/theta*)r*^(1−gamma) ]=0.

Multiplying by valid date-t instruments Z_t and taking unconditional expectations supplies sample moment conditions from realized returns. This avoids separately estimating E_t[r^(1−gamma)] but does not eliminate conditional-information, measurement-error, support or identification requirements. Multiple instruments can supply independent restrictions when their moment gradients differ; they are not automatically independent just because their names differ.

All-u *conditional survival* simulated paths are not draws from the unconditional two-state distribution. In the actual solver, every date's expectation explicitly weights a continued-u and a counterfactual-b payoff by pi and 1−pi (936–953). Substituting the one realized continued-u return into those expectations biases the risk moment. A long realized all-u series alone does not reveal the missing switch payoff schedule.

## 6. M03 kappa and M04 omega_bar, omega_bar*: slope/intercept identification

Let
f_U,t=(1−theta_t)E_t[T dR],
f_W,t=(1−theta_t*)E_t[T* dR],
k=kappa/beta, and h_U=k omega_bar, h_W=k omega_bar*.

The two equity conditions become
f_U,t=k omega_t−h_U,
f_W,t=k omega_t*−h_W.

Thus the primitive objects are risk-weighted equity-return DIFFERENCES and actual equity weights, across states/dates/countries. The slope is common; each country has its own intercept. For matched gamma/pi/return mapping and interior allocations, the pooled design has rows (omega_t,−1,0) and (omega_t*,0,−1). It identifies (k,h_U,h_W) only with rank three. At least two distinct equity weights within ONE country plus an observation in the other can provide that rank. Merely observing two countries at one date gives two equations for three unknowns, even though the two shares differ.

With within-country variation,
k = Delta f_U/Delta omega, or Delta f_W/Delta omega*;
kappa=beta k;
omega_bar=omega−f_U/k, omega_bar*=omega*−f_W/k.

If kappa is fixed, each country-date supplies a conditional center:
omega_bar=omega−beta(1−theta)E_t[T dR]/kappa.
If a center is fixed, kappa=beta f_U/(omega−omega_bar), provided the denominator is nonzero; analogously abroad. When the deviation and risk-return wedge are both zero, that observation does not identify kappa. When kappa=0 (outside the current positive-kappa code restriction), centers have no effect and cannot be identified. Near-zero kappa makes center inference weak. Without a saving-based beta anchor, these equity equations identify kappa/beta, not kappa in levels.

Observed omega is not a preference center. Setting omega_bar=omega imposes a ZERO conditional risk-weighted return gap. Nor is E_L/Q_U the RoW portfolio share omega*: its denominator must be S*, not US capitalization.

Measurement: US omega has a D accounting route with stated perimeter, RoW omega* needs the full-RoW denominator (I/U). f_U,f_W are I/U because risk weights depend on gamma and the physical conditional distribution. For jointly unknown gamma/pi, estimating the slope while treating f as directly observed is circular; evaluate moment functions at trial parameters and check the full Jacobian rank.

Boundary qualification: manuscript1198–1245 has G<=0 at omega=0, G>=0 at omega=1, and G=0 only inside. Boundary observations give inequalities/bounds, not the equality-based inversion. Code450–453 uses sigmoid weights, keeping numerical solutions interior; do not apply this equality mechanically to a data corner.

## 7. M06 eta: one safe-share Euler restriction and its degeneracy

The code fixes Upsilon(theta)=−log(1−theta)+theta^2/2, so
Upsilon'(theta)=1/(1−theta)+theta.

Therefore
eta = beta E_t[T(R_f−R_p)]/[1/(1−theta)+theta],
provided the denominator is nonzero.

Across observations, this is a zero-intercept slope:
E_t[T(R_f−R_p)] = (eta/beta) Upsilon'(theta).
If beta is not separately pinned, the restriction directly disciplines eta/beta. The changing theta and return distribution can strengthen identification; a single correctly measured conditional moment suffices only conditional on beta,gamma,pi and the return/claim mapping. The route is I/U.

The admissible zero of Upsilon' is theta_0=(1−sqrt(5))/2, approximately −0.618034. At that point the numerator must also be zero; the observation supplies no local level information about eta through this FOC. Near the zero, inversion is ill-conditioned. A nonzero numerator at exactly zero is model/moment inconsistency, not an infinite calibrated eta.

The alternative formula eta=beta[1−E_t(T R_p)]/[theta Upsilon'(theta)] follows from E_t(T r)=1 and the same FOC; it is not another independent moment and additionally degenerates at theta=0. The identity E_t(T r)=1 holds by construction for EVERY gamma, so using it as a gamma moment is invalid. Under chi>0 the equilibrium has theta<0, but zero is a meaningful limiting identification check.

eta is a utility wedge, not an observable underwriting fee or a resource expense. State prices/effective stock kernels obtained using eta cannot then be re-used as independent empirical evidence identifying eta.

## 8. M02 gamma and M07 pi: conditional nonlinear moments and explicit two-state inversions

### G1. RoW benchmark-return condition, conditional on pi

Suppose both state-contingent payoffs and the genuine R_f^W are independently available at a current u state. Let x_z=R_p*^z and r_z=R_A*^z, z in {u,b}. Define

w_Q = (R_f^W−x_b)/(x_u−x_b).

FOC4 implies w_Q = [pi r_u^(−gamma)]/[pi r_u^(−gamma)+(1−pi)r_b^(−gamma)].
Thus

logit(w_Q)=logit(pi)−gamma log(r_u/r_b),
gamma=[logit(pi)−logit(w_Q)]/log(r_u/r_b).

This is not the unweighted equity premium and it is not a directly measured risk-aversion parameter. It requires x_u!=x_b, 0<w_Q<1, r_u,r_b>0 and r_u!=r_b. If R_f^W is merely the solver's implied yield, the equation just reconstructs that yield and supplies no independent data restriction. Current mapping: U.

With a credible physical gamma anchor, the same equation gives
pi=logistic[logit(w_Q)+gamma log(r_u/r_b)].
With constant gamma and pi and multiple independently measured states, varying d_t=log(r_u/r_b) gives an intercept/slope route to both: logit(w_Q,t)=logit(pi)−gamma d_t. Rank requires variation in d_t. This is a conditional-pricing route to physical persistence, not a substitute for documenting what u and b mean.

### G2. General inversion, including a route that does NOT need R_f^W

Every cross-multiplied FOC can be expressed as

pi r_u^(−gamma) h_u + (1−pi) r_b^(−gamma) h_b = 0,

where r and h are:
- US equity: r=R_A; h_z=beta(1−theta)dR_z−kappa(omega−omega_bar)r_z.
- US safe share: r=R_A; h_z=beta(R_f−R_p^z)−eta Upsilon'(theta)r_z.
- RoW equity: r=R_A*; h_z=beta(1−theta*)dR_z−kappa(omega*−omega_bar*)r_z.
- RoW benchmark: r=R_A*; h_z=R_f^W−R_p*^z.
- RoW US bond: r=R_A*; h_z=beta(R_f−R_p*^z)+(chi/theta*)r_z.

For h_u h_b<0 and r_u!=r_b,

gamma=log[−pi h_u/((1−pi)h_b)] / log(r_u/r_b).

Conditional on gamma instead,

pi=−r_b^(−gamma)h_b/[r_u^(−gamma)h_u−r_b^(−gamma)h_b].

These are rearrangements of the FIVE original FOCs, not five additional equations. In particular, if beta and chi are recovered by saving evidence, the last row supplies a gamma/pi restriction using only US-safe and equity returns plus portfolio shares: no R_f^W benchmark is required. Its limitations are the latent switch branch, conditional probabilities, cohort mapping, and possible weak rank, rather than the shadow-yield gap.

If both h values vanish the equation adds no information. If they share a nonzero sign no interior pi can satisfy it. If r_u=r_b, gamma cancels. A negative inferred gamma or pi outside (0,1) must be reported as incompatibility with that conditional mapping, not silently truncated.

For simultaneous gamma/pi/friction identification, stack the independent portfolio conditions across states and inspect the Jacobian in the free parameter block. Counting raw target labels is insufficient. Pi and gamma can trade off through the state-odds expression; observable variation in risk exposure and independent persistence/saving evidence helps separate them. Return moments from the same price/holding algebra should not be duplicated under different labels.

### G3. Separate preference evidence

Compatible experimental/structural risk-preference evidence can supply an external gamma anchor, avoiding internal financial-moment identification. It measures risk-taking under its own population/stakes/beliefs; an exact V6 gamma mapping is an assumption. This is I external evidence, not another V6 equilibrium equation. Risk-tolerance reciprocity and representative-agent aggregation require explicit treatment.

### P1. Direct physical-transition or duration evidence for pi

Given an independently operationalized state classifier and a matched period,

pi = Pr(z_{t+1}=u | z_t=u);
sample counterpart = #u-to-u / #transitions at risk in u.

A complete geometric spell has expected duration 1/(1−pi) model periods. Right-censored all-u histories contribute survival likelihood pi^T; they do not reveal an observed interior probability. One absorbing US history has at most one exit; repeated independent spells/countries would require a defensible common-event/common-parameter assumption. Regime labels currently are U; estimated classifiers would produce I. The stock-market crash date is not automatically the technology transition. Annual h maps to pi=(1−h)^Delta only for the same event and constant hazard.

A return-pricing inversion of pi and transition-frequency evidence are genuinely different DATA channels. Within the pricing channel, expected return, state-price and Euler versions are algebraic alternatives, not additional restrictions.

### Absorbing-regime nonidentification

In the deterministic b branch, T=1/R_A and T*=1/R_A*, independently of gamma. Code487–515 contains neither gamma nor pi. Pure b-regime observations cannot identify either parameter from this solver's financial equations. Gamma=1 is numerically well defined in normalized return kernels even though the manuscript's displayed utility needs a limit. The sufficient-bubble theorem gamma<1 must not be used to filter empirical identifying evidence.

## 9. Recommended minimum moment basis for an identification audit

A parsimonious sequence, not an estimated calibration:

1. Adopt period/cohort, asset and income scopes. Use measured Q_U,E_A,E_L,b (or matched NFA), plus Q_W where available, to reconstruct portfolio shares and saving assets. Preserve D accounting status and I/U mapping gaps separately.
2. Anchor beta and chi using two independent saving/capitalization restrictions: US A/e plus RoW A*/e*, OR a rank-two panel of Q against e and e*. Do not count the equivalent NFA identity separately.
3. Fix gamma and pi externally, or include identified physical-regime evidence and enough independent nonlinear return restrictions. The RoW US-bond FOC is a useful extra risk restriction after chi is anchored; the shadow-bond route is currently unavailable as measured evidence.
4. Identify common kappa/beta and both preference centers from within-country portfolio-weight variation and conditional equity-return gaps; add the US safe-share condition for eta/beta.
5. Validate against unused exposures, return responses, macro production moments and external-flow paths. If the moment Jacobian is deficient or ill-conditioned, reduce the internally free block or report identified combinations/sets.

NFA=E_A−E_L+b=A−Q_U is accounting. Delta NFA=CA+VA (plus any empirical other-change/non-equity components) is an accounting closure, not an independent preference FOC. With underlying stocks/transactions/returns already targeted, adding NFA, CA and valuation under multiple labels does not manufacture new rank. They CAN contain additional dynamic empirical information if the primitive time-series flows/returns were previously untargeted; that information enters through the model's dynamics/return moments, not as an extra friction equation. Observed valuation is not an observed bubble; the fundamental/bubble split uses a parameter-dependent pricing kernel and terminal closure.

## 10. Verification and limits

All algebra above was derived from current manuscript and solver equations. A separate synthetic algebra check verifies the wealth reconstruction, safe-spread chi inversion, two-state gamma inversion and Upsilon' zero; it is a formula test, not a model calibration or data estimate. No code/model files were changed.

A lightweight memory lookup located the prior implied-beta diagnostic, then its actual current script was read (lines41–65); all conclusions here rely on current equations rather than a remembered numerical result. No live empirical collection was performed in this subtask.

