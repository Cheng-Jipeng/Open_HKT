# Calibration-Sweep Diagnostic Notebook

## Purpose

For every new calibration or calibration sweep, generate one Jupyter notebook with the four diagnostic sections specified below. The notebook should make it easy to compare calibration cases, identify numerical failures, and assess whether a solved path is approaching the region required for the HKT tail reduction.

Before presenting the four sections, report the min between 80 and **residual-safe, no-buffer horizon** reached by each calibration:

$$
\min \{80, T_{\max}\}.
$$

That is, first check if $T=80$ is residual-safe; if not, then search the largest residual-safe horizon. Plot each calibration only over its min{80, residual-safe horizon}, and report failed or unavailable cases instead of silently dropping them. 

Use consistent colors and line styles across sections. Legends should identify the calibration, country, and path. For a realized switch path, state the switch date $\tau$ and mark it with a vertical line.

## 1. R&D Allocation, Growth, and the U.S. Stock-Funding Identity

### 1.1 Growth-related quantities

For both the all-$u$ path and the realized switch-to-$b$ path, plot

$$
\varphi_{i,t},\qquad
e_{i,t},\qquad
Q_{i,t},\qquad
q_{i,t},\qquad
N_{i,t},
\qquad i\in\{US,W\}.
$$

These are 20 country-path-quantity combinations for each calibration:

$$
2\ \text{paths}
\times 2\ \text{countries}
\times 5\ \text{quantities}
=20.
$$

The plots should reveal how the calibration affects R&D labor allocation, labor income, aggregate equity value, the per-variety equity price, and the number of varieties.

### 1.2 U.S. stock-funding components

Along the all-$u$ path, plot the components

$$
A_t=\frac{s_W e^u_{W,t}}{\beta e^u_{US,t}},
\qquad
B_t=\frac{Q^u_{W,t}}{\beta e^u_{US,t}},
\qquad
\zeta_t=1+A_t-B_t,
$$

and the equivalent ratio representation

$$
m_t=\frac{e^u_{W,t}}{e^u_{US,t}},
\qquad
\mu_t=\frac{Q^u_{W,t}}{e^u_{W,t}},
\qquad
\zeta_t
=1+\frac{m_t}{\beta}(s_W-\mu_t),
$$

where

$$
s_W=\frac{\beta+\chi}{1+\chi}.
$$

## 2. Finite-Prefix Diagnostics for the HKT Tail Reduction

Plot the following quantities over the residual-safe all-$u$ prefix:

$$
\frac{e_{W,t}}{e_{US,t}},
\qquad
\frac{Q_{W,t}}{\beta e_{US,t}},
\qquad
\frac{Q_{W,t}}{\beta e_{W,t}},
\qquad
\frac{Q_{US,t}}{\beta e_{W,t}},
\qquad
\zeta_t=\frac{Q_{US,t}}{\beta e_{US,t}},
$$

together with

$$
\Lambda_t^u,
\qquad
\Lambda_t^b,
\qquad
\frac{\Lambda_t^u}{\Lambda_t^b},
$$

where $b$ indicates the switch-to-b term and

$$
\Lambda_t^z
:=
\frac{R_{A,t}^z}{R_{US,t}^z},
\qquad z\in\{u,b\}.
$$

The purpose of this section is to check whether the finite solved path enters and remains in the U.S.-dominant region required for an asymptotic HKT reduction of the tail. These finite-prefix plots are diagnostics; by themselves, they do not establish that the required inequalities hold over the infinite tail.

## 3. U.S. NFA Moments and VA/CA Decomposition

Decompose the change in U.S. net foreign assets as

$$
\Delta NFA_t
=\Delta FA_t-\Delta FL_t
=VA_t+CA_t,
$$

where the valuation effect is

$$
VA_t
:=
\underbrace{
n_{W,t-1}(q_{W,t}-q_{W,t-1})
}_{\text{capital gain on U.S.-held RoW equity}}
-
\underbrace{
n^*_{US,t-1}(q_{US,t}-q_{US,t-1})
}_{\text{capital gain on foreign-held U.S. equity}},
$$

and the current-account quantity-flow effect is

$$
CA_t
:=
\underbrace{
q_{W,t}(n_{W,t}-n_{W,t-1})
}_{\text{net U.S. purchases of RoW equity}}
-
\underbrace{
q_{US,t}(n^*_{US,t}-n^*_{US,t-1})
}_{\text{net RoW purchases of U.S. equity}}
+
\underbrace{
(b_t-b_{t-1})
}_{\text{change in the U.S. net bond position}}.
$$

Plot:

- $\Delta NFA_t$, $VA_t$, and $CA_t$;
- the asset and liability components of $VA_t$;
- the asset, liability, and bond components of $CA_t$; and
- the underlying positions and prices $n_{W,t}$, $n^*_{US,t}$, $q_{W,t}$, and $q_{US,t}$.

Also report the adding-up residual

$$
\Delta NFA_t-VA_t-CA_t,
$$

which should be numerically negligible.

## 4. U.S. Bubble-Share Bound and Leakage Components

The U.S. bubble share satisfies

$$
\frac{B_{US,t}^u}{q_{US,t}^u}
=
\prod_{s=t+1}^{\infty}\frac{1}{1+a_s}
\le
\prod_{s=t+1}^{T_{\max}}\frac{1}{1+a_s},
$$

provided the omitted-tail leakage terms are nonnegative. Plot the finite-horizon product as a diagnostic upper bound; do not label it as a certified infinite-horizon bubble share without the additional tail conditions required by the theory.

Decompose total leakage as

$$
a_t
=
\underbrace{
\frac{d_t^u}{q_t^u}
}_{\text{dividend leakage}}
+
\underbrace{
\frac{1-\pi}{\pi}
\left(\frac{C_t^u}{C_t^b}\right)^\gamma
\frac{q_t^b+d_t^b}{q_t^u}
}_{\text{switch leakage}}.
$$

Further decompose switch leakage into

$$
\text{switch leakage}
=
\underbrace{
\frac{1-\pi}{\pi}
\left(\frac{C_t^u}{C_t^b}\right)^\gamma
}_{\text{relative state-price/SDF effect}}
\times
\underbrace{
\frac{q_t^b+d_t^b}{q_t^u}
}_{\text{physical payoff-crash effect}}.
$$

Plot:

- the finite-horizon bubble-share upper bound;
- total leakage $a_t$;
- dividend leakage and switch leakage; and
- the state-price/SDF and physical payoff-crash factors.

For long horizons, compute the product in logs to avoid numerical underflow.

## Definition of Done

The notebook is complete when it:

1. reports min{80, the residual-safe, no-buffer $T_{\max}$} for every requested calibration;
2. contains the four numbered diagnostic sections above;
3. compares all successful sweep cases with consistent labeling;
4. reports unsuccessful or unavailable cases explicitly;
5. verifies the $\zeta_t$ identity and the NFA adding-up identity numerically; and
6. clearly distinguishes finite-prefix diagnostics from claims about the infinite tail.
