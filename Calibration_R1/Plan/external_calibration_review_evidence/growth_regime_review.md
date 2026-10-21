# Growth and regime parameters: external-calibration evidence

Reviewed 27 September 2026 against the authoritative \`V6_parameter_calibration_groups.tex\`. Scope: M07, M09 and M16 only. Endowments, Group C and the fixed M17 exponents were not searched.

## Main finding

The closest **definition match** is HKT's own numerical illustration, but it is not empirical calibration. Historical disaster probabilities and innovation-productivity estimates offer useful **scenario and specification discipline**; neither supplies a portable estimate of the V6 technology-switch probability, research coefficient or pair of augmentation elasticities. No identified external benchmark should be manufactured from those analogies.

## M07: persistence of the unbalanced technology regime

**V6 definition.** \(\pi=\Pr(z_{t+1}=u\mid z_t=u)\); state \(b\) is absorbing. The model date length \(\Delta\) and empirical definition of the technology transition must precede an empirical calibration.

| Source and original object | Evidence and setting | V6 transformation and judgment |
|---|---|---|
| **Barro (2006), pp.825,831; Table V p.846.** \(p\) is the intensity of rare downward output jumps. | Historical calibration: 60 contractions of at least 15% in per-capita GDP, 35 countries, approximately the twentieth century. Empirical frequency is 1.7% per year; introductory range 1.5–2%; model sensitivity includes 2.5%. Recurring disasters in a representative-agent asset-pricing economy. | Source jump process uses no-disaster probability \(e^{-p\Delta}\). Thus \(\pi=e^{-p\Delta}\) **only under an additional event-equivalence assumption**. This is a technology-regime scenario analogy, not a V6 estimate. |
| **Barro–Ursúa (2008), pp.284–286; Tables10–11 pp.296–297.** \(p\) is annual normal-to-disaster transition probability. | Annual historical consumption/GDP series starting as early as1870, 24/36 countries; cumulative peak-to-trough contraction threshold10%. \(p=.0363\) for consumption and .0369 for GDP. Raising threshold to15% gives .0218/.0192. These are distinct event definitions, not a confidence interval. | If \(h=p\) is a matched annual hazard, \(\pi=(1-h)^\Delta\). Their symbol \(\pi\), approximately .277/.287, instead denotes disaster **exit** and must not be copied into V6. Events recur and recover; V6's switch is absorbing. |

**Recommendation, separately from evidence:** no evidence-backed V6 point. If exploratory computation requires a center, use annual \(h=.02\) solely as an **analyst-chosen scenario**, with \(h=.01,.02,.04\) as sensitivity cases and \(\pi=(1-h)^\Delta\). These are neither estimated technology hazards nor credible confidence bounds. The grid gives annual persistence .99,.98,.96; for \(\Delta=25\), approximately .778,.603,.360. Use an event-specific regime-duration study when the empirical transition and period are defined.

**Best sources:** [Barro2006](https://doi.org/10.1162/qjec.121.3.823); [Barro–Ursúa2008](https://doi.org/10.1353/eca.0.0000). The original published [BPEA PDF](https://www.brookings.edu/wp-content/uploads/2008/03/2008a_bpea_barro.pdf) was read, avoiding the older NBER abstract's different sample counts.

## M09: research productivity \(a_{US},a_W\)

**V6 definition and exact recovery.**

\[
N_{i,t+1}/N_{i,t}-1=a_i(1-\varphi_{i,t})H_i,\qquad
a_iH_i=\frac{G_{N,i,t}-1}{1-\varphi_{i,t}}.
\]

Only after fixing labor units does this recover \(a_i\). If \(H_i'=cH_i\), preserve behavior with \(a_i'=a_i/c\). For annual net knowledge growth \(g_N\), constant research share \(s_R\), and a \(\Delta\)-year date,
\[
a_iH_i=\frac{(1+g_N)^\Delta-1}{s_R}.
\]
This is a conditional temporal-aggregation formula, not permission to identify TFP with varieties.

| Source | Original evidence | Transferability |
|---|---|---|
| **HKT2025v2, Figure1 p.24.** | Same expanding-variety research law; illustrative \(aH=.2\), unspecified OLG date length. No empirical sample or estimate. | Useful initialization/comparison. It is not .2 annually and does not justify equal US and RoW productivity. |
| **Bloom–Jones–VanReenen–Webb2020**, eqs1–3 pp.1108–1110; Table7 p.1134. | Research productivity is idea-output growth divided by effective researchers. US aggregate1930–2015 uses decadal TFP and IPP spending deflated by skilled wages: Table7 reports −5.1% yearly productivity growth; Moore's Law1971–2014 gives −6.8%; cotton version2 gives +1.3%. | Mostly declining research productivity challenges constant \(a_i\); these are **growth rates of productivity, not levels** to insert for \(a_i\). Idea-output and labor units must match; retain exceptions. |
| **Jones1995**, JPE publisher abstract. | Industrial-country time-series evidence challenges scale effects in standard R&D growth models and motivates semi-endogenous growth. | A specification warning against interpreting a constant coefficient as a timeless empirical fact; no V6 coefficient borrowed. |

**Source discrepancy:** BJRW Table7 and p.1110 say −5.1% and14-year half-life, but the prose just above Table7 says −5.3% and13years. Use the explicitly labeled table values; Scite surfaced the latter prose accurately. No claim is made that this inconsistency is explained.

**Recommendation:** obtain matched knowledge growth and research share and recover \(a_iH_i\) separately for US and the declared RoW aggregate. Pending that bridge, \(.2\) can be retained only as HKT's illustrative \(aH\) starting value. There is no literature-validated portable range for either scalar. Propagate bounds instead:
\[
a_iH_i\in
\left[
\frac{(1+g_{N,\mathrm{lo}})^\Delta-1}{s_{R,\mathrm{hi}}},
\frac{(1+g_{N,\mathrm{hi}})^\Delta-1}{s_{R,\mathrm{lo}}}
\right],
\quad s_{R,\mathrm{lo}}>0.
\]
Alternative knowledge proxies, country coverage and researcher quality generate legitimate robustness specifications; arbitrary coefficient bounds do not become empirical evidence. Time-varying or diminishing research productivity requires a model extension.

## M16: augmentation elasticities \(\xi_u,\nu_u\)

**V6 definitions.**
\[
A_{X,US}=\bar A_{X,US,u}N_{US}^{\xi_u},\qquad
A_{L,US}=\bar A_{L,US,u}N_{US}^{\nu_u}.
\]
Thus \(\xi_u=\partial\log A_X/\partial\log N\), \(\nu_u=\partial\log A_L/\partial\log N\). They are not annual technology-growth rates, CES elasticities, or idea-production elasticities.

- **Same-definition illustration:** [HKT2025v2](https://arxiv.org/html/2501.08215v2), Figure1 p.24, uses \((\xi_u,\lambda_u)=(.7,.2)\), where source \(\lambda_u\) maps to V6 \(\nu_u\). This closed-economy unannualized OLG example provides an illustrative pair, not an estimated joint range.
- **Do not transfer a similarly named exponent:** BJRW eq17 writes \(\dot A/A=(\alpha A^{-\beta})S\). Its Table7 dynamic-diminishing-returns \(\beta=3.1\) for aggregate output and .2 for Moore's Law governs **research productivity**, not either V6 augmentation elasticity (nor V6's utility weight). Appendix \(\lambda=.75\) is an imposed research-input curvature alternative, also not V6 \(\nu\).
- **Original skill-demand evidence:** [Katz–Murphy1992](https://doi.org/10.2307/2118323), eq19 p.69, estimates annual CPS1963–1987 log college/high-school wages on relative supply and trend. The slope is −.709 (SE .150); trend .033 per year (SE .007). These estimated demand shifts cannot be renamed \(\xi_u-\nu_u\).

**Independent V6 derivation clarifying that mismatch.** With constant markup and CES weight,
\[
\frac{w_H}{w_L}
=\vartheta\frac{\alpha}{1-\alpha}
\left(\frac{A_X}{A_L}\right)^{1-\rho}
\left(\frac{\varphi H}{L}\right)^{-\rho},
\]
so
\[
\Delta\log(w_H/w_L)+\rho\,\Delta\log(\varphi H/L)
=(1-\rho)(\xi_u-\nu_u)\Delta\log N.
\]
A residual wage-demand trend disciplines a combination only after accounting for endogenous production/research allocation, CES curvature and knowledge growth. Under \(\rho>1\), increasing the relatively fast augmentation reduces its fixed-input marginal-price contribution; the wage-premium effect of declining \(\varphi\) is separate. Importing a positive skill-demand trend into \(\xi-\nu\) without this distinction can reverse the implied sign.

**Recommendation:** retain \((.7,.2)\) only as a transparent HKT initialization. An empirical baseline and plausible joint range remain unset until the same knowledge proxy is paired with recovered augmentation growth:
\[
\xi_u=\frac{\Delta\log A_X}{\Delta\log N},\qquad
\nu_u=\frac{\Delta\log A_L}{\Delta\log N}.
\]
Propagate joint uncertainty in numerator and denominator. A multiplicative rescaling of \(N\) changes scale coefficients, not these elasticities; a power redefinition of knowledge changes the exponents. Equal/reversed augmentation growth and \(\nu=0\) remain valid evidence possibilities even if outside the present solver/theorem domain.

## Compact recommendations (judgments, not source estimates)

| Parameter | Baseline candidate | Robustness range / design | Mapping confidence | Strongest supporting sources |
|---|---|---|---|---|
| \(\pi\) | No empirical benchmark; optional analyst scenario \(h=.02\), \(\pi=.98^\Delta\) | Analyst hazard grid .01,.02,.04; replace by event-specific durations; not an empirical interval | Low event match; exact conditional frequency conversion | Barro06; Barro–Ursúa08; HKT25 |
| \(a_{US}\) | Matched-growth recovery; HKT \(aH=.2\) only initialization | Propagate knowledge/research-share bounds, compare declining-productivity specification | Low empirical match | HKT25; BJRW20; Jones95 |
| \(a_W\) | Separate RoW matched-growth recovery; no numerical benchmark | Country-coverage and knowledge/research measurement bounds | Low, including aggregation | BJRW20; Jones95 |
| \(\xi_u\) | .7 illustrative HKT initialization; empirical value unset | Joint augmentation/knowledge-growth region, including contrary ordering where supported | High definition match to HKT; low empirical support | HKT25; Katz–Murphy92; BJRW20 |
| \(\nu_u\) | .2 illustrative HKT initialization; empirical value unset | Same joint region; do not truncate evidence solely to satisfy theorem | High definition match to HKT; low empirical support | HKT25; Katz–Murphy92; BJRW20 |

## Source and search audit

1. Hirano, Kishi and Toda(2025), *Technological Innovation and Bursting Bubbles*, arXiv2501.08215v2. Exact local original TeX and PDF checked, Figure1 p24. [Version-specific source](https://arxiv.org/html/2501.08215v2).
2. Barro(2006), *QJE*121(3),823–866. [DOI](https://doi.org/10.1162/qjec.121.3.823); [Harvard published PDF](https://dash.harvard.edu/bitstreams/7312037c-67b1-6bd4-e053-0100007fdf3b/download).
3. Barro and Ursúa(2008), *BPEA*,Spring,255–350 including discussion. [DOI](https://doi.org/10.1353/eca.0.0000); [published PDF](https://www.brookings.edu/wp-content/uploads/2008/03/2008a_bpea_barro.pdf).
4. Bloom, Jones, Van Reenen and Webb(2020), *AER*110(4),1104–1144. [DOI](https://doi.org/10.1257/aer.20180338); [author-hosted published PDF](https://web.stanford.edu/~chadj/IdeaPF.pdf).
5. Jones(1995), *JPE*103(4),759–784. [DOI and verified publisher abstract](https://doi.org/10.1086/262002). Author-hosted PDF was available but browser text extraction empty; no numeric claim relies on inaccessible body text.
6. Katz and Murphy(1992), *QJE*107(1),35–78. [DOI](https://doi.org/10.2307/2118323); [Stanford published PDF](https://cpi.stanford.edu/_media/pdf/Classic_Media/Katz_Murph_1992.pdf).

Requested connectors were used first: Wiley's two distinct queries both returned Internal error; Scite supplied metadata and original BJRW passages, while its Barro fulltext returned no text; Consensus discovery and mandatory fetch for BJRW were completed. Publisher/author PDFs supplied exact locators and numerical verification. Raw connector records are in \`growth_connector_results.json\`. No claimed institutional entitlement, model run, empirical estimation, or final parameter selection.

