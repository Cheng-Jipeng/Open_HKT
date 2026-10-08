# External-Calibration Candidate Set for V6

## Scope and bottom line

I treat the attached `V6_parameter_calibration_groups.tex` as authoritative for the **meaning of each V6 parameter**, and use the literature only to ask whether an external value or range can legitimately be transferred into that definition. I exclude \(H_i,L_i\), which the attachment assigns to labor data; Group C, which is reserved for internal calibration; and the imposed zeros \(\nu_b=0,\xi_W=0\), which are restrictions rather than parameters to be estimated.

The main conclusion is that the external-calibration candidates separate rather sharply into three tiers.

First, **\(\gamma\), \(\vartheta_i\), and—more cautiously—\(\rho_i\)** have recognizable empirical counterparts. They deserve genuine literature-based numerical baselines and ranges. For \(\rho_i\), however, the answer depends strongly on which empirical substitution margin is judged closest to V6.

Second, **\(\beta\)** can be externally disciplined only after fixing the length of a V6 generation/model period. An annual discount factor is not itself V6's \(\beta\).

Third, most Group B objects—**\(a_i,\alpha_i\), the productivity scales, \(\pi\), and \((\xi_u,\nu_u)\)**—do **not** have portable literature values. Their literature is still useful, but primarily for mappings, normalizations, and scenario ranges. Treating those objects as if the literature directly estimated them would create spurious precision.

The two most important substantive findings are somewhat uncomfortable but useful.

**Risk aversion:** external evidence does not naturally justify choosing \(\gamma<1\) merely because that is the V6 bubble region. Chetty obtains a mean relative-risk-aversion estimate around one from labor-supply evidence, whereas large-stake household-gamble evidence exhibits substantial heterogeneity and generally strong aversion to lifetime-income risk. citeturn32view5turn31view4 The latest Hirano–Kishi–Toda paper continues to require \(\gamma<1\) for its bubble-necessity theorem. citeturn32view1 Thus the empirically disciplined \(\gamma\) exercise and the bubble-compatible \(\gamma\) exercise should be visibly distinguished.

**CES curvature:** evidence on aggregate capital–labor substitution is quite supportive of complementarity—Gechert et al.'s meta-analysis puts the specification-adjusted mean elasticity near \(0.3\), and other micro-to-macro work finds values below one—whereas the classic college/high-school labor margin in Katz–Murphy implies an elasticity around \(1.41\). citeturn32view2turn20search2turn20search22 Since V6's \(X\)-versus-\(L\) margin is neither literally aggregate capital versus labor nor simply college versus high-school labor, this disagreement should be preserved rather than resolved mechanically.

My recommended philosophy is therefore

\[
\boxed{
\text{borrow } \gamma,\vartheta,\rho \text{ cautiously;}
\quad
\text{transform } \beta;
\quad
\text{construct rather than borrow most of Group B.}
}
\]

## Preference parameters

### Risk aversion \(\gamma\)

**V6 definition.** In the attachment, \(\gamma\) is the curvature of the old-age consumption certainty equivalent in Epstein–Zin preferences with unit intertemporal elasticity. Thus it is a risk-aversion parameter separated from the intertemporal-substitution margin, not a generic CRRA curvature that simultaneously governs both.

The closest empirical literature is informative but not perfectly mapped.

Chetty derives relative risk aversion from labor-supply elasticities in an expected-utility environment. His reported mean estimate is approximately

\[
\gamma\simeq1,
\]

and values above two require relatively strong labor-supply responses under his maintained structure. citeturn32view5 The attraction of this estimate for V6 is that it is an independently estimated structural preference magnitude rather than a value chosen to solve an asset-pricing puzzle. The mismatch is that Chetty's parameter comes from expected utility over consumption and labor, whereas V6's \(\gamma\) governs the certainty equivalent of stochastic old-age consumption inside an Epstein–Zin aggregator. citeturn32view5

The HRS evidence provides an important counterweight. The Barsky–Juster–Kimball–Shapiro approach uses hypothetical gambles involving large changes in lifetime income and maps responses into relative risk tolerance. Sahm subsequently analyzes 18,625 such gamble responses from 12,003 HRS participants aged roughly 45–70, explicitly using a CRRA interpretation and allowing for response error and persistent household heterogeneity. Most respondents reject even gambles with favorable expected lifetime income, and persistent heterogeneity is large. citeturn31view4 This evidence is conceptually attractive for an OLG model because the risk is large and lifetime-related, but it is not an estimate of a representative-agent Epstein–Zin parameter; aggregation from heterogeneous individual risk tolerances to a single V6 \(\gamma\) is nontrivial. citeturn31view4

The latest HKT specification is especially informative about the model mapping: the two-period OLG structure retains \(\gamma\) as the risk-aversion curvature, and its main bubble result requires \(\gamma<1\). The current 2026 revision still states the strict \(\gamma<1\) condition in the bubble-necessity theorem. citeturn32view0turn32view1 Importantly, the numerical example reported alongside its production block is illustrative rather than an empirical estimate. citeturn32view1

My assessment is therefore:

\[
\boxed{\gamma_{\text{external center}}\approx1}
\]

with a broad substantive robustness set approximately

\[
\boxed{\gamma\in[0.5,4]}
\]

rather than a narrow confidence interval. The lower part captures low-risk-aversion estimates and allows the V6 bubble region; values around one are directly supported by Chetty's labor-supply evidence; substantially larger values acknowledge the HRS-style lifetime-income evidence. citeturn32view5turn31view4

I would **not** label \([0.5,4]\) an econometric confidence interval. It is a defensible literature envelope across distinct empirical strategies and preference objects.

Because the V6 displayed utility excludes \(\gamma=1\), I would treat \(\gamma=1\) as the **conceptual external benchmark**, and use, for example, \(1.01\) when a nearby numerical value is needed. Separately, use something such as \(0.75\) as an explicitly labeled **bubble-compatible low-risk-aversion scenario**. Using \(0.99\) as the sole benchmark simply because it crosses the theorem boundary would be difficult to defend.

**Transferability: moderate for order of magnitude, low-to-moderate for the exact V6 coefficient.**

### OLG utility and saving weight \(\beta\)

**V6 definition.** The attachment defines

\[
U=(1-\beta)\log c_y+\beta\,CE(c_o),
\]

and the unit-EIS structure gives young saving \(A_t=\beta e_{US,t}\). Thus V6's \(\beta\) is simultaneously a normalized two-date utility weight and, given the rest of the model, a saving share. It is **not** an ordinary annual infinite-horizon discount factor.

This creates a simple but critical mapping issue. If an external two-period specification instead writes

\[
u(c_y)+\delta u(c_o),
\]

normalization by \(1+\delta\) gives

\[
\boxed{\beta=\frac{\delta}{1+\delta}}.
\]

If the source reports an annual discount factor \(\delta_a\) and one V6 period spans \(\Delta\) years, then under a literal exponential-discount mapping,

\[
\delta=\delta_a^\Delta,
\qquad
\boxed{
\beta=\frac{\delta_a^\Delta}{1+\delta_a^\Delta}.
}
\]

This transformation is algebraic; the substantive assumption is that an annual infinite-horizon discount factor is transferable to the two-generation V6 utility specification.

Using an annual factor around \(0.96\), a conventional quantitative-macro benchmark, illustrates how consequential the period conversion is: for \(\Delta=20,25,30\) years,

\[
\beta=
0.307,\;0.265,\;0.227,
\]

respectively. A broad annual-factor sensitivity range \(0.95\)–\(0.99\), combined with generation lengths of 20–30 years, translates into approximately

\[
\beta\in[0.18,0.45].
\]

The latest HKT numerical example instead uses

\[
\beta=\frac12,
\]

which is valuable because it comes from the closest model environment, but the authors explicitly present these as numerical-example parameters rather than estimates. citeturn32view1

For V6 I would therefore **not yet fix a single \(\beta\)**. First fix \(\Delta\). Conditional on a 25-year period, a sensible provisional external benchmark is

\[
\boxed{\beta\simeq0.27}
\]

if an annual factor of \(0.96\) is adopted; the robustness range should be roughly \(0.2\)–\(0.45\). HKT's \(0.5\) is useful as an exact-model comparison, not as primary empirical evidence. citeturn32view1

There is an additional identification check worth doing later: since V6 makes \(\beta\) directly determine young saving, the literature-derived preference value should be confronted with the implied saving rate. A value that is individually plausible as impatience but generates grossly implausible V6 saving would indicate that the two objects are not sufficiently transferable—not that \(\beta\) should simply be re-estimated from wealth until the model fits.

**Transferability: low-to-moderate until V6's period length is fixed.**

## Production parameters

### Inverse markup \(\vartheta_i\)

**V6 definition.**

\[
p_i=\frac{w_{H,i}}{\vartheta_i},
\qquad
\mu_i\equiv\frac{p_i}{MC_i}
=
\frac1{\vartheta_i}.
\]

Hence external gross markups map cleanly as

\[
\boxed{\vartheta_i=\mu_i^{-1}}.
\]

This is among the cleanest transformations in the entire calibration inventory.

De Loecker, Eeckhout, and Unger construct firm-level US markups from production data and document a substantial rise in the sales-weighted aggregate markup. Their headline estimates go from about \(21\%\) above marginal cost around 1980 to roughly \(61\%\) above marginal cost in the later sample, i.e.

\[
\mu\simeq1.21
\quad\text{to}\quad
1.61.
\]

They also emphasize that the increase is concentrated in the upper tail and through reallocation toward high-markup firms, while the median markup changes much less. citeturn32view3

Directly mapping those endpoints produces

\[
\vartheta =
\frac1{1.21}\simeq0.826,
\qquad
\frac1{1.61}\simeq0.621.
\]

That gives a natural first-pass range

\[
\boxed{\vartheta_{US}\in[0.62,0.83]}.
\]

I would use

\[
\boxed{\mu_{US}=1.4
\quad\Longleftrightarrow\quad
\vartheta_{US}=0.714}
\]

as a provisional central value, rather than \(1.61\). The reason is not that \(1.4\) is an independently estimated point estimate; it is a middle calibration within the empirical aggregate range that avoids treating the high-markup upper tail as representative of every V6 intermediate producer. De Loecker et al.'s own distributional results make that distinction relevant. citeturn32view3

There are three transfer qualifications.

First, their sample concerns US firms and their production-based marginal-cost measure, whereas V6's markup belongs specifically to monopolistically competitive intermediate producers. Second, measured markups need to be distinguished from accounting profit shares, fixed overhead, and rents. Third, applying the same number to the RoW is considerably weaker than using it for the US because country composition and sectoral markup distributions differ.

I would therefore use the US range above directly, while treating

\[
\vartheta_W\in[0.62,0.85]
\]

as a **provisional cross-country sensitivity range**, not a literature estimate of a single RoW aggregate. A later data pass could replace it with country-weighted markup evidence.

**Transferability: moderate-to-high for the definition, moderate for US aggregation, low-to-moderate for RoW.**

### Final-sector CES curvature \(\rho_i\)

**V6 definition.**

\[
F_i=
\left[
\alpha_i\widetilde X_i^{1-\rho_i}
+
(1-\alpha_i)\widetilde L_i^{1-\rho_i}
\right]^{1/(1-\rho_i)}
\]

with

\[
\boxed{\sigma_i=\frac1{\rho_i}}.
\]

Therefore

\[
\rho>1
\Longleftrightarrow
\sigma<1,
\]

so the current US solver restriction is a complementarity restriction.

Here the empirical literature does **not** give one unambiguous answer because different papers estimate different factor margins.

Gechert, Havranek, Irsova, and Kolcunova collect 3,186 capital–labor elasticity estimates from 121 studies. Their raw literature mean is around \(0.9\), but after accounting for publication bias, cross-country identification, omitted first-order conditions, and other methodological choices, their preferred conditional mean is approximately

\[
\sigma_{KL}\simeq0.3.
\]

They conclude that the accumulated evidence strongly rejects Cobb–Douglas elasticity one. citeturn32view2turn29view0 Under the V6 convention this corresponds to

\[
\rho\simeq\frac1{0.3}=3.33.
\]

Oberfield and Raval use US manufacturing plant-level information to build toward the aggregate capital–labor elasticity; their estimates are generally below one and are commonly reported around \(0.5\)–\(0.7\). Their object is closer to a production-factor substitution parameter than a wage regression, but still not exactly V6's intermediate-input/unskilled-labor margin. citeturn21search29turn22search4 This maps approximately into

\[
\rho\simeq 1.43\text{--}2.
\]

This complements the latest HKT numerical example, which sets

\[
\rho=2,
\]

equivalently \(\sigma=0.5\). Again, HKT is a structural example, not an estimate, but the number happens to sit inside the empirical capital–labor complementarity literature rather than being an arbitrary extreme. citeturn32view1

However, the classic Katz–Murphy college/high-school labor specification gives an elasticity of substitution of approximately

\[
\sigma_{H,L}\simeq1.41,
\]

which would imply

\[
\rho\simeq0.71.
\]

That points in the **opposite direction** from the implemented V6 restriction. citeturn20search2turn20search22

This contradiction should not be hidden. It reflects the fact that Katz–Murphy's margin is high-skilled versus lower-skilled labor, whereas the capital–labor literature studies a broader produced-input-versus-labor margin. V6's \(\widetilde X\) is a technology/variety-intensive intermediate composite while \(\widetilde L\) is unskilled labor, so neither mapping is exact.

My recommendation is therefore two-layered:

\[
\boxed{
\rho_{US}=2
\quad(\sigma=0.5)
}
\]

as the operational baseline, with

\[
\boxed{
\rho_{US}\in[1.4,3.3]
\quad
(\sigma\in[0.3,0.7])
}
\]

as the main robustness range within the current solver's complementarity branch. This is supported by the capital–labor evidence and conveniently includes the HKT benchmark. citeturn32view2turn32view1

But the paper should also acknowledge an **out-of-branch empirical stress test** around

\[
\rho\simeq0.7
\quad(\sigma\simeq1.4),
\]

motivated by Katz–Murphy-style skilled/unskilled substitution. citeturn20search2 If the substantive result depends critically on ruling that region out by code construction, that would be important.

For the RoW, I would initially use the same broad prior range rather than pretending there is a single global estimate.

**Transferability: moderate for the CES concept, low-to-moderate for the precise V6 factor margin.**

### CES distribution weight \(\alpha_i\)

**V6 definition.** Levels enter production through the combinations

\[
\alpha_iA_{X,i}^{1-\rho_i},
\qquad
(1-\alpha_i)A_{L,i}^{1-\rho_i}.
\]

This immediately implies that \(\alpha_i\) is not separately portable from the factor-augmentation scales without a normalization.

Caselli and Coleman explicitly work with factor-specific technology and cross-country skill-price/quantity information, illustrating the general principle that technology levels and factor shares have to be interpreted jointly rather than reading a CES distribution parameter directly from an observed labor income share. citeturn21search3turn21search7

The HKT numerical example uses

\[
\alpha=\frac12,
\]

but once again this is an illustrative specification. citeturn32view1

For V6 I think the most defensible choice is therefore:

\[
\boxed{\alpha_i=0.5\ \text{as an explicit normalization}}
\]

rather than calling \(0.5\) an empirical estimate.

Robustness should not be “change \(\alpha\) holding both \(A_X\) and \(A_L\) fixed,” because that changes the identified composites by construction. Instead re-normalize/refit the augmentation scales under, say,

\[
\alpha_i\in\{0.3,0.5,0.7\}
\]

and ask whether equilibrium outcomes change once the same initial production moments are reproduced. If they do not, that confirms much of the apparent \(\alpha\) variation is normalization; if they do, the source of that difference becomes economically meaningful.

**Transferability of a numerical literature value: low. Confidence in treating it as a normalization: high.**

## Innovation and regime parameters

### Innovation productivity \(a_i\)

**V6 definition.**

\[
\frac{N_{i,t+1}}{N_{i,t}}-1
=
a_i(1-\varphi_{i,t})H_i.
\]

Thus \(a_i\) is “knowledge-stock growth per unit of skilled research labor” in the V6 units and over one V6 period.

There is no portable number here because changing the unit of \(H_i\), the model-period length, or the empirical interpretation of \(N_i\) changes \(a_i\).

This is also where the modern innovation literature actually cautions against too literal a constant-\(a\) interpretation. Jones argues that the strong scale effects of first-generation R&D-based endogenous-growth models are inconsistent with the time-series behavior of industrial economies, motivating specifications in which research effort does not translate one-for-one into permanently higher growth. citeturn27search1turn27search3 Bloom, Jones, Van Reenen, and Webb subsequently document that maintaining growth in several domains has required sharply increasing research effort, motivating their “ideas getting harder to find” interpretation. citeturn28search0turn28search8 Those objects are not V6's \(a_i\), but they warn against claiming that a constant research-productivity coefficient has a well-established empirical level.

HKT's latest numerical example uses

\[
aH=0.2.
\]

Notice that it reports **the composite \(aH\)**, which is precisely the economically sensible object before choosing labor units. citeturn32view1

I would therefore not populate the V6 table with a borrowed scalar \(a_i\). I would externally construct

\[
\boxed{
a_iH_i
=
\frac{g_{N,i}}{1-\varphi_i}
}
\]

from a declared empirical mapping for knowledge growth and the skilled research share, and only then recover

\[
a_i=\frac{a_iH_i}{H_i}.
\]

The HKT value

\[
aH=0.2
\]

is useful as an exact-model **benchmark/check**, not as an empirical baseline. citeturn32view1

The robustness dimension should be alternative definitions of \(N\) and research labor, plus alternative period aggregation—not an arbitrary \(\pm20\%\) interval around one copied number.

**Transferability of a scalar \(a_i\): very low. Transferability of the discipline strategy: high.**

### Unbalanced-regime persistence \(\pi\)

**V6 definition.**

\[
\pi
=
\Pr(z_{t+1}=u\mid z_t=u),
\]

with the balanced regime absorbing.

This is not a business-cycle AR coefficient. It is the survival probability of an unusual technology regime. Consequently, its empirical counterpart depends on defining what historical event constitutes the beginning and end of a “general-purpose-technology unbalanced regime.”

In the corresponding HKT setup, \(\pi\) governs the expected duration of the temporary state; the existence condition for the bubble is driven by other structural conditions rather than by choosing a particular numerical persistence. The latest paper does not provide an empirically estimated \(\pi\) that can simply be copied into V6. citeturn13view0turn32view0

The attachment mentions rare-disaster evidence as an analogy. I agree with the word **analogy**: recurrent consumption/output disasters are not the same stochastic object as an absorbing technological transition, so importing a Barro disaster probability would create a false measurement mapping.

I would parameterize \(\pi\) through an interpretable **expected duration** \(D\). If periods are one year and the geometric expected duration is \(D\),

\[
E[T]=\frac1{1-\pi}
\quad\Rightarrow\quad
\boxed{\pi=1-\frac1D}.
\]

For example, purely as scenarios,

\[
D=10,\ 25,\ 50
\]

years give

\[
\pi=0.90,\ 0.96,\ 0.98
\]

at annual frequency. If one V6 period is five years, the corresponding per-model-period persistence is very different: a 25-year expected duration means five periods, hence \(\pi=0.80\).

Therefore **period length must be fixed before \(\pi\)**.

My provisional benchmark would be a 25-year expected unbalanced-regime duration, not “\(\pi=0.96\)” independently of frequency. A 10–50-year duration grid is best viewed as a structural scenario set pending a more explicit historical technology-regime coding.

**Transferability: low. This is primarily a scenario parameter unless a regime dataset is explicitly constructed.**

### Knowledge elasticities \(\xi_u,\nu_u\)

**V6 definition.**

\[
A^u_{X,US}
=
\bar A_{X,US,u}N_{US}^{\xi_u},
\qquad
A^u_{L,US}
=
\bar A_{L,US,u}N_{US}^{\nu_u},
\]

so

\[
\xi_u=\frac{\partial\log A_X}{\partial\log N},
\qquad
\nu_u=\frac{\partial\log A_L}{\partial\log N}.
\]

These are **factor-specific elasticities of augmentation to the V6 knowledge stock**. They are not the same as the research-productivity coefficient in an idea-production equation.

This distinction eliminates many superficially attractive literature numbers. Jones's scale-effect critique and Bloom et al.'s research-productivity evidence concern the mapping from research inputs into idea/technology growth, not the elasticities with which a given knowledge stock augments the two V6 production factors. citeturn27search1turn28search0 Caselli–Coleman provides useful evidence that factor-specific technology can differ systematically across skill types and countries, but does not identify \((\xi_u,\nu_u)\) with respect to a V6 variety stock. citeturn21search3turn21search7

The strongest numerical candidate is consequently **model-specific rather than empirical**: HKT's current numerical example uses

\[
\boxed{
\xi_u=0.7,\qquad
\lambda_u=0.2,
}
\]

where its \(\lambda_u\) plays the analogous lower factor-augmentation exponent in that specification. citeturn32view1

That pair is useful for V6 because it comes from the closest theoretical architecture and gives substantial directed technological bias:

\[
\xi_u-\nu_u=0.5.
\]

I would therefore use

\[
\boxed{
(\xi_u,\nu_u)=(0.7,0.2)
}
\]

as a **model-specific baseline**, not an empirically estimated calibration.

For robustness, a transparent scenario envelope could be

\[
\xi_u\in[0.4,0.9],
\qquad
\nu_u\in[0,0.4],
\]

with the current solver imposing \(\xi_u>\nu_u\). This range is deliberately labeled a **specification range**, not a literature confidence interval. More informative robustness would hold the difference \(\xi_u-\nu_u\) fixed while changing the common level, and then hold the common level fixed while changing the difference. That separates overall knowledge amplification from directed technological bias.

Because

\[
\psi_{US}
=
(\xi_u-\nu_u)(\rho_{US}-1),
\]

a useful later sensitivity exercise is to report results directly against \(\psi_{US}\). The bubble mechanism may ultimately be better disciplined in that composite direction than in \(\xi_u\) and \(\nu_u\) separately.

**Transferability of HKT's pair: low-to-moderate as a theoretical benchmark; empirical identification of the pair: low.**

## Productivity scales and normalization

The three scale families are the clearest cases where “external calibration” should **not** mean “find a number in another paper.”

### US unbalanced-regime scales

V6 defines

\[
A^u_{X,US}
=
\bar A_{X,US,u}N_{US}^{\xi_u},
\qquad
A^u_{L,US}
=
\bar A_{L,US,u}N_{US}^{\nu_u}.
\]

The scale coefficients therefore depend on the units of \(X\), \(L\), the normalization of \(N_0\), and \(\alpha_{US}\). They are not TFP levels.

Caselli–Coleman's cross-country methodology is relevant precisely because it treats skilled- and unskilled-factor efficiency jointly with quantities and prices rather than interpreting one observed productivity statistic as a primitive technology parameter. citeturn21search3turn21search7

The HKT example reports

\[
A_XH=10,\qquad A_LL=1,
\]

rather than portable stand-alone \(A_X\) and \(A_L\) estimates. citeturn32view1 That should be read as further evidence that these levels are normalization-dependent composites.

My proposed V6 procedure is:

\[
N_{US,0}=1
\]

under the chosen knowledge normalization; choose an explicit \(\alpha_{US}\) normalization such as \(0.5\); then solve \(\bar A_{X,US,u}\) and \(\bar A_{L,US,u}\) jointly from initial US output, relative skilled/unskilled wage information, and the labor quantities.

Thus the “baseline candidate” is **data-implied conditional scales**, not literature numbers.

**Transferability of outside numerical levels: essentially zero.**

### US absorbing-regime scales

\[
\bar A_{X,US,b},\qquad
\bar A_{L,US,b}
\]

determine production and equity cash flows after the regime switch. If the observed historical window is entirely in \(u\), the data do not directly reveal these counterfactual technology levels.

This makes them especially dangerous parameters to camouflage as conventional external calibration.

A clean parameterization is in ratios:

\[
r_X^b
=
\frac{\bar A_{X,US,b}}
     {\bar A_{X,US,u}},
\qquad
r_L^b
=
\frac{\bar A_{L,US,b}}
     {\bar A_{L,US,u}}.
\]

Then

\[
r_X^b=r_L^b=1
\]

can be used as an **explicit continuity benchmark**. It should be described exactly that way: a maintained counterfactual restriction, not evidence that the post-transition technology has the same level.

For sensitivity I would use a symmetric scenario grid such as

\[
r_j^b\in\{0.75,1,1.25\},
\]

and perhaps wider extremes if asset valuations prove sensitive. These numbers are not claimed to come from a precise empirical literature; their purpose is to reveal how much the bubble and valuation conclusions depend on the severity of the eventual technology transition.

This is particularly important because post-switch payoff severity and transition persistence can substitute for one another in current asset values. Hence \((r_X^b,r_L^b,\pi)\) should be varied jointly when the Group C finance parameters are subsequently re-calibrated.

**Transferability: essentially zero; scenario analysis is the appropriate discipline.**

### RoW productivity scales

With \(\xi_W=0\), V6's

\[
\bar A_{X,W},\qquad \bar A_{L,W}
\]

are constant factor augmentations. Their levels depend on the definition of “RoW,” labor normalization, \(\alpha_W\), and output units.

Caselli–Coleman's factor-specific technology framework again supports using wages, skill quantities, and output jointly rather than importing a country-average TFP ratio. citeturn21search3turn21search7

I would choose one global unit normalization and infer the remaining relative RoW scales from the empirical production block. In other words, these parameters should be **externally disciplined by data but internally solved within the production mapping**. That is entirely consistent with your Group B concept: they are outside the international-finance calibration block without pretending they are universal literature coefficients.

**Transferability of literature point values: essentially zero.**

## Recommended candidate set

The table below deliberately distinguishes **evidence** from **my recommendation**. “Range” therefore sometimes means a literature-supported numerical envelope and sometimes an explicitly labeled scenario/normalization range.

| V6 parameter | Literature evidence / closest counterpart | Recommended baseline candidate | Robustness treatment | Mapping confidence |
|---|---|---:|---|---|
| \(\gamma\) | Chetty's labor-supply method gives mean RRA \(\approx1\); HRS lifetime-income gambles imply considerable aversion and heterogeneity. citeturn32view5turn31view4 | **Conceptual:** \(1\). For numerical implementation use a nearby value and state why. | \(0.5\)–\(4\); include a separately labeled bubble-compatible case such as \(0.75\), rather than selecting \(<1\) by construction. | **Moderate** for magnitude; **low–moderate** for EZ representative-agent mapping |
| \(\beta\) | Closest HKT numerical specification uses \(0.5\), but as an illustration. citeturn32view1 Annual discount factors require generational transformation. | After fixing \(\Delta\): \(\beta=\delta_a^\Delta/(1+\delta_a^\Delta)\). At \(\delta_a=.96,\Delta=25\), **\(0.265\)**. | Roughly \(0.18\)–\(0.45\) for annual \(\delta_a=.95\)–.99 and 20–30-year periods; HKT \(0.5\) as model comparison. | **Low–moderate** |
| \(\vartheta_{US}\) | US aggregate markup roughly \(\mu=1.21\) to \(1.61\); rise concentrated in upper tail. citeturn32view3 | \(\mu=1.4\Rightarrow\) **\(\vartheta=.714\)** | \(\mu\in[1.2,1.6]\Rightarrow\vartheta\in[.625,.833]\) | **Moderate** |
| \(\vartheta_W\) | Same structural transformation, but US evidence is not a RoW estimate. | **\(0.714\)** only as provisional common benchmark | \(0.62\)–\(0.85\), then replace with region-weighted evidence | **Low–moderate** |
| \(\rho_{US}\) | Capital–labor evidence favors \(\sigma<1\); meta-analysis adjusted mean about \(0.3\). Katz–Murphy skill margin gives \(\sigma\simeq1.41\). HKT uses \(\rho=2\). citeturn32view2turn20search2turn32view1 | **\(\rho=2\)** (\(\sigma=.5\)) | Main solver range \(1.4\)–\(3.3\); retain \(\rho\simeq0.7\) as an external contradictory stress test requiring a solver extension. | **Moderate** for complementarity evidence; **low–moderate** for exact V6 margin |
| \(\rho_W\) | Same literature; no clean global V6-margin estimate | **\(2\)** provisionally | \(1.4\)–\(3.3\), plus substitutability stress test | **Low–moderate** |
| \(a_i\) | R&D-growth literature shows major specification/unit issues; Jones rejects strong scale-effect implications and Bloom et al. document changing research productivity. citeturn27search1turn28search0 HKT uses \(aH=.2\) illustratively. citeturn32view1 | **No borrowed \(a_i\).** Infer \(a_iH_i=g_N/(1-\varphi_i)\). | Alternative \(N\), R&D-labor and period mappings; HKT \(aH=.2\) as code/model benchmark | **Very low** for scalar transfer |
| \(\alpha_i\) | CES share is confounded with factor augmentation under V6 normalization; Caselli–Coleman illustrates joint factor-specific technology inference. citeturn21search3turn21search7 HKT uses \(.5\). citeturn32view1 | **\(0.5\) as normalization** | Refit augmentation scales under \(\alpha=.3,.5,.7\); do not vary \(\alpha\) alone | **High** as normalization; **low** as empirical coefficient |
| \(\pi\) | HKT interprets it as persistence/duration of the temporary technology regime; no directly estimated V6 counterpart. citeturn13view0turn32view0 | **25-year expected-duration scenario**, after fixing model frequency | Expected durations 10, 25, 50 years; convert to per-period \(\pi\) | **Low** |
| \(\bar A_{X,US,u},\bar A_{L,US,u}\) | Factor-specific technology evidence is useful for construction, not portable levels. citeturn21search3 HKT's \(A_XH=10,A_LL=1\) are normalized composites. citeturn32view1 | **Solve from initial US production moments** under \(N_0,\alpha\), and labor-unit normalization | Alternative normalizations and empirical mappings | **High** for conditional fitting; **near zero** for literature transfer |
| \(\bar A_{X,US,b},\bar A_{L,US,b}\) | Counterfactual post-switch levels are not observed in an all-\(u\) history | **Continuity ratios \(r_X^b=r_L^b=1\)**, explicitly as an assumption | Scenario ratios e.g. \(0.75,1,1.25\), jointly with \(\pi\) | **Very low** |
| \(\bar A_{X,W},\bar A_{L,W}\) | Country technology literature supports fitting factor-specific efficiencies jointly with wages and quantities. citeturn21search3turn21search7 | **Solve from relative RoW output/wages/labor** | Geographic-coverage and normalization alternatives | **High** for conditional fitting; **near zero** for point transfer |
| \((\xi_u,\nu_u)\) | No direct empirical estimate of V6's knowledge-to-factor-augmentation pair. Closest HKT illustration uses \((.7,.2)\). citeturn32view1 Broader innovation evidence concerns different objects. citeturn27search1turn28search0 | **\((0.7,0.2)\)** as model-specific benchmark | Scenario envelope roughly \(\xi_u=.4\)–.9, \(\nu_u=0\)–.4; additionally vary \(\xi_u-\nu_u\) directly | **Low** |

The practical implication is that I would **not** create an `external_parameter_candidates.csv` in which every Group A/B row contains a seemingly comparable literature estimate. A more honest registry would have an `assignment_type` field taking values such as:

\[
\text{literature estimate},
\quad
\text{literature-informed range},
\quad
\text{transformed preference value},
\quad
\text{normalization},
\quad
\text{conditional production fit},
\quad
\text{counterfactual scenario}.
\]

That distinction matters for your later identification exercise. In particular, only a small subset of the block is genuinely “fixed by strong external numerical evidence.” Much of Group B is better viewed as **externally disciplined structural uncertainty**.

For the first quantitative V6 pass, I would use the following provisional vector as the cleanest starting point:

\[
\gamma\simeq1,\qquad
\beta\simeq0.27\ \text{if }\Delta=25,
\qquad
\vartheta_{US}\simeq\vartheta_W\simeq0.71,
\qquad
\rho_{US}\simeq\rho_W\simeq2,
\]

\[
\alpha_{US}=\alpha_W=0.5
\quad\text{as normalizations},\qquad
(\xi_u,\nu_u)=(0.7,0.2)
\quad\text{as an HKT benchmark},
\]

while **solving rather than borrowing** \(a_i\) and the production scales, and treating \(\pi\) and the \(b\)-regime scales through explicit duration/severity scenarios. The current HKT numerical example provides a useful internal consistency benchmark—\(\beta=\alpha=1/2,\rho=2,\xi_u=.7,\lambda_u=.2,aH=.2\)—but its parameters are expressly a numerical example, not an empirical calibration. citeturn32view1

Most importantly, I would **not make \(\gamma<1\), \(\rho_{US}>1\), or \(\xi_u>\nu_u\) look like conclusions of the external literature merely because they are useful for the current theorem/solver**. The first is at best borderline in the external risk-aversion evidence, the second is supported by one important production literature but contradicted by another relevant skill-substitution literature, and the third presently rests much more heavily on the HKT mechanism than on a direct empirical estimate. citeturn32view5turn32view2turn20search2turn32view1

That is actually a productive outcome for the next stage: it tells you exactly which externally assigned objects should be treated as nearly fixed and which should be **re-calibrated around as structural robustness dimensions when assessing the international-finance parameters and, ultimately, the identified range of the bubble contribution**.