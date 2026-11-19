"""Credit, capital and buybacks: can Q/Y rise without the dividend channel? (2026-11-18)

Reads the raw pulls in ../data/raw (fetch_fred.py, fetch_wrds.py) and writes
  ../data/processed/*.csv, ../data/values.{json,tex}, ../figures/f*.{pdf,png}.
Run from this folder:
  uv run --no-project --python 3.12 --with numpy==2.3.5 --with pandas==2.2.3 --with matplotlib==3.10.0 python -I build.py

Sector: Z.1 nonfinancial corporate business (NFC), 93% of AHP total-corporate Q in 2025. Y is NFC GVA.
Fed identity (series analyzer FL102010405): Q = E + FDI_mv + TL - FA, so debt enters Q one-for-one.
"""
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.ticker import FuncFormatter, MultipleLocator

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
FRED, WRDS = ROOT / "data" / "raw" / "fred", ROOT / "data" / "raw" / "wrds"
PROC, FIG = ROOT / "data" / "processed", ROOT / "figures"
PROC.mkdir(parents=True, exist_ok=True)
FIG.mkdir(parents=True, exist_ok=True)
PROJECT = HERE.parents[4]
MAP = PROJECT / "Empirical_Data" / "Variable_mappings" / "Empirical_Mapping_Annual" / "data_intermediate"
Y0, Y1, YB = 2009, 2025, 2011  # u-regime window; 2011 base reported alongside (2009 FCF spike)
VALS: dict[str, float | str] = {}


def V(k, v):
    VALS[k] = v


# ================================================================== 1. Z.1 NFC, annual
def fser(sid):
    d = pd.read_csv(FRED / f"{sid}.csv", na_values=["."])
    d.columns = ["date", "v"]
    d["date"] = pd.to_datetime(d["date"])
    return d.set_index("date")["v"] / 1e6  # million -> trillion USD


def level(sid):  # end of Q4
    x = fser(sid)
    x = x[x.index.month == 10]
    x.index = x.index.year
    return x


def flow(sid):  # sum of four NSA quarterly flows
    x = fser(sid).dropna()
    g = x.groupby(x.index.year)
    return g.sum()[g.count() == 4]


def ttm_latest(sid):  # last four quarters, and the end date
    x = fser(sid).dropna()
    return x.iloc[-4:].sum(), x.index[-1]


def level_latest(sid):
    x = fser(sid).dropna()
    return x.iloc[-1], x.index[-1]


LV = {"Q": "BOGZ1LM102010405Q", "E": "NCBEILQ027S", "FDI": "BOGZ1LM103192105Q", "TL": "TLBSNNCB", "FA": "TFAABSNNCB",
      "DEBT": "BCNSDODNS", "BONDS": "NCBDBIQ027S", "PC": "BOGZ1FL103167205Q", "K": "BOGZ1LM102010005Q",
      "RE_RES": "BOGZ1FL105035023Q", "RE_NONRES": "BOGZ1FL105035033Q", "EQP": "BOGZ1LM105015205Q",
      "IPP": "BOGZ1LM105013765Q", "INV": "BOGZ1LM105020015Q", "Q_FIN": "BOGZ1LM792010405Q"}
FL = {"Y": "BOGZ1FU106902501Q", "COMP": "BOGZ1FU106025005Q", "NOS": "BOGZ1FU106402101Q", "TAX": "BOGZ1FU106220001Q",
      "NCF": "BOGZ1FU105050985Q", "CAPX": "BOGZ1FU105050005Q", "NB": "BOGZ1FU104104005Q", "NEI": "BOGZ1FU103164103Q",
      "DIV": "BOGZ1FU106121075Q", "NAFA": "BOGZ1FU104090005Q", "NIL": "BOGZ1FU104190005Q", "INT": "BOGZ1FU106130003Q"}
z = pd.DataFrame({**{k: level(s) for k, s in LV.items()}, **{k: flow(s) for k, s in FL.items()}}).loc[1990:Y1]
assert z.notna().all().all() and len(z) == 36
z["RE"] = z.RE_RES + z.RE_NONRES
z["EQ"] = z.E + z.FDI  # equity claims at market value
z["OTHER"] = z.TL - z.DEBT - z.FA  # non-debt liabilities minus financial assets (negative)
assert (z.EQ + z.DEBT + z.OTHER - z.Q).abs().max() < 1e-3, "Fed identity Q = E + FDI + TL - FA fails"
z["LOANS"] = z.DEBT - z.BONDS
z["q"] = z.Q / z.K
z["BUY"] = -z.NEI  # net buybacks (net retirements incl. cash M&A), positive = net retirement
z["FCF"] = z.NOS - z.TAX - z.NCF  # AHP D for the NFC sector
z["DEQ"] = z.DIV + z.BUY  # net payout to shareholders
z["NFC_SHARE_Q"] = z.Q / (z.Q + z.Q_FIN)
# cross-check against the project's mapping file (Sept 2026 vintage)
corp = pd.read_csv(MAP / "us_corporate_external_corporate.csv")
m = corp.pivot(index="year", columns="mapping_id", values="value") / 1e6
chk = (m["D_US_AHP_FCF_NFC"].reindex(z.index) / z.FCF - 1).abs().loc[1990:2024].max()
chkQ = (m["Q_US_AHP_ENTERPRISE_VALUE_NFC"].reindex(z.index) / z.Q - 1).abs().loc[1990:2024].max()
print(f"vintage check vs mapping file: FCF max rel diff {chk:.4f}, Q max rel diff {chkQ:.4f}")
V("vintage_fcf_diff", 100 * chk)
V("vintage_q_diff", 100 * chkQ)
z.round(6).to_csv(PROC / "z1_nfc_annual_trn.csv")
r = z.div(z.Y, axis=0)  # shares of NFC GVA
r[["Q", "EQ", "E", "FDI", "DEBT", "BONDS", "LOANS", "PC", "OTHER", "K", "RE", "EQP", "IPP", "INV",
   "NB", "BUY", "DIV", "DEQ", "NCF", "CAPX", "NAFA", "INT", "FCF"]].mul(100).round(3).to_csv(PROC / "z1_nfc_ratios_pct_gva.csv")

# latest quarter (2026Q2): stocks at end-quarter over TTM GVA
yl, dl = ttm_latest(FL["Y"])
lat = {k: level_latest(LV[k])[0] for k in ["Q", "E", "FDI", "DEBT", "K", "PC", "BONDS"]}
V("latest_q", f"{dl.year}Q{(dl.month - 1) // 3 + 1}")
for k in ["Q", "DEBT", "K", "PC"]:
    V(f"lat_{k}Y", 100 * lat[k] / yl)
V("lat_EQY", 100 * (lat["E"] + lat["FDI"]) / yl)
V("lat_q", lat["Q"] / lat["K"])
V("lat_NB_ttm", 1e3 * ttm_latest(FL["NB"])[0])  # USD bn
V("lat_NBY", 100 * ttm_latest(FL["NB"])[0] / yl)
V("lat_BUYY", -100 * ttm_latest(FL["NEI"])[0] / yl)
V("lat_NCFY", 100 * ttm_latest(FL["NCF"])[0] / yl)

for y in [1990, 2000, 2007, Y0, YB, 2019, 2021, Y1]:
    for k in ["Q", "EQ", "DEBT", "BONDS", "LOANS", "PC", "K", "RE", "EQP", "IPP", "INV", "FCF", "DEQ", "DIV", "BUY", "NB", "NCF"]:
        V(f"{k}Y{y}", 100 * r.loc[y, k])
    V(f"q{y}", z.loc[y, "q"])
    V(f"Y_tn{y}", z.loc[y, "Y"])
    V(f"Q_tn{y}", z.loc[y, "Q"])
    V(f"DEBT_tn{y}", z.loc[y, "DEBT"])
V("nfc_share_q2025", 100 * z.loc[Y1, "NFC_SHARE_Q"])
V("PC_tn2025", z.loc[Y1, "PC"])

# ---- decompositions
rows = []
for b in [Y0, YB]:
    dQ = r.loc[Y1, "Q"] - r.loc[b, "Q"]
    comp = {k: r.loc[Y1, k] - r.loc[b, k] for k in ["E", "FDI", "DEBT", "OTHER"]}
    dlQY = np.log(r.loc[Y1, "Q"] / r.loc[b, "Q"])
    dlq, dlKY = np.log(z.loc[Y1, "q"] / z.loc[b, "q"]), np.log(r.loc[Y1, "K"] / r.loc[b, "K"])
    rows.append(dict(base=b, dQY_pp=100 * dQ, **{f"d{k}Y_pp": 100 * v for k, v in comp.items()},
                     **{f"sh_{k}": 100 * v / dQ for k, v in comp.items()},
                     dlogQY=dlQY, dlog_q=dlq, dlog_KY=dlKY, sh_q=100 * dlq / dlQY, sh_KY=100 * dlKY / dlQY))
dec = pd.DataFrame(rows).set_index("base")
dec.round(4).to_csv(PROC / "z1_q_decomposition.csv")
for b in [Y0, YB]:
    for c in dec.columns:
        V(f"dec{b}_{c}", dec.loc[b, c])

# ---- flow averages and cumulative sums
per = {"pre": (1990, 2007), "post": (Y0, Y1), "postB": (YB, Y1)}
for p, (a, bb) in per.items():
    for k in ["NB", "BUY", "DIV", "DEQ", "NCF", "CAPX", "FCF", "NAFA", "INT"]:
        V(f"avg_{p}_{k}", 100 * r.loc[a:bb, k].mean())
for k in ["NB", "BUY", "DIV", "NCF", "FCF", "DEQ"]:
    V(f"cum_{k}", z.loc[Y0:Y1, k].sum())  # trn USD
V("cum_dDEBT", z.loc[Y1, "DEBT"] - z.loc[Y0, "DEBT"])
V("cum_dQ", z.loc[Y1, "Q"] - z.loc[Y0, "Q"])
V("cum_dEQ", z.loc[Y1, "EQ"] - z.loc[Y0, "EQ"])
V("cum_dK", z.loc[Y1, "K"] - z.loc[Y0, "K"])
V("debt_min_post", 100 * r.loc[Y0:Y1, "DEBT"].min())
V("debt_max_post", 100 * r.loc[Y0:Y1, "DEBT"].max())
V("debt_max_post_year", int(r.loc[Y0:Y1, "DEBT"].idxmax()))
V("K_min_post", 100 * r.loc[Y0:Y1, "K"].min())
V("K_max_post", 100 * r.loc[Y0:Y1, "K"].max())

# ---- payout robustness: replace D = FCF by the shareholder payout, Q by equity claims
def dl(s, a, b):
    return float(np.log(s[b] / s[a]))


rob = []
avg = lambda s, a, b: s.loc[a:b].mean()  # noqa: E731
for lab, (a0, a1), (b0, b1) in [("2009", (Y0, Y0), (Y1, Y1)), ("2011", (YB, YB), (Y1, Y1)), ("3y avg", (2009, 2011), (2023, 2025))]:
    for name, num, den in [("FCF/Q (deck)", "FCF", "Q"), ("(div+net buybacks)/equity", "DEQ", "EQ"), ("net dividends/equity", "DIV", "EQ")]:
        Da, Db = avg(r[num], a0, a1), avg(r[num], b0, b1)
        Qa, Qb = avg(r[den], a0, a1), avg(r[den], b0, b1)
        dQY, dDY = np.log(Qb / Qa), np.log(Db / Da)
        rob.append(dict(base=lab, measure=name, yield_start=100 * Da / Qa, yield_end=100 * Db / Qb,
                        dlog_QD=dQY - dDY, dlog_QY=dQY, dlog_DY=dDY, share_QY=100 * dQY / (dQY - dDY)))
rob = pd.DataFrame(rob)
rob.round(4).to_csv(PROC / "payout_robustness_nfc.csv", index=False)
for _, x in rob.iterrows():
    key = {"FCF/Q (deck)": "fcf", "(div+net buybacks)/equity": "deq", "net dividends/equity": "div"}[x.measure]
    bk = {"2009": "a", "2011": "b", "3y avg": "c"}[x.base]
    for c in ["yield_start", "yield_end", "dlog_QD", "dlog_QY", "dlog_DY", "share_QY"]:
        V(f"rob_{key}{bk}_{c}", x[c])

# ---- FCF decomposition from Z.1 table S.5.a (S11.1.i.a), annual; closes exactly
# FCF = NOS - T - NCF = net dividends + net buybacks + net interest - net borrowing
#       + net direct investment (outward - inward, both excl. reinvested earnings)
#       + (other financial assets - other liabilities) + (rents + other current transfers + net capital transfers + stat. discrepancy)
s5 = pd.read_csv(ROOT / "data" / "raw" / "fed_z1" / "S11_1_i_a.csv", na_values=["ND"]).set_index("date")
s5 = s5.loc[:, ~s5.columns.duplicated()].apply(pd.to_numeric, errors="coerce").loc[1990:Y1] / 1e6  # trn USD


def g5(code):
    return s5[f"{code}.A"]


fd = pd.DataFrame(index=s5.index)
fd["NOS"], fd["TAX"], fd["NCF"] = g5("FU106402101"), g5("FU106220001"), g5("FU105050985")
fd["FCF"] = fd.NOS - fd.TAX - fd.NCF
fd["NOS_T"] = fd.NOS - fd.TAX
fd["DIV"] = g5("FU106121001") - g5("FU106121101")  # dividends paid - received
fd["BUY"] = -g5("FU103164105")  # - net equity issuance
fd["INT"] = g5("FU106130001") - g5("FU106130101")  # interest paid - received
fd["NB"] = g5("FU104122005") + g5("FU104135005")  # debt securities + loans, liability transactions
fd["ODI"] = g5("FU103092105") - g5("FU103092201")  # US direct investment abroad, equity, minus reinvested earnings received
fd["IDI"] = g5("FU103192105") - g5("FU103192201")  # FDI in US, equity, minus reinvested earnings paid
fd["NDI"] = fd.ODI - fd.IDI
fd["OFA"] = g5("FU104090005") - g5("FU103092105")  # financial assets other than direct investment equity
fd["OL"] = g5("FU104194005") - fd.NB + fd.BUY - g5("FU103192105")  # liabilities other than debt, equity, FDI equity
fd["NOF"] = fd.OFA - fd.OL
fd["RENT"], fd["TR"], fd["NKT"], fd["SD"] = g5("FU106112001"), g5("FU106403001"), g5("FU105440005"), g5("FU107005045")
fd["OTH"] = fd.RENT + fd.TR + fd.NKT + fd.SD
fd["CRED"] = fd.INT - fd.NB
fd["NAFA"] = g5("FU104090005")
FD_PARTS = ["DIV", "BUY", "CRED", "NDI", "NOF", "OTH"]
res5 = (fd[FD_PARTS].sum(axis=1) - fd.FCF).abs().max()
assert res5 < 1e-4, f"S.5.a FCF identity residual {res5}"
assert (fd.FCF - z.FCF).abs().max() < 1e-4, "S.5.a FCF differs from the FRED-based FCF"
print(f"FCF decomposition closes: max residual {res5:.1e} trn; S.5.a DIV vs FRED net dividends max diff {(fd.DIV - z.DIV).abs().max():.3f} trn")
fd.round(6).to_csv(PROC / "fcf_decomposition_nfc_trn.csv")
V("fd_div_diff", (fd.DIV - z.DIV).abs().max())
fdr = fd.div(z.Y, axis=0)
fdr.mul(100).round(3).to_csv(PROC / "fcf_decomposition_nfc_pct_gva.csv")
FD_FINE = ["NOS_T", "NCF", "FCF", "DIV", "BUY", "INT", "NB", "ODI", "IDI", "OFA", "OL", "RENT", "TR", "NKT", "SD", "OTH", "CRED", "NDI", "NOF", "NAFA"]
for p, (a, bb) in per.items():
    for k in FD_FINE:
        V(f"fd_avg_{p}_{k}", 100 * fdr.loc[a:bb, k].mean())
for lab, a in [("a", Y0), ("b", YB)]:
    for k in FD_FINE:
        V(f"fd_cum{lab}_{k}", fd.loc[a:Y1, k].sum())
    V(f"fd_cum{lab}_DEQ", fd.loc[a:Y1, ["DIV", "BUY"]].sum().sum())
    V(f"fd_cum{lab}_share_payout", 100 * fd.loc[a:Y1, ["DIV", "BUY"]].sum().sum() / fd.loc[a:Y1, "FCF"].sum())

# ---- stock-flow link between the two sides, from the same table (appendix explainer)
# change in each end-year stock = transactions (the cash-flow side) + revaluation (FR) + other volume changes and breaks
# Q = total liabilities and equity - financial assets, so the rows add up to Q.
s5full = pd.read_csv(ROOT / "data" / "raw" / "fed_z1" / "S11_1_i_a.csv", na_values=["ND"]).set_index("date")
s5full = s5full.loc[:, ~s5full.columns.duplicated()].apply(pd.to_numeric, errors="coerce") / 1e6
zero = pd.Series(0.0, index=s5full.index)


def g5f(*codes):
    return sum(s5full[f"{c}.A"] for c in codes)


SF = {  # level, transactions, revaluation
    "E": (g5f("LM103164105"), g5f("FU103164105"), g5f("FR103164105")),
    "FDI": (g5f("FL103192105"), g5f("FU103192105"), g5f("FR103192105")),
    "DEBT": (g5f("FL104122005", "FL104135005"), g5f("FU104122005", "FU104135005"), zero),  # book value: no revaluation line
    "TLE": (g5f("FL104194005"), g5f("FU104194005"), g5f("FR104194005")),
    "FA": (g5f("FL104090005"), g5f("FU104090005"), g5f("FR104090005")),
}
SF["OL"] = tuple(t - e - f - d for t, e, f, d in zip(SF["TLE"], SF["E"], SF["FDI"], SF["DEBT"]))
SF["MFA"] = tuple(-x for x in SF["FA"])  # minus financial assets
SF["Q"] = tuple(t - f for t, f in zip(SF["TLE"], SF["FA"]))
chkS = {k: (SF[k][0].reindex(z.index) - z[c]).abs().max() for k, c in [("E", "E"), ("FDI", "FDI"), ("DEBT", "DEBT"), ("Q", "Q")]}
assert max(chkS.values()) < 1e-3, f"S.5.a stocks differ from the FRED stocks: {chkS}"
SF_ROWS = ["E", "FDI", "DEBT", "OL", "MFA", "Q"]
sf_rows = []


def f1(x):  # USD tn with one decimal, as a string for values.tex; no "-0.0"
    t = f"{x:.1f}"
    return "0.0" if t == "-0.0" else t


for b in [Y0, YB]:
    for k in SF_ROWS:
        lv, fu, fr = SF[k]
        d = lv.loc[Y1] - lv.loc[b]
        fl, rv = fu.loc[b + 1:Y1].sum(), fr.loc[b + 1:Y1].sum()
        sf_rows.append(dict(base=b, item=k, level_base=lv.loc[b], level_end=lv.loc[Y1], change=d, flows=fl, reval=rv, other=d - fl - rv))
sf = pd.DataFrame(sf_rows)
for b in [Y0, YB]:
    s = sf[sf.base == b].set_index("item")
    assert (s.loc[SF_ROWS[:-1], ["change", "flows", "reval", "other"]].sum() - s.loc["Q", ["change", "flows", "reval", "other"]]).abs().max() < 1e-6
    for k in SF_ROWS:
        for c in ["change", "flows", "reval", "other"]:
            V(f"sf{b}_{k}_{c}", f1(s.loc[k, c]))  # one decimal throughout the explainer table
    V(f"sf{b}_E_flows_abs", f1(-s.loc["E", "flows"]))  # net shares retired
    V(f"sf{b}_E_reval_share", 100 * s.loc["E", "reval"] / s.loc["E", "change"])
    V(f"sf{b}_Q_reval_share", 100 * s.loc["Q", "reval"] / s.loc["Q", "change"])
    V(f"sf{b}_dK", z.loc[Y1, "K"] - z.loc[b, "K"])
sf.round(6).to_csv(PROC / "stock_flow_reconciliation_nfc_trn.csv", index=False)
print(f"stock-flow, end-{Y0} to end-{Y1}:\n" + sf[sf.base == Y0].round(2).to_string(index=False))
# 2025 market-value balance sheet (for the value-side explainer)
for k, v in {"Q": z.loc[Y1, "Q"], "FA": z.loc[Y1, "FA"], "E": z.loc[Y1, "E"], "FDI": z.loc[Y1, "FDI"], "DEBT": z.loc[Y1, "DEBT"],
             "OL": z.loc[Y1, "TL"] - z.loc[Y1, "DEBT"], "TOT": z.loc[Y1, "Q"] + z.loc[Y1, "FA"]}.items():
    V(f"bs{Y1}_{k}", f1(v))

# ================================================================== 2. Compustat, US nonfinancial public firms
f = pd.read_csv(WRDS / "funda_us_1989_2026.csv.gz", dtype={"gvkey": str})
co = pd.read_csv(WRDS / "company_us.csv.gz", dtype={"gvkey": str})
f = f.sort_values(["gvkey", "fyear", "at"]).drop_duplicates(["gvkey", "fyear"], keep="last").merge(co[["gvkey", "sic"]], on="gvkey", how="left")
sic = f.sich.fillna(f.sic)
f["fin"] = (sic >= 6000) & (sic < 7000)
f["me"] = f.csho * f.prcc_f
for k in ["dvt", "prstkc", "sstk", "dltis", "dltr", "dlcch", "dltt", "dlc", "che", "capx", "xrd", "oancf", "sale", "at"]:
    f[k] = f[k].fillna(0)
f["debt"] = f.dltt + f.dlc
f["netdebtiss"] = f.dltis - f.dltr + f.dlcch
nf = f[~f.fin & (f.fyear <= Y1)]
cs = nf.groupby("fyear").agg(n=("gvkey", "nunique"), me=("me", "sum"), sale=("sale", "sum"), dvt=("dvt", "sum"), buy=("prstkc", "sum"),
                             iss=("sstk", "sum"), dltis=("dltis", "sum"), dltr=("dltr", "sum"), netdebtiss=("netdebtiss", "sum"),
                             debt=("debt", "sum"), che=("che", "sum"), capx=("capx", "sum"), xrd=("xrd", "sum"), oancf=("oancf", "sum"))
cs.loc[:, cs.columns != "n"] /= 1e3  # USD bn
cs = cs.loc[1990:Y1]
cs["dy"] = cs.dvt / cs.me
cs["py"] = (cs.dvt + cs.buy) / cs.me
cs["npy"] = (cs.dvt + cs.buy - cs.iss) / cs.me
cs["buy_share"] = cs.buy / (cs.dvt + cs.buy)
cs["buy_pct_Y"] = 100 * cs.buy / (1e3 * z.Y.reindex(cs.index))
cs.round(5).to_csv(PROC / "compustat_nonfin_annual_bn.csv")
for y in [1990, 2000, 2007, Y0, YB, 2019, 2021, 2024, Y1]:
    for k in ["dvt", "buy", "iss", "debt", "capx", "netdebtiss"]:
        V(f"cs_{k}{y}", cs.loc[y, k])
    for k in ["dy", "py", "npy", "buy_share"]:
        V(f"cs_{k}{y}", 100 * cs.loc[y, k])
    V(f"cs_n{y}", int(cs.loc[y, "n"]))
V("cs_cumbuy", cs.loc[Y0:Y1, "buy"].sum() / 1e3)
V("cs_cumdiv", cs.loc[Y0:Y1, "dvt"].sum() / 1e3)
V("cs_cumiss", cs.loc[Y0:Y1, "iss"].sum() / 1e3)
V("cs_me_mult", cs.loc[Y1, "me"] / cs.loc[Y0, "me"])
V("cs_pay_mult", (cs.loc[Y1, "dvt"] + cs.loc[Y1, "buy"]) / (cs.loc[Y0, "dvt"] + cs.loc[Y0, "buy"]))
V("cs_me_multB", cs.loc[Y1, "me"] / cs.loc[YB, "me"])
V("cs_pay_multB", (cs.loc[Y1, "dvt"] + cs.loc[Y1, "buy"]) / (cs.loc[YB, "dvt"] + cs.loc[YB, "buy"]))
V("cs_buy_pctY_post", cs.loc[Y0:Y1, "buy_pct_Y"].mean())

# equity share of the AI-related firms (annual market value, fiscal year-end)
AI7 = {"001690": "AAPL", "012141": "MSFT", "160329": "GOOGL", "064768": "AMZN", "170617": "META", "117768": "NVDA", "012142": "ORCL"}
ai = nf[nf.gvkey.isin(AI7)].groupby("fyear").me.sum() / 1e3
cs["ai7_me"] = ai.reindex(cs.index)
for y in [Y0, YB, Y1]:
    V(f"ai7_me_share{y}", 100 * cs.loc[y, "ai7_me"] / cs.loc[y, "me"])
V("ai7_share_dme", 100 * (cs.loc[Y1, "ai7_me"] - cs.loc[Y0, "ai7_me"]) / (cs.loc[Y1, "me"] - cs.loc[Y0, "me"]))
V("ai7_me2025_tn", cs.loc[Y1, "ai7_me"] / 1e3)

# ---- where firm borrowing went: sources-and-uses bounds, from debt_use_bounds.py (run it before this file)
DU_S, DU_A = PROC / "debt_use_bounds_summary.csv", PROC / "debt_use_bounds_annual.csv"
if not (DU_S.exists() and DU_A.exists()):
    raise SystemExit("run debt_use_bounds.py first: it writes data/processed/debt_use_bounds_{summary,annual}.csv")
dus = pd.read_csv(DU_S).set_index(["variant", "window"])
dua = pd.read_csv(DU_A)
DU_K = ["PAY", "INV", "MA", "FIN", "OPD", "PAYMA"]
DU_ROWS = {"": ("base", f"{Y0}-{Y1} firm-years"), "c": ("base", f"{Y0}-{Y1} firm-cumulative"), "B": ("base", f"{YB}-{Y1} firm-years"),
           "g": ("gross_payout", f"{Y0}-{Y1} firm-years"), "r": ("rnd_as_investment", f"{Y0}-{Y1} firm-years")}
for tag, key in DU_ROWS.items():  # keys du{tag}_{use}_{lo,pr,hi}: % of positive net borrowing, whole percent
    row = dus.loc[key]
    for k in DU_K:
        for b in ["lo", "pr", "hi"]:
            V(f"du{tag}_{k}_{b}", f"{row[f'{b}_{k}_pct_ndp']:.0f}")
    for b in ["lo", "pr", "hi"]:
        V(f"du{tag}_paydebt_{b}", f"{row[f'{b}_PAY_pct_pay']:.0f}")  # % of payout paid by debt
        V(f"du{tag}_invdebt_{b}", f"{row[f'{b}_INV_pct_inv']:.0f}")  # % of capex paid by debt
    for k in ["ndp", "ndm", "nd_net"]:
        V(f"du{tag}_{k}", f"{row[f'{k}_tn']:.1f}")
V("du_nfy", int(dus.loc[DU_ROWS[""], "n_firmyears"]))
V("du_nfirms", int(dus.loc[DU_ROWS[""], "n_firms"]))
dub = dua[dua.variant == "base"].set_index("fyear")
du_inv = 100 * dub.pr_INV / dub.ndp
V("du_inv_pr_min_pre", f"{du_inv.loc[Y0:2021].min():.0f}")
V("du_inv_pr_max_pre", f"{du_inv.loc[Y0:2021].max():.0f}")
V("du_inv_pr_min_ai", f"{du_inv.loc[2022:Y1].min():.0f}")
V("du_inv_pr_max_ai", f"{du_inv.loc[2022:Y1].max():.0f}")

# ================================================================== 3. AI firms, quarterly
q = pd.read_csv(WRDS / "fundq_ai_firms.csv.gz", dtype={"gvkey": str}, parse_dates=["datadate"])
q = q.sort_values(["gvkey", "datadate"]).drop_duplicates(["gvkey", "datadate"], keep="last")
for k in ["oancfy", "capxy", "prstkcy", "sstky", "dvy", "dltisy", "dltry"]:
    prev = q.groupby(["gvkey", "fyearq"])[k].shift(1)
    q[k[:-1] + "_q"] = np.where(q.fqtr == 1, q[k], q[k] - prev)
q["debt"] = q.dlttq + q.dlcq
q["cq"] = q.datadate.dt.to_period("Q")
q.to_csv(PROC / "ai_firms_quarterly_musd.csv", index=False)
BIG5 = ["MSFT", "GOOGL", "AMZN", "META", "ORCL"]
b5 = q[q.tic.isin(BIG5)]
FLQ = ["oancf_q", "capx_q", "prstkc_q", "dv_q", "dltis_q", "dltr_q"]


def big5_sum(col):  # NaN unless all five firms report (pivot_table would turn a missing value into 0)
    p = b5.groupby(["cq", "tic"])[col].sum(min_count=1).unstack()
    return p.sum(axis=1).where(p.notna().sum(axis=1) == 5)


qb = pd.DataFrame({c: big5_sum(c) for c in FLQ + ["debt", "cheq", "mkvaltq"]}) / 1e3  # USD bn
ttm = qb[FLQ].rolling(4, min_periods=4).sum().add_suffix("_ttm")
qb = qb.join(ttm)
qb["capx_oancf"] = qb.capx_q_ttm / qb.oancf_q_ttm
qb["netdebtiss_ttm"] = qb.dltis_q_ttm - qb.dltr_q_ttm
qb.index = qb.index.astype(str)
qb.round(3).to_csv(PROC / "ai_big5_quarterly_bn.csv")
debt_firm = (q.pivot_table(index="cq", columns="tic", values="debt") / 1e3)
debt_firm.index = debt_firm.index.astype(str)
debt_firm.round(3).to_csv(PROC / "ai_firms_debt_by_firm_bn.csv")
last = qb.dropna(subset=["capx_q_ttm"]).index[-1]
V("ai_last_q", last)
for p in ["2019Q4", "2023Q4", "2024Q4", "2025Q4", last]:
    t = p.replace("Q", "q")
    for c in ["capx_q_ttm", "oancf_q_ttm", "debt", "cheq"]:
        V(f"b5_{c.split('_')[0]}_{t}", qb.loc[p, c])
    V(f"b5_ratio_{t}", 100 * qb.loc[p, "capx_oancf"])
for p in ["2023Q4", "2025Q4", last]:
    V(f"b5_dltis_{p.replace('Q', 'q')}", qb.loc[p, "dltis_q_ttm"])
    V(f"b5_netiss_{p.replace('Q', 'q')}", qb.loc[p, "netdebtiss_ttm"])
lastb = qb.dropna(subset=["prstkc_q_ttm"]).index[-1]
V("ai_last_qbuy", lastb)
for p in ["2021Q4", "2023Q4", "2025Q4", lastb]:
    V(f"b5_buy_{p.replace('Q', 'q')}", qb.loc[p, "prstkc_q_ttm"])
V("b5_ddebt_yoy", qb.loc[last, "debt"] - qb.loc[str(pd.Period(last) - 4), "debt"])
V("crwv_debt_last", debt_firm.loc[last, "CRWV"])
# scale against the NFC sector, latest Z.1 quarter (2026Q2)
zq = VALS["latest_q"]
V("b5_ddebt_to_zq", qb.loc[zq, "debt"] - qb.loc[str(pd.Period(zq) - 4), "debt"])
V("b5_ddebt_share_nb", 100 * VALS["b5_ddebt_to_zq"] / VALS["lat_NB_ttm"])
V("b5_debt_share_nfc", 100 * qb.loc[zq, "debt"] / (1e3 * level_latest(LV["DEBT"])[0]))

# ================================================================== 4. figures
INK, MUTED, GRID, WASH = "#1A1A1A", "#6B6B6B", "#E6E6E6", "#F0EFEC"
BLUE, ORANGE, AQUA, YELLOW, MAGENTA, VIOLET, DARK, LBLUE = "#2A78D6", "#EB6834", "#1BAF7A", "#EDA100", "#E87BA4", "#6250D6", "#104281", "#8AB8EE"
plt.rcParams.update({
    "font.family": "sans-serif", "font.size": 10.5, "axes.edgecolor": MUTED, "axes.linewidth": 0.8,
    "axes.spines.top": False, "axes.spines.right": False, "xtick.color": MUTED, "ytick.color": MUTED,
    "axes.labelcolor": INK, "text.color": INK, "figure.dpi": 100, "savefig.dpi": 200, "lines.linewidth": 2.0,
    "axes.grid": True, "axes.grid.axis": "y", "grid.color": GRID, "grid.linewidth": 0.7, "axes.axisbelow": True,
    "legend.frameon": False, "legend.fontsize": 9,
})
pct0 = FuncFormatter(lambda v, _: f"{v:.0f}%")
pct1 = FuncFormatter(lambda v, _: f"{v:.1f}%")
XL = (1989.5, Y1 + 2.2)  # room for the value labels at the right end


def context(ax, x0=1989.5, x1=Y0 - 0.5):
    ax.axvspan(x0, x1, color=WASH, lw=0, zorder=0)
    ax.text((x0 + x1) / 2, 0.99, "pre-2009: context", transform=ax.get_xaxis_transform(), ha="center", va="top", fontsize=8.5, color=MUTED)


def endval(ax, x, y, txt, dy=0):
    ax.annotate(txt, (x, y), xytext=(5, dy), textcoords="offset points", va="center", fontsize=9, color=INK)


def below(ax, ncol, **kw):
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.11), ncol=ncol, handlelength=1.8, columnspacing=1.4, **kw)


def save(fig, name):
    fig.savefig(FIG / f"{name}.pdf", bbox_inches="tight", facecolor="white")
    fig.savefig(FIG / f"{name}.png", bbox_inches="tight", facecolor="white")
    plt.close(fig)


yrs = r.index
# ---- F1: credit. Q/Y split into equity claims and debt
fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.4, 4.6), gridspec_kw=dict(width_ratios=[1.35, 1], wspace=0.42))
context(a1)
for k, c, lab, lw, ls in [("Q", DARK, "Q: enterprise value", 2.4, "-"), ("EQ", BLUE, "Equity at market value (incl. FDI equity)", 2.0, "-"),
                          ("DEBT", ORANGE, "Debt securities + loans", 2.0, "-"), ("PC", ORANGE, "of which private credit loans", 1.3, ":")]:
    a1.plot(yrs, 100 * r[k], color=c, lw=lw, ls=ls, label=lab)
    endval(a1, Y1, 100 * r.loc[Y1, k], f"{100 * r.loc[Y1, k]:.0f}%", dy={"Q": -7, "EQ": 7}.get(k, 0))
a1.set_xlim(*XL)
a1.yaxis.set_major_formatter(pct0)
a1.set_ylabel("% of NFC gross value added")
a1.set_title("(a) Q/Y and its funding side, NFC sector, end-year", loc="left", fontsize=10.5)
below(a1, 2)
comps = [("E", "Equity (domestic)"), ("FDI", "FDI equity"), ("DEBT", "Debt securities + loans"), ("OTHER", "Other liabilities\n− financial assets")]
yy = np.arange(len(comps))
for j, (b, c) in enumerate([(Y0, BLUE), (YB, LBLUE)]):
    vals = [dec.loc[b, f"d{k}Y_pp"] for k, _ in comps]
    a2.barh(yy + (j - 0.5) * 0.4, vals, height=0.38, color=c, label=f"{b}→{Y1}   ΔQ/Y = {dec.loc[b, 'dQY_pp']:+.0f} pp")
    for yv, v in zip(yy + (j - 0.5) * 0.4, vals):
        a2.annotate(f"{v:+.0f}", (v, yv), xytext=(4 if v >= 0 else -4, 0), textcoords="offset points", va="center",
                    ha="left" if v >= 0 else "right", fontsize=8.5, color=INK)
a2.set_yticks(yy, [l for _, l in comps])
a2.invert_yaxis()
a2.axvline(0, color=MUTED, lw=0.8)
a2.grid(axis="y", visible=False)
a2.grid(axis="x", color=GRID)
a2.set_xlim(-110, 310)
a2.set_xlabel("contribution to Δ(Q/Y), pp of GVA")
a2.set_title("(b) Q = E + FDI + debt + (other liab. − fin. assets)", loc="left", fontsize=10.5)
a2.legend(loc="upper center", bbox_to_anchor=(0.5, -0.2), ncol=1)
save(fig, "f1_credit_q_funding")

# ---- F2: capital. Q/Y = (Q/K)(K/Y)
fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.4, 4.6), gridspec_kw=dict(width_ratios=[1.35, 1], wspace=0.22))
context(a1)
stack = [("RE", "Real estate (market value)", BLUE), ("EQP", "Equipment", ORANGE), ("IPP", "IPP (R&D, software, originals)", AQUA), ("INV", "Inventories", YELLOW)]
a1.stackplot(yrs, *[100 * r[k] for k, _, _ in stack], colors=[c for *_, c in stack], labels=[l for _, l, _ in stack], edgecolor="white", linewidth=1.2)
a1.plot(yrs, 100 * r.Q, color=DARK, lw=2.4, label="Q: enterprise value")
endval(a1, Y1, 100 * r.loc[Y1, "Q"], f"Q/Y {100 * r.loc[Y1, 'Q']:.0f}%")
endval(a1, Y1, 100 * r.loc[Y1, "K"], f"K/Y {100 * r.loc[Y1, 'K']:.0f}%")
a1.set_xlim(1989.5, Y1 + 4.5)
a1.yaxis.set_major_formatter(pct0)
a1.set_ylabel("% of NFC gross value added")
a1.set_title("(a) Capital K at replacement cost (stacked) vs Q/Y", loc="left", fontsize=10.5)
h, l = a1.get_legend_handles_labels()
a1.legend(h[::-1], l[::-1], loc="upper center", bbox_to_anchor=(0.5, -0.11), ncol=3)
context(a2)
a2.plot(yrs, z.q, color=DARK)
a2.axhline(1, color=MUTED, lw=0.8, ls="--")
for y, off in [(Y0, (14, -10)), (YB, (-6, 10)), (Y1, (0, 10))]:
    a2.plot([y], [z.loc[y, "q"]], "o", color=DARK, ms=6, mec="white", mew=1.5, zorder=3)
    a2.annotate(f"{z.loc[y, 'q']:.2f}", (y, z.loc[y, "q"]), xytext=off, textcoords="offset points", ha="center", fontsize=9)
a2.set_xlim(1989.5, Y1 + 1)
a2.set_ylim(0, 2.8)
a2.set_title("(b) Tobin's q = Q / K", loc="left", fontsize=10.5)
save(fig, "f2_capital_tobin_q")

# ---- F3: flows, % of NFC GVA
fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.4, 4.6), sharey=True, gridspec_kw=dict(wspace=0.08))
context(a1)
a1.bar(yrs, 100 * r.DIV, width=0.8, color=BLUE, label="Net dividends")
pos, neg = (100 * r.BUY).clip(lower=0), (100 * r.BUY).clip(upper=0)
a1.bar(yrs, pos, bottom=100 * r.DIV, width=0.8, color=ORANGE, label="Net buybacks (− net equity issuance)")
a1.bar(yrs, neg, width=0.8, color=ORANGE)
a1.plot(yrs, 100 * r.FCF, color=INK, lw=2.0, label="FCF (AHP D)")
a1.axhline(0, color=MUTED, lw=0.8)
a1.set_xlim(1989.5, Y1 + 0.6)
a1.yaxis.set_major_locator(MultipleLocator(2))
a1.yaxis.set_major_formatter(pct0)
a1.set_ylabel("% of NFC gross value added")
a1.set_title("(a) Shareholder payout vs FCF", loc="left", fontsize=10.5)
below(a1, 3)
context(a2)
for k, c, lab, lw, ls in [("NB", VIOLET, "Net borrowing (debt securities + loans)", 2.0, "-"), ("NCF", AQUA, "Net capital formation", 2.0, "-"),
                          ("BUY", ORANGE, "Net buybacks", 1.4, "--")]:
    a2.plot(yrs, 100 * r[k], color=c, lw=lw, ls=ls, label=lab)
a2.axhline(0, color=MUTED, lw=0.8)
a2.set_xlim(1989.5, Y1 + 0.6)
a2.set_title("(b) Debt flows, investment and buybacks", loc="left", fontsize=10.5)
below(a2, 2)
save(fig, "f3_nfc_flows")

# ---- F4: Compustat payout
fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.4, 4.6), gridspec_kw=dict(wspace=0.22))
cy = cs.index
context(a1)
for k, c, lab in [("buy", ORANGE, "Gross buybacks"), ("dvt", BLUE, "Dividends"), ("iss", MUTED, "Equity issuance")]:
    a1.plot(cy, cs[k], color=c, label=lab)
    endval(a1, Y1, cs.loc[Y1, k], f"{cs.loc[Y1, k]:.0f}")
a1.set_xlim(*XL)
a1.set_ylabel("USD billion, nominal")
a1.set_title("(a) Compustat US nonfinancial firms: payout flows", loc="left", fontsize=10.5)
below(a1, 3)
context(a2)
for k, c, lab, ls in [("py", ORANGE, "(dividends + buybacks) / ME", "-"), ("npy", DARK, "(div. + buybacks − issuance) / ME", "--"), ("dy", BLUE, "dividends / ME", "-")]:
    a2.plot(cy, 100 * cs[k], color=c, ls=ls, label=lab)
    endval(a2, Y1, 100 * cs.loc[Y1, k], f"{100 * cs.loc[Y1, k]:.1f}%")
a2.set_xlim(*XL)
a2.set_ylim(0, None)
a2.yaxis.set_major_formatter(pct0)
a2.set_title("(b) Payout yields on market equity (ME)", loc="left", fontsize=10.5)
below(a2, 2)
save(fig, "f4_compustat_payout")

# ---- F5: AI hyperscalers (x = mid-quarter in fractional years)
def qx(idx):
    return np.array([int(p[:4]) + (int(p[-1]) - 0.5) / 4 for p in idx])


fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.4, 4.6), gridspec_kw=dict(wspace=0.2))
qq = qb.loc["2018Q4":]
xq = qx(qq.index)
for k, c, lab in [("oancf_q_ttm", DARK, "Operating cash flow"), ("capx_q_ttm", AQUA, "Capex"),
                  ("prstkc_q_ttm", ORANGE, "Buybacks"), ("dltis_q_ttm", VIOLET, "Gross long-term debt issuance")]:
    s = qq[k]
    a1.plot(xq, s, color=c, label=lab)
    i = list(qq.index).index(s.last_valid_index())
    endval(a1, xq[i], s.iloc[i], f"{s.iloc[i]:.0f}", dy={"capx_q_ttm": -6, "oancf_q_ttm": 6}.get(k, 0))
a1.set_xlim(2018.5, 2027.2)
a1.xaxis.set_major_locator(MultipleLocator(1))
a1.set_ylabel("USD billion, trailing four quarters")
a1.set_title("(a) MSFT + GOOGL + AMZN + META + ORCL: cash flows", loc="left", fontsize=10.5)
below(a1, 2)
d5 = debt_firm.loc["2019Q4":, BIG5 + ["CRWV"]].fillna(0)
xb = qx(d5.index)
bottom = np.zeros(len(d5))
for k, c in zip(BIG5 + ["CRWV"], [BLUE, ORANGE, AQUA, YELLOW, MAGENTA, VIOLET]):
    a2.bar(xb, d5[k], bottom=bottom, color=c, width=0.2, label=k, edgecolor="white", linewidth=0.6)
    bottom += d5[k].values
cash = qb["cheq"].reindex(d5.index)
a2.plot(xb, cash, color=INK, lw=1.6, ls="--", label="Big-5 cash + short-term investments")
a2.annotate(f"{bottom[-1]:.0f}", (xb[-1], bottom[-1]), xytext=(0, 4), textcoords="offset points", ha="center", fontsize=9)
a2.set_xlim(2019.6, 2026.9)
a2.xaxis.set_major_locator(MultipleLocator(1))
a2.set_ylabel("USD billion, end of quarter")
a2.set_title("(b) Debt (long-term + current), by firm", loc="left", fontsize=10.5)
h, l = a2.get_legend_handles_labels()
a2.legend(h, l, loc="upper center", bbox_to_anchor=(0.5, -0.11), ncol=4)
save(fig, "f5_ai_hyperscalers")

# ---- F6: FCF decomposition (S.5.a). (a) annual uses of FCF, % of GVA; (b) cumulated 2009-25 waterfall, USD tn
GRAY = "#A9A7A1"
FD_STYLE = {"DIV": ("Net dividends", BLUE), "BUY": ("Net buybacks", ORANGE), "CRED": ("Net interest − net borrowing", VIOLET),
            "NDI": ("Net direct investment (out − in)", AQUA), "NOF": ("Other fin. assets − other liabilities", YELLOW),
            "OTH": ("Rents, transfers, stat. discrepancy", GRAY)}
fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.4, 4.9), gridspec_kw=dict(width_ratios=[1.35, 1], wspace=0.5))
context(a1)
pos_b, neg_b = np.zeros(len(fdr)), np.zeros(len(fdr))
for k in FD_PARTS:
    lab, c = FD_STYLE[k]
    v = 100 * fdr[k].values
    p, n = np.clip(v, 0, None), np.clip(v, None, 0)
    a1.bar(fdr.index, p, bottom=pos_b, width=0.8, color=c, label=lab, edgecolor="white", linewidth=0.5)
    a1.bar(fdr.index, n, bottom=neg_b, width=0.8, color=c, edgecolor="white", linewidth=0.5)
    pos_b, neg_b = pos_b + p, neg_b + n
a1.plot(fdr.index, 100 * fdr.FCF, color=INK, lw=2.0, label="FCF = NOS − T − NCF (AHP D)", zorder=4)
a1.axhline(0, color=MUTED, lw=0.8)
a1.set_xlim(1989.5, Y1 + 0.6)
a1.set_ylim(-12.5, 23)
a1.yaxis.set_major_locator(MultipleLocator(5))
a1.yaxis.set_major_formatter(pct0)
a1.set_ylabel("% of NFC gross value added")
a1.set_title("(a) Where FCF goes, NFC sector, annual", loc="left", fontsize=10.5)
below(a1, 3, fontsize=8.5)
wf = [("DIV", "Net dividends", BLUE), ("BUY", "Net buybacks", ORANGE), ("INT", "Net interest", VIOLET), ("NB", "− Net borrowing", VIOLET),
      ("ODI", "Outward direct inv.", AQUA), ("IDI", "− Inward direct inv.", AQUA), ("OFA", "Other fin. assets", YELLOW),
      ("OL", "− Other liabilities", YELLOW), ("OTH", "Rents, transfers, SD", GRAY)]
cum5 = fd.loc[Y0:Y1].sum()
run = 0.0
for i, (k, lab, c) in enumerate(wf):
    v = cum5[k] * (-1 if lab.startswith("−") else 1)
    a2.barh(i, v, left=run, height=0.62, color=c)
    a2.annotate(f"{v:+.1f}".replace("-", "−"), (run + v, i), xytext=(4 if v >= 0 else -4, 0), textcoords="offset points",
                va="center", ha="left" if v >= 0 else "right", fontsize=8.5, color=INK)
    a2.plot([run + v, run + v], [i + 0.31, i + 0.69], color=MUTED, lw=0.6)  # connector to the next bar
    run += v
a2.barh(len(wf), cum5["FCF"], height=0.62, color=INK)
a2.annotate(f"{cum5['FCF']:.1f}", (cum5["FCF"], len(wf)), xytext=(4, 0), textcoords="offset points", va="center", fontsize=8.5, color=INK)
assert abs(run - cum5["FCF"]) < 1e-4
a2.set_yticks(range(len(wf) + 1), [l for _, l, _ in wf] + ["= FCF"])
a2.invert_yaxis()
a2.axvline(0, color=MUTED, lw=0.8)
a2.grid(axis="y", visible=False)
a2.grid(axis="x", color=GRID)
a2.set_xlim(0, 31)
a2.set_xlabel("USD trillion, summed over 2009–2025")
a2.set_title(f"(b) Cumulated {Y0}–{Y1}: FCF of {cum5['FCF']:.1f} tn", loc="left", fontsize=10.5)
save(fig, "f6_fcf_decomposition")

# ---- F7: where firm borrowing went (Compustat). (a) bounds by use, 2009-25; (b) pro-rata shares by fiscal year
from matplotlib.lines import Line2D

DU_USES = [("PAY", "Net payout\n(div. + buybacks − issuance)", ORANGE), ("MA", "Cash M&A", MAGENTA),
           ("PAYMA", "Payout + cash M&A\n(Z.1 shareholder line)", DARK), ("INV", "Capex", AQUA),
           ("FIN", "Cash and financial assets", YELLOW), ("OPD", "Operating deficit", GRAY)]
fig, (a1, a2) = plt.subplots(1, 2, figsize=(12.4, 4.6), gridspec_kw=dict(width_ratios=[1.1, 1], wspace=0.45))
fy, fcum = dus.loc[DU_ROWS[""]], dus.loc[DU_ROWS["c"]]
for i, (k, lab, c) in enumerate(DU_USES):
    lo, pr, hi = (fy[f"{b}_{k}_pct_ndp"] for b in ["lo", "pr", "hi"])
    a1.plot([lo, hi], [i - 0.12] * 2, color=c, lw=8, solid_capstyle="butt")
    a1.plot([pr], [i - 0.12], "o", color="white", mec=INK, mew=1.4, ms=7, zorder=3)
    clo, cpr, chi = (fcum[f"{b}_{k}_pct_ndp"] for b in ["lo", "pr", "hi"])
    a1.plot([clo, chi], [i + 0.22] * 2, color=c, lw=2, alpha=0.6)
    a1.plot([cpr], [i + 0.22], "o", color=c, ms=4.5, zorder=3)
    a1.annotate(f"{lo:.0f}–{hi:.0f}%, pro rata {pr:.0f}%", (hi, i - 0.12), xytext=(6, 0), textcoords="offset points",
                va="center", fontsize=8.5, color=INK)
a1.set_yticks(range(len(DU_USES)), [l for _, l, _ in DU_USES], fontsize=9)
a1.invert_yaxis()
a1.grid(axis="y", visible=False)
a1.grid(axis="x", color=GRID)
a1.set_xlim(0, 100)
a1.xaxis.set_major_formatter(pct0)
a1.set_xlabel(f"% of positive net borrowing, {Y0}–{Y1} (USD {fy.ndp_tn:.1f} tn)")
a1.set_title("(a) Share of borrowing that went to each use: bounds", loc="left", fontsize=10.5)
a1.legend([Line2D([], [], color=MUTED, lw=8), Line2D([], [], ls="", marker="o", color="white", mec=INK, mew=1.4, ms=7),
           Line2D([], [], color=MUTED, lw=2, alpha=0.6)],
          ["lower–upper bound, firm-years", "pro rata", f"same, firm flows summed over {Y0}–{Y1}"],
          loc="upper center", bbox_to_anchor=(0.5, -0.16), ncol=3, handlelength=1.8, columnspacing=1.2)
context(a2)
for k, lab, c, lw, dy in [("PAYMA", "Payout + cash M&A", DARK, 2.2, -6), ("INV", "Capex", AQUA, 2.2, 6),
                          ("PAY", "Net payout", ORANGE, 1.6, None), ("FIN", "Cash and financial assets", YELLOW, 1.6, None)]:
    s = 100 * dub[f"pr_{k}"] / dub.ndp
    a2.plot(s.index, s, color=c, lw=lw, label=lab)
    if dy is not None:  # end labels only on the two lines the slide compares
        endval(a2, Y1, s.loc[Y1], f"{s.loc[Y1]:.0f}%", dy=dy)
a2.set_xlim(*XL)
a2.set_ylim(0, None)
a2.yaxis.set_major_formatter(pct0)
a2.set_ylabel("% of positive net borrowing, pro rata")
a2.set_title("(b) Pro-rata shares by fiscal year", loc="left", fontsize=10.5)
below(a2, 2)
save(fig, "f7_debt_use_bounds")

# ================================================================== 5. values
def fmt(v):
    if isinstance(v, str):
        return v
    if isinstance(v, (int, np.integer)):
        return f"{v:,}"
    a = abs(v)
    return f"{v:,.0f}" if a >= 100 else f"{v:.1f}" if a >= 10 else f"{v:.2f}"


(ROOT / "data" / "values.json").write_text(json.dumps({k: (v if isinstance(v, str) else float(v)) for k, v in VALS.items()}, indent=1))
with open(ROOT / "data" / "values.tex", "w") as fh:
    for k, v in VALS.items():
        fh.write(f"\\expandafter\\def\\csname v:{k}\\endcsname{{{fmt(v)}}}\n")
print(f"{len(VALS)} values; figures in {FIG}")
for k in ["QY2009", "QY2025", "EQY2009", "EQY2025", "DEBTY2009", "DEBTY2025", "KY2009", "KY2025", "q2009", "q2025",
          "dec2009_sh_E", "dec2009_sh_FDI", "dec2009_sh_DEBT", "dec2009_sh_OTHER", "dec2009_sh_q", "dec2011_sh_q",
          "avg_post_NB", "avg_post_BUY", "avg_post_DIV", "avg_post_NCF", "avg_post_FCF", "cum_NB", "cum_BUY", "cum_DIV", "cum_NCF",
          "cum_dDEBT", "cum_dQ", "cum_dEQ", "cum_dK", "cs_py2009", "cs_py2011", "cs_py2025", "cs_npy2011", "cs_npy2025", "cs_cumbuy", "cs_cumdiv",
          "ai7_me_share2009", "ai7_me_share2025", "ai7_share_dme", "b5_capx_2023q4", "b5_capx_" + last.replace("Q", "q"),
          "b5_debt_2023q4", "b5_debt_" + last.replace("Q", "q"), "b5_ddebt_share_nb", "b5_debt_share_nfc", "lat_QY", "lat_DEBTY", "lat_KY", "lat_NBY"]:
    print(f"  {k:24s} {fmt(VALS[k])}")
