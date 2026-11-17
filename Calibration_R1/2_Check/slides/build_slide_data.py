#!/usr/bin/env python3
"""Build every series plotted in model_vs_data_slides.tex from the project's saved outputs.

Inputs are read only. Outputs go to ./data/ as CSV (one file per chart family) plus
data/overview_rows.tex and data/values.tex, which the slides \\input.

Run from anywhere:
  uv run --no-project --python 3.12 --with numpy==2.3.5 --with pandas==2.2.3 python -B build_slide_data.py
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
CODES = HERE.parents[2]
PROJECT = CODES.parent
OUT = HERE / "data"
OUT.mkdir(exist_ok=True)

EMP = PROJECT / "Empirical_Data"
MAP = EMP / "Variable_mappings" / "Empirical_Mapping_Annual"
MECH = MAP / "Mechanism_Evidence_US_ROW" / "processed"
SKILL = EMP / "Skill_Premium_and_RD_Share_2026-10-26" / "data"
AHP = EMP / "AHP_NFA"
SIM = CODES / "Two_country_proudction_zero_nu_b" / "outputs_zero_nu_b"
NB05 = SIM / "05_nu_u_funding_regime_sweeps"
NB04 = SIM / "04_phi_spillover_funding_sweeps"
NB06 = SIM / "06_post2008_ahp_nfa_calibration_search"
R1 = CODES / "Calibration_R1" / "1_Do" / "runs"

CASES = {"nu_u_1_25": "nu125", "nu_u_1_00": "nu100", "nu_u_0_75": "nu075"}
BETA, THETA, A_US, A_W = 0.45, 0.85, 0.20, 0.06
checks: list[tuple[str, float, float]] = []


def check(name: str, got: float, want: float, tol: float) -> None:
    checks.append((name, got, want))
    assert abs(got - want) <= tol, f"{name}: got {got}, want {want}"


def save(df: pd.DataFrame, name: str) -> None:
    df.to_csv(OUT / name, index=False, na_rep="nan", float_format="%.6g")


# ---------------------------------------------------------------- US corporate accounts
corp = pd.read_csv(MAP / "data_intermediate" / "us_corporate_external_corporate.csv")
corp = corp[corp.country_or_region == "US"]
assert corp.groupby(["mapping_id", "year"]).size().max() == 1
wide = corp.pivot(index="year", columns="mapping_id", values="value") / 1e6
Y = wide["Y_US_AHP_TOTAL_CORP_GVA"]
COMP = wide["COMP_US_AHP_TOTAL_CORP"]
Q = wide["Q_US_AHP_ENTERPRISE_VALUE_TOTAL_CORP"]
FCF = wide["D_US_AHP_FCF_TOTAL_CORP"]
NCF = wide["NET_CAPITAL_FORMATION_US_AHP_TOTAL_CORP"]
RY = wide["Y_US_REAL_CORP_GVA"]

beta_main = pd.read_csv(MAP / "data_final" / "implied_beta_US_main.csv").set_index("year")
check("implied beta 2025", beta_main.beta_implied[2025], 6.3194, 1e-3)

# ---------------------------------------------------------------- CPS bridge (package, through 2022 to avoid top-code break)
lab = pd.read_csv(MAP / "data_intermediate" / "labor_wages.csv")
lab = lab.pivot_table(index="year", columns="mapping_id", values="value", aggfunc="first")
H = lab["H_US_COLLEGE_EQUIV"]
L = lab["L_US_NONCOLLEGE"]
PKG = lab["WHWL_US_CPS_COMPOSITION_ADJ_COLLEGE_NONCOLLEGE"]
variants = pd.read_csv(SKILL / "derived" / "premium_variants.csv").set_index("year")
acs = pd.read_csv(SKILL / "inputs_copied" / "acs_skill_premium_wide.csv").set_index("year")
cand = pd.read_csv(SKILL / "derived" / "one_minus_phi_candidates.csv")
RECEN = variants["prem_recensor"]
years_lab = H.index[H.index <= 2024]
bh_cps = COMP.reindex(years_lab) * RECEN.reindex(years_lab).combine_first(PKG.reindex(years_lab)) * H.reindex(years_lab) / (
    RECEN.reindex(years_lab).combine_first(PKG.reindex(years_lab)) * H.reindex(years_lab) + L.reindex(years_lab)
)

# ---------------------------------------------------------------- Notebook 06 best point: rebuild production objects
best = pd.read_csv(NB06 / "best_candidate_path.csv")
T06 = len(best)
N = np.ones(T06 + 1)
NW = np.ones(T06 + 1)
for i in range(T06):
    N[i + 1] = N[i] * (1 + A_US * (1 - best.phi_US.iloc[i]))
    NW[i + 1] = NW[i] * (1 + A_W * 3.0 * (1 - best.phi_W.iloc[i]))


def ces(ax: np.ndarray, al: np.ndarray, x: np.ndarray, l: float, theta: float):
    xt, lt = ax * x, al * l
    br = 0.5 / xt + 0.5 / lt
    F = 1 / br
    FX = 0.5 * br ** (-2) * xt ** (-2)
    FL = 0.5 * br ** (-2) * lt ** (-2)
    return F, theta * FX * ax, FL * al


nn = N[:-1]
AX, AL = 15 * nn**2.25, 1.5 * nn**1.75
phi = best.phi_US.values
Y06, wH06, wL06 = ces(AX, AL, phi, 1.0, THETA)
q06 = wH06 / (A_US * nn)
D06 = (1 - THETA) / THETA * wH06 * phi
I06 = (1 - phi) * wH06
e06 = wH06 + wL06
Q06 = N[1:] * q06
check("nb06 rebuilt Y vs file (max rel err)", float(np.max(np.abs(Y06 / best.Y_US - 1))), 0.0, 1e-5)
check("nb06 rebuilt q_US vs file (max rel err)", float(np.max(np.abs(q06 / best.q_US - 1))), 0.0, 1e-5)
check("nb06 identity Y=e+D-I", float(np.max(np.abs(Y06 - (e06 + D06 - I06)))), 0.0, 1e-9)
check("nb06 identity NFA=beta e-Q", float(np.max(np.abs(best.NFA - (BETA * e06 - Q06)))), 0.0, 1e-5)

m06 = pd.DataFrame(
    {
        "t": best.t,
        "year": 2007 + best.t,
        "N": nn,
        "Y": Y06,
        "e": e06,
        "wH": wH06,
        "wL": wL06,
        "premium": wH06 / wL06,
        "bill_share": wH06 / e06,
        "rd_share": 1 - phi,
        "Q_e": Q06 / e06,
        "zeta": Q06 / (BETA * e06),
        "D_Y": D06 / Y06,
        "D_Q": D06 / Q06,
        "netcash_Y": (D06 - I06) / Y06,
        "Q_Y": Q06 / Y06,
        "aH_G": A_US / (1 + A_US * (1 - phi)),
        "Y_idx": Y06 / Y06[0],
        "q_US_idx": best.q_US_index,
        "q_W_idx": best.q_W_index,
        "liab_Y": best.liability_exposure_Y,
        "asset_Y": best.asset_exposure_Y,
        "NFA_Y": best.NFA / best.Y_US,
    }
)
# Notebook 06 maps its 16 periods onto 2008Q1-2023Q3
m06["q_year"] = 2008 + (best.t - 1) * 15.5 / 15
save(m06, "model_nb06_path.csv")

# ---------------------------------------------------------------- Notebook 05 sweeps: rebuild production objects
st = pd.read_csv(NB05 / "all_u_and_realized_switch_state_paths.csv")
wg = pd.read_csv(NB05 / "production_wage_and_force_paths.csv")
wg_us = wg[wg.country == "US"][["case_id", "path", "t", "w_H", "w_L"]]
wg_w = wg[wg.country == "W"][["case_id", "path", "t", "w_H", "w_L"]].rename(columns={"w_H": "w_HW", "w_L": "w_LW"})
sw = st.merge(wg_us, on=["case_id", "path", "t"]).merge(wg_w, on=["case_id", "path", "t"])
sw["D"] = (1 - THETA) / THETA * sw.w_H * sw.phi_US
sw["I"] = (1 - sw.phi_US) * sw.w_H
sw["Y"] = sw.e_US + sw.D - sw.I
sw["Y_W"] = 1 / (0.5 / (10 * sw.phi_W * 3) + 0.5 / (1 * 3))
sw["Q_e"] = sw.Q_US / sw.e_US
sw["bill_share"] = sw.w_H / sw.e_US
sw["premium"] = sw.w_H / sw.w_L
sw["D_Y"] = sw.D / sw.Y
sw["netcash_Y"] = (sw.D - sw.I) / sw.Y
sw["rd_share"] = 1 - sw.phi_US
sw["rd_share_W"] = 1 - sw.phi_W
sw["zeta"] = sw.Q_US / (BETA * sw.e_US)
sw["D_Q"] = sw.D / sw.Q_US
_ew = 3 * sw.w_HW + 3 * sw.w_LW
check("RoW e_W rebuilt", float(np.max(np.abs(_ew - sw.e_W))), 0.0, 1e-9)
check("RoW identity Y_W=e_W+D_W-I_W", float(np.max(np.abs(sw.Y_W - (sw.e_W + 3 * sw.w_HW * sw.phi_W - 3 * (1 - sw.phi_W) * sw.w_HW)))), 0.0, 1e-9)
allu = sw[sw.path == "all_u"]
# identity w_H H/e = beta zeta a H / G_N on every all-u date
G = 1 + A_US * (1 - allu.phi_US)
check("sweep identity wH H/e", float(np.max(np.abs(allu.bill_share - BETA * allu.zeta * A_US / G))), 0.0, 1e-6)


def sweep(col: str) -> pd.DataFrame:
    out = allu.pivot(index="t", columns="case_id", values=col).rename(columns=CASES).reset_index()
    return out[["t", "nu125", "nu100", "nu075"]]


for col in ["D_Q", "Q_e", "bill_share", "premium", "D_Y", "netcash_Y", "rd_share", "rd_share_W", "q_US", "q_W", "zeta", "e_W", "phi_W", "Y", "Y_W", "N_W"]:
    save(sweep(col), f"sweep_{col}.csv")
# Spillover baseline nu_u=1.75, T=30 (notebook 04)
sp = pd.read_csv(NB04 / "spillover_sweep_paths.csv")
sp = sp[sp.case_id == "baseline"][["t", "R_and_D_share_US_all_u"]].rename(columns={"R_and_D_share_US_all_u": "nu175"})
save(sp, "sweep_rd_share_nu175.csv")

# ---------------------------------------------------------------- Slide: valuation
val = pd.DataFrame({"year": Y.index, "Q_Y": (Q / Y).values, "Q_COMP": (Q / COMP).values})
val["A_e"] = beta_main.beta_implied.reindex(Y.index).values
val["NFA_e"] = (beta_main.NFA_million_USD / beta_main.e_million_USD_per_calendar_year).reindex(Y.index).values
for T in (5, 7, 10):
    val[f"A_e_T{T}"] = val.A_e / T
save(val, "val_us.csv")
# Foreign net funding share of Q
foreign_share_2025 = -val.NFA_e.iloc[-1] / val.Q_COMP.iloc[-1]

# ---------------------------------------------------------------- Slide: prices and external (June-2026 vintage in AHP_NFA; same as notebook 06 targets)
ahp = pd.read_csv(AHP / "ahp_us_nfa_decomposition_latest.csv", parse_dates=["date"])
ahp["yq"] = ahp.date.dt.year + (ahp.date.dt.quarter - 1) / 4
base = ahp[ahp.yq == 2008.0].iloc[0]
win = ahp[(ahp.yq >= 2008.0) & (ahp.yq <= 2023.5)].copy()
px = pd.DataFrame(
    {
        "year": win.yq,
        "liab_idx": win.equity_liability_price_index / base.equity_liability_price_index,
        "asset_idx": win.equity_asset_price_index / base.equity_asset_price_index,
        "liab_Y": win.equity_liabilities_us_musd / win.gva_corporate_saar_musd,
        "asset_Y": win.equity_assets_us_musd / win.gva_corporate_saar_musd,
        "NFA_Y": win.nfa_us_musd / win.gva_corporate_saar_musd,
    }
)
save(px, "ext_quarterly.csv")
comp = pd.read_csv(NB06 / "model_empirical_comparison.csv").set_index("metric")
check("liability price growth", px.liab_idx.iloc[-1], comp.empirical["q_us_growth"], 1e-6)
check("asset price growth", px.asset_idx.iloc[-1], comp.empirical["q_w_growth"], 1e-6)
check("liability exposure", px.liab_Y.iloc[-1], comp.empirical["liability_exposure"], 1e-6)

bars = pd.DataFrame(
    {
        "term": ["delta_nfa", "liability_va", "asset_va", "current_account"],
        "data": [comp.empirical[k] for k in ["delta_nfa", "liability_va", "asset_va", "current_account"]],
        "model": [comp.model[k] for k in ["delta_nfa", "liability_va", "asset_va", "current_account"]],
    }
)
bars["ypos"] = range(len(bars), 0, -1)
save(bars, "ext_bars.csv")

# ---------------------------------------------------------------- Slide: GVA stack
sel = [1990, 2000, 2007, 2009, 2015, 2019, 2022, 2025]
stack = pd.DataFrame({"year": Y.index})
stack["comp"] = (COMP / Y).values
stack["fcf"] = (FCF / Y).values
stack["ncf"] = (NCF / Y).values
stack["cfc_tax"] = 1 - stack.comp - stack.fcf - stack.ncf
save(stack, "gva_stack_all.csv")
s2 = stack[stack.year.isin(sel)].copy()
s2["xpos"] = range(1, len(s2) + 1)
s22 = stack[stack.year == 2022].iloc[0]
s2["model_net"] = 0.0
s2 = pd.concat(
    [s2, pd.DataFrame([{"year": 2022, "comp": s22.comp, "fcf": 0.0, "ncf": 0.0, "cfc_tax": 0.0, "xpos": len(s2) + 2, "model_net": 1 - s22.comp}])],
    ignore_index=True,
)
save(s2, "gva_stack.csv")
check("comp+cfc+ncf+fcf", float((stack.comp + stack.cfc_tax + stack.ncf + stack.fcf).max()), 1.0, 1e-9)

# ---------------------------------------------------------------- Slide: markup closed form
mk = []
for prem, g in cand.groupby("premium"):
    g = g.set_index("year")
    phi_n = 1 - g.nscg_business_for_profit
    mu0 = (1 + (Y - COMP).reindex(g.index) / g.skilled_bill_nominal_T) / phi_n
    mu1 = (1 + FCF.reindex(g.index) / g.skilled_bill_nominal_T) / phi_n
    check(f"closed form vs saved implied markup {prem}", float(np.max(np.abs(mu0 - g.markup_implied_nscg_business_for_profit))), 0.0, 1e-6)
    mk.append(pd.DataFrame({"year": g.index, "premium": prem, "mu_nocap": mu0.values, "mu_cap": mu1.values}))
mk = pd.concat(mk)
mkw = mk.pivot(index="year", columns="premium", values=["mu_nocap", "mu_cap"])
mk_out = pd.DataFrame(
    {
        "year": mkw.index,
        "nocap_lo": mkw["mu_nocap"].min(axis=1).values,
        "nocap_hi": mkw["mu_nocap"].max(axis=1).values,
        "nocap_recensor": mkw["mu_nocap"]["cps_recensor_2884"].values,
        "nocap_acs": mkw["mu_nocap"]["acs_annual_compadj2009"].values,
        "cap_lo": mkw["mu_cap"].min(axis=1).values,
        "cap_hi": mkw["mu_cap"].max(axis=1).values,
        "cap_recensor": mkw["mu_cap"]["cps_recensor_2884"].values,
        "cap_acs": mkw["mu_cap"]["acs_annual_compadj2009"].values,
    }
)
save(mk_out, "markup.csv")
for nm, lo, hi in [("nocap", "nocap_lo", "nocap_hi"), ("cap", "cap_lo", "cap_hi")]:
    band = pd.DataFrame({"x": list(mk_out.year) + list(mk_out.year[::-1]), "y": list(mk_out[hi]) + list(mk_out[lo][::-1])})
    save(band, f"markup_band_{nm}.csv")

# ---------------------------------------------------------------- Slide: Q/D decomposition
dec = []
for lab_, a, b in [("Data 1990--2025", 1990, 2025), ("Data 2007--2025", 2007, 2025), ("Data 2009--2024", 2009, 2024)]:
    dec.append((lab_, "data", math.log((Q[b] / Y[b]) / (Q[a] / Y[a])), -math.log((FCF[b] / Y[b]) / (FCF[a] / Y[a]))))
for lab_, cid, a, b in [
    (r"Model $\nu_u=1.00$, $t=1$--$80$", "nu_u_1_00", 1, 80),
    (r"Model $\nu_u=1.25$, $t=1$--$80$", "nu_u_1_25", 1, 80),
]:
    g = allu[allu.case_id == cid].set_index("t")
    dec.append((lab_, "model", math.log((g.Q_US[b] / g.Y[b]) / (g.Q_US[a] / g.Y[a])), -math.log(g.D_Y[b] / g.D_Y[a])))
dec.append(
    (
        r"Model notebook 06, $t=1$--$16$",
        "model",
        math.log(m06.Q_Y.iloc[-1] / m06.Q_Y.iloc[0]),
        -math.log(m06.D_Y.iloc[-1] / m06.D_Y.iloc[0]),
    )
)
dec = pd.DataFrame(dec, columns=["label", "kind", "qy", "dy"])
dec["total"] = dec.qy + dec.dy
dec["ypos"] = range(len(dec), 0, -1)
_d = dec.assign(label=dec.label.str.replace(",", ";", regex=False))
save(_d[_d.kind == "data"], "decomp_data.csv")
save(_d[_d.kind == "model"], "decomp_model.csv")
dy = pd.DataFrame({"year": Y.index, "fcf_y": (FCF / Y).values, "d_q": (FCF / Q).values})
save(dy, "dy_us.csv")

# ---------------------------------------------------------------- Slide: R&D share
rd = cand[cand.premium == "cps_recensor_2884"].set_index("year")
rd_acs = cand[cand.premium == "acs_annual_compadj2009"].set_index("year")
nscg = pd.read_csv(SKILL / "inputs_copied" / "nscg_rd1_share_by_sector.csv")
nscg = nscg[nscg.sector == "business_for_profit"].set_index("year")
rd_out = pd.DataFrame({"year": rd.index})
rd_out["researchers"] = rd.berd_researchers_over_H.values
rd_out["personnel"] = rd.berd_personnel_over_H.values
rd_out["labor_cost_cps"] = rd.berd_labor_cost_over_skilled_bill.values
rd_out["labor_cost_acs"] = rd_acs.berd_labor_cost_over_skilled_bill.reindex(rd.index).values
rd_out["nscg"] = nscg.rd1_share.reindex(rd.index).values
save(rd_out, "rd_data.csv")
# what the yield decline would require
needed = {}
for a in (2007, 1990):
    fall = (FCF[2025] / Q[2025]) / (FCF[a] / Q[a])
    needed[a] = 1 - 0.93 * fall

# ---------------------------------------------------------------- Slide: free entry
ai = pd.read_csv(MAP / "data_final" / "implied_ai_US_main.csv")
ai_w = ai.pivot_table(index="year", columns="knowledge_mapping_id", values="a_times_H_per_year")
ai_w = ai_w.rename(
    columns={
        "N_US_RD_CAPITAL": "rd_cap",
        "N_US_RD_CAPITAL_REAL_PROXY": "rd_real",
        "N_US_TRIADIC_PATENT_STOCK": "triadic",
        "N_US_PATENT_STOCK_DEPR": "patent",
    }
).reset_index()
save(ai_w, "free_entry_aH.csv")
ya = list(range(1995, 2023))
fe = pd.DataFrame({"year": ya})
fe["BH_Q"] = (bh_cps.reindex(ya) / Q.reindex(ya)).values
wh = bh_cps.reindex(ya) / H.reindex(ya) * 1e6
fe["Q_wH_idx"] = ((Q.reindex(ya) / wh) / (Q[1995] / wh[1995])).values
fe["BH_e"] = (bh_cps.reindex(ya) / COMP.reindex(ya)).values
fe["Q_e"] = (Q.reindex(ya) / COMP.reindex(ya)).values
save(fe, "free_entry_data.csv")
check("identity BH/e=(Q/e)(BH/Q)", float(np.max(np.abs(fe.BH_e - fe.Q_e * fe.BH_Q))), 0.0, 1e-9)
r2 = pd.read_csv(R1 / "02_fixed_mean_labor" / "results" / "conditional_paths.csv")
r2 = r2[r2.run_id == "mu3.5_rho2_sample_mean"].copy()
r2["rd_workers"] = r2.H - r2.X
save(r2[["year", "Q", "Q_free_entry_fit", "relative_Q_residual", "phi", "I", "rd_workers", "G_a", "D", "net_cashflow_fit"]], "r1_run2_mu35.csv")

seed1 = allu[(allu.case_id == "nu_u_1_00") & (allu.t == 1)].iloc[0]
_d22 = fe[fe.year == 2022].iloc[0]
db = pd.DataFrame(
    {
        "label": [r"$w_HH/e$", r"$Q/e$", r"$aH/G_N$"],
        "data": [_d22.BH_e, _d22.Q_e, _d22.BH_Q],
        "model": [seed1.bill_share, seed1.Q_e, A_US / (1 + A_US * (1 - seed1.phi_US))],
        "ypos": [3, 2, 1],
    }
)
save(db, "identity_dumbbell.csv")
check("identity model t=1", float(db.model[0] - db.model[1] * db.model[2]), 0.0, 1e-9)

# ---------------------------------------------------------------- Slide: premium, bill share, H/L, xi-nu
prem = pd.DataFrame({"year": range(2009, 2025)})
prem["cps"] = RECEN.reindex(prem.year).values
prem["acs_annual"] = acs["ANNUAL_COMPADJ_2009"].reindex(prem.year).values
prem["acs_hourly"] = acs["HOURLY_WINSOR_COMPADJ_2007"].reindex(prem.year).values
save(prem, "premium_data.csv")
bill = pd.DataFrame({"year": range(1994, 2025)})
bill["cps"] = (bh_cps.reindex(bill.year) / COMP.reindex(bill.year)).values
a_share = cand[cand.premium == "acs_annual_compadj2009"].set_index("year").skilled_bill_nominal_T
bill["acs"] = (a_share.reindex(bill.year) / COMP.reindex(bill.year)).values
save(bill, "bill_share_data.csv")
hl = pd.DataFrame({"year": range(1994, 2025)})
hl["HL_idx"] = (H / L).reindex(hl.year).values / (H[1994] / L[1994])
pm = RECEN.reindex(hl.year).combine_first(PKG.reindex(hl.year))
hl["prem_idx"] = pm.values / pm[1994]
save(hl, "hl_premium.csv")
xn = pd.read_csv(SKILL / "derived" / "calibration_sensitivity.csv")
xn = xn[xn.premium != "baseline_2023_24_spliced"]
names = {
    "package_baseline": "Package CPS",
    "recensor_2884": r"CPS re-censored",
    "recensor_pareto": "CPS + Pareto tail",
    "recensor_x1.5": r"CPS cap $\times 1.5$",
    "cell_median": "CPS cell medians",
    "BLS_median_weekly_BA_HS": "BLS medians",
    "ACS_annual_compadj2009": "ACS annual",
    "ACS_hourly_compadj2007": "ACS hourly",
}
xnw = xn.pivot(index="premium", columns="labor", values="xi_minus_nu").reindex(list(names)).reset_index()
xnw["label"] = xnw.premium.map(names)
xnw["ypos"] = range(len(xnw), 0, -1)
save(xnw[["label", "observed", "sample_mean", "ypos"]], "xi_nu.csv")

# ---------------------------------------------------------------- Slide: output growth
gr = pd.DataFrame({"year": range(2008, 2024)})
gr["data"] = RY.reindex(gr.year).values / RY[2008]
gr["model"] = m06.Y_idx.values
save(gr, "growth.csv")
grate = {
    "1990-2025": math.log(RY[2025] / RY[1990]) / 35,
    "2008-2023": math.log(RY[2023] / RY[2008]) / 15,
    "2009-2024": math.log(RY[2024] / RY[2009]) / 15,
    "model_nb06": (m06.Y.iloc[-1] / m06.Y.iloc[0]) ** (1 / 15) - 1,
}

# ---------------------------------------------------------------- Slide: RoW
rfmt = pd.read_csv(MECH / "labor_formal_rd_intensity.csv")
rfmt = rfmt[rfmt.variant == "RESEARCHER"].pivot_table(index="year", columns="region", values="value").reset_index()
rfmt = rfmt.rename(columns={"ROW_G4": "g4", "US": "us"})
save(rfmt, "row_research.csv")
sdm = pd.read_csv(MECH / "suggestive_data_moments.csv", low_memory=False)
rc = sdm[sdm.mapping_id == "N_RD_NET_EUKLEMS_INDEX2007"].pivot_table(index="year", columns="region", values="value").reset_index()
rc = rc.rename(columns={"ROW_G4": "g4", "US": "us"})
save(rc, "row_rdcap.csv")
w100 = allu[allu.case_id == "nu_u_1_25"].sort_values("t")
row_m = pd.DataFrame({"t": w100.t, "N_W": w100.N_W / w100.N_W.iloc[0], "Y_W": w100.Y_W / w100.Y_W.iloc[0]})
save(row_m, "row_model.csv")

# ---------------------------------------------------------------- Slide: switch and bubble
sw100 = sw[sw.case_id == "nu_u_1_00"]
a_ = sw100[sw100.path == "all_u"].set_index("t")
b_ = sw100[sw100.path == "realized_switch"].set_index("t")
tr = pd.DataFrame({"rel": range(-5, 11)})
tr["t"] = tr.rel + 16
tr["e_b"] = b_.e_US.reindex(tr.t).values / a_.e_US[15]
tr["Q_b"] = b_.Q_US.reindex(tr.t).values / a_.Q_US[15]
tr["e_u"] = a_.e_US.reindex(tr.t).values / a_.e_US[15]
save(tr, "switch_model.csv")
crisis = pd.DataFrame({"year": range(2005, 2016)})
crisis["rel"] = crisis.year - 2008
crisis["real_gva"] = RY.reindex(crisis.year).values / RY[2007]
crisis["ev"] = Q.reindex(crisis.year).values / Q[2007]
save(crisis, "switch_data.csv")
lk = pd.read_csv(NB05 / "us_bubble_share_bound_leakage.csv")
lkw = lk.pivot(index="t", columns="case_id", values="finite_prefix_upper_bound").rename(columns=CASES).reset_index()
save(lkw[["t", "nu125", "nu100", "nu075"]], "bubble_bound.csv")
lk100 = lk[(lk.case_id == "nu_u_1_00") & (lk.t >= 2)][["t", "total_leakage", "dividend_leakage", "switch_leakage"]]
save(lk100, "bubble_leakage.csv")

# ---------------------------------------------------------------- Slide: two external vintages
ext = pd.read_csv(MAP / "data_intermediate" / "us_corporate_external_external.csv")
ext = ext[ext.mapping_id == "EQUITY_LIABILITIES_ROW_IN_US_AHP_IMA"]
vw = ext.pivot(index="year", columns="vintage", values="value") / 1e6
vint = pd.DataFrame({"year": vw.index})
vint["june"] = (vw["local_replication_2026-08-21"] / Y.reindex(vw.index)).values
vint["sept"] = (vw["latest_official_2026-09-14"] / Y.reindex(vw.index)).values
save(vint[vint.year >= 2007], "vintage_liab.csv")
v25 = vint[vint.year == 2025].iloc[0]
check("June-release liabilities/GVA 2025", v25.june, 2.274, 1e-3)
check("September-release liabilities/GVA 2025", v25.sept, 1.940, 1e-3)

# ---------------------------------------------------------------- Overview: one model point vs the same window
y = 2023
nscg_2023 = nscg.rd1_share[2023]
last = m06.iloc[-1]
bh_recen_2023 = rd.skilled_bill_nominal_T[2023]
bh_acs_2023 = a_share[2023]
rows = [
    ("Valuation", r"$Q/\text{COMP}$", Q[y] / COMP[y], last.Q_e, "{:.2f}"),
    ("Valuation", r"Implied $\beta=(Q+\text{NFA})/e$", beta_main.beta_implied[y], BETA, "{:.2f}"),
    ("Valuation", r"US equity price, end/base", comp.empirical["q_us_growth"], comp.model["q_us_growth"], "{:.2f}"),
    ("Valuation", r"RoW equity price, end/base", comp.empirical["q_w_growth"], comp.model["q_w_growth"], "{:.2f}"),
    ("Income", r"$D/Q$ (FCF/EV)", FCF[y] / Q[y], last.D_Q, "{:.3f}"),
    ("Income", r"$D/Y$ (FCF/GVA)", FCF[y] / Y[y], last.D_Y, "{:.3f}"),
    ("Production", r"R\&D share $1-\varphi$", nscg_2023, last.rd_share, "{:.3f}"),
    ("Production", r"$aH/G_N$ ($=B_H/Q$)", bh_recen_2023 / Q[y], last.aH_G, "{:.3f}"),
    ("Production", r"Skilled bill share $w_HH/e$", bh_recen_2023 / COMP[y], last.bill_share, "{:.2f}"),
    ("Production", r"Skill premium $w_H/w_L$", RECEN[y], last.premium, "{:.2f}"),
    ("Production", r"Output growth per year", grate["2008-2023"], grate["model_nb06"], "{:.3f}"),
    ("External", r"Equity liabilities/GVA", comp.empirical["liability_exposure"], comp.model["liability_exposure"], "{:.2f}"),
    ("External", r"Equity assets/GVA", comp.empirical["asset_exposure"], comp.model["asset_exposure"], "{:.2f}"),
    ("External", r"$\Delta$NFA/GVA", comp.empirical["delta_nfa"], comp.model["delta_nfa"], "{:.3f}"),
    ("External", r"Liability VA/GVA", comp.empirical["liability_va"], comp.model["liability_va"], "{:.3f}"),
    ("External", r"Asset VA/GVA", comp.empirical["asset_va"], comp.model["asset_va"], "{:.4f}"),
    ("External", r"Current account/GVA", comp.empirical["current_account"], comp.model["current_account"], "{:.3f}"),
    ("External", r"Liability share of gross VA", comp.empirical["liability_share_gross_va"], comp.model["liability_share_gross_va"], "{:.2f}"),
]
ov = pd.DataFrame(rows, columns=["group", "label", "data", "model", "fmt"])
ov["ratio"] = ov.model / ov.data
ov["flip"] = ov.ratio < 0
ov["abs_ratio"] = ov.ratio.abs()
_y, _yp, _prev = float(len(ov)) + 1.8, [], None
for g_ in ov.group:
    _y -= 1.0 if (_prev is None or g_ == _prev) else 1.6
    _yp.append(round(_y, 2))
    _prev = g_
ov["ypos"] = _yp


def fmtnum(v: float, f: str) -> str:
    s = f.format(v)
    return s.replace("-", "$-$")


with open(OUT / "overview_rows.tex", "w", encoding="utf-8") as fh:
    fh.write("% generated by build_slide_data.py\n")
    for r in ov.itertuples():
        style = "ovflip" if r.flip else "ovdot"
        fh.write(f"\\addplot[{style}] coordinates {{({r.abs_ratio:.6g},{r.ypos})}};\n")
        fh.write(f"\\addplot[ovstem] coordinates {{(1,{r.ypos}) ({r.abs_ratio:.6g},{r.ypos})}};\n")
with open(OUT / "overview_labels.tex", "w", encoding="utf-8") as fh:
    fh.write("% generated by build_slide_data.py\n")
    for g_, gdf in ov.groupby("group", sort=False):
        fh.write(f"\\ovgroup{{{gdf.ypos.iloc[0]}}}{{{g_}}}\n")
    for r in ov.itertuples():
        fh.write(
            f"\\ovrow{{{r.ypos}}}{{{r.label}}}{{{fmtnum(r.data, r.fmt)}}}{{{fmtnum(r.model, r.fmt)}}}\n"
        )
save(ov.drop(columns=["fmt"]), "overview.csv")

# ---------------------------------------------------------------- Scalars for the slide text
vals = {
    "foreignshare": f"{100 * foreign_share_2025:.0f}",
    "needA": f"{100 * needed[2007]:.0f}",
    "needB": f"{100 * needed[1990]:.0f}",
    "cfctaxTwentyTwo": f"{100 * s22.cfc_tax:.1f}",
    "ncfTwentyTwo": f"{100 * s22.ncf:.1f}",
    "fcfTwentyTwo": f"{100 * s22.fcf:.1f}",
    "compTwentyTwo": f"{100 * s22.comp:.1f}",
    "nonlaborTwentyTwo": f"{100 * (1 - s22.comp):.1f}",
    "muNocapLo": f"{mk_out.nocap_lo.min():.2f}",
    "muNocapHi": f"{mk_out.nocap_hi.max():.2f}",
    "muCapLo": f"{mk_out.cap_lo.min():.2f}",
    "muCapHi": f"{mk_out.cap_hi.max():.2f}",
    "growthData": f"{100 * grate['2008-2023']:.1f}",
    "growthModel": f"{100 * grate['model_nb06']:.1f}",
}
with open(OUT / "values.tex", "w", encoding="utf-8") as fh:
    fh.write("% generated by build_slide_data.py\n")
    for k, v in vals.items():
        fh.write(f"\\newcommand{{\\val{k}}}{{{v}}}\n")

# ---------------------------------------------------------------- Report
print("CHECKS (all passed):")
for n, g, w in checks:
    print(f"  {n}: {g:.6g} (target {w:.6g})")
print("\nValues used in slide text:", vals)
print("Overview model/data ratios:")
print(ov[["label", "data", "model", "ratio"]].round(4).to_string())
