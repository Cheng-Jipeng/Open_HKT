# Curvature choice for the 2009–latest rerun

Selection date: 12 October 2026. The user requests an operational calibration respecting the model's primitive restriction rho > 1. Use **rho = 2**, hence substitution elasticity **sigma = 1/rho = 0.5**. This supersedes rho = 2/3 for this run. It is a maintained, literature-informed complementarity calibration, not an estimated V6 coefficient.

## Verified primary evidence

- Ezra Oberfield and Devesh Raval (2021), *Micro Data and Macro Technology*, Econometrica 89(2), 703–732, [DOI 10.3982/ECTA12807](https://doi.org/10.3982/ECTA12807), [published author PDF](https://ezraoberfield.github.io/CESAggregation.pdf). The abstract and pp. 703–705 report aggregate US manufacturing capital–labor substitution elasticities of 0.5–0.7. The selected 0.5 is the lower endpoint of that reported range; reciprocal 2 is our conversion to V6 notation.
- Sebastian Gechert, Tomas Havranek, Zuzana Irsova and Dominika Kolcunova (2022), *Measuring Capital-Labor Substitution: The Importance of Method Choices and Publication Bias*, Review of Economic Dynamics 45, 55–82, [DOI 10.1016/j.red.2021.05.003](https://doi.org/10.1016/j.red.2021.05.003), [published author PDF](https://meta-analysis.cz/sigma/sigma2.pdf). Table 9, printed p. 77, gives 0.50 for the country-level-data variant, with 95% interval [0.18, 0.81]; its preferred best-practice estimate is 0.30. The chosen 0.50 is a specific literature-supported calibration, not their unique preferred estimate.

Both numerical claims were checked against the published PDFs on the selection date. No confidence interval is imposed as a parameter restriction.

## Economic interpretation and admissibility

The evidence concerns physical capital versus labor. V6 instead combines a knowledge-intensive intermediate input produced with skilled labor and unskilled labor. Transferring sigma = 0.5 is an explicit analogy. The closer skill-substitution evidence retained in the Plan remains relevant evidence, but its rho < 1 candidates are excluded from the executed model class as requested. The Plan and manuscript are not revised by this run.

All executed external-curvature candidates must satisfy rho > 1; the runner rejects an incompatible configuration before estimation. Other parameter signs/orderings are evaluated separately, and an unrestricted diagnostic fit that violates xi > nu >= 0 is not presented as a runnable full-model calibration. The existing markup, sources, units, wage bridge, and alpha = 0.5 and N_2009 = 1 normalizations are retained.

Changing rho cannot change P1, which contains no curvature term. A remaining P1 failure therefore remains an empirical mapping/model-accounting incompatibility. No markup is increased merely to accept the primary calibration. Existing higher-markup scenarios remain separately labelled diagnostics.

The sample starts in 2009 and ends at the latest common complete year of the necessary inputs in the preserved September 2026 package. This is 2024 on this run: labor quantities and the premium stop in 2024, although corporate accounts extend to 2025. All 16 years are fitting observations; 2023–2024 are no longer a holdout. Their previously documented CPS disclosure/topcoding comparability caveat remains applicable.
