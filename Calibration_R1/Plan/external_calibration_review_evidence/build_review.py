"""Assemble the standalone review and audit ledgers; never modify model sources."""
from pathlib import Path
import csv
import hashlib
import json
import re
import unicodedata

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "V6_external_calibration_literature_review.tex"

ALIASES = {
    "P1": "KM92", "P2": "CP05", "P3": "CC06", "P4": "KORV00",
    "P5": "DLEU20", "P6": "Traina18", "P7": "DE21", "P8": "BHKZ21",
    "P9": "DL21", "P10": "OR21", "P11": "GHIK22", "P12": "HILZ24",
}
def read(name):
    return json.loads((HERE / name).read_text())

sources = {}
for s in read("preference_review.json")["literature"]:
    sources[s["key"]] = dict(s)
for s in read("production_review.json")["sources"]:
    key = ALIASES[s["id"]]
    sources[key] = dict(s, key=key, original_evidence_id=s["id"])
for key, s in read("growth_bibliography.json").items():
    if key not in sources or key == "HKT25":
        sources[key] = dict(s, key=key)
sources["CFL2013"] = dict(read("preference_supplement.json"), key="CFL2013")
sources.update({
    "Rossi22": {
        "key": "Rossi22", "authors": "Federico Rossi", "year": 2022,
        "title": "The Relative Efficiency of Skilled Labor across Countries: Measurement and Interpretation",
        "venue": "American Economic Review 112(1), 235-266",
        "doi": "10.1257/aer.20191852",
        "url": "https://wrap.warwick.ac.uk/id/eprint/159013/1/WRAP-Relative-efficiency-skilled-labor-across-countries-measurement-interpretation-2021.pdf",
        "locator": "July 2021 accepted manuscript, equations (4)-(8), pp. 7-8; Table I, p. 31 (PDF page 32). Publication metadata checked against AEA.",
        "source_definition": "(A_H Q_H)/(A_L Q_L), relative efficiency including embodied worker quality; US normalized to one",
        "verified_numbers": {"sigma_imposed": 1.5, "US": 1, "Canada": 0.711, "India": 0.041},
        "method": "Static skill CES inversion from comparable wages and hours; 12 countries circa 2000",
        "mapping": "Re-invert V6 with production research split and intermediate markup; country values are not V6 RoW scales",
    },
    "CL12": {
        "key": "CL12", "authors": "Cristiano Cantore and Paul Levine", "year": 2012,
        "title": "Getting Normalization Right: Dealing with Dimensional Constants in Macroeconomics",
        "venue": "Journal of Economic Dynamics and Control 36(12), 1931-1949",
        "doi": "10.1016/j.jedc.2012.05.009",
        "url": "https://archives.dynare.org/wp-repo/dynarewp009.pdf",
        "locator": "Detailed method: Dynare Working Paper 9 (July 2011), sections 2.1-2.5.",
        "method": "Dimensional analysis and equivalent CES reparameterization; not empirical estimates",
    },
    "KMW12": {
        "key": "KMW12", "authors": "Rainer Klump, Peter McAdam and Alpo Willman", "year": 2012,
        "title": "The Normalized CES Production Function: Theory and Empirics",
        "venue": "Journal of Economic Surveys 26(5), 769-799",
        "doi": "10.1111/j.1467-6419.2012.00730.x",
        "url": "https://www.ecb.europa.eu/pub/pdf/scpwps/ecbwp1294.pdf",
        "locator": "Detailed method: ECB Working Paper 1294 (2011), equations (10), (15)-(16).",
        "method": "Methodological survey of CES normalization; no transferable numeric raw distribution coefficient",
    },
    "LMW10": {
        "key": "LMW10", "authors": "Miguel A. Leon-Ledesma, Peter McAdam and Alpo Willman", "year": 2010,
        "title": "Identifying the Elasticity of Substitution with Biased Technical Change",
        "venue": "American Economic Review 100(4), 1330-1357",
        "doi": "10.1257/aer.100.4.1330",
        "url": "https://www.ecb.europa.eu/pub/pdf/scpwps/ecbwp1001.pdf",
        "locator": "Method verified in ECB Working Paper 1001 (January 2009); published metadata checked at AEA.",
        "method": "Monte Carlo normalized CES system identification; not a new empirical V6 point estimate",
    },
})

venues = {
    "GP02": "Econometrica 70(1), 47-89",
    "LLMRT26": "Review of Financial Studies 39(6), 1580-1610; online 2024, issue 2026",
    "BJKS97": "Quarterly Journal of Economics 112(2), 537-579",
    "KSS08": "Journal of the American Statistical Association 103(483), 1028-1038",
    "HL02": "American Economic Review 92(5), 1644-1655",
    "VA03": "American Economic Review Papers and Proceedings 93(2), 383-391",
    "EHI25": "Journal of Economic Surveys 39(5), 2315-2333",
    "KR07": "Journal of Monetary Economics 54(6), 1670-1701",
    "BP07": "Economic Journal 117(518), 486-511",
    "DE21": "Working paper, 10 February 2021 version; NBER Working Paper 24768 first issued 2018",
    "BHKZ21": "Journal of Monetary Economics 121, 1-14",
    "DL21": "Journal of Monetary Economics 121, 15-18",
    "OR21": "Econometrica 89(2), 703-732",
    "GHIK22": "Review of Economic Dynamics 45, 55-82",
    "HILZ24": "Review of Economics and Statistics 106(5), 1187-1200; online 2022",
    "BJRW20": "American Economic Review 110(4), 1104-1144",
    "Jones95": "Journal of Political Economy 103(4), 759-784",
}
for key, venue in venues.items():
    sources[key]["venue"] = venue
sources["VA03"]["locator"] = "Numeric evidence: author-uploaded extended manuscript dated 10 January 2003, Table 2A, case 4, p. 14; journal article is shorter."
sources["CFL2013"]["year"] = 2013
sources["CFL2013"]["venue"] = "Quantitative Economics 4(1), 39-83"
sources["HKT25"]["locator"] = "Pinned arXiv v2 and matching local original TeX; Figure 1, p. 24. Numerical illustration, not an estimate."
sources["HILZ24"]["locator"] = "Final published Table 5, p. 1197; supersedes 2020/2021 low-elasticity working paper."
locators = {
    "CFL2013": "Equations (1)-(2), p. 44; Table 2, p. 62; methods and interpretation, pp. 56-58, 64-65.",
    "DLEU20": "Author manuscript, 15 November 2019: equation (7), section 3.1 and Figure 1, pp. 9-10.",
    "Traina18": "Longer Time Horizons subsection and Figure 5; numerical passage verified in original full text via Scite.",
    "DE21": "Data: section 2; regional estimates: Table 1, manuscript p. 13.",
    "KORV00": "Table II, p. 1041; alternative skill threshold: footnote 16, p. 1044.",
    "CC06": "Equations (2)-(3), pp. 499-502; section I.B and Table 2, pp. 504-505.",
    "OR21": "Abstract, p. 703; introduction, p. 705; Figure 4b, p. 719.",
    "GHIK22": "Table 9, p. 77; method: section 5.4; conclusion, p. 78.",
    "KR07": "Equations (7)-(9), p. 1677; Table 2, p. 1683; sample/durations, p. 1682; identification, p. 1687.",
    "BJRW20": "Equations (1)-(3), pp. 1108-1110; Table 7 and equation (17), p. 1134; Table A1, p. 1140.",
    "BP07": "Equations (5)-(9), pp. 492-494; sample, p. 495; Table 4, p. 501; interpretation, p. 502.",
}
for key, locator in locators.items():
    sources[key]["locator"] = locator

# Retain the connector-generated bibliography unchanged as a provenance artifact.
raw = read("scite_bibliography_raw.json")
meta = json.loads(next(x["text"] for x in raw["content"] if x["type"] == "text"))
(HERE / "scite_references_raw.bib").write_text(meta["content"])
assert meta["found"] == 31 and not meta["notFound"]
# Prefer full author metadata from this discovery record where agent ledgers use surnames.
for block in re.split(r"(?=@)", meta["content"]):
    doi = re.search(r'doi\s*=\s*"([^"]+)"', block)
    author = re.search(r'author\s*=\s*"([^"]+)"', block)
    title = re.search(r'title\s*=\s*"([^"]+)"', block)
    if not doi:
        continue
    for key, s in sources.items():
        if s.get("doi", "").lower() == doi[1].lower():
            if author and key in {"GP02", "LLMRT26", "BJKS97", "KSS08", "HL02", "VA03", "EHI25"}:
                s["authors"] = author[1]
            if key == "DL21" and title:
                s["title"] = title[1]

def clean_text(s):
    s = str(s).replace("–", "--").replace("—", "---").replace("‐", "-")
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))

def esc(s):
    s = clean_text(s)
    return "".join({"&": r"\&", "%": r"\%", "_": r"\_", "#": r"\#", "$": r"\$",
                    "{": r"\{", "}": r"\}", "~": r"\textasciitilde{}"}.get(c, c) for c in s)

def url(s):
    return str(s).replace("%", r"\%").replace("&", r"\&").replace("#", r"\#")

parts = ["preamble_intro.tex", "preference_tables.tex", "production_tables.tex",
         "growth_tables.tex", "scale_tables.tex", "recommendations.tex"]
body = "\n\n".join((HERE / name).read_text() for name in parts)
for old, new in ALIASES.items():
    body = body.replace(r"\src{" + old + "}", r"\src{" + new + "}")
# Keep math in printed headings while providing clean PDF bookmarks.
def heading(match):
    original = match[1]
    short = re.sub(r"\\([a-zA-Z]+)", r"\1", original)
    short = re.sub(r"[$_{}]", " ", short)
    short = re.sub(r"\s+", " ", short).strip()
    return r"\section[" + short + "]{" + original + "}"
body = re.sub(r"^\\section\{(.*)\}$", heading, body, flags=re.M)
keys = list(dict.fromkeys(re.findall(r"\\src\{([^}]+)\}", body)))
assert set(keys) <= sources.keys(), set(keys) - sources.keys()
scalars = re.findall(r"^% SCALAR: (.+)$", body, re.M)
assert len(scalars) == len(set(scalars)) == 19
candidate_rows = []
for block in re.split(r"^% SCALAR: ", body, flags=re.M)[1:]:
    scalar, row = block.split("\n", 1)
    row = re.split(r"\\\\\[5pt\]", row, maxsplit=1)[0]
    cells = [re.sub(r"\s+", " ", c).strip() for c in re.split(r"(?<!\\)&", row)]
    assert len(cells) == 5, (scalar, cells)
    candidate_rows.append(dict(zip(
        ["parameter_latex", "baseline_candidate_latex", "robustness_latex", "mapping_confidence", "sources_latex"],
        cells), scalar=scalar, evidence_role="recommendation, not an additional estimate"))
(HERE / "candidate_rows.json").write_text(json.dumps(candidate_rows, ensure_ascii=False, indent=2))

bib = [r"\clearpage", r"\section{References and verified versions}",
       r"Links in each entry lead to the DOI and the paper/version used for the checks. Page and table locators refer to that version where specified. Working papers, illustrative calibrations and meta-analyses retain their distinct status.",
       r"\begin{multicols}{2}\fontsize{9.2}{10.8}\selectfont\setlength{\parskip}{7pt}"]
for key in keys:
    s = sources[key]
    authors = s.get("authors", "")
    if isinstance(authors, list):
        authors = ", ".join(authors)
    authors = authors.replace(";", " and")
    venue = s.get("venue", s.get("publication", s.get("journal", "")))
    loc = s.get("locator", s.get("locus", ""))
    if not loc:
        loc = "; ".join(s.get("locators", []))
    main = (rf"\hypertarget{{ref:{key}}}{{}}\textbf{{{esc(key)}}}. "
            f"{esc(authors)} ({s['year']}). {esc(s['title'])}. "
            rf"\emph{{{esc(venue)}}}. ")
    if s.get("doi"):
        main += rf"\href{{https://doi.org/{url(s['doi'])}}}{{DOI}}. "
    if s.get("url"):
        main += rf"\href{{{url(s['url'])}}}{{Verified source/version}}. "
    if loc:
        main += esc(loc)
    bib.append(r"\begin{minipage}{\linewidth}" + main + r"\end{minipage}\par")
bib += [r"\end{multicols}", r"\end{document}", ""]
OUT.write_text(body + "\n\n" + "\n".join(bib))
(HERE / "source_ledger.json").write_text(json.dumps([sources[k] for k in keys], ensure_ascii=False, indent=2))
with (HERE / "source_ledger.csv").open("w", newline="") as f:
    fields = ["key", "authors", "year", "title", "venue", "doi", "url", "locator"]
    w = csv.DictWriter(f, fieldnames=fields)
    w.writeheader()
    for k in keys:
        s = sources[k]
        row = {field: s.get(field, "") for field in fields}
        row["locator"] = s.get("locator", s.get("locus", "; ".join(s.get("locators", []))))
        w.writerow(row)
manifest = {
    "review_date": "2026-09-27", "source_file": str(OUT),
    "scalar_count": len(scalars), "scalars": scalars, "source_count": len(keys),
    "bibliography_keys": keys, "fragments": parts,
    "tex_sha256": hashlib.sha256(OUT.read_bytes()).hexdigest(),
    "exclusions": ["M08 labor endowments", "M03-M06 Group C", "M17 imposed zero exponents"],
    "status": "Assembled; compilation and visual QA reported separately",
}
(HERE / "manifest.json").write_text(json.dumps(manifest, indent=2))
print(json.dumps({"tex": str(OUT), "scalars": len(scalars), "sources": len(keys)}))
