"""Validate inventory coverage, unchanged sources, PDF bounds and compilation.

This checks a research artifact. It is not a data validation or identification test.
Run with the bundled Python containing pypdf and pdfplumber.
"""
from pathlib import Path
import hashlib
import json
import re
from collections import Counter
import pdfplumber
from pypdf import PdfReader

evidence = Path(__file__).resolve().parent
calibration = evidence.parent
root = calibration.parent.parent
name = "V6_parameter_identifying_moments"
tex = (calibration / f"{name}.tex").read_text()
authority = (calibration / "V6_parameter_calibration_groups.tex").read_text()
entries = re.findall(r"% ENTRY: (M\d+); GROUP: ([ABC]); SCALARS: (\d+)", tex)
original = dict(re.findall(r"% ENTRY: (M\d+); GROUP: ([ABC]);", authority))
assert len(entries) == 17 and len({i for i, _, _ in entries}) == 17
assert {i: g for i, g, _ in entries} == original
assert sum(int(n) for _, _, n in entries) == 30
expected = json.loads((evidence / "source_hashes.json").read_text())
unchanged = {
    p: hashlib.sha256((root / p).read_bytes()).hexdigest() == h
    for p, h in expected.items()
}
assert all(unchanged.values())
log = (calibration / "build" / "identifying_moments" / f"{name}.log").read_text()
bad_patterns = [r"Overfull", r"undefined", r"duplicate ignored", r"^!", r"LaTeX Error"]
bad_log = [p for p in bad_patterns if re.search(p, log, flags=re.MULTILINE)]
assert not bad_log, bad_log
assert "Output written on" in log
pdf = calibration / f"{name}.pdf"
reader = PdfReader(pdf)
assert len(reader.pages) == 8
assert len(reader.outline) == 8
pdftext = "\n".join(page.extract_text() or "" for page in reader.pages)
assert all(i in pdftext for i in original)
page_metrics = []
with pdfplumber.open(pdf) as document:
    for number, page in enumerate(document.pages, 1):
        chars = [c for c in page.chars if c["text"].strip()]
        overflow = [c["text"] for c in chars if c["x0"] < 35 or c["x1"] > page.width - 35
                    or c["top"] < 10 or c["bottom"] > page.height - 10]
        assert not overflow, (number, overflow)
        page_metrics.append({"page": number, "characters": len(chars), "outside_page_bounds": 0})
output = {
    "status": "passed",
    "families": len(entries),
    "scalars": sum(int(n) for _, _, n in entries),
    "groups": dict(Counter(g for _, g, _ in entries)),
    "columns_in_main_tables": 3,
    "source_files_unchanged": unchanged,
    "compile_errors_or_overfull_boxes": bad_log,
    "harmless_underfull_box_warnings": len(re.findall(r"Underfull", log)),
    "pages": page_metrics,
    "outline_entries": len(reader.outline),
    "tex_sha256": hashlib.sha256((calibration / f"{name}.tex").read_bytes()).hexdigest(),
    "pdf_sha256": hashlib.sha256(pdf.read_bytes()).hexdigest(),
    "scope": "Artifact validation only; no empirical identification or data-readiness claim.",
}
(evidence / "artifact_validation.json").write_text(json.dumps(output, indent=2) + "\n")
print(json.dumps({"status": "passed", "families": 17, "scalars": 30, "pages": len(reader.pages)}))
