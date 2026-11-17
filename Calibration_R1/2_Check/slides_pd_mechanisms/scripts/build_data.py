"""Build the tables and figures for slides_pd_mechanisms from saved outputs (read-only on inputs).

Main window: 2009–2025, the years identified with the unbalanced-growth (u) regime. 1990–2008 appears only as grey context.
Because 2009 FCF is a crisis spike (D/Y 14.4%, D/Q 7.4%), 2011 and 2013 bases are reported alongside 2009.

Run from this folder:
  uv run --no-project --python 3.12 --with numpy==2.3.5 --with pandas==2.2.3 --with matplotlib==3.10.0 python -I build_data.py
Inputs: ../../figures/figure_data.csv, ../../slides/data/*.csv, the mapping package (H headcount, cash-dividend yield),
and the Compustat extract in ../data/wrds (fetch_wrds.py). Outputs: ../data/*.csv, ../data/values.tex, ../figures/*.pdf|png.
Color rule: blue = data, orange = model, green = Compustat cohort objects, grey = pre-2009 context.
"""
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.ticker import FuncFormatter, NullFormatter, PercentFormatter

HERE = Path(__file__).resolve().parent
DECK = HERE.parent
CHECK = DECK.parent
PROJECT = CHECK.parents[2]
SD = CHECK / "slides" / "data"
MAPA = PROJECT / "Empirical_Data" / "Variable_mappings" / "Empirical_Mapping_Annual"
DATA, FIG = DECK / "data", DECK / "figures"
DATA.mkdir(exist_ok=True), FIG.mkdir(exist_ok=True)
Y0, Y1, YB = 2009, 2025, 2011   # main window, end, robustness base

C = dict(dC="#2A78D6", dD="#104281", dM="#5598E7", dL="#86B6EF", mC="#EB6834", mD="#A93F14", mL="#F2A07C",
         g="#1BAF7A", gD="#0E6E4C", mu="#898781", ctx="#C3C2B7", grid="#E1E0D9", ink="#0B0B0B", wash="#F0EFEC")
plt.rcParams.update({"font.size": 11, "axes.edgecolor": "#C3C2B7", "axes.spines.top": False, "axes.spines.right": False,
                     "axes.grid": True, "grid.color": C["grid"], "grid.linewidth": 0.5, "axes.axisbelow": True,
                     "legend.frameon": False, "figure.dpi": 150, "savefig.bbox": "tight", "lines.linewidth": 2.0})
pct = PercentFormatter(1.0, decimals=0); pct1 = PercentFormatter(1.0, decimals=1)
logfmt = FuncFormatter(lambda v, _: f"{v:g}")

def save(fig, name):
    fig.savefig(FIG / f"{name}.pdf"); fig.savefig(FIG / f"{name}.png", dpi=160); plt.close(fig)

def shade_pre(ax, x0=Y0):
    """Grey wash over the pre-window years and a marker line at the window start."""
    lo = ax.get_xlim()[0]
    ax.axvspan(lo, x0, color=C["wash"], zorder=0); ax.axvline(x0, color=C["ctx"], lw=0.9)

vals = {}
def V(k, v): vals[k] = v
def mult(s, a, b): return s.loc[b] / s.loc[a]
def gr(s, a, b): return 100 * (mult(s, a, b) ** (1 / (b - a)) - 1)

# ------------------------------------------------------------------ 1. core US corporate series (AHP mapping, nominal trn USD)
df = pd.read_csv(CHECK / "figures" / "figure_data.csv").set_index("year")
df["A_e"] = pd.read_csv(SD / "val_us.csv").set_index("year")["A_e"]
cy = pd.read_csv(MAPA / "Mechanism_Evidence_US_ROW" / "processed" / "corporate_yields.csv")
df["CASHDIV_EQ"] = cy[cy.variant == "US_CASH_DIVIDENDS_EQUITY"].set_index("year")["value"] / 100
df["D_e"], df["Q_e"], df["PROFIT_SHARE"], df["e_Y"] = df.FCF / df.COMP, df.Q / df.COMP, 1 - df.COMP / df.Y, df.COMP / df.Y
df["EL_Y_sept"] = pd.read_csv(SD / "vintage_liab.csv").set_index("year")["sept"]
df.to_csv(DATA / "t0_core_series.csv")

rows = []
for (a, b) in [(Y0, Y1), (2010, Y1), (YB, Y1), (2013, Y1)]:
    for k, lab in [("Q", "Q (EV)"), ("FCF", "D (FCF)"), ("Y", "Y (GVA)"), ("COMP", "e (COMP)")]:
        rows.append(dict(window=f"{a}-{b}", series=lab, multiple=mult(df[k], a, b), growth_pa=gr(df[k], a, b) / 100))
pd.DataFrame(rows).to_csv(DATA / "t1_multiples.csv", index=False)
for k in ["Q", "FCF", "Y", "COMP"]:
    V(f"mult{k}", mult(df[k], Y0, Y1)); V(f"gr{k}", gr(df[k], Y0, Y1)); V(f"multB{k}", mult(df[k], YB, Y1)); V(f"grB{k}", gr(df[k], YB, Y1))
V("gapDe09", gr(df.FCF, Y0, Y1) - gr(df.COMP, Y0, Y1)); V("gapDe11", gr(df.FCF, YB, Y1) - gr(df.COMP, YB, Y1))
V("Demin", 100 * df.loc[Y0:Y1, "D_e"].min()); V("Demax", 100 * df.loc[Y0:Y1, "D_e"].max())

t2 = pd.DataFrame({y: {k: df.loc[y, k] for k in ["D_Q", "CASHDIV_EQ", "D_e", "D_Y", "Q_Y", "Q_e", "A_e", "PROFIT_SHARE", "EL_Y_sept"]} for y in [Y0, 2011, 2013, 2019, 2024, Y1]}).T
t2.index.name = "year"; t2.to_csv(DATA / "t2_ratios.csv")
for y in [Y0, 2010, 2011, 2013, 2015, 2019, Y1]:
    for k in ["D_Q", "CASHDIV_EQ", "D_e", "D_Y", "PROFIT_SHARE"]: V(f"{k}{y}", 100 * df.loc[y, k])
    for k in ["Q_e", "A_e", "Q_Y", "EL_Y_sept"]: V(f"{k}{y}", df.loc[y, k])
V("ELYmult", mult(df.EL_Y_sept, Y0, Y1)); V("DYmult", mult(df.D_Y, Y0, Y1)); V("eYmult", mult(df.e_Y, Y0, Y1)); V("ELYmult11", mult(df.EL_Y_sept, YB, Y1)); V("DYmult11", mult(df.D_Y, YB, Y1))

# f01: multiples, 2009 = 1, pre-window grey
fig, ax = plt.subplots(figsize=(6.6, 4.3))
for k, lab, col in [("Q", "Q: enterprise value", C["dD"]), ("FCF", "D: free cash flow", C["dC"]), ("Y", "Y: corporate GVA", C["dM"]), ("COMP", "e: compensation", C["dL"])]:
    s = df[k] / df.loc[Y0, k]; ax.plot(s.loc[:Y0].index, s.loc[:Y0], color=C["ctx"], lw=1.4); ax.plot(s.loc[Y0:].index, s.loc[Y0:], color=col, label=lab)
    ax.annotate(f"×{s.loc[Y1]:.1f}", (Y1 + 0.3, s.loc[Y1]), va="center", fontsize=10, color=col)
ax.set_yscale("log"); ax.set_yticks([0.25, 0.5, 1, 2, 4]); ax.yaxis.set_major_formatter(logfmt); ax.yaxis.set_minor_formatter(NullFormatter())
ax.set_xlim(1990, 2028); shade_pre(ax); ax.set_ylabel("Index, 2009 = 1 (log scale)"); ax.legend(loc="upper left", fontsize=9.5)
save(fig, "f01_multiples")

# f02: D/e and the yields
fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.4, 4.2))
for ax_, cols in [(a1, [("D_e", "D/e: FCF / compensation", C["dD"]), ("D_Y", "D/Y: FCF / GVA", C["dC"]), ("PROFIT_SHARE", "(Y−COMP)/Y: non-labor share", C["dL"])]),
                  (a2, [("D_Q", "FCF / EV (model D/Q)", C["dD"]), ("CASHDIV_EQ", "Cash dividends / market equity", C["dM"])])]:
    for k, lab, col in cols:
        ax_.plot(df.loc[:Y0].index, df.loc[:Y0, k], color=C["ctx"], lw=1.4); ax_.plot(df.loc[Y0:].index, df.loc[Y0:, k], color=col, label=lab)
    ax_.set_xlim(1990, 2026); shade_pre(ax_)
a1.yaxis.set_major_formatter(pct); a1.set_ylim(0, 0.5); a1.legend(fontsize=9.5, loc="upper left"); a1.set_title("D/e has no trend toward zero in the window", fontsize=11, loc="left")
a2.yaxis.set_major_formatter(pct1); a2.set_ylim(0, 0.09); a2.legend(fontsize=9.5); a2.set_title("The yield falls, through Q", fontsize=11, loc="left")
save(fig, "f02_de_dq")

# f03: decomposition of Δlog(Q/D), windows inside 2009–2025, plus the model rows
dec_rows = []
for (a, b) in [(Y0, Y1), (YB, Y1), (2013, Y1)]:
    qy, dy = np.log(mult(df.Q_Y, a, b)), np.log(mult(df.D_Y, a, b))
    dec_rows.append(dict(label=f"Data {a}–{b}", kind="data", qy=qy, dy=dy, total=qy - dy))
dm = pd.read_csv(SD / "decomp_model.csv")
for _, r in dm.iterrows(): dec_rows.append(dict(label=r.label.replace("$", "").replace("\\nu_u", "ν").replace("Model notebook 06; t=1--16", "Model nb06, t=1–16").replace("; t=1--80", ", t=1–80"), kind="model", qy=r.qy, dy=r.dy, total=r.total))
dec = pd.DataFrame(dec_rows); dec.to_csv(DATA / "t3_decomposition.csv", index=False)
for (a, b) in [(Y0, Y1), (YB, Y1), (2013, Y1)]:
    r = dec[dec.label == f"Data {a}–{b}"].iloc[0]; V(f"decQD{a}", r.total); V(f"decQY{a}", r.qy); V(f"decDY{a}", -r.dy); V(f"decShare{a}", 100 * r.qy / r.total)
fig, ax = plt.subplots(figsize=(7.4, 4.3))
ypos = np.arange(len(dec))[::-1]
for i, (_, r) in enumerate(dec.iterrows()):
    cq, cd = (C["dC"], C["dL"]) if r.kind == "data" else (C["mC"], C["mL"])
    ax.barh(ypos[i] + 0.18, r.qy, height=0.34, color=cq); ax.barh(ypos[i] - 0.18, -r.dy, height=0.34, color=cd); ax.plot([r.total], [ypos[i]], marker="D", color=C["ink"], ms=6, ls="none")
ax.set_yticks(ypos); ax.set_yticklabels(dec.label, fontsize=9.5); ax.axvline(0, color=C["mu"], lw=0.8)
ax.set_xlabel("Δlog contributions: Q/Y (dark), −D/Y (light); diamond = Δlog(Q/D)"); ax.set_xlim(-1.3, 3.0); save(fig, "f03_decomp")

# f04: funding side
fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.4, 4.2))
a1.axhspan(0, 1, color=C["wash"]); 
for k, lab, col in [("Q_e", "Q / e", C["dC"]), ("A_e", "Implied β = (Q + NFA)/e", C["dD"])]:
    a1.plot(df.loc[:Y0].index, df.loc[:Y0, k], color=C["ctx"], lw=1.4); a1.plot(df.loc[Y0:].index, df.loc[Y0:, k], color=col, label=lab)
a1.axhline(0.45, color=C["mC"], lw=1.6, ls="--", label="Model β = 0.45 (cap: Q ≤ βe)"); a1.set_xlim(1990, 2026); a1.axvline(Y0, color=C["ctx"], lw=0.9)
a1.set_ylim(0, 9); a1.legend(fontsize=9.5, loc="upper left"); a1.set_title("Equity value vs one cohort's wage income", fontsize=11, loc="left")
sub = df.loc[Y0:Y1]
a2.plot(sub.index, sub.EL_Y_sept / sub.EL_Y_sept.loc[Y0], color=C["dD"], label="Foreign-held US equity / Y")
a2.plot(sub.index, sub.D_Y / sub.D_Y.loc[Y0], color=C["dC"], label="D / Y"); a2.plot(sub.index, sub.e_Y / sub.e_Y.loc[Y0], color=C["dL"], label="e / Y")
a2.set_xticks([2009, 2013, 2017, 2021, 2025]); a2.set_ylim(0.4, 3.2); a2.legend(fontsize=9.5, loc="upper left"); a2.set_ylabel("Index, 2009 = 1"); a2.set_title("Foreign demand grows; D/Y does not", fontsize=11, loc="left")
save(fig, "f04_funding")

# ------------------------------------------------------------------ 2. free entry and implied research productivity, 2009–2022
fe = pd.read_csv(SD / "free_entry_data.csv").set_index("year")
H = pd.read_csv(MAPA / "data_intermediate" / "labor_wages.csv").query("mapping_id == 'H_US_COLLEGE_EQUIV'").set_index("year")["value"] / 1e6
fe["H_mn"] = H; fe["a_raw"] = fe.BH_Q / fe.H_mn; fe["a_idx"] = fe.a_raw / fe.a_raw.loc[Y0]; fe["bjvw"] = np.exp(-0.051 * (fe.index - Y0))
fe.to_csv(DATA / "t5_free_entry.csv")
sub = fe.loc[Y0:2022]; slope = np.polyfit(sub.index, np.log(sub.a_idx), 1)[0]
V("aSlope", 100 * slope); V("aIdx2022", fe.a_idx.loc[2022]); V("QwH0922", fe.Q_wH_idx.loc[2022] / fe.Q_wH_idx.loc[Y0]); V("BHQ2009", fe.BH_Q.loc[Y0]); V("BHQ2022", fe.BH_Q.loc[2022])
V("Hmult", mult(H, Y0, 2024)); V("Hgr", gr(H, Y0, 2024))
fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.4, 4.2))
a1.plot(fe.loc[:Y0].index, fe.loc[:Y0, "BH_Q"], color=C["ctx"], lw=1.4); a1.plot(fe.loc[Y0:].index, fe.loc[Y0:, "BH_Q"], color=C["dD"], label="B_H/Q = aH/G (data)")
a1.set_ylim(0, 0.15); a1.yaxis.set_major_formatter(pct); a1.set_xlim(1995, 2023); a1.axvline(Y0, color=C["ctx"], lw=0.9)
a1b = a1.twinx(); q = fe.Q_wH_idx / fe.Q_wH_idx.loc[Y0]; a1b.plot(q.loc[:Y0].index, q.loc[:Y0], color=C["ctx"], lw=1.4); a1b.plot(q.loc[Y0:].index, q.loc[Y0:], color=C["dC"], label="Q/w_H, 2009 = 1 (right)"); a1b.set_ylim(0, 3.0); a1b.grid(False)
h1, l1 = a1.get_legend_handles_labels(); h2, l2 = a1b.get_legend_handles_labels(); a1.legend(h1 + h2, l1 + l2, fontsize=9.5, loc="upper left"); a1.set_title("Free entry: price vs replication cost", fontsize=11, loc="left")
a2.plot(fe.loc[:Y0].index, fe.loc[:Y0, "a_idx"], color=C["ctx"], lw=1.4); a2.plot(fe.loc[Y0:].index, fe.loc[Y0:, "a_idx"], color=C["dD"], label="Implied a ∝ (B_H/Q)/H, 2009 = 1")
a2.plot(fe.loc[Y0:].index, fe.loc[Y0:, "bjvw"], color=C["mu"], ls="--", label="−5.1%/yr: BJVW research productivity")
a2.set_yscale("log"); a2.set_yticks([0.3, 0.5, 0.7, 1, 1.5]); a2.yaxis.set_major_formatter(logfmt); a2.yaxis.set_minor_formatter(NullFormatter()); a2.set_xlim(1995, 2023); a2.axvline(Y0, color=C["ctx"], lw=0.9)
a2.legend(fontsize=9.5, loc="lower left"); a2.set_title(f"Implied research productivity, 2009–2022 trend {100*slope:+.1f}%/yr", fontsize=11, loc="left")
save(fig, "f05_free_entry")

# ------------------------------------------------------------------ 3. R&D share: data vs model (unchanged: data are 2009–2024 already)
rd = pd.read_csv(SD / "rd_data.csv").set_index("year")
sw = pd.read_csv(SD / "sweep_rd_share.csv").set_index("t"); sw175 = pd.read_csv(SD / "sweep_rd_share_nu175.csv").set_index("t")
fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.4, 4.2))
for k, lab_, col in [("nscg", "NSCG RD1 share of for-profit BA+", C["dD"]), ("labor_cost_cps", "BERD labor cost / skilled bill (CPS premium)", C["dC"]),
                     ("labor_cost_acs", "BERD labor cost / skilled bill (ACS premium)", C["dM"]), ("personnel", "BERD R&D personnel / H", C["dL"]), ("researchers", "BERD researchers / H", "#B9D4F5")]:
    s = rd[k].dropna(); a1.plot(s.index, s, marker="o", ms=3.5, color=col, label=lab_)
a1.set_ylim(0, 0.14); a1.yaxis.set_major_formatter(pct); a1.set_xlim(2009, 2024.5); a1.legend(fontsize=8.6, loc="upper left"); a1.set_title("Data: 1−φ stays at 3–10%", fontsize=11, loc="left")
for k, lab_, col in [("nu075", "ν_u = 0.75", C["mD"]), ("nu100", "ν_u = 1.00", C["mC"]), ("nu125", "ν_u = 1.25", C["mL"])]: a2.plot(sw.index, sw[k], color=col, label=lab_)
a2.plot(sw175.index, sw175.nu175, color=C["mu"], label="ν_u = 1.75 (to T=30)")
a2.set_ylim(0, 1.02); a2.yaxis.set_major_formatter(pct); a2.set_xlabel("Model period t"); a2.legend(fontsize=9.5, loc="upper left"); a2.set_title("Model: 1−φ goes to 1 (or to 0)", fontsize=11, loc="left")
save(fig, "f06_rd_share")
V("nscg2010", 100 * rd.nscg.loc[2010]); V("nscg2023", 100 * rd.nscg.loc[2023]); V("lccps2015", 100 * rd.labor_cost_cps.loc[2015]); V("lccps2023", 100 * rd.labor_cost_cps.loc[2023])

# ------------------------------------------------------------------ 4. yield identity: the R&D share each reading needs, by base year
share = np.linspace(0.005, 0.60, 600); phi = 1 - share
def required(y0, r0=0.07):
    ratio = df.loc[Y1, "D_Q"] / df.loc[y0, "D_Q"]; k = (1 - r0) / r0
    return dict(base=y0, yield_base=df.loc[y0, "D_Q"], yield_2025=df.loc[Y1, "D_Q"], reqA=1 - (1 - r0) * ratio, reqB=1 / (1 + k * ratio))
t6 = pd.DataFrame([required(y) for y in [Y0, 2010, YB, 2013, 2015]]); t6.to_csv(DATA / "t6_yield_identity_required.csv", index=False)
for _, r in t6.iterrows(): V(f"reqA{int(r.base)}", 100 * r.reqA); V(f"reqB{int(r.base)}", 100 * r.reqB)
ANCH = 2013; ya, phia = df.loc[ANCH, "D_Q"], 0.93
yA = ya * phi / phia; yB = ya * (phi / (1 - phi)) / (phia / (1 - phia))
pd.DataFrame(dict(rd_share=share, yield_fixed_aH=yA, yield_fixed_G=yB)).to_csv(DATA / "t6_yield_identity_curves.csv", index=False)
fig, ax = plt.subplots(figsize=(7.2, 4.3))
ax.plot(share, yA, color=C["mC"], label="Reading A (HKT): a, H fixed ⇒ D/Q ∝ φ"); ax.plot(share, yB, color=C["dC"], label="Reading B: G fixed ⇒ D/Q ∝ φ/(1−φ)")
for yv, txt in [(df.loc[2010, "D_Q"], "2010 yield 5.9%"), (df.loc[Y1, "D_Q"], "2025 yield 2.7%")]:
    ax.axhline(yv, color=C["mu"], lw=0.9, ls=":"); ax.annotate(txt, (0.42, yv), xytext=(0, 4), textcoords="offset points", fontsize=9, color=C["mu"])
ax.plot([0.07], [ya], "o", color=C["ink"], ms=6); ax.annotate(f"anchor {ANCH}: 7%, {100*ya:.1f}%", (0.07, ya), xytext=(6, 6), textcoords="offset points", fontsize=9)
rA, rB = t6.set_index("base").loc[ANCH, ["reqA", "reqB"]]
ax.plot([rA], [df.loc[Y1, "D_Q"]], "o", color=C["mC"], ms=6); ax.annotate(f"A needs {100*rA:.0f}%", (rA, df.loc[Y1, "D_Q"]), xytext=(6, -14), textcoords="offset points", fontsize=9, color=C["mC"])
ax.plot([rB], [df.loc[Y1, "D_Q"]], "o", color=C["dC"], ms=6); ax.annotate(f"B needs {100*rB:.0f}%", (rB, df.loc[Y1, "D_Q"]), xytext=(6, -14), textcoords="offset points", fontsize=9, color=C["dC"])
rA10, rB10 = t6.set_index("base").loc[2010, ["reqA", "reqB"]]
ax.annotate(f"from a 2010 base: A {100*rA10:.0f}%, B {100*rB10:.0f}%", (0.42, df.loc[2010, "D_Q"]), xytext=(0, -13), textcoords="offset points", fontsize=9, color=C["mu"])
ax.set_xlim(0, 0.60); ax.set_ylim(0, 0.08); ax.xaxis.set_major_formatter(pct); ax.yaxis.set_major_formatter(pct1)
ax.set_xlabel("R&D share of skilled labor, 1−φ"); ax.set_ylabel("Dividend yield D/Q"); ax.legend(fontsize=9.5, loc="upper right"); save(fig, "f09_yield_identity")

# table: free-entry implied knowledge growth and the markup implied by the yield
rows = []
for y in [2010, 2013, 2015, 2019, 2022, 2024]:
    for r in [0.05, 0.07, 0.10]:
        BH, Q, D = df.loc[y, "B_H"], df.loc[y, "Q"], df.loc[y, "FCF"]; I = r * BH; G = Q / (Q - I)
        rows.append(dict(year=y, rd_share=r, BH_Q=BH / Q, G_minus_1=G - 1, mu_implied=1 + (D / Q) / ((1 - r) / r * (G - 1) / G)))
t7 = pd.DataFrame(rows); t7.to_csv(DATA / "t7_free_entry_levels.csv", index=False)
s7 = t7[t7.rd_share == 0.07].set_index("year")
for y in [2010, 2013, 2015, 2019, 2022, 2024]: V(f"BHQ{y}", s7.loc[y, "BH_Q"]); V(f"G07_{y}", 100 * s7.loc[y, "G_minus_1"]); V(f"mu07_{y}", s7.loc[y, "mu_implied"])
post = t7[t7.year >= 2013]; V("Gmin", 100 * post.G_minus_1.min()); V("Gmax", 100 * post.G_minus_1.max()); V("mumin", post.mu_implied.min()); V("mumax", post.mu_implied.max())

# ------------------------------------------------------------------ 5. Compustat: incumbent cohorts 2009/2010/2011, payout, supply of claims
f = pd.read_csv(DECK / "data" / "wrds" / "funda_us_1989_2024.csv.gz"); co = pd.read_csv(DECK / "data" / "wrds" / "company_us.csv.gz")
f = f.sort_values(["gvkey", "fyear", "at"]).drop_duplicates(["gvkey", "fyear"], keep="last"); f["me"] = f.csho * f.prcc_f
for k in ["dvt", "dvc", "prstkc", "sstk", "oancf", "capx"]: f[k + "0"] = f[k].fillna(0)
f["netpay"] = f.dvt0 + f.prstkc0 - f.sstk0; f["fcf"] = f.oancf0 - f.capx0; f["netiss"] = f.sstk0 - f.prstkc0
f = f.merge(co[["gvkey", "sic"]], on="gvkey", how="left")
def agg(d):
    g = d.groupby("fyear").agg(n=("gvkey", "nunique"), dvt=("dvt0", "sum"), dvc=("dvc0", "sum"), netpay=("netpay", "sum"), fcf=("fcf", "sum"), me=("me", "sum"), netiss=("netiss", "sum"), buyback=("prstkc0", "sum"), issue=("sstk0", "sum"))
    return g / np.array([1, 1e3, 1e3, 1e3, 1e3, 1e3, 1e3, 1e3, 1e3])  # USD bn, counts
allf = agg(f); allf["dvt_me"], allf["netpay_me"], allf["netiss_me"] = allf.dvt / allf.me, allf.netpay / allf.me, allf.netiss / allf.me
allf["n_listed_nyse_amex_nasdaq"] = f[f.exchg.isin([11, 12, 14]) & (f.me > 0)].groupby("fyear").gvkey.nunique(); allf["n_priced"] = f[f.me > 0].groupby("fyear").gvkey.nunique()
allf.to_csv(DATA / "t8_compustat_all_firms.csv")
COMPn = df.COMP
summ, cohorts = [], {}
for y0 in [Y0, 2010, YB]:
    ids = set(f[(f.fyear == y0) & (f["at"] > 0)].gvkey); g = agg(f[f.gvkey.isin(ids)]).loc[y0:2024]
    for k in ["dvt", "netpay", "fcf", "me"]: g[k + "_idx"] = g[k] / g.loc[y0, k]
    g["comp_idx"] = (COMPn / COMPn.loc[y0]).reindex(g.index); g["Q_idx"] = (df.Q / df.Q.loc[y0]).reindex(g.index); g["all_dvt_idx"] = (allf.dvt / allf.dvt.loc[y0]).reindex(g.index); g["all_me_idx"] = (allf.me / allf.me.loc[y0]).reindex(g.index)
    g["dvt_me"], g["netpay_me"], g["share_dvt"], g["share_me"] = g.dvt / g.me, g.netpay / g.me, g.dvt / allf.dvt.reindex(g.index), g.me / allf.me.reindex(g.index)
    g.to_csv(DATA / f"t9_cohort_{y0}.csv"); cohorts[y0] = g; T = 2024 - y0
    summ.append(dict(cohort=y0, n0=int(g.loc[y0, "n"]), n2024=int(g.loc[2024, "n"]), dvt_mult=g.loc[2024, "dvt_idx"], netpay_mult=g.loc[2024, "netpay_idx"], fcf_mult=g.loc[2024, "fcf_idx"], me_mult=g.loc[2024, "me_idx"],
                     comp_mult=g.loc[2024, "comp_idx"], Q_ahp_mult=g.loc[2024, "Q_idx"], all_dvt_mult=g.loc[2024, "all_dvt_idx"], all_me_mult=g.loc[2024, "all_me_idx"],
                     dvt_gr=g.loc[2024, "dvt_idx"] ** (1 / T) - 1, netpay_gr=g.loc[2024, "netpay_idx"] ** (1 / T) - 1, comp_gr=g.loc[2024, "comp_idx"] ** (1 / T) - 1, me_gr=g.loc[2024, "me_idx"] ** (1 / T) - 1,
                     dvt_me0=g.loc[y0, "dvt_me"], dvt_me2024=g.loc[2024, "dvt_me"], share_dvt2024=g.loc[2024, "share_dvt"], share_me2024=g.loc[2024, "share_me"]))
ts = pd.DataFrame(summ); ts.to_csv(DATA / "t9_cohort_summary.csv", index=False)
for _, r in ts.iterrows():
    c = int(r.cohort)
    for k in ["dvt_mult", "netpay_mult", "fcf_mult", "me_mult", "comp_mult", "Q_ahp_mult", "all_dvt_mult", "all_me_mult", "n0", "n2024"]: V(f"c{c}{k}", r[k])
    for k in ["dvt_gr", "netpay_gr", "comp_gr", "me_gr", "dvt_me0", "dvt_me2024", "share_dvt2024", "share_me2024"]: V(f"c{c}{k}", 100 * r[k])
w = allf.loc[Y0:2024]
V("allNlisted2009", allf.loc[Y0, "n_listed_nyse_amex_nasdaq"]); V("allNlisted2024", allf.loc[2024, "n_listed_nyse_amex_nasdaq"]); V("allNlistedMin", w.n_listed_nyse_amex_nasdaq.min()); V("allNlistedMinYear", int(w.n_listed_nyse_amex_nasdaq.idxmin()))
V("netissMean", 100 * w.netiss_me.mean()); V("netissNegYears", int((w.netiss < 0).sum())); V("netissYears", int(len(w))); V("buyback2024", allf.loc[2024, "buyback"]); V("issue2024", allf.loc[2024, "issue"])
V("buybackCum", w.buyback.sum() / 1e3); V("issueCum", w.issue.sum() / 1e3)  # trn USD
V("allDvtMe2009", 100 * allf.loc[Y0, "dvt_me"]); V("allDvtMe2024", 100 * allf.loc[2024, "dvt_me"]); V("allMeMult", mult(allf.me, Y0, 2024))

g9 = cohorts[Y0]
fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.4, 4.2))
a1.plot(g9.index, g9.comp_idx, color=C["dD"], label="e: corporate compensation (AHP)"); a1.plot(g9.index, g9.dvt_idx, color=C["g"], label="2009 cohort: cash dividends")
a1.plot(g9.index, g9.netpay_idx, color=C["gD"], ls="--", label="2009 cohort: net payout (div + buybacks − issuance)"); a1.plot(g9.index, g9.me_idx, color=C["g"], ls=":", label="2009 cohort: market equity")
a1.plot(g9.index, g9.all_dvt_idx, color=C["dL"], label="All Compustat firms: cash dividends")
a1.set_yscale("log"); a1.set_yticks([1, 2, 4, 8]); a1.yaxis.set_major_formatter(logfmt); a1.yaxis.set_minor_formatter(NullFormatter()); a1.set_xticks([2009, 2012, 2015, 2018, 2021, 2024])
a1.set_ylabel("Index, 2009 = 1 (log)"); a1.legend(fontsize=8.6, loc="upper left"); a1.set_title("Incumbents' dividends outgrow e", fontsize=11, loc="left")
a2.plot(g9.index, g9.dvt_me, color=C["g"], label="2009 cohort: dividends / market equity"); a2.plot(w.index, w.dvt_me, color=C["dL"], label="All Compustat firms"); a2.plot(df.loc[Y0:2024].index, df.loc[Y0:2024, "D_Q"], color=C["dD"], label="AHP: FCF / EV")
a2.yaxis.set_major_formatter(pct1); a2.set_ylim(0, 0.08); a2.set_xticks([2009, 2012, 2015, 2018, 2021, 2024]); a2.legend(fontsize=9.5); a2.set_title("Cohort yield falls as its price rises", fontsize=11, loc="left")
save(fig, "f07_cohort")
fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.4, 4.2))
for y0, col in [(2010, C["gD"]), (YB, C["g"])]:
    g = cohorts[y0]; a1.plot(g.index, g.dvt_idx, color=col, label=f"{y0} cohort: cash dividends"); a1.plot(g.index, g.netpay_idx, color=col, ls="--", label=f"{y0} cohort: net payout"); a1.plot(g.index, g.comp_idx, color=C["dD"], lw=1.4, label="e (AHP)" if y0 == 2010 else None)
a1.set_ylim(0.7, 8); a1.set_yscale("log"); a1.set_yticks([1, 2, 4, 8]); a1.yaxis.set_major_formatter(logfmt); a1.yaxis.set_minor_formatter(NullFormatter()); a1.set_xticks([2010, 2013, 2016, 2019, 2022])
a1.legend(fontsize=8.6, loc="upper left"); a1.set_ylabel("Index, base year = 1 (log)"); a1.set_title("2010 and 2011 cohorts: the same picture", fontsize=11, loc="left")
a2.plot(g9.index, g9.share_dvt, color=C["g"], label="2009 cohort share of all-firm dividends"); a2.plot(g9.index, g9.share_me, color=C["gD"], ls="--", label="2009 cohort share of all-firm market equity")
a2.yaxis.set_major_formatter(pct); a2.set_ylim(0, 1.05); a2.set_xticks([2009, 2012, 2015, 2018, 2021, 2024]); a2b = a2.twinx(); a2b.plot(g9.index, g9.n, color=C["mu"], lw=1.2, label="Surviving firms (right)"); a2b.set_ylim(0, 7000); a2b.grid(False)
h1, l1 = a2.get_legend_handles_labels(); h2, l2 = a2b.get_legend_handles_labels(); a2.legend(h1 + h2, l1 + l2, fontsize=9, loc="lower left"); a2.set_title("Exits shrink the cohort, not its payout", fontsize=11, loc="left")
save(fig, "f07b_cohort_more")
fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.4, 4.2))
a1.bar(w.index, w.netiss_me, color=[C["dC"] if v < 0 else C["dL"] for v in w.netiss_me]); a1.axhline(0, color=C["mu"], lw=0.8); a1.set_xticks([2009, 2012, 2015, 2018, 2021, 2024])
a1.yaxis.set_major_formatter(pct1); a1.set_title("Net equity issuance / market equity, all Compustat US firms", fontsize=11, loc="left"); a1.set_ylabel("(issuance − repurchases) / market equity")
a2.plot(w.index, w.n_listed_nyse_amex_nasdaq, color=C["dD"], label="NYSE, AMEX, Nasdaq with a year-end price"); a2.plot(w.index, w.n_priced, color=C["dL"], label="Any exchange with a year-end price")
a2.set_ylim(0, 10000); a2.set_xticks([2009, 2012, 2015, 2018, 2021, 2024]); a2.legend(fontsize=9.5, loc="lower right"); a2.set_title("Listed US firms in Compustat", fontsize=11, loc="left")
save(fig, "f08_supply")

# ------------------------------------------------------------------ 6. values.tex
def fmt(k, v):
    if isinstance(v, (int, np.integer)): return f"{v:,}"
    if float(v).is_integer() and abs(v) >= 100: return f"{v:,.0f}"
    if abs(v) >= 100: return f"{v:,.0f}"
    return f"{v:.1f}" if abs(v) >= 2 else f"{v:.2f}"
(DATA / "values.tex").write_text("% generated by build_data.py; use \\val{key} in the deck\n" + "".join(f"\\expandafter\\def\\csname v:{k}\\endcsname{{{fmt(k, v)}}}\n" for k, v in vals.items()))
json.dump({k: (float(v) if not isinstance(v, (int, np.integer)) else int(v)) for k, v in vals.items()}, open(DATA / "values.json", "w"), indent=1)
print(json.dumps({k: round(float(v), 3) for k, v in vals.items()}, indent=0))
