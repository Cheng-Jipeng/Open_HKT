"""Data-only figures, 1990-2025 (no model moments). Read-only on the data folders.

Run from this folder:
  uv run --no-project --python 3.12 --with numpy==2.3.5 --with pandas==2.2.3 --with matplotlib==3.10.0 python -B make_figures.py
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.lines import Line2D
from matplotlib.patches import Patch
from matplotlib.ticker import FuncFormatter, MultipleLocator

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[3]
MAP = PROJECT / "Empirical_Data" / "Variable_mappings" / "Empirical_Mapping_Annual" / "data_intermediate"
VINTAGE = "latest_official_2026-09-14"  # September 2026 release for external positions
SKILL = PROJECT / "Empirical_Data" / "Skill_Premium_and_RD_Share_2026-10-26" / "data"
KLEMS = PROJECT / "Empirical_Data" / "BEA_BLS_KLEMS_2026-04-27" / "processed" / "college_compensation_aggregates.csv"

# ---------------------------------------------------------------- data (trillion USD, nominal)
corp = pd.read_csv(MAP / "us_corporate_external_corporate.csv")
assert corp.groupby(["mapping_id", "year"]).size().max() == 1
w = corp.pivot(index="year", columns="mapping_id", values="value") / 1e6
Y = w["Y_US_AHP_TOTAL_CORP_GVA"]
COMP = w["COMP_US_AHP_TOTAL_CORP"]
Q = w["Q_US_AHP_ENTERPRISE_VALUE_TOTAL_CORP"]
FCF = w["D_US_AHP_FCF_TOTAL_CORP"]
NCF = w["NET_CAPITAL_FORMATION_US_AHP_TOTAL_CORP"]
CFCTAX = Y - COMP - FCF - NCF

ext = pd.read_csv(MAP / "us_corporate_external_external.csv")
ext = ext[ext.vintage == VINTAGE]
assert ext.groupby(["mapping_id", "year"]).size().max() == 1
x = ext.pivot(index="year", columns="mapping_id", values="value") / 1e6
EL = x["EQUITY_LIABILITIES_ROW_IN_US_AHP_IMA"]  # foreign-held US equity
EA = x["EQUITY_ASSETS_US_IN_ROW_AHP_IMA"]  # US-held RoW equity

df = pd.DataFrame({"Y": Y, "COMP": COMP, "CFC_TAX": CFCTAX, "NCF": NCF, "FCF": FCF, "Q": Q, "EL": EL, "EA": EA})
df = df.loc[1990:2025].dropna()
assert len(df) == 36
assert abs((df.COMP + df.CFC_TAX + df.NCF + df.FCF) / df.Y - 1).max() < 1e-12
df["D_Q"], df["Q_Y"], df["D_Y"] = df.FCF / df.Q, df.Q / df.Y, df.FCF / df.Y

# Skilled / unskilled split of compensation (same bridge as the slides and R1):
# skilled = BA or more, unskilled = everyone else, private for-profit workers aged 16+, CPS headcounts.
# Share of the wage bill s = wH / (wH + L), with w the CPS composition-adjusted hourly premium,
# re-censored at the pre-2023 top code from 2003 on. Applied to national-accounts compensation.
lab = pd.read_csv(MAP / "labor_wages.csv").pivot_table(index="year", columns="mapping_id", values="value", aggfunc="first")
H_BA, L_NONBA = lab["H_US_COLLEGE_EQUIV"], lab["L_US_NONCOLLEGE"]
prem_pkg = lab["WHWL_US_CPS_COMPOSITION_ADJ_COLLEGE_NONCOLLEGE"]
prem_rec = pd.read_csv(SKILL / "derived" / "premium_variants.csv").set_index("year")["prem_recensor"]
prem = prem_rec.reindex(df.index).combine_first(prem_pkg.reindex(df.index))
s_cps = (prem * H_BA / (prem * H_BA + L_NONBA)).reindex(df.index)
df["PREMIUM"], df["H_SHARE_EMP"], df["S_SKILLED"] = prem, (H_BA / (H_BA + L_NONBA)).reindex(df.index), s_cps
df["B_H"], df["B_L"] = df.COMP * s_cps, df.COMP * (1 - s_cps)
assert abs(df.S_SKILLED[2022] - 0.495024) < 1e-5 and abs(df.S_SKILLED[1994] - 0.293412) < 1e-5
# alternatives: ACS annual-earnings premium (2009-2024), STEM occupations (2011-2024),
# and the BEA-BLS production account college share of private-industry labor compensation (1997-2024)
cand = pd.read_csv(SKILL / "derived" / "one_minus_phi_candidates.csv")
df["S_SKILLED_ACS"] = (cand[cand.premium == "acs_annual_compadj2009"].set_index("year").skilled_bill_nominal_T
                       .reindex(df.index) / df.COMP)
w_stem, h_stem, l_stem = lab["WHWL_US_CPS_RAW_MEAN_HOURLY_STEM"], lab["H_US_STEM_OCC"], lab["L_US_NON_STEM"]
df["S_SKILLED_STEM"] = (w_stem * h_stem / (w_stem * h_stem + l_stem)).reindex(df.index)
kl = pd.read_csv(KLEMS)
kl = kl[kl["aggregate"] == "private_industries"].set_index("year")
df["S_SKILLED_KLEMS"] = kl.college_share_of_labor_comp.reindex(df.index)
assert abs(df.S_SKILLED_KLEMS[2022] - 0.573) < 1e-3 and df.S_SKILLED_KLEMS.notna().sum() == 28
df.round(6).to_csv(HERE / "figure_data.csv")

# ---------------------------------------------------------------- style
INK, MUTED, GRID = "#1A1A1A", "#6B6B6B", "#E6E6E6"
C = {"COMP": "#C4C3B5", "B_L": "#DCDBD0", "B_H": "#8E8C78", "COMP_NA": "#C4C3B5", "CFC_TAX": "#8AB8EE", "NCF": "#2A78D6", "FCF": "#0F3F82"}
LAB = {"B_L": "Compensation, unskilled (no BA)", "B_H": "Compensation, skilled (BA or more)",
       "COMP_NA": "Compensation, split not available", "COMP": "Compensation", "CFC_TAX": "CFC and taxes", "NCF": "Net capital formation", "FCF": "FCF"}
C_EL, C_EA = "#C2255C", "#1F8A70"
LINE = "#2A78D6"
plt.rcParams.update({
    "font.family": "sans-serif", "font.size": 11, "axes.edgecolor": MUTED, "axes.linewidth": 0.8,
    "axes.spines.top": False, "axes.spines.right": False, "xtick.color": MUTED, "ytick.color": MUTED,
    "axes.labelcolor": INK, "text.color": INK, "figure.dpi": 100, "savefig.dpi": 200,
})


def finish(fig, name):
    fig.savefig(HERE / f"{name}.png", bbox_inches="tight", facecolor="white")
    fig.savefig(HERE / f"{name}.pdf", bbox_inches="tight", facecolor="white")
    plt.close(fig)


# ---------------------------------------------------------------- GVA decomposition, every year
SPLITS = {
    "cps": ("S_SKILLED", "skilled (BA or more)", "unskilled (no BA)",
            "skilled share of the wage bill = wH/(wH+L), CPS BA-or-more vs other private for-profit workers, "
            "w = composition-adjusted hourly premium (re-censored top code); 1994-2024 only.",
            "labor_wages.csv, Skill_Premium_and_RD_Share package"),
    "acs": ("S_SKILLED_ACS", "skilled (BA or more)", "unskilled (no BA)",
            "same bridge with the ACS annual-earnings premium (composition-adjusted, 2009 weights), which includes "
            "hours differences; CPS headcounts; 2009-2024 only.",
            "labor_wages.csv, Skill_Premium_and_RD_Share package"),
    "stem": ("S_SKILLED_STEM", "skilled (STEM occupations)", "unskilled (non-STEM)",
             "skilled share of the wage bill = wH/(wH+L), CPS STEM vs non-STEM occupations, w = raw mean hourly "
             "premium; 2011-2024 only. 2023-24 not re-censored for the CPS top-code change.",
             "labor_wages.csv, Skill_Premium_and_RD_Share package"),
    "klems": ("S_SKILLED_KLEMS", "skilled (college)", "unskilled (non-college)",
              "college share of labor compensation in private industries, BEA-BLS Integrated Industry-Level Production "
              "Account (April 2026), applied to AHP corporate compensation; 1997-2024 only.\n"
              "The production account covers noncorporate business and the self-employed. 2024 looks like a source break "
              "(college +19%, non-college -12% in one year); treat it as provisional.",
              "BEA-BLS KLEMS 1997-2024 workbook"),
}


def stack_figure(share: bool, name: str, split: str | None = None):
    scale = df.Y if share else pd.Series(1.0, index=df.index)
    sh = df[SPLITS[split][0]] if split else df.S_SKILLED
    have = sh.notna()
    parts = {"B_L": (df.COMP * (1 - sh)).fillna(0), "B_H": (df.COMP * sh).fillna(0), "COMP_NA": df.COMP.where(~have, 0.0)}
    lab_k = dict(LAB)
    if split:
        lab_k["B_H"], lab_k["B_L"] = "Compensation, " + SPLITS[split][1], "Compensation, " + SPLITS[split][2]
    keys = (["B_L", "B_H", "COMP_NA"] if split else ["COMP"]) + ["CFC_TAX", "NCF", "FCF"]
    fig, ax = plt.subplots(figsize=(14, 6.6))
    years = df.index.values
    bottom = pd.Series(0.0, index=df.index)
    for k in keys:
        v = parts.get(k, df.get(k)) / scale
        hatch = dict(hatch="////", edgecolor="white") if k == "COMP_NA" else dict(edgecolor="white")
        # stack positive and negative parts separately so a negative NCF (2009) is visible below zero
        pos = v.clip(lower=0)
        ax.bar(years, pos, bottom=bottom, width=0.72, color=C[k], linewidth=0.6, zorder=2, **hatch)
        bottom = bottom + pos
        neg = v.clip(upper=0)
        if (neg < 0).any():
            ax.bar(years, neg, width=0.72, color=C[k], edgecolor="white", linewidth=0.6, zorder=2)
    ax.axhline(0, color=MUTED, linewidth=0.8, zorder=1)
    ax.yaxis.grid(True, color=GRID, linewidth=0.8, zorder=0)
    ax.set_axisbelow(True)
    ax.set_xlim(1989.3, 2025.7)
    ax.set_xticks(years)
    ax.set_xticklabels([str(y) if y % 5 == 0 else "" for y in years])
    ax.tick_params(axis="x", length=3)
    if share:
        ax.set_ylim(-0.03, 1.03)
        ax.set_yticks([0, 0.25, 0.5, 0.75, 1.0])
        ax.set_yticklabels([f"{int(100 * t)}%" for t in ax.get_yticks()])
        ax.set_ylabel("Percent of corporate GVA")
        title = "US corporate GVA by use, percent of GVA"
    else:
        ax.set_ylim(-0.3, 19)
        ax.set_ylabel("Trillion USD, nominal")
        title = "US corporate GVA by use, trillion USD"
    ax.set_title(title, loc="left", fontsize=14, fontweight="bold", pad=34)
    handles = [Patch(facecolor=C[k], label=lab_k[k], hatch="////" if k == "COMP_NA" else None, edgecolor="white")
               for k in keys]
    ax.legend(handles=handles, loc="lower left", bbox_to_anchor=(0, 1.0), ncol=len(keys), frameon=False,
              fontsize=10, handlelength=1.4, columnspacing=1.4, borderaxespad=0.2)
    fig.text(0.125, 0.01,
             "Stack: GVA = compensation + (CFC + taxes) + net capital formation + AHP free cash flow. "
             "Net capital formation is negative in 2009 and drawn below zero.\n"
             + ("Compensation split: " + SPLITS[split][3] + "\n" if split else "")
             + "Source: us_corporate_external_corporate.csv" + ((", " + SPLITS[split][4] + ".") if split else "."),
             fontsize=8.5, color=MUTED, va="top")
    finish(fig, name)


stack_figure(True, "gva_decomposition_percent_1990_2025")
stack_figure(False, "gva_decomposition_values_1990_2025")
for key in SPLITS:
    stack_figure(True, f"gva_decomposition_skill_{key}_percent_1990_2025", split=key)
    stack_figure(False, f"gva_decomposition_skill_{key}_values_1990_2025", split=key)

# ---------------------------------------------------------------- skilled share of compensation, four measures
SHARE_LINES = [  # column, label, color
    ("S_SKILLED_KLEMS", "BEA-BLS production account, college (private industries)", "#0F3F82"),
    ("S_SKILLED_ACS", "ACS bridge, BA or more", "#EB6834"),
    ("S_SKILLED", "CPS bridge, BA or more", "#2A78D6"),
    ("S_SKILLED_STEM", "CPS bridge, STEM occupations", "#1F8A70"),
]
fig, ax = plt.subplots(figsize=(11, 6))
for col, label, color in SHARE_LINES:
    s = df[col].dropna()
    solid = s[s.index <= 2023] if col == "S_SKILLED_KLEMS" else s
    ax.plot(solid.index, solid.values, color=color, linewidth=2.2, zorder=3)
    if col == "S_SKILLED_KLEMS":  # 2024 drawn dashed with an open marker: likely source break
        ax.plot(s.index[-2:], s.values[-2:], color=color, linewidth=1.6, linestyle=(0, (3, 2)), zorder=3)
        ax.scatter([s.index[-1]], [s.values[-1]], s=40, facecolor="white", edgecolor=color, linewidth=1.6, zorder=4)
    below = col == "S_SKILLED_ACS"  # the ACS start sits just under the BEA-BLS line
    ax.annotate(f"{100 * s.values[0]:.0f}%", (s.index[0], s.values[0]), xytext=(-2, -7 if below else 7),
                textcoords="offset points", ha="left", va="top" if below else "bottom", fontsize=9.5, color=color)
    end = s[s.index <= 2023].iloc[-1] if col == "S_SKILLED_KLEMS" else s.iloc[-1]
    nudge = {"S_SKILLED_ACS": 0.012, "S_SKILLED_KLEMS": -0.012}.get(col, 0.0)  # keep the two close end labels apart
    ax.text(2024.6, end + nudge, label, ha="left", va="center", fontsize=10, color=color, fontweight="bold")
ax.annotate("2024: 64%,\nlikely source break", (2024, df.S_SKILLED_KLEMS[2024]), xytext=(2019.2, 0.665),
            fontsize=9, color="#0F3F82", ha="center", va="center",
            arrowprops=dict(arrowstyle="-", color="#0F3F82", lw=0.8, shrinkA=2, shrinkB=4))
ax.set_xlim(1993, 2025)
ax.set_ylim(0, 0.72)
ax.set_xticks(range(1995, 2026, 5))
ax.yaxis.set_major_locator(MultipleLocator(0.1))
ax.yaxis.set_major_formatter(FuncFormatter(lambda t, _: f"{100 * t:.0f}%"))
ax.yaxis.grid(True, color=GRID, linewidth=0.8, zorder=0)
ax.set_axisbelow(True)
ax.set_title("Skilled share of labor compensation, four measures", loc="left", fontsize=14, fontweight="bold", pad=12)
fig.text(0.125, 0.02,
         "BEA-BLS: college compensation over total labor compensation, private industries (excludes government), "
         "including the self-employed; April 2026 release.\n"
         "Bridges: wH/(wH+L) with CPS private for-profit headcounts. CPS: composition-adjusted hourly premium, "
         "re-censored top code. ACS: annual-earnings premium.\n"
         "STEM: raw mean hourly premium, 2023-24 not re-censored. Sources: BEA-BLS KLEMS 1997-2024 workbook, "
         "labor_wages.csv, Skill_Premium_and_RD_Share package.",
         fontsize=8.5, color=MUTED, va="top")
finish(fig, "skilled_share_of_compensation_measures")

# ---------------------------------------------------------------- D/Q, Q/Y, D/Y time series
WINDOWS = [(1990, 2025), (2007, 2025), (2009, 2024)]
MARK = [1990, 2007, 2009, 2024, 2025]
SERIES = {
    "D_Q": ("D/Q: free cash flow over enterprise value", True),
    "Q_Y": ("Q/Y: enterprise value over corporate GVA", False),
    "D_Y": ("D/Y: free cash flow over corporate GVA", True),
}


def draw_series(ax, key, compact=False):
    s = df[key]
    pct = SERIES[key][1]
    fmt = (lambda v: f"{100 * v:.1f}%") if pct else (lambda v: f"{v:.2f}")
    ax.plot(s.index, s.values, color=LINE, linewidth=2, zorder=3)
    ax.scatter(MARK, s[MARK], s=34, color=LINE, edgecolor="white", linewidth=1.2, zorder=4)
    top = s.max() * 1.42
    ax.set_ylim(0, top)
    below = {"D_Q": (2007, 2024), "Q_Y": (1990, 2009, 2024), "D_Y": (1990, 2007, 2024)}[key]
    for yr in MARK:
        above = yr not in below
        ha = {1990: "left", 2025: "right", 2024: "center", 2009: "left"}.get(yr, "center")
        ax.annotate(fmt(s[yr]), (yr, s[yr]), xytext=(0, 8 if above else -9), textcoords="offset points",
                    ha=ha, va="bottom" if above else "top", fontsize=9.5, color=INK)
    # the three windows used in the decomposition, drawn as brackets above the series
    for i, (a, b) in enumerate(WINDOWS):
        yb = top * (0.965 - 0.062 * i)
        ax.plot([a, b], [yb, yb], color=MUTED, linewidth=1.1, zorder=2)
        for e in (a, b):
            ax.plot([e, e], [yb - top * 0.012, yb + top * 0.012], color=MUTED, linewidth=1.1, zorder=2)
        change = s[b] / s[a]
        ax.text((a + b) / 2, yb + top * 0.008, f"{a}–{b}: ×{change:.2f}", ha="center", va="bottom",
                fontsize=8.5 if compact else 9, color=MUTED,
                bbox=dict(facecolor="white", edgecolor="none", pad=0.6))
    ax.yaxis.grid(True, color=GRID, linewidth=0.8, zorder=0)
    ax.set_axisbelow(True)
    ax.set_xlim(1989, 2026)
    ax.set_xticks(range(1990, 2026, 5))
    step = {"D_Q": 0.02, "Q_Y": 1.0, "D_Y": 0.05}[key]
    ax.yaxis.set_major_locator(MultipleLocator(step))
    if pct:
        ax.yaxis.set_major_formatter(FuncFormatter(lambda t, _: f"{100 * t:.0f}%"))
    ax.set_title(SERIES[key][0], loc="left", fontsize=12 if compact else 14, fontweight="bold", pad=10)


NOTE1 = ("US total corporate sector, annual. D = AHP free cash flow, Q = AHP enterprise value (year-end), "
         "Y = corporate GVA.\nBrackets: the three windows of the Q/D decomposition, with end value over start value. "
         "Source: us_corporate_external_corporate.csv.")
NOTE = NOTE1.replace("\n", " ")
for key in SERIES:
    fig, ax = plt.subplots(figsize=(10, 5.4))
    draw_series(ax, key)
    fig.text(0.125, 0.02, NOTE1, fontsize=8.5, color=MUTED, va="top")
    finish(fig, f"series_{key}_1990_2025")

fig, axes = plt.subplots(1, 3, figsize=(18, 5.2))
for ax, key in zip(axes, SERIES):
    draw_series(ax, key, compact=True)
fig.subplots_adjust(wspace=0.16)
fig.text(0.125, 0.03, NOTE, fontsize=8.5, color=MUTED, va="top")
finish(fig, "series_DQ_QY_DY_1990_2025")

print(df.loc[[1990, 2007, 2009, 2024, 2025], ["D_Q", "Q_Y", "D_Y", "EL", "EA", "Y"]].round(4))

# ---------------------------------------------------------------- contributions to nominal GVA growth, with the skill split
for a, b in [(2009, 2024), (1994, 2024)]:
    dY = df.Y[b] - df.Y[a]
    print(f"\n{a}-{b}: GVA {df.Y[a]:.2f} -> {df.Y[b]:.2f}, x{df.Y[b] / df.Y[a]:.2f}")
    for k in ["B_L", "B_H", "CFC_TAX", "NCF", "FCF"]:
        print(f"  {k:8s} d={df[k][b] - df[k][a]:5.2f}  share of dY {100 * (df[k][b] - df[k][a]) / dY:5.1f}%  "
              f"x{df[k][b] / df[k][a]:5.2f}  share of Y {100 * df[k][a] / df.Y[a]:5.1f}% -> {100 * df[k][b] / df.Y[b]:5.1f}%")
print(df.loc[[1994, 2007, 2009, 2019, 2022, 2024], ["PREMIUM", "H_SHARE_EMP", "S_SKILLED", "S_SKILLED_ACS", "S_SKILLED_STEM"]].round(3))

# ---------------------------------------------------------------- labor block, BEA-BLS production account (private industries)
# Data:     w_H H, w_L L = published college / non-college labor compensation, summed over private industries.
# Computed: labor input indexes, chained Tornqvist over industries (BEA_BLS_KLEMS build script).
# Anchor:   H, L levels set to CPS 2017 headcounts (BA+ / non-BA, private wage and salary incl. nonprofits, 16+).
# Derived:  w_H = (w_H H)/H, w_L = (w_L L)/L, premium = w_H/w_L. Its growth does not depend on the anchor; its level does.
ANCHOR = 2017
kh = kl.loc[1997:2024].copy()
H_cps, L_cps = lab["H_US_COLLEGE_EQUIV_PRIVATE_ALL"] / 1e6, lab["L_US_NONCOLLEGE_PRIVATE_ALL"] / 1e6
kh["BH"], kh["BL"] = kh.college_comp / 1e6, kh.noncollege_comp / 1e6  # trillion USD
kh["H"] = kh.college_input_idx / 100 * H_cps[ANCHOR]  # million worker-equivalents
kh["L"] = kh.noncollege_input_idx / 100 * L_cps[ANCHOR]
kh["wH"], kh["wL"] = 1e3 * kh.BH / kh.H, 1e3 * kh.BL / kh.L  # thousand USD per worker-equivalent per year
kh["premium"] = kh.wH / kh.wL
assert abs(kh.H[ANCHOR] - H_cps[ANCHOR]) < 1e-9 and abs(kh.premium[ANCHOR] - (kh.BH / kh.BL)[ANCHOR] * L_cps[ANCHOR] / H_cps[ANCHOR]) < 1e-9
kh[["BH", "BL", "college_input_idx", "noncollege_input_idx", "H", "L", "wH", "wL", "premium"]].round(6).to_csv(HERE / "labor_block_klems.csv")

C_H, C_L, C_P = "#0F3F82", "#1F8A70", "#1A1A1A"
BADGE = {
    "data": ("DATA: published", "#E3EEFB", "#2A78D6", "#0F3F82"),
    "anchor": ("DATA growth, ANCHORED level", "#F1F0EA", "#8E8C78", "#4A4838"),
    "derived": ("DERIVED", "#FFF1E8", "#C85A1E", "#8A3B10"),
}


def badge(ax, kind):
    text, face, edge, ink = BADGE[kind]
    ax.text(1.0, 1.035, text, transform=ax.transAxes, ha="right", va="bottom", fontsize=9, color=ink, fontweight="bold",
            bbox=dict(boxstyle="round,pad=0.32", facecolor=face, edgecolor=edge, linewidth=1))


def provisional_line(ax, s, color, label, fmt, lw=2.2, label_dy=0.0):
    """Solid through 2023, dashed segment and open marker for 2024 (likely source break)."""
    ax.plot(s.loc[:2023].index, s.loc[:2023].values, color=color, linewidth=lw, zorder=3)
    ax.plot([2023, 2024], [s[2023], s[2024]], color=color, linewidth=lw * 0.7, linestyle=(0, (3, 2)), zorder=3)
    ax.scatter([2024], [s[2024]], s=36, facecolor="white", edgecolor=color, linewidth=1.5, zorder=4)
    ax.annotate(fmt(s[1997]), (1997, s[1997]), xytext=(0, 7), textcoords="offset points", ha="left", va="bottom",
                fontsize=9, color=color)
    ax.text(2025.0, s[2023] + label_dy, f"{label}\n{fmt(s[2023])} in 2023", ha="left", va="center", fontsize=9.5,
            color=color, fontweight="bold", linespacing=1.15)


def style(ax, title, unit):
    ax.set_title(title, loc="left", fontsize=12.5, fontweight="bold", pad=22)
    ax.text(0, 1.035, unit, transform=ax.transAxes, ha="left", va="bottom", fontsize=9.5, color=MUTED)
    ax.yaxis.grid(True, color=GRID, linewidth=0.8, zorder=0)
    ax.set_axisbelow(True)
    ax.set_xlim(1996, 2031)
    ax.set_xticks(range(2000, 2025, 5))
    ax.spines["bottom"].set_bounds(1996, 2024.5)


fig, axes = plt.subplots(2, 2, figsize=(14.5, 10))
(a1, a2), (a3, a4) = axes
trn = lambda v: f"{v:.2f}T"  # noqa: E731
mil = lambda v: f"{v:.1f}M"  # noqa: E731
thd = lambda v: f"${v:.0f}k"  # noqa: E731

provisional_line(a1, kh.BH, C_H, "w_H H, college", trn)
provisional_line(a1, kh.BL, C_L, "w_L L, non-college", trn, label_dy=-0.45)
a1.set_ylim(0, 9.5)
style(a1, "Wage bills  w_H H  and  w_L L", "Trillion USD, nominal")
badge(a1, "data")

for s, color, label, dy in [(kh.H, C_H, "H, college", 0.0), (kh.L, C_L, "L, non-college", 0.0)]:
    a2.plot(s.index, s.values, color=color, linewidth=2.2, zorder=3)
    a2.annotate(mil(s[1997]), (1997, s[1997]), xytext=(0, 7), textcoords="offset points", ha="left", va="bottom",
                fontsize=9, color=color)
    a2.text(2025.0, s[2024] + dy, f"{label}\n{mil(s[2024])} in 2024", ha="left", va="center", fontsize=9.5, color=color,
            fontweight="bold", linespacing=1.15)
for s, color in [(H_cps, C_H), (L_cps, C_L)]:  # CPS headcounts, the anchor source, for reference
    s = s.loc[1997:2024]
    a2.plot(s.index, s.values, color=color, linewidth=1.1, linestyle=(0, (1, 2)), zorder=2)
a2.scatter([ANCHOR, ANCHOR], [H_cps[ANCHOR], L_cps[ANCHOR]], s=42, marker="D", color="white",
           edgecolor=MUTED, linewidth=1.3, zorder=5)
a2.annotate(f"anchor: CPS {ANCHOR}\nheadcounts", (ANCHOR, H_cps[ANCHOR]), xytext=(ANCHOR - 5.2, 57),
            fontsize=9, color=MUTED, ha="center", arrowprops=dict(arrowstyle="-", color=MUTED, lw=0.8, shrinkB=5))
a2.text(2010.5, 10, "dotted lines: CPS headcounts, BA+ and non-BA", fontsize=9, color=MUTED, ha="center")
a2.set_ylim(0, 95)
style(a2, "Labor input  H  and  L", "Million worker-equivalents")
badge(a2, "anchor")

provisional_line(a3, kh.wH, C_H, "w_H, college", thd)
provisional_line(a3, kh.wL, C_L, "w_L, non-college", thd)
a3.set_ylim(0, 230)
style(a3, "Wages  w_H  and  w_L", "Thousand USD per worker-equivalent per year")
badge(a3, "derived")

provisional_line(a4, kh.premium, C_P, "w_H / w_L", lambda v: f"{v:.2f}")
for yr in (2007, 2017):
    a4.scatter([yr], [kh.premium[yr]], s=24, color=C_P, zorder=4)
    a4.annotate(f"{kh.premium[yr]:.2f}", (yr, kh.premium[yr]), xytext=(0, 7), textcoords="offset points",
                ha="center", va="bottom", fontsize=9, color=C_P)
a4.annotate(f"2024: {kh.premium[2024]:.2f},\nlikely source break", (2024, kh.premium[2024]), xytext=(2018.0, 3.0),
            fontsize=9, color=C_P, ha="center", va="center",
            arrowprops=dict(arrowstyle="-", color=C_P, lw=0.8, shrinkA=2, shrinkB=4))
a4.set_ylim(1.5, 3.25)
style(a4, "Skill premium  w_H / w_L", "Ratio")
badge(a4, "derived")

fig.suptitle("US labor block from the BEA-BLS production account, private industries, 1997-2024",
             x=0.06, ha="left", fontsize=15, fontweight="bold", y=0.995)
fig.subplots_adjust(hspace=0.42, wspace=0.28, left=0.06, right=0.97, top=0.9, bottom=0.12)
fig.text(0.06, 0.075,
         "DATA: w_H H and w_L L are BEA-BLS published college and non-college labor compensation (bachelor's degree "
         "and above vs below), summed over 61 private industries.\n"
         "DATA growth, ANCHORED level: H and L grow with the BEA-BLS labor input indexes (hours weighted across age, sex "
         "and class-of-worker cells), chained across industries\n"
         f"with compensation weights. Their levels are set to {ANCHOR} CPS headcounts of BA+ and non-BA private wage and "
         "salary workers (incl. nonprofits, 16+); the CPS excludes the self-employed.\n"
         "DERIVED: w_H = (w_H H)/H, w_L = (w_L L)/L, premium = w_H/w_L. The premium's change over time does not depend on "
         "the anchor; its level does.\n"
         "2024 (dashed, open marker): college compensation +19% and non-college -12% in one year while labor input is "
         "flat; likely a source break, treat as provisional.\n"
         "Sources: BEA-BLS Integrated Industry-Level Production Account, April 2026 release; labor_wages.csv (CPS).",
         fontsize=8.5, color=MUTED, va="top", linespacing=1.35)
finish(fig, "labor_block_klems_1997_2024")
print(kh.loc[[1997, 2007, 2009, 2017, 2019, 2022, 2023, 2024], ["BH", "BL", "H", "L", "wH", "wL", "premium"]].round(3))
