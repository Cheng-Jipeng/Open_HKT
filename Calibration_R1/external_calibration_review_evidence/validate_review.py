"""Check coverage, links, compilation, transformations, and preserved model files."""
from pathlib import Path
import hashlib
import json
import math
import re
from pypdf import PdfReader
import pdfplumber

HERE = Path(__file__).resolve().parent
BASE = HERE.parent
ROOT = BASE.parents[1]
BUILD = BASE / "build" / "external_review"
PDF = BUILD / "V6_external_calibration_literature_review.pdf"
tex = (BASE / "V6_external_calibration_literature_review.tex").read_text()
manifest = json.loads((HERE / "manifest.json").read_text())
expected = {"beta", "gamma", "pi", "vartheta_US", "vartheta_W", "rho_US", "rho_W",
            "a_US", "a_W", "alpha_US", "alpha_W", "A_X_US_u", "A_L_US_u",
            "Abar_X_US", "Abar_L_US", "Abar_X_W", "Abar_L_W", "xi_u", "nu_u"}
assert set(manifest["scalars"]) == expected and len(manifest["scalars"]) == 19
assert len(json.loads((HERE / "candidate_rows.json").read_text())) == 19
assert not re.search(r"\\(?:input|include|bibliography)\{", tex)
refs = set(re.findall(r"\\src\{([^}]+)\}", tex))
assert len(refs) == 31
assert refs == set(re.findall(r"\\hypertarget\{ref:([^}]+)\}", tex))
hashes = json.loads((HERE / "source_hashes_before.json").read_text())
for path, before in hashes.items():
    assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == before, path
log = (BUILD / "V6_external_calibration_literature_review.log").read_text()
issues = [line for line in log.splitlines()
          if re.search(r"Warning|Overfull|Underfull|^!|Fatal", line)]
assert not issues, issues
reader = PdfReader(PDF)
assert len(reader.pages) == 16
assert all("ref:" + key in reader.named_destinations for key in refs)
texts = [page.extract_text() for page in reader.pages]
assert all(len(t) > 500 and "\ufffd" not in t and "??" not in t for t in texts)
out_of_page = []
with pdfplumber.open(PDF) as doc:
    for page_num, page in enumerate(doc.pages, 1):
        for char in page.chars:
            if char["x0"] < -0.5 or char["x1"] > page.width + 0.5 or char["top"] < -0.5 or char["bottom"] > page.height + 0.5:
                out_of_page.append((page_num, char.get("text")))
assert not out_of_page, out_of_page
arithmetic = {
    "beta_GP_delta09598_D30": .9598**30/(1+.9598**30),
    "beta_GP_delta09569_D30": .9569**30/(1+.9569**30),
    "beta_LLM_delta09601_D30": .9601**30/(1+.9601**30),
    "beta_exp_envelope_min": .9569**40/(1+.9569**40),
    "beta_exp_envelope_max": .9601**20/(1+.9601**20),
    "beta_present_bias_continuation_scenario_max": .9891**20/(1+.9891**20),
    "pi_KR_annual": .99**4,
    "pi_KR_25years": .99**100,
    "vartheta_DLEU2016": 1/1.61,
    "vartheta_Traina_sample_end": 1/1.15,
    "rho_CP05": 1/1.5,
}
assert round(arithmetic["beta_exp_envelope_min"],4) == .1465
assert round(arithmetic["beta_exp_envelope_max"],4) == .3070
assert round(arithmetic["beta_present_bias_continuation_scenario_max"],4) == .4454
assert round(arithmetic["pi_KR_25years"],4) == .3660
ces_errors = []
for rho in [.27, 2/3, 2, 3.33]:
    alpha, s, Y, X, L = .5, .4, 3.2, .7, 1.4
    ax = Y/X * (s/alpha)**(1/(1-rho))
    al = Y/L * ((1-s)/(1-alpha))**(1/(1-rho))
    y = (alpha*(ax*X)**(1-rho)+(1-alpha)*(al*L)**(1-rho))**(1/(1-rho))
    share = alpha*(ax*X)**(1-rho)/y**(1-rho)
    ces_errors += [abs(y-Y), abs(share-s)]
assert max(ces_errors) < 1e-12
result = {
    "status": "passed",
    "pages": len(reader.pages), "unique_scalars": 19, "unique_sources": 31,
    "tex_warnings_or_overflows": issues, "pdf_out_of_page_characters": out_of_page,
    "citations_resolve": True, "standalone_tex": True, "authoritative_model_files_unchanged": True,
    "numeric_transformations": arithmetic, "ces_roundtrip_max_abs_error": max(ces_errors),
    "pdf_sha256": hashlib.sha256(PDF.read_bytes()).hexdigest(),
    "tex_sha256": hashlib.sha256((BASE/"V6_external_calibration_literature_review.tex").read_bytes()).hexdigest(),
    "compiler": "Existing local MacTeX latexmk/pdflatex; success",
    "native_compiler": "Attempted but returned no result; waiting terminated. Native preview compilation unverified.",
    "visual_qa": "Pages 1-8 and 9-16 independently inspected at 1600px; all pass. Parent separately inspected formula/summary pages. Final bibliography spacing polished and pages15-16 re-rendered for final inspection.",
    "scope": "Literature review and proposed candidates only; no model calibration or equilibrium run performed.",
}
(HERE/"validation.json").write_text(json.dumps(result, indent=2))
print(json.dumps({k: result[k] for k in ["status","pages","unique_scalars","unique_sources","authoritative_model_files_unchanged"]}))
