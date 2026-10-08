# Variables and parameters in `V6_production.tex`

Prepared on 2026-09-22 from the complete [manuscript source][source] (3,015 lines), with the notation macros in `preamble.tex` checked. The source SHA-256 is `5b972aefffff66d48d7f913d093d53f1fdf245bf3a8e53c9ecaa65780c57feb9`.

The classification is for the **two-country general equilibrium**, including the specialized technology and bubble analysis. A quantity taken as given by one household or firm need not be exogenous in general equilibrium. Country and type variants are grouped where their economic roles coincide; branch superscripts and Markov-function versions inherit the classification of the underlying quantity. Proof notation is included separately within the relevant category so that it is not mistaken for an additional calibration input.

| Category | Classification rule |
| --- | --- |
| **Parameters** | Fixed preference, technology, demographic, and transition-law inputs. Composite parameters and mathematical constants used in proofs are identified explicitly; they are not additional independent structural parameters. |
| **Exogenous variables** | Regime realizations and externally supplied initial conditions. Initial knowledge is supplied to the model, whereas subsequent knowledge is an endogenous state. |
| **Endogenous variables** | Equilibrium states, allocations, prices, holdings, returns, and quantities calculated from them. This category includes equilibrium policy functions, accounting identities, and selected balanced-growth values. |

Two classification choices are consequential. First, the manuscript defines **$\mathcal Q_{i,t}=N_{i,t+1}q_{i,t}$**, while **$\mathcal D_{i,t}=N_{i,t}d_{i,t}$**: capitalization values the post-issuance stock supply at the current ex-dividend price. Second, the productivity **maps** $A_{X,i}(\cdot),A_{L,i}(\cdot)$ are primitive functions, but their realized **levels** depend on endogenous knowledge and the exogenous regime. They are therefore listed as derived endogenous quantities, not as independently specified productivity paths.

## 1. Parameters

### 1.1 Primitive scalar and functional parameters

| Symbol | Economic meaning | Definition, restriction, or relationship to other objects | Source |
| --- | --- | --- | --- |
| $H_i$, $i\in\{US,W\}$ | Mass of skilled young agents born each date | Fixed, strictly positive; supplies skilled labor to intermediate production and R&D. | [L300][population] |
| $L_i$ | Mass of unskilled young agents born each date | Fixed, strictly positive; supplies labor to final-good production. A fixed endowment parameter, distinct from leakage $L_t^D,L_t^S$. | [L300][population] |
| $a_i$ | R&D productivity per skilled worker per existing variety | $a_i>0$; one R&D worker creates $a_iN_{i,t}$ new varieties. | [L393][knowledge-law] |
| $\vartheta_i$ | Curvature of the intermediate-variety aggregator; inverse monopoly markup | $0<\vartheta_i<1$; demand elasticity is $1/(1-\vartheta_i)$ and price/wage markup is $1/\vartheta_i$. | [L330][aggregator] |
| $F_i(\cdot,\cdot)$ | Country final-good production technology | Primitive function: continuously differentiable, concave, homogeneous of degree one, with positive partial derivatives. Only the US function is subsequently specialized to CES; the RoW function remains general. | [L319][technology]; [L1744][ces] |
| $A_{X,i}(\cdot),A_{L,i}(\cdot)$ | Primitive state-to-productivity maps | Measurable functions of $s=(z,N_{US},N_W)$. Their functional forms are inputs; evaluating them at an endogenous state produces the levels in Table 3.1. | [L304][state]; [L1506][productivity-maps] |
| $\beta$ | Weight on old-age utility | $0<\beta<1$; US saving rate is $\beta$, while the RoW saving rate is $(\beta+\chi)/(1+\chi)$. | [L522][preferences]; [L609][us-saving]; [L829][row-saving] |
| $\gamma$ | Risk-aversion parameter in the Epstein–Zin aggregator | General portfolio block: $\gamma>0$, $\gamma\ne1$ in the displayed formula. The sufficient bubble theorem additionally requires $0<\gamma<1$. | [L522][preferences]; [L2810][bubble-theorem] |
| $\kappa$ | Intensity of the quadratic equity-share preference penalty | Utility contains $-\kappa(\omega-\bar\omega)^2/2$, with the same coefficient for RoW. The source does not explicitly state a global sign/domain restriction; a nonnegative penalty interpretation is not a separately written assumption. | [L545][us-problem]; [L752][row-problem] |
| $\bar\omega$ | US household target weight on US equity within its equity portfolio | Explicitly restricted to $[1/2,1]$. Distinct from the endogenous actual weight $\omega_t$. | [L571][bond-cost] |
| $\bar\omega^*$ | RoW household target weight on US equity within its equity portfolio | Appears in $-\kappa(\omega^*_{a,t}-\bar\omega^*)^2/2$. The source gives no explicit interval for this target; no restriction such as $\bar\omega^*\le1/2$ is imposed here. | [L752][row-problem] |
| $\eta$ | Intensity of the US bond-share utility cost | Multiplies $\Upsilon(\theta)$; the proof explicitly permits $\eta=0$. A full global domain is not separately stated in the source. | [L545][us-problem]; [L2762][eta-zero] |
| $\Upsilon(\cdot)$ | US bond-share cost function | Primitive differentiable function on $(-\infty,1)$, with $\Upsilon'$ bounded near zero. No global coercivity condition is imposed. $\Upsilon'(\theta_t)$ is its derivative evaluated at an endogenous share. | [L573][bond-cost-assumption] |
| $\chi$ | RoW convenience-utility coefficient for US bonds | $\chi>0$; utility includes $\chi\log(q^B_{US,t}B^*_{US,a,t+1})$. | [L752][row-problem]; [L780][convenience] |
| $\Pi$ | Markov transition matrix for the regime | Primitive probabilities $\Pi(z,z')$. In the specialized two-state model, ordered as $(u,b)$, $\Pi=\begin{pmatrix}\pi&1-\pi\\0&1\end{pmatrix}$. Thus $\Pi$ and $\pi$ are not independent inputs after specialization. | [L304][state]; [L1340][regime] |
| $\pi$ | Probability of remaining in regime $u$ for one more period | $\pi\in(0,1)$; the switch probability is $1-\pi$, and $b$ is absorbing. | [L1340][regime] |
| $\alpha_{US}$ | US CES distribution parameter | $0<\alpha_{US}<1$; $F_{US}(X,L)=[\alpha_{US}X^{1-\rho_{US}}+(1-\alpha_{US})L^{1-\rho_{US}}]^{1/(1-\rho_{US})}$. | [L1744][ces] |
| $\rho_{US}$ | US CES curvature parameter | $\rho_{US}>1$ in the specialized model. In this parameterization the elasticity of substitution is **$1/\rho_{US}$**, not $\rho_{US}$. | [L1744][ces] |
| $\bar A_{X,US,u}$, $\bar A_{L,US,u}$ | US productivity scale coefficients in regime $u$ | Both positive; $A^u_{X,US,t}=\bar A_{X,US,u}(N^u_{US,t})^{\xi_u}$ and $A^u_{L,US,t}=\bar A_{L,US,u}(N^u_{US,t})^{\nu_u}$. | [L1506][productivity-maps] |
| $\bar A_{X,US,b}$, $\bar A_{L,US,b}$ | US productivity scale coefficients in regime $b$ | Both positive; both factor augmentations have knowledge exponent $\nu_b$. | [L1506][productivity-maps] |
| $\bar A_{X,W}$, $\bar A_{L,W}$ | RoW productivity scale coefficients | Both positive and regime-invariant; both factor augmentations have knowledge exponent $\xi_W$. | [L1506][productivity-maps] |
| $\xi_u$ | Knowledge elasticity of US knowledge-input productivity in regime $u$ | Exponent in $A^u_{X,US}=\bar A_{X,US,u}N_{US}^{\xi_u}$; specialized restrictions impose $\xi_u>\nu_u$. | [L1506][productivity-maps] |
| $\nu_u$ | Knowledge elasticity of US unskilled-labor productivity in regime $u$ | Exponent in $A^u_{L,US}=\bar A_{L,US,u}N_{US}^{\nu_u}$; $\nu_u>\nu_b$. | [L1506][productivity-maps] |
| $\nu_b$ | Common knowledge elasticity of both US factor augmentations in regime $b$ | $\nu_b\ge0$ and $\xi_u>\nu_u>\nu_b$ in the sufficient-conditions technology block. | [L1506][productivity-maps] |
| $\xi_W$ | Common knowledge elasticity of both RoW factor augmentations | $\xi_W\ge0$. Regime-invariance of these primitives does not make RoW allocations or prices regime-invariant. | [L1506][productivity-maps] |

### 1.2 Composite parameters and technology functions

These objects are determined by primitive parameters. They should be computed rather than independently calibrated. Constants that summarize a selected equilibrium, even when a closed-form expression is available, are reported with endogenous quantities in Table 3.7.

| Symbol | Meaning | Relationship to more primitive parameters | Source |
| --- | --- | --- | --- |
| $\psi_{US}$ | Exponent governing US relative factor-productivity growth in the CES wage-bill relation | $\psi_{US}=(\xi_u-\nu_u)(\rho_{US}-1)>0$. | [L1527][psi] |
| $K_u$ | Coefficient in the exact US CES wage-bill ratio | $K_u=\dfrac{1-\alpha_{US}}{\vartheta_{US}\alpha_{US}}\left(\dfrac{\bar A_{X,US,u}H_{US}}{\bar A_{L,US,u}L_{US}}\right)^{\rho_{US}-1}$. | [L1799][ku] |
| $D_u$ | Constant in the limiting HKT scalar equation | $D_u=1/(a_{US}H_{US})+1-\beta>0$. This is not a dividend. | [L2305][tail-constants] |
| $G_u$ | Maximum US knowledge-growth factor; attained asymptotically on the selected all-$u$ tail | $G_u=1+a_{US}H_{US}$. The finite-date factor $G_t=1+a_{US}(1-\varphi_t)H_{US}$ is endogenous. | [L2305][tail-constants] |
| $\kappa_D$ | Dividend-leakage decay exponent | $\kappa_D=\psi_{US}/\rho_{US}>0$. Unrelated to the portfolio penalty $\kappa$. | [L2832][leakage-exponents] |
| $\kappa_S$ | Switch-leakage decay exponent associated with US knowledge | $\kappa_S=(\nu_u-\nu_b)(1-\gamma)>0$ under the bubble theorem. | [L2832][leakage-exponents] |
| $B(x)$ | CES output function after dividing by the augmented unskilled-labor input | $B(x)=[\alpha_{US}x^{1-\rho_{US}}+1-\alpha_{US}]^{1/(1-\rho_{US})}$. A technology function; its argument $x_t$ is endogenous. Distinct from bonds and bubbles. | [L1854][ces-proof] |
| $\widehat w_{H,W}(\varphi)$, $\widehat w_{L,W}(\varphi)$ | Normalized RoW wage schedules | $\widehat w_{H,W}(\varphi)=\vartheta_WF_{W,X}(\bar A_{X,W}\varphi H_W,\bar A_{L,W}L_W)\bar A_{X,W}$; $\widehat w_{L,W}(\varphi)=F_{W,L}(\bar A_{X,W}\varphi H_W,\bar A_{L,W}L_W)\bar A_{L,W}$. The schedules follow from primitives; their equilibrium evaluations depend on $\varphi_{W,t}$. | [L1758][normalized-row] |
| $\widehat e_W(\varphi)$ | Normalized RoW young-income schedule | $\widehat e_W(\varphi)=H_W\widehat w_{H,W}(\varphi)+L_W\widehat w_{L,W}(\varphi)$. Its supremum and that of $\widehat w_{H,W}$ are assumed finite. | [L1772][normalized-row-income] |

### 1.3 Auxiliary constants, thresholds, and proof constructions

The following are **mathematical parameters or derived bounds**, not additional economic primitives. Where a constant bounds an equilibrium path, that bound must be established or imposed as a selection condition; naming it does not make the underlying equilibrium variable exogenous.

| Symbol | Role | Definition or relationship | Source |
| --- | --- | --- | --- |
| $c_U$ | Positive lower-bound coefficient for US income | $e^u_{US,t}\ge c_UN_t^{\nu_u}$. The proof constructs a uniform constant using primitives and $N_t\ge N_0>0$. | [L1824][scale-bounds]; [L1893][income-bound-detail] |
| $C_W$ | Upper-bound coefficient for RoW income | $e^u_{W,t}\le C_W(N^u_{W,t})^{\xi_W}$, using the bounded normalized income schedule. | [L1824][scale-bounds] |
| $C_{\mathcal QW}$, $C_{\mathcal DW}$ | Upper-bound coefficients for RoW capitalization and dividends | $\mathcal Q^u_{W,t}\le C_{\mathcal QW}(N^u_{W,t})^{\xi_W}$ and $\mathcal D^u_{W,t}\le C_{\mathcal DW}(N^u_{W,t})^{\xi_W}$. | [L1824][scale-bounds] |
| $C_{\mathcal PW}$ | Uniform coefficient bounding the RoW successor equity payoff | $N_{W,t}(q^z_{W,t}+d^z_{W,t})\le C_{\mathcal PW}N_{W,t}^{\xi_W}$ for $z\in\{u,b\}$. | [L1836][payoff-bound] |
| $C_\zeta$ | Coefficient linking the funding deviation to relative country scale | $\lvert\zeta_t-1\rvert\le C_\zeta r_t$. Follows from country-scale bounds and world capitalization clearing. | [L1843][funding-bound] |
| $N^I$, $\varepsilon^I$ | Thresholds sufficient for active US innovation | $N_t\ge N^I$ and $r_t\le\varepsilon^I$ imply $\varphi_t<1$; these thresholds are constructed from primitives. | [L1945][innovation-threshold] |
| $\bar\varphi_H$ | Chosen upper bound on the production share inside the HKT cone | Chosen in $(0,1)$ small enough that $\Gamma_H<1$. It is not an equilibrium constant production share. | [L2065][gamma-h] |
| $\Gamma_H$ | Upper bound on relative-scale growth inside the HKT cone | $\Gamma_H=\dfrac{(1+a_WH_W)^{\xi_W}}{[1+a_{US}(1-\bar\varphi_H)H_{US}]^{\nu_u}}<1$. | [L2065][gamma-h] |
| $\varepsilon_H$, $N^\dagger$ | Relative-scale and US-knowledge thresholds defining the HKT cone | Chosen with $\varepsilon_H\le\varepsilon^I$, $C_\zeta\varepsilon_H\le1/2$, and $N^\dagger\ge N^I$ sufficiently large to bound $\varphi_t$. | [L2074][cone]; [L2104][cone-proof] |
| $\mathcal C_H$ | Constructed forward-invariant set of knowledge stocks | $\mathcal C_H=\{(N,M)\in\mathbb R_{++}^2:N\ge N^\dagger,\ M^{\xi_W}/N^{\nu_u}\le\varepsilon_H\}$. Here $N,M$ are set coordinates, not pricing kernels. | [L2074][cone] |
| $C_\varphi$ | Coefficient in the production-share upper bound | $C_\varphi=\left[\dfrac{2(1/(a_{US}H_{US})+1)}{\beta K_u}\right]^{1/\rho_{US}}$; $\varphi_t\le C_\varphi N_t^{-\psi_{US}/\rho_{US}}$ inside the cone. | [L2117][phi-bound] |
| $\widehat\varphi$ | Chosen production-share bound for the finite-prefix sufficient condition | Chosen in $(0,1)$ to ensure $\Gamma_{\mathrm{pre}}<1$. Distinct from an observed or solved labor share. | [L2154][prefix] |
| $\Gamma_{\mathrm{pre}}$, $\underline G_{US}$ | Prefix relative-scale contraction bound and US knowledge-growth lower bound | $\underline G_{US}=1+a_{US}(1-\widehat\varphi)H_{US}$; $\Gamma_{\mathrm{pre}}=(1+a_WH_W)^{\xi_W}/\underline G_{US}^{\nu_u}<1$. | [L2154][prefix] |
| $\underline\zeta$, $\underline\omega$ | Lower bounds imposed or verified on finite-prefix equilibrium funding and US equity weight | Require $\zeta_t\ge\underline\zeta>0$; the sufficient portfolio condition is $\omega_t^u\ge\underline\omega>0$. Under that condition one may set $\underline\zeta=\underline\omega$. These are selection/verification constants, not preference targets. | [L2193][prefix-funding]; [L2210][prefix-portfolio] |
| $T_N$, $T_r$, $T^\star$ | Derived sufficient horizons for meeting the cone thresholds | $T_N=\left\lceil\log(N^\dagger/N_0)/\log\underline G_{US}\right\rceil_+$; $T_r=\left\lceil\log(r_0/\varepsilon_H)/(-\log\Gamma_{\mathrm{pre}})\right\rceil_+$; $T^\star=\max\{T_N,T_r\}$. They are proof bounds calculated from thresholds and initial conditions, not independent horizon calibrations. | [L2173][prefix-horizons] |
| $C_{w,b}$, $C_b$ | Uniform US switch-state wage and equity-payoff bounds | $w^b_{H,US,t}\le C_{w,b}N_t^{\nu_b}$ and $q_t^b+d_t^b\le C_bN_t^{\nu_b-1}$. | [L2443][switch-price]; [L2457][switch-wage] |
| $C_D$, $C_S$ | Coefficients bounding the two contributions to total leakage | $a_t\le C_DN_t^{-\kappa_D}+\dfrac{1-\pi}{\pi}C_S[N_t^{-\kappa_S}+r_{t-1}^{1-\gamma}+r_{t-1}]$ eventually. | [L2842][leakage-bound] |
| $\epsilon_0$, $N_0^H$ | Domain thresholds for existence of the interior scalar terminal root | $0<\epsilon_0<1$; require $\lvert\zeta-1\rvert\le\epsilon_0$ and $N\ge N_0^H$. Choose $\beta(1+\epsilon_0)<1/(a_{US}H_{US})+1$. $N_0^H$ is not initial US knowledge $N_0$. | [L2932][terminal]; [L2971][terminal-domain] |
| $C_H$ | Bound on sensitivity of the scalar terminal root to funding | $\lvert\log\varphi^{2C}(N_t,\zeta_t)-\log\varphi^{HKT}(N_t)\rvert\le C_H\lvert\zeta_t-1\rvert$. Distinct from the set $\mathcal C_H$. | [L2944][terminal-gap] |
| $C$ | Generic finite bound used locally in proofs | A placeholder whose value can change across inequalities; it is not a single shared economic parameter. | [L2295][pricing-holder-proof]; [L2620][direct-bound] |

## 2. Exogenous variables and initial conditions

| Symbol | Role | Definition or relationship | Source |
| --- | --- | --- | --- |
| $z_t$ | Exogenous aggregate regime state | $z_t\in\{u,b\}$ with law $\Pi$. In the specialized model $\Pr(z_{t+1}=u\mid z_t=u)=\pi$ and $\Pr(z_{t+1}=b\mid z_t=b)=1$. | [L304][state]; [L1340][regime] |
| $z_0$ | Supplied initial regime | Part of $s_0$. The bubble analysis starts from $z_0=u$. | [L1010][equilibrium]; [L1340][regime] |
| $N_{US,0}$, $N_{W,0}$; $N_0:=N^u_{US,0}$ | Supplied initial knowledge stocks | Strictly positive initial conditions. They are predetermined inputs for an equilibrium path; $N_{i,t}$ at later dates is endogenous through past R&D. | [L1010][equilibrium]; [L1789][tail-aliases]; [L2163][prefix-initial] |
| $s_0$ | Supplied initial aggregate state | $s_0=(z_0,N_{US,0},N_{W,0})\in\mathcal S$. This does not make the entire process $s_t$ exogenous. | [L1010][equilibrium] |
| $r_0$ | Relative real scale at the supplied initial state | $r_0=(N^u_{W,0})^{\xi_W}/N_0^{\nu_u}$; a derived initial condition, not an additional independent input. | [L2163][prefix-initial] |
| $\tau$ | First-switch date; exogenous stopping time in the production application | $\tau=\min\{t\ge1:z_t=b\}$ when $z_0=u$. Section 1 allows a general first-switch environment; the production specialization makes this a function of the exogenous regime history. | [L99][abstract-switch]; [L1340][regime] |
| $\mathbf1_{\{\tau>t\}}$, $\mathbf1_{\{\tau=t\}}$, $\mathbf1_{\{\tau\le T\}}$, $\mathbf1_{\{\tau<\infty\}}$ | Indicators of survival, switching, or eventual switching | Functions of the exogenous regime path. In the specialized model, $\Pr(\tau>t)=\pi^t$ and $\Pr(\tau=t)=\pi^{t-1}(1-\pi)$. The indicators are not additional shocks. | [L99][abstract-switch]; [L196][leakage]; [L1417][branch-leakage-proof] |

The model contains no independently specified labor-income/endowment process $e_{i,t}$, no exogenous risk-free-rate process, and no independent law of motion for the productivity levels once their state maps are given. Initial financial holdings of the young are fixed at zero by the model structure; no separate named initial-wealth state is introduced.

## 3. Endogenous variables

### 3.1 States, production, innovation, income, and equity values

| Symbol | Economic meaning and role | Definition or relationship to more primitive quantities | Source |
| --- | --- | --- | --- |
| $N_{i,t}$; $N_t:=N^u_{US,t}$ | Knowledge stock / measure of incumbent varieties; endogenous predetermined state | $N_{i,t+1}=[1+a_i(1-\varphi_{i,t})H_i]N_{i,t}$. At a given date it is inherited, but its path is determined by equilibrium R&D. | [L393][knowledge-law]; [L1789][tail-aliases] |
| $s_t$, $s$ | Aggregate state, containing endogenous and exogenous components | $s_t=(z_t,N_{US,t},N_{W,t})$. Classified here as a mixed state vector, not as a wholly exogenous process. | [L304][state] |
| $A_{X,i,t}$, $A_{L,i,t}$; $A^z_{X,i,t}$, $A^z_{L,i,t}$ | Realized factor-augmenting productivities; technologically determined endogenous levels | $A_{X,i,t}=A_{X,i}(s_t)$ and $A_{L,i,t}=A_{L,i}(s_t)$. Under specialization: US $u$ exponents $(\xi_u,\nu_u)$, US $b$ exponents $(\nu_b,\nu_b)$, and RoW exponents $(\xi_W,\xi_W)$, multiplied by the corresponding $\bar A$ coefficients. | [L304][state]; [L1506][productivity-maps] |
| $\varphi_{i,t}$, $\varphi_i(s)$; $\varphi_t:=\varphi^u_{US,t}$ | Skilled-labor share in intermediate production; equilibrium allocation | $0<\varphi_{i,t}\le1$. The R&D share is $1-\varphi_{i,t}$; the production and research labor masses are $\varphi_{i,t}H_i$ and $(1-\varphi_{i,t})H_i$. Determined jointly by free-entry complementarity and equilibrium funding. | [L391][labor-share]; [L459][free-entry] |
| $X_{i,t}$, $X_i(s)$ | Quantity of the knowledge-intensive input | $X_{i,t}=N_{i,t}x_{i,t}=\varphi_{i,t}H_i$ in symmetric equilibrium; its primitive aggregator is the normalized continuum CES expression. | [L330][aggregator]; [L387][x-clearing] |
| $x_{i,t}(j)$, $x_{i,t}$ | Output and skilled-labor input of an individual intermediate firm | Symmetry gives $x_{i,t}(j)=x_{i,t}=X_{i,t}/N_{i,t}$. Individual demand is $x_{i,t}(j)=(X_{i,t}/N_{i,t})[p_{i,t}(j)/P_{i,t}]^{-1/(1-\vartheta_i)}$. | [L340][symmetry] |
| $p_{i,t}(j)$; local choice $p$ | Intermediate variety price | $p_{i,t}(j)=w_{H,i,t}/\vartheta_i$. Under symmetry and the aggregator normalization this also equals $P_{i,t}$. | [L340][symmetry]; [L403][factor-prices] |
| $Y_{i,t}$, $Y_i(s)$ | Final-good output | $Y_{i,t}=F_i(A_{X,i,t}X_{i,t},A_{L,i,t}L_i)=e_{i,t}+\mathcal D_{i,t}-\mathcal I_{i,t}$. | [L325][output]; [L508][output-identity] |
| $F_{i,X,t}$, $F_{i,L,t}$ | Marginal products evaluated at the equilibrium effective inputs | Partial derivatives of primitive $F_i$ at $(A_{X,i,t}X_{i,t},A_{L,i,t}L_i)$. The functions $F_{i,X},F_{i,L}$ follow from technology; their evaluated values depend on the state and allocation. | [L403][factor-prices] |
| $P_{i,t}$, $P_i(s)$ | Price of the knowledge-intensive composite good | $P_{i,t}=F_{i,X,t}A_{X,i,t}$. | [L403][factor-prices] |
| $w_{H,i,t}$, $w_{L,i,t}$, $w_{a,i,t}$ | Skilled wage, unskilled wage, and type-specific young income | $w_{H,i,t}=\vartheta_iF_{i,X,t}A_{X,i,t}$; $w_{L,i,t}=F_{i,L,t}A_{L,i,t}$; $w_{a,i,t}$ selects $H$ or $L$. R&D workers receive the same skilled income through entry revenues when R&D is active. | [L403][factor-prices]; [L496][income] |
| $q_{i,t}(j)$, $q_{i,t}$, $q_i(s)$ | Ex-dividend price of one firm-level equity claim | Identical claims have $q_{i,t}(j)=q_{i,t}$. Free entry implies $q_{i,t}\le w_{H,i,t}/(a_iN_{i,t})$, with equality **only when $\varphi_{i,t}<1$**. At zero R&D, equity-market conditions and the inequality jointly determine price. | [L412][equity-price]; [L459][free-entry]; [L1134][no-rd] |
| $d_{i,t}(j)$, $d_{i,t}$, $d_i(s)$ | Dividend / monopoly profit per incumbent variety | $d_{i,t}(j)=d_{i,t}=\dfrac{1-\vartheta_i}{\vartheta_i}w_{H,i,t}x_{i,t}=\dfrac{1-\vartheta_i}{\vartheta_i}w_{H,i,t}\dfrac{\varphi_{i,t}H_i}{N_{i,t}}$. | [L438][dividends] |
| $\mathcal Q_{i,t}$, $\mathcal Q_i(s)$ | Country equity-market capitalization after current issuance | **$\mathcal Q_{i,t}=N_{i,t+1}q_{i,t}$**. It is an aggregate accounting value, not the primitive per-variety price and not $N_{i,t+1}q_{i,t+1}$. | [L427][stock-aggregation] |
| $\mathcal D_{i,t}$, $\mathcal D_i(s)$ | Aggregate dividends paid by incumbent firms | $\mathcal D_{i,t}=N_{i,t}d_{i,t}=\dfrac{1-\vartheta_i}{\vartheta_i}w_{H,i,t}X_{i,t}$. | [L427][stock-aggregation]; [L445][aggregate-dividends] |
| $e_{i,t}$, $e_i(s)$ | Aggregate young-agent budget income | $e_{i,t}=H_iw_{H,i,t}+L_iw_{L,i,t}$. Endogenous labor/IPO income; it is not an exogenous endowment and generally differs from $Y_{i,t}$. | [L496][income] |
| $\mathcal I_{i,t}$ | IPO transfer to current R&D workers | $\mathcal I_{i,t}=(1-\varphi_{i,t})H_iw_{H,i,t}=(N_{i,t+1}-N_{i,t})q_{i,t}$. Complementarity supports this identity also at zero R&D, when both sides are zero. | [L502][ipo] |
| $d_{i,t}/q_{i,t}$ | Per-variety dividend yield | When R&D is active, $d_{i,t}/q_{i,t}=a_i(1-\vartheta_i)\varphi_{i,t}H_i/\vartheta_i$. At the zero-R&D boundary use the ratio of equilibrium dividend and price directly. | [L477][yield] |
| $\mathcal D_{i,t}/\mathcal Q_{i,t}$ | Aggregate dividend yield | $\mathcal D_{i,t}/\mathcal Q_{i,t}=(N_{i,t}/N_{i,t+1})(d_{i,t}/q_{i,t})$; differs from the per-variety yield because current capitalization includes newly issued claims. | [L488][aggregate-yield] |
| $A_{X,i,t}/A_{L,i,t}$, $w_{L,i,t}/w_{H,i,t}$, $L_iw_{L,i,t}/(H_iw_{H,i,t})$ | Derived relative productivity, wage, and wage-bill quantities | All are ratios of the preceding objects. In US regime $u$, $A_X/A_L=(\bar A_{X,US,u}/\bar A_{L,US,u})N_t^{\xi_u-\nu_u}$ and $L_{US}w^u_{L,US,t}/(H_{US}w^u_{H,US,t})=K_uN_t^{\psi_{US}}\varphi_t^{\rho_{US}}$. | [L1506][productivity-maps]; [L1982][wage-bill] |

### 3.2 Household choices and their aggregation

An asterisk identifies the **RoW investor**, whereas the subscript $US$ or $W$ on an asset identifies its **issuer**. Thus $n^*_{US,t}$ is RoW ownership of US equity. Aggregate quantities sum per-agent choices using the corresponding country masses $H_i,L_i$.

| Symbol | Economic meaning and role | Definition or relationship to more primitive quantities | Source |
| --- | --- | --- | --- |
| $c_{y,a,t}$, $c^*_{y,a,t}$ | Young consumption of a US or RoW type-$a$ agent | $c_{y,a,t}=(1-\beta)w_{a,US,t}$; $c^*_{y,a,t}=\dfrac{1-\beta}{1+\chi}w_{a,W,t}$. | [L602][type-saving]; [L829][row-saving] |
| $c_{o,a,t+1}$, $c^*_{o,a,t+1}$ | Old consumption of the agent born at $t$ | US: $(q_{US,t+1}+d_{US,t+1})n_{US,a,t}+(q_{W,t+1}+d_{W,t+1})n_{W,a,t}+B_{a,t+1}$. RoW: the same equity-payoff formula using starred holdings, plus $B^*_{US,a,t+1}+B^*_{W,a,t+1}$. Each must be strictly positive in every successor state. | [L553][us-budgets]; [L761][row-budgets] |
| $n_{US,a,t}$, $n_{W,a,t}$ | US type-$a$ holdings of each country's firm-level equity claims | Nonnegative quantities purchased at $t$; values sum to $S_{a,t}$. They are measures of claims, not ownership fractions or equity-market values. | [L532][us-portfolio] |
| $n^*_{US,a,t}$, $n^*_{W,a,t}$ | RoW type-$a$ holdings of each country's equity claims | Nonnegative; values sum to $S^*_{a,t}$. | [L740][row-portfolio] |
| $B_{a,t+1}$ | US type-$a$ position in the US one-period bond, measured by its date-$(t+1)$ payoff | May be negative subject to budgets and positive successor consumption; present value is $b_{a,t}=q^B_{US,t}B_{a,t+1}$. | [L540][us-choices]; [L577][type-bond] |
| $B^*_{US,a,t+1}$, $B^*_{W,a,t+1}$ | RoW type-$a$ bond positions | The convenience term requires $B^*_{US,a,t+1}>0$; the RoW bond has no such convenience term. | [L748][row-choices]; [L752][row-problem] |
| $S_{a,t}$, $S^*_{a,t}$ | Type-level total equity investment at purchase prices | $S_{a,t}=q_{US,t}n_{US,a,t}+q_{W,t}n_{W,a,t}$; $S^*_{a,t}=q_{US,t}n^*_{US,a,t}+q_{W,t}n^*_{W,a,t}$. | [L532][us-portfolio]; [L740][row-portfolio] |
| $b_{a,t}$ | Present value of the US type-$a$ bond position | $b_{a,t}=q^B_{US,t}B_{a,t+1}$. | [L577][type-bond] |
| $A_{a,t}$, $A^*_{a,t}$ | Type-level total saving, including bonds | $A_{a,t}=S_{a,t}+b_{a,t}=\beta w_{a,US,t}$; $A^*_{a,t}=S^*_{a,t}+q^B_{US,t}B^*_{US,a,t+1}+q^B_{W,t}B^*_{W,a,t+1}=\dfrac{\beta+\chi}{1+\chi}w_{a,W,t}$. | [L577][type-bond]; [L602][type-saving]; [L829][row-saving] |
| $\omega_{a,t}$, $\omega^*_{a,t}$; $\omega_t$, $\omega_t^*$ | Share of equity investment allocated to US equity | $\omega_{a,t}=q_{US,t}n_{US,a,t}/S_{a,t}$; starred analogue for RoW. Homogeneity gives common shares across types in each country: $\omega_{a,t}=\omega_t$, $\omega^*_{a,t}=\omega_t^*$. Both lie in $[0,1]$. | [L532][us-portfolio]; [L596][common-shares]; [L740][row-portfolio] |
| $\theta_{a,t}$; $\theta_t$ | US bond share of total saving | $\theta_{a,t}=b_{a,t}/A_{a,t}=\theta_t$. After market clearing, $\theta_t=-\theta^*_{US,t}A_t^*/A_t<0$. This is a financing share, not the production share $\varphi_{i,t}$. | [L577][type-bond]; [L918][theta-sign]; [L1082][eliminated-shares] |
| $x_{US,a,t}$, $x_{W,a,t}$ | US type-$a$ equity positions measured in current value | $x_{US,a,t}=q_{US,t}n_{US,a,t}$; $x_{W,a,t}=q_{W,t}n_{W,a,t}$; $A_{a,t}=x_{US,a,t}+x_{W,a,t}+b_{a,t}$. Distinct from intermediate-good quantities. | [L666][stock-values] |
| $n_{US,t}$, $n_{W,t}$ | Aggregate US holdings of each country's equity | $n_{i,t}=H_{US}n_{i,H,t}+L_{US}n_{i,L,t}$. Value shares imply $q_{US,t}n_{US,t}=\omega_tS_t$ and $q_{W,t}n_{W,t}=(1-\omega_t)S_t$. | [L614][us-holdings] |
| $n^*_{US,t}$, $n^*_{W,t}$ | Aggregate RoW holdings of each country's equity | $n^*_{i,t}=H_Wn^*_{i,H,t}+L_Wn^*_{i,L,t}$. Equity clearing: $n_{i,t}+n^*_{i,t}=N_{i,t+1}$. | [L782][row-holdings]; [L894][stock-clearing] |
| $B_{US,t+1}$ | Aggregate US position in US bonds | $B_{US,t+1}=H_{US}B_{H,t+1}+L_{US}B_{L,t+1}=-B^*_{US,t+1}<0$. This is the bond quantity; $B_{US,t}$ is also reused elsewhere for a stock bubble. | [L614][us-holdings]; [L903][bond-clearing] |
| $B^*_{US,t+1}$, $B^*_{W,t+1}$ | Aggregate RoW bond positions | $B^*_{i,t+1}=H_WB^*_{i,H,t+1}+L_WB^*_{i,L,t+1}$. Clearing gives $B^*_{US,t+1}=-B_{US,t+1}>0$ and $B^*_{W,t+1}=0$. Zero is an equilibrium restriction, not an exogenous bond demand. | [L788][row-bonds]; [L903][bond-clearing] |
| $b_t$, $b^*_{US,t}$, $b^*_{W,t}$ | Aggregate bond positions at present value | $b_t=q^B_{US,t}B_{US,t+1}$; $b^*_{US,t}=q^B_{US,t}B^*_{US,t+1}$; $b^*_{W,t}=q^B_{W,t}B^*_{W,t+1}$. Clearing gives $b_t+b^*_{US,t}=0$, $b^*_{W,t}=0$. | [L622][us-values]; [L793][row-values]; [L910][pv-clearing] |
| $A_t$, $A_t^*$; $A(s)$, $A^*(s)$ | Aggregate total saving | $A_t=H_{US}A_{H,t}+L_{US}A_{L,t}=\beta e_{US,t}$; $A_t^*=\dfrac{\beta+\chi}{1+\chi}e_{W,t}$. Here $A_{L,t}$ denotes an unskilled US agent's saving, not labor-augmenting productivity. | [L609][us-saving]; [L829][row-saving] |
| $S_t$, $S_t^*$; $S(s)$, $S^*(s)$ | Aggregate equity investment by US and RoW investors | $S_t=(1-\theta_t)A_t=q_{US,t}n_{US,t}+q_{W,t}n_{W,t}$; $S_t^*=(1-\theta^*_{US,t}-\theta^*_{W,t})A_t^*=q_{US,t}n^*_{US,t}+q_{W,t}n^*_{W,t}$. | [L622][us-values]; [L793][row-values] |
| $\theta^*_{US,t}$, $\theta^*_{W,t}$ | RoW bond shares of total saving | $\theta^*_{US,t}=b^*_{US,t}/A_t^*$ and $\theta^*_{W,t}=b^*_{W,t}/A_t^*$. The reduced-system domain has $0<\theta^*_{US,t}<1$, and clearing imposes $\theta^*_{W,t}=0$. Common across RoW types. | [L782][row-holdings]; [L801][row-shares]; [L1136][reduced-domain] |
| $C_{y,t}$, $C^*_{y,t}$ | Aggregate young consumption | $C_{y,t}=H_{US}c_{y,H,t}+L_{US}c_{y,L,t}=(1-\beta)e_{US,t}$; $C^*_{y,t}=H_Wc^*_{y,H,t}+L_Wc^*_{y,L,t}=\dfrac{1-\beta}{1+\chi}e_{W,t}$. | [L609][us-saving]; [L829][row-saving] |
| $C_{o,t+1}$, $C^*_{o,t+1}$; $C_{o,t}$, $C^*_{o,t}$ | Aggregate old consumption | $C_{o,t+1}=A_tR_{A,t+1}$; $C^*_{o,t+1}=A_t^*R^*_{A,t+1}$. The date-$t$ versions refer to the preceding cohort. | [L628][old-consumption]; [L814][row-returns]; [L953][goods-clearing] |
| $U^*_{a,t}$ | RoW type-$a$ lifetime utility attained at a feasible portfolio and consumption choice | $(1-\beta)\log c^*_{y,a,t}+\dfrac{\beta}{1-\gamma}\log E_t[(c^*_{o,a,t+1})^{1-\gamma}]-\dfrac{\kappa}{2}(\omega^*_{a,t}-\bar\omega^*)^2+\chi\log(q^B_{US,t}B^*_{US,a,t+1})$. Its coefficients are primitive; its value is endogenous. | [L752][row-problem] |

### 3.3 Asset returns, pricing kernels, and preference wedges

| Symbol | Meaning and role | Definition or relationship | Source |
| --- | --- | --- | --- |
| $q^B_{US,t}$, $q^B_{W,t}$ | Prices of one-period bonds paying one unit next period | $q^B_{US,t}=1/R_{f,t}$; $q^B_{W,t}=1/R^W_{f,t}$. Their prices are determined by household Euler equations and market clearing. | [L532][us-portfolio]; [L740][row-portfolio]; [L884][bond-pricing] |
| $R_{f,t}$, $R^W_{f,t}$; $R_f(s)$, $R_f^W(s)$ | US and RoW gross risk-free bond returns | Equilibrium unknowns, known when portfolios are chosen at $t$; not exogenous policy rates. RoW convenience utility gives $q^B_{US,t}>q^B_{W,t}$, hence $R_{f,t}<R^W_{f,t}$. | [L884][bond-pricing]; [L1096][reduced-vector] |
| $R_{i,t+1}$; $R_i(s,z')$ | Gross return on a per-variety equity claim | $R_{i,t+1}=(q_{i,t+1}+d_{i,t+1})/q_{i,t}$; $R_i(s,z')=[q_i(\Gamma(s,z'))+d_i(\Gamma(s,z'))]/q_i(s)$. No variety-growth factor is inserted into the return on one existing claim. | [L585][stock-returns]; [L999][recursive-returns] |
| $R_{p,a,t+1}$, $R_{p,t+1}$ | US type-level and common equity-portfolio gross return | $R_{p,a,t+1}=\omega_{a,t}R_{US,t+1}+(1-\omega_{a,t})R_{W,t+1}=R_{p,t+1}$. | [L590][us-returns] |
| $R_{A,a,t+1}$, $R_{A,t+1}$ | US type-level and common gross return on total saving | $R_{A,a,t+1}=(1-\theta_{a,t})R_{p,a,t+1}+\theta_{a,t}R_{f,t}=R_{A,t+1}$. Negative $\theta_t$ represents bond-financed equity investment. | [L590][us-returns] |
| $R^*_{p,t+1}$ | RoW equity-portfolio gross return | $R^*_{p,t+1}=\omega_t^*R_{US,t+1}+(1-\omega_t^*)R_{W,t+1}$. | [L814][row-returns] |
| $R^*_{A,t+1}$ | RoW gross return on total saving | $R^*_{A,t+1}=(1-\theta^*_{US,t}-\theta^*_{W,t})R^*_{p,t+1}+\theta^*_{US,t}R_{f,t}+\theta^*_{W,t}R^W_{f,t}$; the last term is zero in equilibrium. | [L814][row-returns] |
| $M_{t,t+1}$; $M(s,z';x)$ | Undistorted US stochastic discount factor | $M_{t,t+1}=R_{A,t+1}^{-\gamma}/E_t[R_{A,t+1}^{1-\gamma}]$. It depends on endogenous saving returns and the primitive transition law. | [L630][us-sdf]; [L1261][markov-sdfs] |
| $M^*_{t,t+1}$; $M^*(s,z';x)$ | Undistorted RoW stochastic discount factor | $M^*_{t,t+1}=\dfrac{\beta}{1-\beta}\dfrac{C^*_{y,t}(C^*_{o,t+1})^{-\gamma}}{E_t[(C^*_{o,t+1})^{1-\gamma}]}=\dfrac{\beta}{\beta+\chi}\dfrac{(R^*_{A,t+1})^{-\gamma}}{E_t[(R^*_{A,t+1})^{1-\gamma}]}$. | [L835][row-sdf]; [L1261][markov-sdfs] |
| $\tilde M^*_{t,t+1}$; $\tilde M^*(s,z';x)$ | Normalized RoW kernel used in share FOCs | $\tilde M^*_{t,t+1}=\dfrac{\beta+\chi}{\beta}M^*_{t,t+1}=\dfrac{(R^*_{A,t+1})^{-\gamma}}{E_t[(R^*_{A,t+1})^{1-\gamma}]}$. This is not identical to the undistorted RoW SDF when $\chi>0$. | [L835][row-sdf] |
| $\phi_t$ | US equity-share preference wedge | $\phi_t=\dfrac{\kappa}{\beta(1-\theta_t)}(\omega_t-\bar\omega)$. Distinct from production share $\varphi_{i,t}$. | [L655][wedges] |
| $\lambda_t$ | US bond-share wedge in stock pricing | $\lambda_t=\dfrac{\eta\theta_t}{\beta}\Upsilon'(\theta_t)$. | [L655][wedges] |
| $\Psi_t$ | US effective-equity-kernel normalization | $\Psi_t=1-\lambda_t+\phi_t(1-\omega_t)=E_t[M_{t,t+1}R_{US,t+1}]>0$ when the US pricing holder has a positive US-stock position. | [L698][psi-wedge] |
| $\mathcal M_{t,t+1}$ | Effective kernel pricing US equity | $\mathcal M_{t,t+1}=M_{t,t+1}/\Psi_t$. The generic kernel of Section 1 is held fixed for that characterization; in the production application it is this derived equilibrium object. The pricing equality requires a positive pricing-holder position. | [L722][effective-kernel]; [L38][generic-pricing] |
| $\phi_t^*$ | RoW equity-share preference wedge | $\phi_t^*=\dfrac{\kappa C^*_{y,t}}{(1-\beta)S_t^*}(\omega_t^*-\bar\omega^*)$. | [L876][row-effective] |
| $\mathcal M^{*,US}_{t,t+1}$, $\mathcal M^{*,W}_{t,t+1}$ | RoW effective kernels for each country's equity | $\mathcal M^{*,US}=M^*/[1+\phi_t^*(1-\omega_t^*)]$; $\mathcal M^{*,W}=M^*/[1-\phi_t^*\omega_t^*]$. Their stock-pricing equalities apply at positive holdings; a zero holding instead satisfies its KKT inequality. | [L868][row-stock-pricing]; [L876][row-effective] |
| $\mathcal M_{0,t}$, $\mathcal M_{t,T}$, $\mathcal M_{\tau,T}$; $\mathcal M^u_{0,t-1}$ | Products of sequential effective pricing kernels | $\mathcal M_{0,t}=\prod_{s=1}^t\mathcal M_{s-1,s}$; $\mathcal M_{t,T}=\prod_{s=t+1}^T\mathcal M_{s-1,s}$; $\mathcal M^u_{0,t-1}=\prod_{j=0}^{t-2}\mathcal M^u_{j,j+1}$. Empty products equal one, including $\mathcal M_{0,0}=1$. | [L60][kernel-products]; [L1392][branch-kernel-product] |

### 3.4 International accounting, fundamental values, and bubbles

| Symbol | Meaning and role | Definition or relationship | Source |
| --- | --- | --- | --- |
| $NFA_t$ | US net foreign assets at post-trade date-$t$ values | $NFA_t=q_{W,t}n_{W,t}+q^B_{US,t}B_{US,t+1}-q_{US,t}n^*_{US,t}$. US equity owned by RoW enters as a liability. | [L1285][nfa] |
| $VA_t$ | Equity-price valuation component of the change in US NFA | $VA_t=n_{W,t-1}(q_{W,t}-q_{W,t-1})-n^*_{US,t-1}(q_{US,t}-q_{US,t-1})$. Uses beginning-of-period holdings. | [L1300][valuation] |
| $CA_t$ | Current account defined consistently with the manuscript's valuation convention | $CA_t=NFA_t-NFA_{t-1}-VA_t$. The source defines it as the residual non-valuation change; it does not supply a separate primitive current-account process. | [L1307][current-account] |
| $q_t$, $d_t$ in Section 1 | Generic long-lived-claim price and dividend | In the production application these correspond to the US per-variety $q_{US,t},d_{US,t}$. They are equilibrium price/payoff objects; Section 1 itself abstracts from their economic determination. | [L38][generic-pricing]; [L1362][branch-objects] |
| $V_t$ | Fundamental value of the generic claim under the selected kernel | $V_t=E_t[\sum_{s=1}^{\infty}\mathcal M_{t,t+s}d_{t+s}]$. This value is kernel-relative. | [L78][fundamental] |
| $B_t$ in Section 1; $B_0$; $B_{US,t}$ in the aggregation bridge | Per-variety rational bubble | $B_t=q_t-V_t=\lim_{T\to\infty}E_t[\mathcal M_{t,T}q_T]$. $B_{US,t}$ is the US specialization. Distinct from bond face values and the locally redefined return $B_t$ in Table 3.8. | [L78][fundamental]; [L1323][aggregate-bubble] |
| $\mathcal B_t$; $\mathcal B_0$ | Date-0 discounted value of the claim restricted to surviving histories | $\mathcal B_t=E_0[\mathcal M_{0,t}q_t\mathbf1_{\{\tau>t\}}]$. Since $\tau\ge1$, $\mathcal B_0=q_0$. Under switched-history transversality $B_0=\lim_t\mathcal B_t$. | [L196][leakage] |
| $L_t^D$ in Section 1 | Date-0 discounted dividend leakage on surviving histories | $L_t^D=E_0[\mathcal M_{0,t}d_t\mathbf1_{\{\tau>t\}}]$. In the specialized model $L_t^D/\mathcal B_t=d_t^u/q_t^u$. | [L196][leakage]; [L1417][branch-leakage-proof] |
| $L_t^S$ in Section 1 | Date-0 discounted first-switch payoff leakage | $L_t^S=E_0[\mathcal M_{0,t}(q_t+d_t)\mathbf1_{\{\tau=t\}}]$. This is not the dimensionless quantity later given the same symbol in the direct-leakage proof. | [L196][leakage] |
| $a_t$ | Total leakage relative to the surviving discounted value | $a_t=(L_t^D+L_t^S)/\mathcal B_t$. In the production specialization: $a_t=d_t^u/q_t^u+\dfrac{1-\pi}{\pi}(C_t^u/C_t^b)^\gamma(q_t^b+d_t^b)/q_t^u$. Distinct from R&D productivity $a_i$. | [L196][leakage]; [L1403][branch-leakage]; [L2907][total-leakage] |
| $\mathcal B^{\mathrm{agg}}_{US,t}$ | Aggregate US stock bubble under the selected effective kernel | $\mathcal B^{\mathrm{agg}}_{US,t}=N_{US,t+1}B_{US,t}$. Different from the surviving terminal-value object $\mathcal B_t$. | [L1323][aggregate-bubble] |

### 3.5 Markov representations and reduced equilibrium system

These are functions or vectors of the variables above, not additional independent unknowns beyond the model's equilibrium system.

| Symbol | Meaning and role | Definition or relationship | Source |
| --- | --- | --- | --- |
| $\Gamma(s,z')$ | Endogenous full-state transition map | $\Gamma(s,z')=(z',[1+a_{US}(1-\varphi_{US}(s))H_{US}]N_{US},[1+a_W(1-\varphi_W(s))H_W]N_W)$; $s_{t+1}=\Gamma(s_t,z_{t+1})$. Only the regime transition law is exogenous. | [L973][state-transition] |
| $N_i^+(s,\varphi_i)$, $N_i^+(s,x)$, $N_i^+(s)$ | Post-issuance supply of country-$i$ claims | $N_i^+=[1+a_i(1-\varphi_i)H_i]N_i$, evaluated at a candidate or equilibrium production share. Equivalent to $N_{i,t+1}$ on a realized path. | [L989][next-knowledge] |
| $\mathcal P(s)$ | Vector of price functions | $\mathcal P(s)=\{P_i(s),w_{H,i}(s),w_{L,i}(s),q_i(s)\}_{i\in\{US,W\}}$. Bond returns are listed separately in the equilibrium definition. | [L1010][equilibrium] |
| $x(s)$; candidate vector $x$ | Reduced vector of equilibrium allocations and bond returns | $x(s)=(\varphi_{US}(s),\varphi_W(s),\omega(s),\theta_{US}^*(s),\omega^*(s),R_f(s),R_f^W(s))$. The first five are allocation/share choices; the last two are equilibrium returns. | [L1096][reduced-vector] |
| $X_i(s,\varphi_i)$, $w_{H,i}(s,\varphi_i)$, $q_i(s,\varphi_i)$, $d_i(s,\varphi_i)$ | Production and price formulas evaluated at a candidate labor allocation | Same definitions as Table 3.1. In particular, $q_i(s,\varphi_i)=w_{H,i}(s,\varphi_i)/(a_iN_i)$ is the **active-R&D substitution**, not an unconditional formula at $\varphi_i=1$. | [L1108][reduced-production] |
| $A(s,x)$, $A^*(s,x)$, $S(s,x)$, $S^*(s,x)$ | Candidate aggregate saving and equity-investment values | $A=\beta e_{US}(s,\varphi_{US})$; $A^*=\dfrac{\beta+\chi}{1+\chi}e_W(s,\varphi_W)$; $\theta=-\theta^*_{US}A^*/A$; $S=(1-\theta)A$; $S^*=(1-\theta^*_{US})A^*$ after eliminating $\theta_W^*=0$. | [L1145][candidate-saving] |
| $\widehat{\mathcal Q}_{US}(s,x)$, $\widehat{\mathcal Q}_W(s,x)$ | Capitalizations implied by candidate equity demand | $\widehat{\mathcal Q}_{US}=\omega S+\omega^*S^*$; $\widehat{\mathcal Q}_W=(1-\omega)S+(1-\omega^*)S^*$. At an equilibrium these equal $N_i^+q_i=\mathcal Q_i$. The hat indicates a candidate demand value, not a separate asset price. | [L1165][candidate-capitalization] |
| $G_{US}(s,x)$, $G_W(s,x)$ | Equity-share optimality residuals | $G_{US}=\beta(1-\theta)E_s[M(R_{US}-R_W)]-\kappa(\omega-\bar\omega)$; $G_W=\beta(1-\theta^*_{US})E_s[\tilde M^*(R_{US}-R_W)]-\kappa(\omega^*-\bar\omega^*)$. Residual is zero at an interior share, $\le0$ at zero, and $\ge0$ at one. | [L1199][equity-residuals] |
| $R_p(s,z';x)$, $R_p^*(s,z';x)$, $R_A(s,z';x)$, $R_A^*(s,z';x)$ | Candidate Markov return functions | The portfolio-return formulas of Table 3.3 evaluated at $s,x,z'$; $R_A^*=(1-\theta^*_{US})R_p^*+\theta^*_{US}R_f$ after bond clearing. Kernels $M,M^*,\tilde M^*$ are recomputed from these returns. | [L1246][candidate-returns] |

### 3.6 Branch values, relative scales, and asymptotic allocations

| Symbol | Meaning and role | Definition or relationship | Source |
| --- | --- | --- | --- |
| $s_t^u$, $s_t^b$; $s_\tau$ | Endogenous branch states and inherited switch state | From a common all-$u$ predecessor, $s_t^z=\Gamma(s^u_{t-1},z)$. Date-$t$ knowledge stocks are identical across the two immediate successors; productivity and choices can differ with $z$. $s_\tau=(b,N_{US,\tau},N_{W,\tau})$ inherits past endogenous knowledge. | [L1352][branch-states]; [L1538][absorbing-selection] |
| $q_t^z$, $d_t^z$, $e_t^z$, $z\in\{u,b\}$ | US per-variety price, dividend, and young income on a successor branch | $q_t^z=q_{US}(s_t^z)$; $d_t^z=d_{US}(s_t^z)$; $e_t^z=e_{US}(s_t^z)$. They are evaluations of the same equilibrium functions, not new parameters. | [L1362][branch-objects] |
| $C_t^z$, $A_{t-1}^u$ | US old consumption on each successor branch and common prior saving | $C_t^z=A_{t-1}^uR_{A,t}^z$, with $A_{t-1}^u=\beta e^u_{US,t-1}$. $C_t^z$ denotes old consumption here, not total contemporaneous consumption. | [L1371][branch-consumption] |
| $R_{US,t}^z$, $R_{W,t}^z$, $R_{p,t}^z$, $R_{A,t}^z$ | Equity, equity-portfolio, and total-saving returns across the two successors | $R_{US,t}^z=(q_t^z+d_t^z)/q^u_{t-1}$; RoW equity uses the analogous return. $R_{p,t}^z=\omega^u_{t-1}R_{US,t}^z+(1-\omega^u_{t-1})R_{W,t}^z$; $R_{A,t}^z=(1-\theta^u_{t-1})R_{p,t}^z+\theta^u_{t-1}R_{f,t-1}$. Portfolio weights are inherited from the common predecessor. | [L2479][portfolio-multiplier]; [L2596][branch-portfolio] |
| $M^z_{t-1,t}$, $\mathcal M^z_{t-1,t}$; other $u,b$ superscripts | Branch evaluations of pricing kernels and other equilibrium objects | Evaluate the same definitions at the relevant state. In particular, $\mathcal M^b/\mathcal M^u=M^b/M^u=(R^b_{A,t}/R^u_{A,t})^{-\gamma}=(C_t^u/C_t^b)^\gamma$, since the prior wedge and normalization cancel. | [L1437][kernel-ratio] |
| $\Lambda_t^z$ | Total-saving return relative to US-equity return | $\Lambda_t^z=R_{A,t}^z/R_{US,t}^z$. This portfolio multiplier is endogenous and distinct from the wedge $\lambda_t$. | [L2479][portfolio-multiplier] |
| $\zeta_t$ | US equity funding relative to US young saving, along all-$u$ | $\zeta_t=\mathcal Q^u_{US,t}/(\beta e^u_{US,t})$. World clearing implies $\zeta_t-1=[\frac{\beta+\chi}{1+\chi}e^u_{W,t}-\mathcal Q^u_{W,t}]/(\beta e^u_{US,t})$. It is jointly endogenous with production and portfolios. | [L1809][funding-ratio]; [L1934][funding-identity] |
| $r_t$ | RoW real scale relative to US real scale along all-$u$ | $r_t=(N^u_{W,t})^{\xi_W}/N_t^{\nu_u}$. It is a scale ratio, not an interest rate. | [L1815][scale-ratio] |
| $G_t$ | Finite-date US knowledge-growth factor along all-$u$ | $G_t=N_{t+1}/N_t=1+a_{US}(1-\varphi_t)H_{US}$. It converges to the composite parameter $G_u$ under the tail result. | [L2024][growth-factor] |
| $x_t$ in the CES bounds and tail proof | Ratio of US effective production inputs | $x_t=A^u_{X,US,t}\varphi_tH_{US}/(A^u_{L,US,t}L_{US})$. Then $Y^u_{US,t}=A^u_{L,US,t}L_{US}B(x_t)$. Distinct from $x(s)$, $x_{i,t}$, and $x_{i,a,t}$. | [L1854][ces-proof] |
| $T_H$ | A finite cone-entry date for the selected all-$u$ equilibrium path | The selection condition requires $(N_{T_H},N^u_{W,T_H})\in\mathcal C_H$. The manuscript need not choose the first such date. Under the prefix sufficient condition one can take $T_H=T^\star$. This is a property/certificate of the selected path. | [L2144][cone-entry]; [L2208][entry-certificate] |
| $F(\varphi;N,\zeta)$ | Residual of the funding-adjusted HKT scalar equation | $F(\varphi;N,\zeta)=\beta\zeta[1+K_uN^{\psi_{US}}\varphi^{\rho_{US}}]-[1/(a_{US}H_{US})+1-\varphi]$. It depends on state, funding, and a candidate allocation; it is not the production function $F_i$. | [L2237][scalar-residual]; [L2963][terminal-residual] |
| $\varphi^{2C}(N,\zeta)$ | Interior two-country scalar labor-allocation root | The unique root of $F(\varphi;N,\zeta)=0$ on the stated large-$N$, near-unit-funding domain. Along the relevant equilibrium tail, $\varphi_t=\varphi^{2C}(N_t,\zeta_t)$. | [L2932][terminal] |
| $\varphi^{HKT}(N)$ | HKT scalar reference allocation used for terminal closure | $\varphi^{HKT}(N)=\varphi^{2C}(N,1)$. It is a derived root under unit funding, not a fixed production-share parameter; $\varphi_t/\varphi^{HKT}(N_t)\to1$ under the stated conditions. | [L2940][hkt-root] |

### 3.7 Selected balanced-growth values and limiting equilibrium constants

A bar does not generally identify a primitive parameter. Unlike the productivity coefficients $\bar A$, the barred objects below summarize equilibrium allocations or values. Absorbing-branch constants can depend on the inherited relative scale $N_{W,\tau}^{\xi_W}/N_{US,\tau}^{\nu_b}$ and on the selected stationary normalized equilibrium.

| Symbol | Meaning and role | Definition or relationship | Source |
| --- | --- | --- | --- |
| $\bar\varphi_b$, $\bar\varphi_{W,b}$ | Selected absorbing-branch US and RoW production shares | On a fixed continuation, $\varphi_{US,t}=\bar\varphi_b$ and $\varphi_{W,t}=\bar\varphi_{W,b}$ for $t\ge\tau$. US selection requires $0<\bar\varphi_b<1$; RoW may have zero R&D at $\bar\varphi_{W,b}=1$. | [L1538][absorbing-selection]; [L1571][balanced-growth] |
| $G_{N,US,b}$, $G_{N,W,b}$ | Selected absorbing-branch knowledge-growth factors | $G_{N,US,b}=1+a_{US}(1-\bar\varphi_b)H_{US}$; $G_{N,W,b}=1+a_W(1-\bar\varphi_{W,b})H_W$. | [L1548][absorbing-growth] |
| $G_b$, $G_W$ | Selected absorbing-branch real growth factors | $G_b=G_{N,US,b}^{\nu_b}$; $G_W=G_{N,W,b}^{\xi_W}$. The condition $G_b=G_W$ is part of the selected stationary world equilibrium, not a pair of independently calibrated growth rates. | [L1558][common-growth] |
| $\bar Y_{US}$, $\bar e_{US}$ | Normalized US output and young income on a fixed absorbing continuation | $\bar Y_{US}=Y_{US,t}/N_{US,t}^{\nu_b}$; $\bar e_{US}=e_{US,t}/N_{US,t}^{\nu_b}$. Equivalently, $\bar Y_{US}=F_{US}(\bar A_{X,US,b}\bar\varphi_bH_{US},\bar A_{L,US,b}L_{US})$. | [L1583][us-bg-values] |
| $\bar q_{US}$, $\bar d_{US}$ | Normalized per-variety US equity price and dividend on that continuation | $\bar q_{US}=q_{US,t}/N_{US,t}^{\nu_b-1}$; $\bar d_{US}=d_{US,t}/N_{US,t}^{\nu_b-1}$. Their ratio is the equilibrium yield $\delta_b$. | [L1583][us-bg-values] |
| $\bar{\mathcal Q}_{US}$, $\bar{\mathcal D}_{US}$ | Normalized aggregate US capitalization and dividends | $\bar{\mathcal Q}_{US}=\mathcal Q_{US,t}/N_{US,t}^{\nu_b}=G_{N,US,b}\bar q_{US}$; $\bar{\mathcal D}_{US}=\mathcal D_{US,t}/N_{US,t}^{\nu_b}=\bar d_{US}$. | [L1583][us-bg-values] |
| $\bar Y_W$, $\bar e_W$ | Normalized RoW output and young income on a fixed absorbing continuation | $\bar Y_W=Y_{W,t}/N_{W,t}^{\xi_W}$; $\bar e_W=e_{W,t}/N_{W,t}^{\xi_W}=\widehat e_W(\bar\varphi_{W,b})$. | [L1624][row-bg-values] |
| $\bar q_W$, $\bar d_W$ | Normalized per-variety RoW equity price and dividend | $\bar q_W=q_{W,t}/N_{W,t}^{\xi_W-1}$; $\bar d_W=d_{W,t}/N_{W,t}^{\xi_W-1}$. Normalized price comes from the selected equilibrium; active RoW R&D is not required. | [L1624][row-bg-values]; [L1679][row-bg-proof] |
| $\bar{\mathcal Q}_W$, $\bar{\mathcal D}_W$ | Normalized aggregate RoW capitalization and dividends | $\bar{\mathcal Q}_W=\mathcal Q_{W,t}/N_{W,t}^{\xi_W}=G_{N,W,b}\bar q_W$; $\bar{\mathcal D}_W=\mathcal D_{W,t}/N_{W,t}^{\xi_W}=\bar d_W$. | [L1624][row-bg-values] |
| $\delta_b$, $\delta_{W,b}$ | Constant per-variety dividend yields on a fixed absorbing continuation | $\delta_b=\bar d_{US}/\bar q_{US}=a_{US}(1-\vartheta_{US})\bar\varphi_bH_{US}/\vartheta_{US}>0$; $\delta_{W,b}=\bar d_W/\bar q_W>0$. The latter need not use the active-R&D formula. | [L1715][us-bg-yield]; [L1641][row-bg-yield] |
| $\bar c_\varphi$ | Limit of the normalized all-$u$ US production share | $N_t^{\psi_{US}/\rho_{US}}\varphi_t\to\bar c_\varphi=(D_u/(\beta K_u))^{1/\rho_{US}}$. A closed-form equilibrium limit, not a separate fitted parameter. | [L2305][tail-constants] |
| $\bar Y_u$ | Limit of normalized all-$u$ US output | $Y^u_{US,t}/N_t^{\nu_u}\to\bar Y_u=\bar A_{L,US,u}L_{US}(1-\alpha_{US})^{-1/(\rho_{US}-1)}$. | [L2339][tail-limits] |
| $\bar e_u$ | Limit of normalized all-$u$ US young income | $e^u_{US,t}/N_t^{\nu_u}\to\bar e_u=\bar Y_u(1+\beta/D_u)$. | [L2339][tail-limits] |
| $\bar q_u$ | Limit of normalized all-$u$ US per-variety price | $q_t^u/N_t^{\nu_u-1}\to\bar q_u=\beta\bar e_u/G_u$; aggregate capitalization obeys $\mathcal Q^u_{US,t}/N_t^{\nu_u}\to\beta\bar e_u$. | [L2339][tail-limits] |
| $\bar c_D$ | Limit of normalized all-$u$ US dividend yield | $N_t^{\psi_{US}/\rho_{US}}d_t^u/q_t^u\to\bar c_D=a_{US}(1-\vartheta_{US})H_{US}\bar c_\varphi/\vartheta_{US}$. | [L2339][tail-limits] |

### 3.8 Local proof variables and notation collisions

| Symbol and context | Meaning | Exact relationship and distinction | Source |
| --- | --- | --- | --- |
| $x_s$ in the deterministic terminal-product proof | Local dividend-yield sequence | $x_s=d_s/q_s$. It is not an intermediate quantity, portfolio value, or effective-input ratio. | [L143][deterministic-proof] |
| $X_t$; process $X$ in the switched-history proof | Discounted equity-price process | $X_t=\mathcal M_{0,t}q_t$. It is not the production input $X_{i,t}$. | [L163][supermartingale-proof] |
| $\epsilon_t$ in the direct-leakage proof | Magnitude of the previous-date US borrowing share | $\epsilon_t=-\theta^u_{t-1}>0$. Distinct from the fixed proof tolerances $\varepsilon^I,\varepsilon_H,\epsilon_0$. | [L2644][direct-proof-aliases] |
| $P_t^z$ in the direct-leakage proof | Local name for the US risky-portfolio return on branch $z$ | $P_t^z=R_{p,t}^z$. It is not the knowledge-good price $P_{i,t}$. | [L2644][direct-proof-aliases] |
| $F_t$ in the direct-leakage proof | Local name for the prior-date US risk-free return | $F_t=R_{f,t-1}$. Distinct from the production functions $F_i$ and scalar residual $F(\varphi;N,\zeta)$. | [L2644][direct-proof-aliases] |
| $U_t$, $B_t$ in the direct-leakage proof | Local names for continuation- and switch-state total-saving returns | $U_t=R_{A,t}^u=(1+\epsilon_t)P_t^u-\epsilon_tF_t$; $B_t=R_{A,t}^b=(1+\epsilon_t)P_t^b-\epsilon_tF_t$. Here $B_t$ is neither a bond quantity nor the rational bubble, and $U_t$ is not lifetime utility. | [L2653][direct-proof-returns] |
| $L_t^S$ in the direct-leakage proof | Dimensionless switch-leakage factor with the hazard ratio omitted | $L_t^S=(C_t^u/C_t^b)^\gamma(q_t^b+d_t^b)/q_t^u$. To reconcile the reused notation: $(L_t^S\text{ of Section 1})/\mathcal B_t=[(1-\pi)/\pi]\,(L_t^S\text{ of this proof})$. | [L2676][direct-proof-leakage]; [L1403][branch-leakage] |

## 4. Indices, sets, and operators

These are notation rather than additional parameters or economic variables. They are included to make the inventory complete without assigning index labels an economic classification.

| Notation | Interpretation |
| --- | --- |
| $i\in\{US,W\}$; $US$, $W$ | Country/issuer index and country labels; $W$ denotes the rest of the world. |
| $a\in\mathfrak T=\{H,L\}$; $H$, $L$ | Household-type index and type labels. The index $a$ is distinct from R&D productivity $a_i$ and leakage $a_t$. |
| $j\in[0,N_{i,t}]$ | Intermediate-variety/claim index; the integration domain's measure is endogenous. The $j$ in a kernel product is instead a dummy time index. |
| $t,s,T,n$ in sums, products, and stopping arguments | Date, summation, finite horizon, and truncation indices. The time index $s$ is distinct from the aggregate state $s$. $T_H,T_N,T_r,T^\star$ have specific roles recorded above. |
| $u,b$; $z,z',\tilde z$ | Regime labels and current/successor/dummy regime arguments. In a conditional expectation, $z',\tilde z$ range over possible exogenous realizations. A superscript $b$ is distinct from the bond-value variable $b_t$. |
| $\mathcal S=\{u,b\}\times\mathbb R_{++}^2$ | Domain of the mixed aggregate state. The set is specified by the model; a realized point $s_t$ contains endogenous knowledge stocks. |
| $\widetilde\omega,\widetilde\omega^*\in[0,1]$ | Arbitrary comparison allocations in the equity-share variational inequalities; not separate equilibrium shares or shocks. |
| $X,L$ in $F_i(X,L)$; $x,\varphi,N,M,\zeta$ as function/set arguments | Dummy arguments. In particular, $M$ in the cone's pair $(N,M)$ denotes a candidate RoW knowledge stock, whereas $M_{t,t+1}$ denotes an SDF. Actual paths/evaluations are classified above. |
| $E_t$, $E_s$, $\Pr$ | Conditional expectation and probability under the specified regime law; $E_s[f(z')]=\sum_{z'\in\{u,b\}}\Pi(z,z')f(z')$. They are operators, not economic variables. |
| $\lceil x\rceil_+$ | Nonnegative ceiling: $\max\{0,\lceil x\rceil\}$. Used to construct sufficient prefix horizons. |
| $O(\cdot)$, $\sim$, $\propto$, $\gtrsim$, $\tau\wedge n$ | Asymptotic order, asymptotic equivalence, proportionality, a lower bound up to a positive constant, and $\min\{\tau,n\}$; none is an additional model object. |

## 5. Implications for a calibration implementation

| Implementation distinction | Consequence |
| --- | --- |
| Primitive inputs versus derived coefficients | Specify the entries in Table 1.1 and the initial conditions; calculate Table 1.2 mechanically. Do not independently target both a primitive parameter combination and the same composite coefficient without an explicit identifying restriction. |
| Endogenous state versus exogenous shock | The regime follows $\Pi$, but knowledge follows equilibrium R&D. Productivity levels inherit both sources of variation through the primitive maps. |
| Equity price versus capitalization | Store per-variety $q_{i,t}$ separately from $\mathcal Q_{i,t}=N_{i,t+1}q_{i,t}$; use incumbent $N_{i,t}$ for dividends. |
| Interior R&D versus no-R&D boundary | Apply $q_{i,t}=w_{H,i,t}/(a_iN_{i,t})$ only where $\varphi_{i,t}<1$. Else retain the inequality and complementarity condition. |
| Reduced equilibrium unknowns | The source's reduced vector contains seven coordinates: $(\varphi_{US},\varphi_W,\omega,\theta^*_{US},\omega^*,R_f,R_f^W)$. Recover $\theta_W^*=0$ and $\theta=-\theta^*_{US}A^*/A$ from bond clearing, with all returns and continuation functions evaluated consistently. |
| Constant equilibrium quantities versus primitive parameters | Solve for absorbing shares, normalized valuations, and growth rates under the selected continuation. Their constancy on that continuation does not turn them into independent primitives. |
| Structural restrictions versus sufficient-theorem restrictions | $\xi_u>\nu_u>\nu_b\ge0$, $\rho_{US}>1$, $0<\gamma<1$, and $(1+a_{US}H_{US})^{\nu_u}>(1+a_WH_W)^{\xi_W}$ belong to the sufficient bubble argument. The absorbing common-growth condition and prefix funding bounds additionally restrict the equilibrium selection; they are not a complete primitive characterization of bubble existence. |
| Source domain gaps | The source does not give a complete explicit domain for $\kappa$, $\eta$, or $\bar\omega^*$. Any numerical implementation must state its chosen restrictions rather than attribute them to the manuscript. |

