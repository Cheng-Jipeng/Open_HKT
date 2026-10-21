# V6 production and technology: identifying moments after eliminating latent knowledge

Prepared 2026-09-29. This is an algebraic identification audit, not an estimate or a new data-access claim. Current parameter definitions, manuscript equations, and the zero-exponent Julia solver were read. No model or solver file was edited. The root confirmed its PDF-create marker before this memo was authored.

## Main conclusions

1. **Neither innovation productivity nor the US spillover exponents intrinsically require observed knowledge stocks.** Binding free entry and the correct post-issuance capitalization timing eliminate their levels and growth. Their empirical route is conditional/model-implied **I**, subject to the payout/research-input bridge; latent `N` alone is not a valid reason to label the route **U**.
2. **The CES weight and augmentation scales have an exact normalization confounding.** For rho different from one, production identifies two effective coefficients, not alpha plus two separate augmentations. More observations do not remove this invariance without a normalization/restriction.
3. **Relative wages alone identify at most the difference between the two spillover exponents.** An absolute output/wage-growth equation supplies the common growth component. Joint identification of rho and the two exponents additionally requires non-collinear changes in input allocation and knowledge growth.
4. **Do not treat AHP net cash flow as incumbent dividends without a bridge.** In V6, net payout `F=D-I=Y-e`. If empirical FCF corresponds to F, it cannot replace D in formulas recovering I; counting F alongside Y and e adds an accounting duplicate.

## Notation and measurement classification

Suppress country/time indices when harmless. `Q=N_{t+1}q_t` is post-entry, ex-dividend capitalization; `D=N_t d_t` is the current incumbent dividend/profit distribution; `I=(1-phi)H w_H` is new-variety funding transferred to researchers. Set `B_H=w_H H`, `B_L=w_L L`, `r=1-phi`, `X=phi H`, `G=N_{t+1}/N_t`, and `e=B_H+B_L`. `Delta log Z_t` means `log Z_{t+1}-log Z_t`; its matching knowledge increment is `log G_t`. Same-date valuation/accounting ratios may use matched nominal values, with the same currency and model-period flow convention. CES level and growth inversions require output and wages in consistent **real final-good units**. Common inflation does not cancel from the absolute wage/output growth equations for xi and nu; an unmatched nominal deflator would masquerade as common technology growth.

**D** means a direct or accurate accounting counterpart after an explicit empirical perimeter; arithmetic does not turn a D moment into I. **I** means a conditional structural construction or qualified proxy. **U** means a required input lacks a credible operational mapping and cannot be eliminated by the maintained equations. An I parameter inversion can use D ingredients. These labels concern the route, not a claim that a parameter itself is directly observed.

| Primitive empirical input | Current status and qualification |
|---|---|
| H,L and exhaustive skill counts/hours | D under a matched age/cohort, sector, country and unit convention; efficiency-unit adjustments are I. |
| Y,e and US operating-asset value Q | D accounting candidates in the existing audit; adoption of V6 production, claim and cohort perimeters still matters. |
| Skill-specific mean compensation w_H,w_L or B_H,B_L | D for genuinely matched means/compensation; corporate scaling of earnings and current RoW wage-level completion are I. Medians cannot be substituted for means. |
| Research share r or research wage bill I | I with existing researcher/task proxies; potentially D if the same skilled population, hours and compensation are actually matched. Generic BERD expenditure includes capital and other inputs. |
| Incumbent D | D/I: gross payout/accounting data exist, but V6 pays operating monopoly profits; retained earnings, taxes, capital costs and financing neutrality require a bridge. AHP FCF may instead be D-I. |
| N or standalone factor-augmentation series | No direct exact variety/augmentation measure; U for a literal direct measurement route, I for an explicitly qualified proxy. Neither is required by the main eliminations below. |
| Observed absorbing-regime data | U until a credible regime rule is supplied; I once a justified classification and matching observations exist. An arbitrary crisis label is not the V6 state. |

## Independent primitive routes and redundant identities

### M08: labor endowments

Use matched `H` and `L` counts/hours directly. Ratios alone identify only relative quantities; choosing H=1 is a scale convention. A common change of labor units changes a inversely while leaving `aH` unchanged. No financial moment determines the absolute labor unit. Four scalar inputs are involved, not four structural regressions.

### M09: innovation productivity without N

With active R&D (`phi<1`), free entry gives `aNq=w_H`. Therefore

\[
Q=GNq=\frac{G}{a}w_H
 =\frac{w_H}{a}+rHw_H=\frac{w_H}{a}+I.
\]

Thus the parsimonious moment and inversion are

\[
\frac{Q}{B_H}-r=\frac1{aH},\qquad
a=\frac{w_H}{Q-I},\qquad
aH=\frac{B_H}{Q-I},\qquad
G=\frac{Q}{Q-I},\quad G-1=\frac{I}{Q-I}.
\tag{A}
\]

No N, per-variety q, patent stock, alpha, rho, spillover exponent, portfolio preference or discount factor is required. Moment ingredients are D/I; recovery of a and G is I because entry/parity/technology are maintained. `Q/B_H-r>0` is an admissibility condition. Recover a only after fixing the units of H and length of a period. A constant-a restriction across time is testable; do not count each algebraic rearrangement as a new independent moment.

There are four genuinely different empirical input routes:

* **Research-labor route:** Q, w_H, H and independently mapped r. Form I=r B_H and apply (A).
* **Entry-funding route:** Q, w_H and independently mapped I. Recover a and G by (A), and recover r=I/B_H if H is available. Raw net equity issuance or IPO proceeds are not automatically V6 I: buybacks, acquisitions, secondary sales, refinancing and issuance by incumbent firms differ.
* **Production-accounting route:** independently matched Q,Y,D,B_H,B_L. Use `I=e+D-Y` and obtain `a=w_H/[Q-e-D+Y]`. This removes the need to observe a research allocation separately. It is I unless the incumbent-dividend and production perimeter is accurate. If empirical D was generated from the same model accounting identity, the construction is circular.
* **Externally fixed markup route:** with theta supplied independently, output exhaustion gives `phi=theta(Y-B_L)/B_H`, `I=B_H-theta(Y-B_L)` and `a=w_H/[Q-B_H+theta(Y-B_L)]`. This eliminates both measured research labor and a separate D series. The primitive inputs are Q,Y,w_H,w_L,H,L, all potentially D under a matched perimeter; phi, I, G and a remain I structural constructions. It is not permissible to use this fitted phi as an independent research-allocation moment or to recover theta from the same static share as if it supplied new information.

There is also a **joint a/theta time-series route**, using their constancy across observations rather than an external theta. Combining the last route with (A) gives

\[
\underbrace{Q_t/w_{H,t}-H}_{y_t}
=\underbrace{1/a}_{c}
-\vartheta\underbrace{(Y_t-B_{L,t})/w_{H,t}}_{x_t}.
\tag{A2}
\]

Two or more independent observations with nonconstant x identify the intercept c and slope -theta algebraically, hence a=1/c, without direct phi, I, D or N. A single observation supplies only the locus `c=y+theta x`. This is a new cross-date restriction from constant a and theta, not a second use of the same static accounting equation. Require c>0, theta in (0,1), interior implied phi, comparable units and constant parameters. If H varies in data, the displayed formula still includes that known H_t, but this changes the fixed-endowment model application and needs an explicit empirical convention. Identification fails when x is constant, at no-entry boundaries, or when Q/Y/wages are generated by imposing the same model. With empirical disturbances, valid estimation and measurement-error treatment are additional requirements; a two-point algebraic slope is not a high-quality econometric estimate.

Two alternative routes should remain visible but are not preferred: an independently mapped knowledge-growth proxy yields `a=(G-1)/(rH)` (I; no literal direct variety-growth series verified), and an independently observed per-variety yield gives `a=(d/q) theta/[(1-theta)phi H]` (U for a literal V6 claim pair). The aggregate dividend-yield version is

\[
\frac{D}{Q}=\frac{aH(1-\vartheta)\varphi}
 {\vartheta[1+aH(1-\varphi)]},\quad
aH=\frac{y}{[(1-\vartheta)/\vartheta]\varphi-y(1-\varphi)},\quad y=D/Q.
\]

It uses D,Q,phi and externally fixed theta, so is an alternative I route when skilled wages are unavailable. It adds no rank if D itself was computed from theta and production wages; when both D and wages are independently observed it is a useful overidentifying restriction.

**Boundary:** at phi=1, I=0 and G=1, but free entry is only `aNq<=w_H`, so `a<=w_H/Q`. Equality cannot be imposed merely to obtain a point estimate. The current numerical production function imposes equality at its strictly interior allocation; the manuscript explicitly permits the no-R&D boundary. At Q close to I, all inversions are ill-conditioned.

### M10: inverse markups

Three empirical routes use different primitives:

\[
\vartheta=1/\mu;
\qquad \vartheta=1-1/\epsilon_{\rm varieties};
\qquad \vartheta=\frac{w_H X}{w_H X+D}.
\tag{B}
\]

Micro price/marginal-cost markups and variety demand elasticities require compatible sector definitions and identification (I); the last formula uses production compensation plus matched incumbent profits (D/I ingredients, I structural interpretation). The final-sector elasticity `1/rho` is NOT the variety elasticity in (B).

The output decomposition eliminates phi, H and w_H from a useful alternative:

\[
\vartheta=1-\frac{D}{Y-B_L},\qquad
\varphi=\frac{Y-B_L-D}{B_H},\qquad
I=e+D-Y.
\tag{C}
\]

Thus independent Y,D and the two skill wage bills jointly recover theta, phi and I. Together with Q and w_H they also recover a via (A). Required inequalities are `0<D<Y-B_L`, `0<Y-B_L-D<=B_H`, `0<=I<Q`. A profit share, a markup and an output residual calculated from those same components are not three identifying moments. If phi is independently measured, (C) instead supplies a test of the production/compensation/payout bridge.

If phi is independently measured but D is not, the alternative is `theta=phi B_H/(Y-B_L)`; this is the output-exhaustion version of (B). If neither phi nor D is measured, (A2) can identify theta jointly with a from time variation. At one date and without an externally fixed theta, output shares alone do not identify it.

### M11, M13 and M15: effective CES coefficients, alpha and augmentation scales

For rho different from one define

\[
C_{X,t}=\alpha A_{X,t}^{1-\rho},\qquad
C_{L,t}=(1-\alpha)A_{L,t}^{1-\rho},\qquad P_t=w_{H,t}/\vartheta.
\]

The factor prices imply the conditional inversions

\[
C_{X,t}=P_t(X_t/Y_t)^\rho,
\qquad C_{L,t}=w_{L,t}(L/Y_t)^\rho.
\tag{D}
\]

An output-plus-share version is

\[
s_{X,t}=\frac{P_tX_t}{Y_t}=1-\frac{w_{L,t}L}{Y_t},\quad
s_{L,t}=\frac{w_{L,t}L}{Y_t},\quad
A_{X,t}=\frac{Y_t}{X_t}(s_{X,t}/\alpha)^{1/(1-\rho)},\quad
A_{L,t}=\frac{Y_t}{L}(s_{L,t}/(1-\alpha))^{1/(1-\rho)}.
\tag{E}
\]

The output-residual definition of s_X can remove a separately fixed theta from (E); it imposes the model's factor exhaustion. Equality of that definition and the observed markup-adjusted skilled compensation is an overidentifying test if both are independently supplied. These are **I conditional constructions from potentially D wages/output/labor**, not a requirement to observe augmentations. Do not count (D) and (E) separately.

There is an exact invariance. For any alpha-prime in (0,1), replace

\[
\bar A'_X=\bar A_X(\alpha/\alpha')^{1/(1-\rho)},\qquad
\bar A'_L=\bar A_L[(1-\alpha)/(1-\alpha')]^{1/(1-\rho)}.
\]

Every output, factor price and financial implication is unchanged. Alpha plus two scales has rank at most two. The same alpha transformation applies simultaneously to both US regimes; adding counterfactual b prices does not remove it. Fix alpha or one declared augmentation restriction before recovering separate scales. If relative augmentation `R_A=A_X/A_L` is independently fixed, one may instead use `alpha/(1-alpha)=(P/w_L)(X/L)^rho R_A^(rho-1)`; with R_A unmeasured this is U as a direct empirical route, or a normalization/scenario rather than evidence.

For u scales, `bar A_X,u=A_X,t/N_t^xi`, `bar A_L,u=A_L,t/N_t^nu`. Set N at a reference date to one and use the constructed relative path below. That supplies scale coordinates, not a measured initial knowledge level. Replacing N by cN rescales these bars by c^(-xi) and c^(-nu); a and exponents are unchanged. For RoW, the current restriction xi_W=0 makes the recovered augmentations constant bars; matched time variation supplies specification checks.

**Cobb-Douglas boundary rho=1:** the formulas with 1/(1-rho) are invalid. Then alpha=s_X is identified from a matched markup-adjusted factor share, but only `A_X^alpha A_L^(1-alpha)` is identified, not two separate augmentations. The current US solver excludes this boundary; the RoW CES routine implements it. Near rho=1, individual augmentation recovery is weak/ill-conditioned.

### M12: substitution curvature and technology controls

The core relative-wage equation is

\[
\log(w_H/w_L)=c+(1-\rho)\log(A_X/A_L)-\rho\log(X/L),
\quad c=\log[\vartheta\alpha/(1-\alpha)].
\tag{F}
\]

1. **Stable relative technology route:** RoW common augmentation growth implies a fixed A_X/A_L even outside the zero-exponent specialization; the same is true within US b. With constant theta and independent variation in X/L, `rho=-Delta log(w_H/w_L)/Delta log(X/L)`. This is I, uses D/I input and wage ingredients, and requires a nonzero denominator. A stationary selected BGP has no input-ratio variation and provides no such estimate. An actual measured b regime is required for the US route.
2. **US u joint route:** let `k_t=log(N_t/N_ref)=sum_{s< t}log G_s`, constructed by (A). Then (F) becomes `log(w_H/w_L)=c_u+(1-rho)(xi-nu)k_t-rho log(X/L)`. Rank of `[1,k_t,log(X/L)]` must be three to separate rho from the relative technology slope. If log phi is exactly affine in k, the two effects are confounded. A trend-controlled skill regression is one maintained approximation, not independent observation of technology. The equivalent log factor-share-odds equation uses the same prices/quantities and does not add rank.
3. **Quantity-only production-curve route:** for constant technology, fit `Y_t^(1-rho)=C_X X_t^(1-rho)+C_L L_t^(1-rho)` jointly for C_X,C_L,rho, using independent output and input variation. At least three informative levels and a full-column-rank nonlinear Jacobian are needed; the observation count alone is insufficient. US u adds `C_X,0 exp[(1-rho)xi k_t]` and `C_L,0 exp[(1-rho)nu k_t]`, so identification is joint with technology slopes and needs corresponding rank. This uses a different set of primitive measurements if wages are unavailable. If X was itself inferred using the same output equation, it is not an independent quantity observation.
4. **External micro/structural substitution estimates:** I after mapping the input margin. Generic K-L estimates do not identify the X=phi H versus unskilled-L margin; treat as a separately labeled analogy.

Allowing unrestricted A_X,t and A_L,t makes any admissible rho fit (D); wage/input variation alone then does not identify rho. The current solver requires rho_US>1; this is a restriction, not evidence. Code line 68 incorrectly calls rho>1 substitutes; the authoritative definition correctly calls it complementarity. No edit made.

### M16: separate spillover exponents without N, alpha or augmentation levels

Construct G by (A). For two successive dates both in u, constant theta, rho different from one and log G different from zero, (D) gives

\[
\boxed{\xi_u=\frac{\Delta\log w_H-\rho\Delta\log(Y/X)}{(1-\rho)\log G}},\qquad
\boxed{\nu_u=\frac{\Delta\log w_L-\rho\Delta\log(Y/L)}{(1-\rho)\log G}}.
\tag{G}
\]

Alpha and level scales cancel. Theta also cancels because it is constant. Neither N0 nor any knowledge/TFP proxy is needed. Alternatively use `Delta log A_X=Delta log(Y/X)+Delta log s_X/(1-rho)` and the analogous L expression; these are the same equations with a different primitive source choice. If rho is externally fixed, a single nonzero knowledge-growth interval gives conditional algebraic recovery; repeated intervals test constant exponents. An observed wage/TFP series constructed by imposing the very exponents being estimated would be circular.

In the external-theta route, insert `X=theta(Y-B_L)/w_H` and `G=Q/[Q-B_H+theta(Y-B_L)]` directly into (G). This reduces the required primitives to output, capitalization, skill compensation and labor quantities, conditional on externally fixed rho and theta. If theta and a are instead identified through (A2), their uncertainty and the generated X,G must enter the joint estimation. The generated input allocation is not an independently measured research moment.

For joint identification, write

\[
\Delta\log w_H=\rho\Delta\log(Y/X)+b_X\log G,
\quad
\Delta\log w_L=\rho\Delta\log(Y/L)+b_L\log G,
\quad b_X=(1-\rho)\xi,\ b_L=(1-\rho)\nu.
\tag{H}
\]

Stacking the two equations identifies three slopes only if the design matrix with columns `(output/input growth, skill-specific knowledge-growth columns)` has rank three. One interval supplies only two equations for three unknowns. Across intervals, rank fails if both output-per-input growth series are proportional to log G, a serious issue near limiting balanced/tail paths. Exponents then trade off with rho. Relative wages alone identify only `(1-rho)(xi-nu)` conditional on rho; retaining an absolute wage/output equation is indispensable. This algebraic rank result is not a claim of valid OLS instruments or causal identification with measurement error/endogenous allocation.

At rho=1 only the aggregate technology-growth combination `alpha xi+(1-alpha)nu` is identified. At G=1 there is no knowledge-growth denominator; within-regime allocation changes may still help identify rho but cannot reveal knowledge elasticities. Crossing u to b invalidates the u growth equations because scale/regime changes intervene. Routes using recovered G and research funding are currently **I**, whereas a literal regression on unobserved exact knowledge and augmentation series remains U. The elimination changes the appropriate route classification.

### M14: US absorbing scales

With a credible observed b regime and fixed alpha,rho, apply (D)-(E); since nu_b=0, the recovered A_X,A_L equal the bars. This is I conditional production recovery, with the same alpha confounding. With only observed u production, no direct b-production moment exists: U for that proposed moment, or a counterfactual scenario. All-u financial prices can in principle discipline b payoffs jointly with probabilities/preferences/frictions, but this is a different full-equilibrium identification exercise; two b scales cannot be declared identified merely because a b price appears in a pricing equation.

### M17: fixed zero exponents

The code imposes nu_b=xi_W=0. These are neither estimated points nor free calibration moments. Test their implications using `Delta log C_X=Delta log C_L=0` within the appropriate observed branch, conditional on rho and the production mapping. A changing phi can change output and wages even when both augmentations are constant; do not test zero technology growth using unadjusted output growth except at a fixed allocation. If reopened in another solver, a common exponent would have to match both recovered augmentation-growth equations divided by log G. Current b aggregate observables are exactly invariant to N levels; per-variety prices/dividends rescale by 1/N. The common-growth equation is the identity 1=1, not an extra identifying restriction.

## Recommended parsimonious moment basis

Use one empirical source for each primitive rather than a long list of mechanically linked ratios:

* Labor quantities H,L (D), skill compensation levels or bills (D/I).
* Same-perimeter Y,Q and **either** matched research funding/share **or** independently matched incumbent D (D/I). With an external theta, neither extra series is essential to the conditional inversion; with informative time variation, (A2) is a joint a/theta alternative.
* One of (A)'s input routes for a; one of (B)-(C)'s routes for theta. Retain other independently measured inputs as validation, not automatically as new rank.
* Conditional CES effective coefficients (D), or an output-only curve, for scale normalization.
* Independent within-regime growth/relative-allocation variation in (F)-(H) for rho,xi,nu. No standalone N or augmentation-level series is required.
* No invented empirical moment for unobserved b scales or imposed zero exponents.

**Do not count separately:** Q/B_H, Q/e and the funding-adjusted HKT equation after e=B_H+B_L; D/Q and d/q after G timing conversion; phi and r; D/profits and output residuals constructed from the same accounts; skill wage premia and factor-share odds; effective CES coefficients and augmentations recovered from them; N's constructed path and its defining growth law; FCF=Y-e and D-I if all are identical accounting inputs.

## Current-source locations

* `V6_parameter_calibration_groups.tex`: M08 lines 58-59; M10 lines 60-61; M12 lines 62-63; M09 lines 75-76; M11 lines 77-78; M13-M17 lines 79-88.
* `AI_drafting/V6_production.tex`: normalized variety technology and monopoly profit lines 330-384; labor and knowledge laws 387-409; Q/D timing 425-436; aggregate dividend formula 438-450; entry complementarity 459-485; income/IPO/output 496-513; regime maps 1506-1535; US CES and generic RoW theory 1744-1758; exact funding/wage identities 1977-2048.
* `Codes/Two_country_proudction_zero_nu_b/TwoCountryProductionOLG.jl`: parameter fields 67-104; restrictions 143-158; CES and Cobb-Douglas limit 198-223; regime maps 231-244; production/wages/q/dividends/IPO 254-282; capitalization timing 480-484; zero-exponent N invariance 578-603. Both countries use CES in this code, though the current manuscript's RoW theorem allows a more general production function.
* `V6_calibration_measurability.tex`: prior empirical mapping assessments M08-M17 lines 80-99; labor/knowledge/research mapping 105-117; output/wages/compensation/claims 129-140. These are source-backed prior data candidates, not new access receipts.

All algebra was derived from these current equations. The accompanying JSON supplies route-level entries and independent numerical spot-check results. A previous memory lookup located the wage-ratio diagnostic; the equations above were reverified against the current manuscript and code, rather than relying on memory.
