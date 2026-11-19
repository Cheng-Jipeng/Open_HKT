"""Which mechanisms can drive the rise in Q/Y, and what do the data say? (2026-11-19)

Merges the evidence of two decks into qy_mechanisms_data_2026_11_19.tex. Nothing is fetched; every input is read-only.

  Deck A (16 Nov 2026, HKT mechanisms; AHP total corporate sector):
      Logistics/Discussion_note/29_11_16/slides/{data/values.tex, figures/*.pdf}
  Deck B (18 Nov 2026, credit, capital, buybacks; Z.1 nonfinancial corporate sector, NFC):
      Codes/Calibration_R1/2_Check/2026_11_18_Credit_Buybacks/{data/values.tex, data/processed/*.csv, figures/*.pdf}
  Repository CSVs read by deck A's build.py (for the new synthesis figure and the sector table):
      Codes/Calibration_R1/2_Check/figures/figure_data.csv, zeta_funding_ratio_1990_2025.csv
      Empirical_Data/AHP_NFA/ahp_us_nfa_decomposition_latest.csv

Writes (only inside this deck's folder):
  data/values_a.tex  \\va{key}: deck A's formatted strings, verbatim  (csname "va:key")
  data/values_b.tex  \\vb{key}: deck B's formatted strings, verbatim  (csname "vb:key")
  data/values_c.tex  \\vc{key}: numbers computed here                  (csname "vc:key")
  data/values_c.json, data/synthesis_indexed_ratios.csv, data/sector_reconciliation.csv
  figures/a_*.pdf, figures/b_*.pdf (copies), figures/s_synthesis_indexed_ratios.pdf (new)
Then scans the deck's .tex for every \\va/\\vb/\\vc key and fails if one is undefined.

Run from the deck folder:
  uv run --no-project --python 3.12 --with numpy==2.3.5 --with pandas==2.2.3 --with matplotlib==3.10.0 python -I scripts/build.py
"""
import json
import re
import shutil
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
DECK = HERE.parent
ROOT = HERE.parents[4]  # .../Two_country_HKT
SRC_A = ROOT / "Logistics/Discussion_note/29_11_16/slides"
SRC_B = ROOT / "Codes/Calibration_R1/2_Check/2026_11_18_Credit_Buybacks"
CHK = ROOT / "Codes/Calibration_R1/2_Check"
OUTD, OUTF = DECK / "data", DECK / "figures"
OUTD.mkdir(exist_ok=True)
OUTF.mkdir(exist_ok=True)
TEX = DECK / "qy_mechanisms_data_2026_11_19.tex"
Y0, YB, Y1, YK = 2009, 2011, 2025, 2023  # window start, 2011 base, window end, last KLEMS year (2024 is a source break)

# ================================================================== 1. namespaced copies of the two value files
LINE = re.compile(r"^\\expandafter\\def\\csname v:(.+?)\\endcsname\{(.*)\}\s*$")


def parse_values(path):
    out = {}
    for ln in path.read_text().splitlines():
        if not ln.strip():
            continue
        m = LINE.match(ln)
        if not m:
            raise SystemExit(f"unparsed line in {path}: {ln}")
        out[m.group(1)] = m.group(2)
    return out


def write_values(vals, prefix, path, origin):
    with open(path, "w") as fh:
        fh.write(f"% {origin}\n% Written by scripts/build.py; do not edit. Use \\{prefix}{{key}}.\n")
        for k, v in vals.items():
            fh.write(f"\\expandafter\\def\\csname {prefix}:{k}\\endcsname{{{v}}}\n")


VA = parse_values(SRC_A / "data/values.tex")
VB = parse_values(SRC_B / "data/values.tex")
write_values(VA, "va", OUTD / "values_a.tex", f"Deck A (16 Nov 2026, AHP total corporate): verbatim copy of {SRC_A.relative_to(ROOT)}/data/values.tex")
write_values(VB, "vb", OUTD / "values_b.tex", f"Deck B (18 Nov 2026, Z.1 NFC): verbatim copy of {SRC_B.relative_to(ROOT)}/data/values.tex")
print(f"deck A: {len(VA)} values; deck B: {len(VB)} values")

# ================================================================== 2. figures copied from the two decks (provenance in the prefix)
COPY_A = ["f_ratios", "f_decomposition", "f_gva_values", "f_gva_percent", "c_labor_klems", "f_zeta", "f_valuation",
          "f_topcode_monthly", "f_premium_treatments", "f_free_entry"]
COPY_B = ["f1_credit_q_funding", "f2_capital_tobin_q", "f3_nfc_flows", "f4_compustat_payout", "f5_ai_hyperscalers",
          "f6_fcf_decomposition", "f7_debt_use_bounds"]
for n in COPY_A:
    shutil.copy2(SRC_A / "figures" / f"{n}.pdf", OUTF / f"a_{n}.pdf")
for n in COPY_B:
    shutil.copy2(SRC_B / "figures" / f"{n}.pdf", OUTF / f"b_{n}.pdf")

# ================================================================== 3. new numbers
VC = {}


def put(k, x, fmt="{:.2f}"):
    s = x if isinstance(x, str) else fmt.format(x)
    VC[k] = "\\ensuremath{-}" + s[1:] if s.startswith("-") else s


# ---- total corporate (AHP), as in deck A's build.py
fd = pd.read_csv(CHK / "figures/figure_data.csv").set_index("year")
fd["BH_Y"] = fd.COMP * fd.S_SKILLED_KLEMS / fd.Y  # skilled compensation (KLEMS college share) over corporate GVA
for y in (Y0, YB, YK):
    put(f"BHY{y}", 100 * fd.BH_Y[y], "{:.1f}")
assert VC[f"BHY{Y0}"] == VA[f"g_skilled_sh{Y0}"] and VC[f"BHY{YK}"] == VA[f"g_skilled_sh{YK}"], "B_H/Y differs from deck A"

z = pd.read_csv(CHK / "figures/zeta_funding_ratio_1990_2025.csv").set_index("year")

nf = pd.read_csv(ROOT / "Empirical_Data/AHP_NFA/ahp_us_nfa_decomposition_latest.csv", parse_dates=["date"])
q4 = nf[nf.date.dt.month == 10].copy()
q4["year"] = q4.date.dt.year
q4 = q4.set_index("year")
# quantity of foreign-held US equity (market value over its price index) relative to corporate GVA, end of year
xq = (q4.equity_liabilities_us_musd / q4.equity_liability_price_index) / q4.gva_corporate_saar_musd
assert abs((xq[Y1] / xq[Y0]) - float(VA["x_qtyL"]) / float(VA["x_gva"])) < 0.01, "foreign quantity/GVA differs from deck A"

# ---- NFC (Z.1), deck B's processed table, % of NFC GVA
rb = pd.read_csv(SRC_B / "data/processed/z1_nfc_ratios_pct_gva.csv").set_index("date")
rb["q"] = rb.Q / rb.K
for k, kb in (("QY", "QY"), ("FCFY", "FCFY"), ("DEBTY", "DEBTY"), ("KY", "KY")):  # cross-check against deck B's strings
    for y in (Y0, YB, Y1):
        v = rb.loc[y, k[:-1]]
        assert abs(v - float(VB[f"{kb}{y}"])) <= 0.5 * 10 ** -(len(VB[f"{kb}{y}"].split(".")[1]) if "." in VB[f"{kb}{y}"] else 0) + 1e-9, (k, y)

# ---- sector reconciliation table: Q/Y and D/Y, total corporate vs NFC
rec = []
for sec, QY, DY in (("total", fd.Q_Y, fd.D_Y), ("nfc", rb.Q / 100, rb.FCF / 100)):
    for y in (Y0, YB, Y1):
        put(f"rec_{sec}_QY{y}", QY[y]); put(f"rec_{sec}_DY{y}", 100 * DY[y], "{:.1f}"); put(f"rec_{sec}_DQ{y}", 100 * DY[y] / QY[y], "{:.1f}")
    for b in (Y0, YB):
        dqy, ddy = np.log(QY[Y1] / QY[b]), np.log(DY[Y1] / DY[b])
        put(f"rec_{sec}_dQY{b}", dqy); put(f"rec_{sec}_dDY{b}", ddy); put(f"rec_{sec}_dQD{b}", dqy - ddy)
        put(f"rec_{sec}_shQY{b}", 100 * dqy / (dqy - ddy), "{:.0f}")
        put(f"rec_{sec}_shDY{b}", 100 * -ddy / (dqy - ddy), "{:.0f}")  # share of the D/Y term, so the two shares add to 100
        rec.append(dict(sector=sec, base=b, QY_base=QY[b], QY_2025=QY[Y1], DY_base=DY[b], DY_2025=DY[Y1],
                        dlog_QY=dqy, dlog_DY=ddy, dlog_QD=dqy - ddy, share_QY=dqy / (dqy - ddy)))
pd.DataFrame(rec).round(5).to_csv(OUTD / "sector_reconciliation.csv", index=False)
for b in (Y0, YB):  # the total-corporate row must reproduce deck A
    assert VC[f"rec_total_shQY{b}"] == VA[f"shQY{b}"] and VC[f"rec_total_dQY{b}"] == VA[f"dQY{b}"], b
zb = pd.read_csv(SRC_B / "data/processed/z1_nfc_annual_trn.csv").set_index("date")
for y in (Y0, Y1):
    put(f"nfc_Yshare{y}", 100 * zb.loc[y, "Y"] / fd.Y[y], "{:.0f}")  # NFC GVA / total corporate GVA

# ---- synthesis figure: each mechanism's own ratio, indexed, against Q/Y of the same sector
SERIES = {  # key: (series, sector tag, Q/Y reference)
    "DY": (fd.D_Y, "total", fd.Q_Y),
    "PAY": (rb.DEQ, "nfc", rb.Q),
    "BHY": (fd.BH_Y.loc[:YK], "total", fd.Q_Y),
    "ZETA": (z.zeta_sep, "total", fd.Q_Y),
    "XQ": (xq, "total", fd.Q_Y),
    "DEBT": (rb.DEBT, "nfc", rb.Q),
    "KY": (rb.K, "nfc", rb.Q),
    "q": (rb.q, "nfc", rb.Q),
}
rows = []
for k, (s, sec, ref) in SERIES.items():
    s = s.dropna()
    end = int(s.index.max())
    for b in (Y0, YB):
        put(f"idx{b % 100:02d}_{k}", 100 * s[end] / s[b], "{:.0f}")
        put(f"idx{b % 100:02d}_QYref_{k}", 100 * ref[end] / ref[b], "{:.0f}")
    put(f"end_{k}", str(end))
    for y in s.index:
        if 1997 <= y <= Y1:
            rows.append(dict(series=k, sector=sec, year=int(y), value=s[y], index_2011=100 * s[y] / s[YB],
                             QY_ref_index_2011=100 * ref[y] / ref[YB]))
for sec, ref in (("total", fd.Q_Y), ("nfc", rb.Q)):
    for b in (Y0, YB):
        put(f"idx{b % 100:02d}_QY_{sec}", 100 * ref[Y1] / ref[b], "{:.0f}")
syn = pd.DataFrame(rows)
syn.round(5).to_csv(OUTD / "synthesis_indexed_ratios.csv", index=False)

# style as deck B's build.py (the later deck); pre-2009 in grey as in both decks
INK, MUTED, GRID, WASH, CTX = "#1A1A1A", "#6B6B6B", "#E6E6E6", "#F0EFEC", "#C3C2B7"
BLUE, DARK = "#2A78D6", "#104281"
plt.rcParams.update({
    "font.family": "sans-serif", "font.size": 12, "axes.edgecolor": MUTED, "axes.linewidth": 0.8,
    "axes.spines.top": False, "axes.spines.right": False, "xtick.color": MUTED, "ytick.color": MUTED,
    "axes.labelcolor": INK, "text.color": INK, "figure.dpi": 100, "savefig.dpi": 200, "lines.linewidth": 2.0,
    "axes.grid": True, "axes.grid.axis": "y", "grid.color": GRID, "grid.linewidth": 0.7, "axes.axisbelow": True,
    "legend.frameon": False, "legend.fontsize": 11.5,
})
TITLES = {
    "DY": ("(a) D/Y = FCF / GVA", "total corporate (AHP)"),
    "PAY": ("(b) Payout / GVA", "NFC; div. + net buybacks"),
    "BHY": ("(c) Skilled pay $B_H$ / GVA", "total corp. × KLEMS; to 2023"),
    "ZETA": (r"(d) Funding ratio $\zeta$", "US; Q / (Q + NFA)"),
    "XQ": ("(e) RoW equity quantity / GVA", "US equity held by RoW; nominal GVA"),
    "DEBT": ("(f) Debt / GVA", "NFC; debt securities + loans"),
    "KY": ("(g) K / GVA", "NFC; replacement cost"),
    "q": ("(h) Tobin's q = Q / K", "NFC"),
}
fig, axs = plt.subplots(2, 4, figsize=(13.4, 5.5), sharey=True, sharex=True, gridspec_kw=dict(wspace=0.16, hspace=0.5))
XMAX = Y1 + 10.5
for a, k in zip(axs.flat, SERIES):
    d = syn[syn.series == k].set_index("year")
    a.axvspan(1996.5, Y0 - 0.5, color=WASH, lw=0, zorder=0)
    a.axhline(100, color=MUTED, lw=0.7, zorder=1)
    a.plot(d.loc[:Y0].index, d.QY_ref_index_2011.loc[:Y0], color=CTX, lw=1.3, ls=(0, (4, 2)))
    a.plot(d.loc[Y0:].index, d.QY_ref_index_2011.loc[Y0:], color=INK, lw=1.4, ls=(0, (4, 2)))
    a.plot(d.loc[:Y0].index, d.index_2011.loc[:Y0], color=CTX, lw=2.0)
    a.plot(d.loc[Y0:].index, d.index_2011.loc[Y0:], color=BLUE, lw=2.4)
    if k == "ZETA":  # where the HKT tail would take zeta: zeta = 1
        lvl = 100 / z.zeta_sep[YB]
        a.axhline(lvl, color=BLUE, lw=0.9, ls=":")
        a.text(1997.2, lvl - 4, "ζ = 1", color=BLUE, fontsize=10.5, va="top")
    e = int(d.index.max())
    vr, vq = d.index_2011[e], d.QY_ref_index_2011[e]
    dyr, dyq = (0, 0)
    if abs(vr - vq) < 22:  # keep the two end labels apart
        dyr, dyq = (-7, 7) if vr < vq else (7, -7)
    a.annotate(f"{vr:.0f}", (e, vr), xytext=(4, dyr), textcoords="offset points", va="center", fontsize=11.5, color=BLUE, fontweight="bold")
    a.annotate(f"Q/Y {vq:.0f}", (e, vq), xytext=(4, dyq), textcoords="offset points", va="center", fontsize=10.5, color=INK)
    t, sec = TITLES[k]
    a.set_title(f"{t}\n", loc="left", fontsize=12)
    a.text(0, 1.035, sec, transform=a.transAxes, fontsize=10, color=MUTED, va="bottom")
    a.set_xlim(1996.5, XMAX)
    a.set_xticks([1997, 2009, 2025])
    a.tick_params(axis="x", labelsize=10.5)
    a.set_ylim(20, 235)
    a.set_yticks([50, 100, 150, 200])
axs[0, 0].text(1997.2, 228, "pre-2009:\ncontext", fontsize=9.5, color=MUTED, va="top")
from matplotlib.lines import Line2D

fig.legend([Line2D([], [], color=BLUE, lw=2.4), Line2D([], [], color=INK, lw=1.4, ls=(0, (4, 2)))],
           ["ratio named in the panel title (index, 2011 = 100)", "Q/Y of the same sector, 2011 = 100"],
           loc="lower center", ncol=2, bbox_to_anchor=(0.5, -0.035), handlelength=2.4, columnspacing=2.5)
fig.savefig(OUTF / "s_synthesis_indexed_ratios.pdf", bbox_inches="tight", facecolor="white")
plt.close(fig)

# ================================================================== 4. write the new values
with open(OUTD / "values_c.tex", "w") as fh:
    fh.write("% New numbers computed by scripts/build.py (synthesis figure, sector table); do not edit. Use \\vc{key}.\n")
    for k, v in VC.items():
        fh.write(f"\\expandafter\\def\\csname vc:{k}\\endcsname{{{v}}}\n")
(OUTD / "values_c.json").write_text(json.dumps(VC, indent=1))
print(f"new values: {len(VC)}")
for k in sorted(VC):
    if k.startswith(("idx", "rec_")):
        print(f"  {k:28s} {VC[k]}")

# ================================================================== 5. every value macro in the deck must be defined
if TEX.exists():
    src = re.sub(r"(?<!\\)%.*", "", TEX.read_text())
    if re.search(r"\\val\{", src):
        raise SystemExit("deck uses the un-namespaced \\val{}: use \\va, \\vb or \\vc")
    keys = {ns: set(re.findall(rf"\\{ns}\{{([^}}]+)\}}", src)) for ns in ("va", "vb", "vc")}
    have = {"va": VA, "vb": VB, "vc": VC}
    missing = {ns: sorted(k for k in ks if k not in have[ns]) for ns, ks in keys.items()}
    n = sum(len(v) for v in keys.values())
    if any(missing.values()):
        raise SystemExit(f"UNDEFINED value keys in {TEX.name}: {missing}")
    print(f"key check passed: {n} distinct keys ({', '.join(f'{ns} {len(k)}' for ns, k in keys.items())}), none undefined")
else:
    print(f"key check skipped: {TEX.name} not found", file=sys.stderr)
