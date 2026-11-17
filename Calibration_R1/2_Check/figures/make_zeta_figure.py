"""US funding ratio zeta_t = Q_US / (beta e_US) in the data, 1990-2025. Read-only on the data folders.

Model mapping (V5_2_production.tex, US saving rule and zero-net-supply bonds):
  A_t = beta e_US,t  and  NFA_t = A_t - Q_US,t   =>   zeta_t = Q_US,t / (Q_US,t + NFA_US,t) = 1 - NFA_t / A_t.
No beta and no income series enter; the ratio is stock over stock, so it does not depend on the model period length.

Decomposition (exact): zeta_t - 1 = (EL - EA)/A + (NEL - NEA)/A,
  EL/EA = foreign-held US equity / US-held RoW equity, NEL/NEA = non-equity liabilities / assets.

Releases. The main line uses Q and NFA from the 11 September 2026 Fed release. Q exists only in that release, so the
June-consistent line moves the inward-equity revision into Q (inward FDI equity is part of US corporate equity):
  Q_Jun = Q_Sep + (EL_Jun - EL_Sep),  A_Jun = Q_Jun + NFA_Jun.
Mixing September Q with June NFA is not shown (it overstates zeta).

Run from this folder:
  uv run --no-project --python 3.12 --with numpy==2.3.5 --with pandas==2.2.3 --with matplotlib==3.10.0 python -B make_zeta_figure.py
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.lines import Line2D
from matplotlib.patches import Patch

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[3]
MAP = PROJECT / "Empirical_Data" / "Variable_mappings" / "Empirical_Mapping_Annual" / "data_intermediate"
SEP, JUN = "latest_official_2026-09-14", "local_replication_2026-08-21"  # 11 Sep 2026 and 11 Jun 2026 Fed releases
NAME = "zeta_funding_ratio_1990_2025"

# ---------------------------------------------------------------- data (trillion USD, nominal, end-year)
corp = pd.read_csv(MAP / "us_corporate_external_corporate.csv")
corp = corp[corp.mapping_id.eq("Q_US_AHP_ENTERPRISE_VALUE_TOTAL_CORP")]
assert set(corp.vintage) == {SEP} and not corp.year.duplicated().any()
Q = corp.set_index("year").value.sort_index() / 1e6

ext = pd.read_csv(MAP / "us_corporate_external_external.csv")
assert ext.groupby(["mapping_id", "vintage", "year"]).size().max() == 1
IDS = {"NFA": "NFA_US_AHP_IMA", "EL": "EQUITY_LIABILITIES_ROW_IN_US_AHP_IMA", "EA": "EQUITY_ASSETS_US_IN_ROW_AHP_IMA",
       "NEL": "NON_EQUITY_LIABILITIES_ROW_IN_US_AHP_IMA", "NEA": "NON_EQUITY_ASSETS_US_IN_ROW_AHP_IMA"}


def release(v):
    x = ext[ext.vintage.eq(v)].pivot(index="year", columns="mapping_id", values="value") / 1e6
    return pd.DataFrame({k: x[m] for k, m in IDS.items()})


s, j = release(SEP), release(JUN)
df = pd.DataFrame({"Q_sep": Q, "NFA_sep": s.NFA, "EL_sep": s.EL, "EA_sep": s.EA, "NEL_sep": s.NEL, "NEA_sep": s.NEA,
                   "NFA_jun": j.NFA, "EL_jun": j.EL}).loc[1990:2025]
assert len(df) == 36 and df.notna().all().all()
# NFA is equity plus non-equity net positions (IMA levels are rounded to USD 1 million)
assert ((s.EA - s.EL + s.NEA - s.NEL) - s.NFA).abs().max() < 2e-6

df["A_sep"] = df.Q_sep + df.NFA_sep
df["zeta_sep"] = df.Q_sep / df.A_sep
df["Q_jun"] = df.Q_sep + (df.EL_jun - df.EL_sep)
df["A_jun"] = df.Q_jun + df.NFA_jun
df["zeta_jun"] = df.Q_jun / df.A_jun
df["eq_contrib_sep"] = (df.EL_sep - df.EA_sep) / df.A_sep
df["debt_contrib_sep"] = (df.NEL_sep - df.NEA_sep) / df.A_sep
assert np.allclose(df.eq_contrib_sep + df.debt_contrib_sep, df.zeta_sep - 1, atol=1e-6)
assert np.allclose(df.zeta_sep, 1 - df.NFA_sep / df.A_sep)
assert abs(df.zeta_sep[2025] - 1.3204) < 1e-3

W0, W1 = 2009, 2025  # main data window; pre-2009 is context
win = df.loc[W0:W1]
MEAN = win.zeta_sep.mean()


def slope(y):
    return np.polyfit(y.index.values, y.values, 1)[0]


summary = {
    "zeta_sep_mean_2009_2025": MEAN, "zeta_jun_mean_2009_2025": win.zeta_jun.mean(),
    "zeta_sep_slope_pp_per_year": 100 * slope(win.zeta_sep), "zeta_jun_slope_pp_per_year": 100 * slope(win.zeta_jun),
    "A_jun_over_A_sep_2025": df.A_jun[2025] / df.A_sep[2025],
}
df.round(6).to_csv(HERE / f"{NAME}.csv")

# ---------------------------------------------------------------- style (same vocabulary as make_figures.py)
INK, MUTED, GRID, CONTEXT = "#1A1A1A", "#6B6B6B", "#E6E6E6", "#F3F3F1"
C_SEP, C_JUN = "#2A78D6", "#EB6834"  # categorical slots 1-2 (validated: CVD dE 24.7, normal 33.6)
C_EQ, C_DEBT = "#6250D6", "#1BAF7A"  # violet / aqua (validated: CVD dE 27.1, normal 32.8; aqua < 3:1 -> labelled)
plt.rcParams.update({
    "font.family": "sans-serif", "font.size": 11, "axes.edgecolor": MUTED, "axes.linewidth": 0.8,
    "axes.spines.top": False, "axes.spines.right": False, "xtick.color": MUTED, "ytick.color": MUTED,
    "axes.labelcolor": INK, "text.color": INK, "figure.dpi": 100, "savefig.dpi": 200,
})


def frame(ax, title, unit):
    ax.axvspan(1989.4, W0 - 0.5, color=CONTEXT, zorder=0, linewidth=0)
    ax.text(1990, 0.985, "pre-2009: context", transform=ax.get_xaxis_transform(), fontsize=8.5, color=MUTED, va="top")
    ax.set_title(title, loc="left", fontsize=12.5, pad=24)
    ax.text(0, 1.035, unit, transform=ax.transAxes, ha="left", va="bottom", fontsize=9.5, color=MUTED)
    ax.yaxis.grid(True, color=GRID, linewidth=0.8, zorder=0)
    ax.set_axisbelow(True)
    ax.set_xlim(1989.4, 2026.6)
    ax.set_xticks(range(1990, 2026, 5))
    ax.tick_params(length=0)


fig, (a1, a2) = plt.subplots(1, 2, figsize=(14.5, 5.6), gridspec_kw={"wspace": 0.2})

# ---- (a) level
frame(a1, r"(a) US funding ratio $\zeta_t = Q_{US,t}\,/\,(Q_{US,t}+NFA_{US,t})$", "ratio; model: $\\zeta_t = Q_{US,t}/(\\beta e_{US,t})$")
a1.axhline(1, color=MUTED, linewidth=1, linestyle=(0, (4, 3)), zorder=1)
a1.text(1990, 0.993, r"$\zeta=1$: one-country HKT, the theory's tail limit", fontsize=9, color=MUTED, va="top")
a1.plot([W0, W1], [MEAN, MEAN], color=C_SEP, linewidth=1, linestyle=(0, (1, 2)), zorder=2)
jl = df.zeta_jun.loc[2011:]
a1.plot(jl.index, jl.values, color=C_JUN, linewidth=2, linestyle=(0, (4, 2)), zorder=3)
a1.plot(df.index, df.zeta_sep, color=C_SEP, linewidth=2.2, zorder=4)
a1.scatter([2007, 2008, 2009, 2010, 2011], df.zeta_sep.loc[[2007, 2008, 2009, 2010, 2011]], s=34, color=C_SEP,
           edgecolor="white", linewidth=1.2, zorder=5)
a1.annotate(f"2007: {df.zeta_sep[2007]:.2f}", (2007, df.zeta_sep[2007]), xytext=(-8, 0), textcoords="offset points",
            ha="right", va="center", fontsize=9, color=INK)
a1.annotate(f"2008: {df.zeta_sep[2008]:.2f}", (2008, df.zeta_sep[2008]), xytext=(0, 8), textcoords="offset points",
            ha="center", va="bottom", fontsize=9, color=INK)
a1.annotate(f"2009: {df.zeta_sep[2009]:.2f}", (2009, df.zeta_sep[2009]), xytext=(2006.9, 1.262), ha="right", va="center",
            fontsize=9, color=INK, arrowprops=dict(arrowstyle="-", color=MUTED, lw=0.8, shrinkA=2, shrinkB=4))
a1.annotate(f"2010: {df.zeta_sep[2010]:.2f}", (2010, df.zeta_sep[2010]), xytext=(0, -10), textcoords="offset points",
            ha="center", va="top", fontsize=9, color=INK)
a1.annotate(f"2011: {df.zeta_sep[2011]:.2f}", (2011, df.zeta_sep[2011]), xytext=(-2, 9), textcoords="offset points",
            ha="center", va="bottom", fontsize=9, color=INK)
for col, c, dy in [("zeta_sep", C_SEP, -0.018), ("zeta_jun", C_JUN, 0.018)]:
    a1.scatter([2025], [df[col][2025]], s=36, color=c, edgecolor="white", linewidth=1.2, zorder=5)
    a1.text(2025.5, df[col][2025] + dy, f"{df[col][2025]:.2f}", fontsize=9.5, color=INK, va="center")
a1.set_ylim(0.95, 1.60)
a1.legend(handles=[Line2D([], [], color=C_SEP, lw=2.2, label="September 2026 release (main)"),
                   Line2D([], [], color=C_JUN, lw=2, ls=(0, (4, 2)), label="June 2026 release (FDI revision moved into Q)"),
                   Line2D([], [], color=C_SEP, lw=1, ls=(0, (1, 2)), label=f"2009–25 mean, September: {MEAN:.2f}")],
          loc="upper left", bbox_to_anchor=(0.0, 0.94), frameon=False, fontsize=9)

# ---- (b) decomposition of zeta - 1
frame(a2, r"(b) Who funds the gap: $\zeta_t-1=-NFA_t/A_t$", "share of US wealth $A=Q+NFA$; September 2026 release")
yrs = df.index.values
pos_b, neg_b = np.zeros(len(df)), np.zeros(len(df))
for k, c in [("debt_contrib_sep", C_DEBT), ("eq_contrib_sep", C_EQ)]:
    v = df[k].values
    p, n = np.clip(v, 0, None), np.clip(v, None, 0)
    a2.bar(yrs, p, bottom=pos_b, width=0.72, color=c, edgecolor="white", linewidth=0.6, zorder=2)
    a2.bar(yrs, n, bottom=neg_b, width=0.72, color=c, edgecolor="white", linewidth=0.6, zorder=2)
    pos_b, neg_b = pos_b + p, neg_b + n
a2.axhline(0, color=MUTED, linewidth=0.8, zorder=3)
z1 = df.zeta_sep - 1
a2.plot(yrs, z1, color=INK, linewidth=1.8, zorder=4)
a2.scatter(yrs, z1, s=14, color=INK, edgecolor="white", linewidth=0.8, zorder=5)
a2.text(2025.6, z1[2025] + 0.05, f"$\\zeta-1$\n{z1[2025]:.2f}", fontsize=8.5, color=INK, va="center")
a2.text(2025.6, df.debt_contrib_sep[2025] / 2, f"debt\n{df.debt_contrib_sep[2025]:+.2f}", fontsize=8.5, color=INK, va="center")
a2.text(2025.6, df.debt_contrib_sep[2025] + df.eq_contrib_sep[2025] / 2, f"equity\n{df.eq_contrib_sep[2025]:+.2f}",
        fontsize=8.5, color=INK, va="center")
a2.text(2009, df.eq_contrib_sep[2009] - 0.02, f"equity {df.eq_contrib_sep[2009]:+.2f}".replace("-", "−"), fontsize=8.5,
        color=INK, ha="center", va="top")
a2.set_ylim(-0.32, 0.86)
a2.legend(handles=[Patch(facecolor=C_DEBT, label="Net foreign debt funding (non-equity liabilities − assets)/A"),
                   Patch(facecolor=C_EQ, label="Net foreign equity funding (foreign-held US − US-held RoW equity)/A"),
                   Line2D([], [], color=INK, lw=1.8, marker="o", ms=4, mec="white", label=r"$\zeta_t-1$")],
          loc="upper left", bbox_to_anchor=(0.0, 0.94), frameon=False, fontsize=9)

NOTE = ("Mapping: the US saving rule $A_t=\\beta e_{US,t}$ and zero-net-supply bonds give $NFA_t=A_t-Q_{US,t}$, so "
        "$\\zeta_t=Q_{US,t}/A_t$; neither β nor an income series enters. Q: end-year total-corporate enterprise value "
        "(Fed Z.1, AHP mapping). NFA and positions: US international investment position (AHP/IMA).\n"
        "June-consistent line: Q exists only in the September release, so the inward-equity revision is added back to Q "
        f"(Q_Jun = Q_Sep + EL_Jun − EL_Sep); A_Jun/A_Sep = {summary['A_jun_over_A_sep_2025']:.3f} in 2025. "
        "The September release cut inward FDI equity by ≈27% from 2020Q1 and reclassified ≈$1tn of outward equity\n"
        "to non-equity from 2012Q4 (moves the split in (b), not ζ). Data NFA includes foreign holdings of Treasuries; "
        f"model bonds are private. 2009–25 trend: {summary['zeta_sep_slope_pp_per_year']:+.1f}pp/yr (September), "
        f"{summary['zeta_jun_slope_pp_per_year']:+.1f}pp/yr (June-consistent). Data: {NAME}.csv.")
fig.text(0.125, 0.015, NOTE, fontsize=8, color=MUTED, va="top", linespacing=1.45)

fig.savefig(HERE / f"{NAME}.png", bbox_inches="tight", facecolor="white")
fig.savefig(HERE / f"{NAME}.pdf", bbox_inches="tight", facecolor="white")
plt.close(fig)
print({k: round(v, 4) for k, v in summary.items()})
print(df.loc[[2007, 2009, 2010, 2011, 2015, 2019, 2023, 2025], ["zeta_sep", "zeta_jun", "eq_contrib_sep", "debt_contrib_sep"]].round(3))
