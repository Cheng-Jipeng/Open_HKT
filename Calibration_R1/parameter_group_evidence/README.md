# V6 parameter calibration groups

This separate calibration-strategy register is dated 27 September 2026. It covers parameter families M01–M17 and all 30 economic scalar fields in the zero-exponent solver.

- Group A: four families / nine scalars. Risk aversion, CES curvature and inverse markup receive priority for external literature review. Four labor endowments are externally measured inputs.
- Group B: nine families / sixteen scalars. Saving, regime and technology parameters need a V6-specific mapping, joint ranges or normalization. The two zero exponents are explicitly imposed, not free calibration candidates.
- Group C: four families / five scalars. Equity friction, two preference centers, convenience utility and the bond-share friction are candidates for joint internal financial calibration.

Grouping concerns assignment strategy. It does not establish identification, select parameter values, define a final moment vector, or certify that current data identify all five financial coefficients.

The references are verified entry points and conceptual comparisons. No comprehensive numerical review or new data collection was performed. AHP's model inversion is not an identification result for V6. The HKT comparison is pinned to the local 2025 v2.

The generated standalone LaTeX and companion CSV are in the parent directory. Edit row definitions in build_groups.py, then rerun it to regenerate the artifacts. rows.json contains the code-field and V6-equation-label crosswalk; sources.json contains bibliographic records and verified source URLs. baseline_hashes.json protects the reviewed model, reference and previous calibration artifacts. coverage.json records one-to-one coverage checks.

Compile the generated LaTeX file and export the PDF with the available LaTeX compiler. Build products and rendered review pages belong in the parent build/parameter_groups directory. The final PDF is placed alongside the LaTeX file after visual inspection.
