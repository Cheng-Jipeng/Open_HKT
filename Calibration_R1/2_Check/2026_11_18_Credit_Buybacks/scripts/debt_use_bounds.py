"""Where did borrowing go? Firm-level sources-and-uses bounds, Compustat US nonfinancial firms (2026-11-18).

Money is fungible inside a firm, so a dollar of net borrowing cannot be traced to one use. Each firm-year identity
    oancf + ND = capx + aqc + PAY + FIN
    ND  = dltis - dltr + dlcch            net debt issuance
    PAY = dvt + prstkc - sstk             net payout to shareholders (negative = net equity issuer)
    FIN = residual                        cash build-up, purchases of financial assets, other investing/financing lines
only bounds how much of a firm's positive net borrowing went to each use k:
    lower bound  debt that is left over after internal funds have gone to k first:  max(0, u_k - I)
    upper bound  internal funds go to k last, so debt covers k as far as it can:     min(u_k, X)
    pro rata     debt split in proportion to the uses:                               ND+ * u_k / sum(u)
I = internal funds (positive oancf, cash drawdown and asset sales), X = external funds (ND+ and net equity issuance);
debt is the share ND+/X of every external dollar. Summing over firms removes the cross-firm netting in the Z.1
aggregate (borrowers and payers may be different firms). The width of the bounds is the within-firm fungibility.

Variants: base (net payout, capx), gross payout (sstk an external source), R&D as investment (xrd added to oancf
and to investment), sector view (cash M&A counted with payout, as Z.1 counts it in equity retirement), and
firm-cumulative 2009-2025 flows (removes timing between borrowing and spending across years).

Run from this folder:
  uv run --no-project --python 3.12 --with numpy==2.3.5 --with pandas==2.2.3 python -I debt_use_bounds.py
Reads ../data/raw/wrds/{funda_us_1989_2026,company_us}.csv.gz (licensed Compustat extract: research use only).
Writes ../data/processed/debt_use_bounds_{annual,summary}.csv (aggregates only, USD bn). Run it before build.py,
which reads both files for the deck (slide 9, figure f7).
"""
from pathlib import Path

import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
WRDS, PROC = ROOT / "data" / "raw" / "wrds", ROOT / "data" / "processed"
Y0, Y1, YB = 2009, 2025, 2011

f = pd.read_csv(WRDS / "funda_us_1989_2026.csv.gz", dtype={"gvkey": str})
co = pd.read_csv(WRDS / "company_us.csv.gz", dtype={"gvkey": str})
f = f.sort_values(["gvkey", "fyear", "at"]).drop_duplicates(["gvkey", "fyear"], keep="last").merge(co[["gvkey", "sic"]], on="gvkey", how="left")
sic = f.sich.fillna(f.sic)
nf = f[~((sic >= 6000) & (sic < 7000)) & f.fyear.between(1990, Y1) & f.oancf.notna() & (f["at"] > 0)].copy()  # same sector cut as build.py
for k in ["dvt", "prstkc", "sstk", "dltis", "dltr", "dlcch", "capx", "aqc", "xrd"]:
    nf[k] = nf[k].fillna(0)

USES = ["PAY", "INV", "MA", "FIN", "OPD"]
LAB = {"PAY": "shareholder payout", "INV": "investment", "MA": "cash M&A", "FIN": "cash and financial assets",
       "OPD": "operating deficit", "PAYMA": "payout + cash M&A"}


def allocate(d, gross=False, rnd=False):
    """Per-row debt allocation bounds. d holds summed flows (firm-year or firm-period)."""
    cf = d.oancf + (d.xrd if rnd else 0)
    inv = d.capx + (d.xrd if rnd else 0)
    ma = d.aqc.clip(lower=0)
    nd = d.dltis - d.dltr + d.dlcch
    pay = d.dvt + d.prstkc - (0 if gross else d.sstk)
    eq_ext = (d.sstk if gross else 0) + (-pay).clip(lower=0)  # equity issuance (and negative payout records) as external sources
    fin = cf + nd + (d.sstk if gross else 0) - inv - ma - pay  # residual, signed
    u = pd.DataFrame({"PAY": pay.clip(lower=0), "INV": inv.clip(lower=0), "MA": ma, "FIN": fin.clip(lower=0),
                      "OPD": (-cf).clip(lower=0), "NDM": (-nd).clip(lower=0)})
    I = cf.clip(lower=0) + (-fin).clip(lower=0) + (-inv).clip(lower=0)  # internal: operating cash, drawdowns, asset sales
    ndp = nd.clip(lower=0)
    X = ndp + eq_ext
    s = np.where(X > 0, ndp / X.where(X > 0, 1), 0.0)
    tot = u.sum(axis=1)
    out = pd.DataFrame({"ndp": ndp, "ndm": u.NDM, "pay": u.PAY, "inv": u.INV, "ma": u.MA})
    uu = u.assign(PAYMA=u.PAY + u.MA)
    for k in USES + ["PAYMA"]:
        out[f"lo_{k}"] = s * np.maximum(0, uu[k] - I)
        out[f"hi_{k}"] = s * np.minimum(uu[k], X)
        out[f"pr_{k}"] = np.where(tot > 0, ndp * uu[k] / tot.where(tot > 0, 1), 0.0)
    gap = (I + X - tot).abs().max()  # sources = uses, row by row
    assert gap < 1e-6, gap
    return out


FL = ["oancf", "dvt", "prstkc", "sstk", "dltis", "dltr", "dlcch", "capx", "aqc", "xrd"]
VARIANTS = {"base": {}, "gross_payout": {"gross": True}, "rnd_as_investment": {"rnd": True}}

annual = []
for name, kw in VARIANTS.items():
    a = allocate(nf, **kw).assign(fyear=nf.fyear.values).groupby("fyear").sum() / 1e3  # USD bn
    annual.append(a.assign(variant=name))
annual = pd.concat(annual).reset_index()
annual.round(3).to_csv(PROC / "debt_use_bounds_annual.csv", index=False)


def summarize(tab, label):
    s = tab.sum(numeric_only=True)
    row = {"window": label, "ndp_tn": s.ndp / 1e3, "ndm_tn": s.ndm / 1e3, "nd_net_tn": (s.ndp - s.ndm) / 1e3,
           "pay_tn": s.pay / 1e3, "inv_tn": s.inv / 1e3, "ma_tn": s.ma / 1e3}
    for k in USES + ["PAYMA"]:
        for b in ["lo", "hi", "pr"]:
            row[f"{b}_{k}_pct_ndp"] = 100 * s[f"{b}_{k}"] / s.ndp
    for b in ["lo", "hi", "pr"]:
        row[f"{b}_PAY_pct_pay"] = 100 * s[f"{b}_PAY"] / s.pay
        row[f"{b}_INV_pct_inv"] = 100 * s[f"{b}_INV"] / s.inv
    return row


rows = []
for name in VARIANTS:
    for a, b in [(Y0, Y1), (YB, Y1)]:
        t = annual[(annual.variant == name) & annual.fyear.between(a, b)]
        w = nf[nf.fyear.between(a, b)]
        rows.append({"variant": name, **summarize(t, f"{a}-{b} firm-years"), "n_firmyears": len(w), "n_firms": w.gvkey.nunique()})
# firm-cumulative: sum each firm's flows over the window first, then bound (no timing mismatch across years)
for name, kw in VARIANTS.items():
    for a, b in [(Y0, Y1), (YB, Y1)]:
        cum = nf[nf.fyear.between(a, b)].groupby("gvkey")[FL].sum()
        rows.append({"variant": name, **summarize(allocate(cum, **kw) / 1e3, f"{a}-{b} firm-cumulative"), "n_firmyears": len(cum), "n_firms": len(cum)})
summ = pd.DataFrame(rows)
summ.round(2).to_csv(PROC / "debt_use_bounds_summary.csv", index=False)

pd.set_option("display.width", 250)
pd.set_option("display.max_columns", 60)
n = nf[nf.fyear.between(Y0, Y1)]
print(f"sample {Y0}-{Y1}: {len(n)} firm-years, {n.gvkey.nunique()} firms")
show = ["variant", "window", "ndp_tn", "ndm_tn", "nd_net_tn", "pay_tn", "inv_tn", "ma_tn"]
print(summ[show].round(2).to_string(index=False))
for k in USES + ["PAYMA"]:
    print(f"\n% of positive net borrowing -> {LAB[k]}  [lower, pro rata, upper]")
    print(summ[["variant", "window", f"lo_{k}_pct_ndp", f"pr_{k}_pct_ndp", f"hi_{k}_pct_ndp"]].round(1).to_string(index=False))
print("\n% of payout financed by debt, and % of capex financed by debt  [lower, pro rata, upper]")
print(summ[["variant", "window", "lo_PAY_pct_pay", "pr_PAY_pct_pay", "hi_PAY_pct_pay", "lo_INV_pct_inv", "pr_INV_pct_inv", "hi_INV_pct_inv"]].round(1).to_string(index=False))
b = annual[annual.variant == "base"].set_index("fyear").loc[Y0:Y1]
yr = pd.DataFrame({"ndp": b.ndp, "ndm": b.ndm, **{f"{x}_PAY%": 100 * b[f"{x}_PAY"] / b.ndp for x in ["lo", "pr", "hi"]},
                   **{f"{x}_INV%": 100 * b[f"{x}_INV"] / b.ndp for x in ["lo", "pr", "hi"]},
                   **{f"{x}_MA%": 100 * b[f"{x}_MA"] / b.ndp for x in ["lo", "pr", "hi"]}})
print("\nbase, by fiscal year (USD bn; % of positive net borrowing)")
print(yr.round(1).to_string())
