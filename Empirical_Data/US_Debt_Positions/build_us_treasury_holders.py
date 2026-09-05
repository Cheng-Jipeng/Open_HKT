#!/usr/bin/env python3
"""Build a reproducible dataset and figures on holders of U.S. Treasury debt.

Sources
-------
1. Federal Reserve Financial Accounts, Table L.210, via FRED CSV endpoints.
2. U.S. Treasury International Capital (TIC), Major Foreign Holders table.
3. OpenEcon is used as the discovery/query layer; its successful series
   resolution and metadata are recorded in ``openecon_query_log.json``.

The sector and country rankings are deliberately kept separate because the
underlying datasets differ in coverage, frequency, and valuation conventions.
"""

from __future__ import annotations

import csv
import io
import json
import re
import time
import urllib.request
from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parent
RAW_DIR = ROOT / "raw"
PLOT_DATA_DIR = ROOT / "plot_data"

QUERY_DATE = "2026-09-04"
FRED_GRAPH = "https://fred.stlouisfed.org/graph/fredgraph.csv?id={series_id}"
FED_L210 = "https://www.federalreserve.gov/apps/FOF/Guide/L210.pdf"
TIC_HISTORY = (
    "https://ticdata.treasury.gov/resource-center/data-chart-center/tic/"
    "Documents/mfhhis01.csv"
)
TIC_RECENT = (
    "https://ticdata.treasury.gov/resource-center/data-chart-center/tic/"
    "Documents/slt_table5.txt"
)
TIC_PAGE = "https://ticdata.treasury.gov/Publish/slt_table5.html"


# Non-overlapping holder rows in Federal Reserve Financial Accounts Table L.210.
# ``Total assets`` is the denominator and is not included as a holder in ranks.
SECTOR_SERIES = [
    ("Total assets", "Total", "FL893061105", "BOGZ1FL893061105Q"),
    ("Households and nonprofits", "Domestic nonfinancial", "LM153061105", "BOGZ1LM153061105Q"),
    ("Nonfinancial corporations", "Domestic nonfinancial", "LM103061103", "BOGZ1LM103061103Q"),
    ("Noncorporate businesses", "Domestic nonfinancial", "LM113061003", "BOGZ1LM113061003Q"),
    ("State and local governments", "Domestic government", "LM213061103", "BOGZ1LM213061103Q"),
    ("Federal Reserve", "Domestic financial", "LM713061103", "BOGZ1LM713061103Q"),
    ("U.S.-chartered banks", "Domestic financial", "LM763061100", "BOGZ1LM763061100Q"),
    ("Foreign bank offices in U.S.", "Domestic financial", "LM753061103", "BOGZ1LM753061103Q"),
    ("Banks in U.S.-affiliated areas", "Domestic financial", "LM743061103", "BOGZ1LM743061103Q"),
    ("Credit unions", "Domestic financial", "LM473061105", "BOGZ1LM473061105Q"),
    ("Property-casualty insurers", "Domestic financial", "LM513061105", "BOGZ1LM513061105Q"),
    ("Life insurers", "Domestic financial", "LM543061105", "BOGZ1LM543061105Q"),
    ("Private pension funds", "Domestic financial", "LM573061105", "BOGZ1LM573061105Q"),
    ("Federal government pension funds", "Domestic government", "LM343061105", "BOGZ1LM343061105Q"),
    ("State and local pension funds", "Domestic government", "LM223061143", "BOGZ1LM223061143Q"),
    ("Money market funds", "Domestic financial", "FL633061105", "BOGZ1FL633061105Q"),
    ("Mutual funds", "Domestic financial", "LM653061105", "BOGZ1LM653061105Q"),
    ("Closed-end funds", "Domestic financial", "LM553061103", "BOGZ1LM553061103Q"),
    ("Exchange-traded funds", "Domestic financial", "LM563061103", "BOGZ1LM563061103Q"),
    ("Government-sponsored enterprises", "Domestic financial", "LM403061105", "BOGZ1LM403061105Q"),
    ("ABS issuers", "Domestic financial", "FL673061103", "BOGZ1FL673061103Q"),
    ("Brokers and dealers", "Domestic financial", "LM663061105", "BOGZ1LM663061105Q"),
    ("Holding companies", "Domestic financial", "LM733061103", "BOGZ1LM733061103Q"),
    ("Other financial business", "Domestic financial", "FL503061123", "BOGZ1FL503061123Q"),
    ("Rest of world", "Foreign", "LM263061105", "ROWTSEQ027S"),
]


def fetch_text(url: str, retries: int = 3) -> str:
    """Download UTF-8 text with a descriptive user agent and short retries."""
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "Academic research replication; contact via source repository"},
    )
    error: Exception | None = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return response.read().decode("utf-8-sig", errors="replace")
        except Exception as exc:  # pragma: no cover - network-dependent
            error = exc
            if attempt + 1 < retries:
                time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"Failed to download {url}: {error}")


def clean_numeric(value: object) -> float | None:
    text = str(value).strip().replace(",", "")
    if not text or text.lower() in {"nan", "n.a.", "na", "*", "--"}:
        return None
    text = re.sub(r"[a-zA-Z]+/$", "", text).strip()
    try:
        return float(text)
    except ValueError:
        return None


def fetch_sector_data() -> tuple[pd.DataFrame, pd.DataFrame]:
    frames: list[pd.DataFrame] = []
    metadata: list[dict[str, object]] = []
    for holder, category, fof_code, fred_id in SECTOR_SERIES:
        url = FRED_GRAPH.format(series_id=fred_id)
        text = fetch_text(url)
        raw_path = RAW_DIR / f"fred_{fred_id}.csv"
        raw_path.write_text(text, encoding="utf-8")
        frame = pd.read_csv(io.StringIO(text))
        if frame.shape[1] != 2 or frame.columns[0] != "observation_date":
            raise ValueError(f"Unexpected FRED response for {fred_id}")
        value_col = frame.columns[1]
        frame = frame.rename(columns={value_col: "value_usd_millions"})
        frame["date"] = pd.to_datetime(frame["observation_date"], errors="coerce")
        frame["value_usd_millions"] = pd.to_numeric(
            frame["value_usd_millions"], errors="coerce"
        )
        frame = frame.loc[frame["date"].ge("1990-01-01")].copy()
        frame["quarter"] = frame["date"].dt.to_period("Q").astype(str)
        frame["holder"] = holder
        frame["holder_category"] = category
        frame["fof_code"] = fof_code
        frame["fred_series_id"] = fred_id
        frame["value_usd_billions"] = frame["value_usd_millions"] / 1000
        frames.append(
            frame[
                [
                    "date",
                    "quarter",
                    "holder",
                    "holder_category",
                    "fof_code",
                    "fred_series_id",
                    "value_usd_millions",
                    "value_usd_billions",
                ]
            ]
        )
        metadata.append(
            {
                "holder": holder,
                "holder_category": category,
                "fof_code": fof_code,
                "fred_series_id": fred_id,
                "frequency": "Quarterly, end of period",
                "units": "Millions of U.S. dollars",
                "seasonal_adjustment": "Not seasonally adjusted",
                "fred_source_url": f"https://fred.stlouisfed.org/series/{fred_id}",
                "federal_reserve_table_url": FED_L210,
                "query_date": QUERY_DATE,
            }
        )

    data = pd.concat(frames, ignore_index=True)
    totals = (
        data.loc[data["holder"].eq("Total assets"), ["date", "value_usd_billions"]]
        .rename(columns={"value_usd_billions": "total_assets_usd_billions"})
        .drop_duplicates("date")
    )
    data = data.merge(totals, on="date", how="left", validate="many_to_one")
    data["share_of_total_assets"] = (
        data["value_usd_billions"] / data["total_assets_usd_billions"]
    )
    data = data.sort_values(["date", "holder"]).reset_index(drop=True)
    return data, pd.DataFrame(metadata)


def normalize_tic_entity(label: str) -> str:
    label = re.sub(r"\s+", " ", label).strip()
    label = re.sub(r"\s*\d+/\s*$", "", label).strip()
    aliases = {
        "For. Official": "Foreign official",
        "Of Which: Foreign Official": "Foreign official",
        "Of which: Foreign Official": "Foreign official",
        "Treasury Bills": "Foreign official Treasury bills",
        "T-Bonds & Notes": "Foreign official Treasury bonds and notes",
        "Of Which: Foreign Official Treasury Bills": "Foreign official Treasury bills",
        "Of Which: Foreign Official T-Bonds & Notes": "Foreign official Treasury bonds and notes",
    }
    return aliases.get(label, label)


def tic_entity_type(entity: str) -> str:
    if entity in {
        "Grand Total",
        "All Other",
        "Foreign official",
        "Foreign official Treasury bills",
        "Foreign official Treasury bonds and notes",
    }:
        return "Aggregate"
    if entity.startswith("Total ") or entity.startswith("Memo:"):
        return "Aggregate"
    return "Country or economy"


def parse_tic_history(text: str) -> pd.DataFrame:
    rows = list(csv.reader(io.StringIO(text)))
    records: list[dict[str, object]] = []
    for i, row in enumerate(rows):
        if not row or row[0].strip() != "Country":
            continue
        months = rows[i - 1][1:13]
        years = row[1:13]
        if not months or not years or not all(str(y).strip().isdigit() for y in years if y):
            continue
        j = i + 1
        while j < len(rows):
            current = rows[j]
            if current and current[0].strip() == "Country":
                break
            label = normalize_tic_entity(current[0] if current else "")
            values = current[1:13] if len(current) > 1 else []
            numeric_values = [clean_numeric(v) for v in values]
            if label and any(v is not None for v in numeric_values):
                for month, year, value in zip(months, years, numeric_values):
                    if value is None or not str(year).strip().isdigit():
                        continue
                    try:
                        date = pd.Timestamp(f"{str(year).strip()}-{str(month).strip()}-01")
                    except ValueError:
                        continue
                    records.append(
                        {
                            "date": date,
                            "country_or_group": label,
                            "entity_type": tic_entity_type(label),
                            "value_usd_billions": value,
                            "source_file": "mfhhis01.csv",
                        }
                    )
            j += 1
    result = pd.DataFrame(records)
    if result.empty:
        raise ValueError("No observations parsed from TIC historical file")
    return result


def parse_tic_recent(text: str) -> pd.DataFrame:
    rows = list(csv.reader(io.StringIO(text), delimiter="\t"))
    header_index = next(i for i, row in enumerate(rows) if row and row[0].strip() == "Country")
    dates = [pd.Timestamp(d.strip() + "-01") for d in rows[header_index][1:] if d.strip()]
    records: list[dict[str, object]] = []
    for row in rows[header_index + 1 :]:
        if not row or not row[0].strip() or row[0].strip() == "Notes:":
            if row and row[0].strip() == "Notes:":
                break
            continue
        entity = normalize_tic_entity(row[0])
        values = [clean_numeric(v) for v in row[1 : 1 + len(dates)]]
        if not any(v is not None for v in values):
            continue
        for date, value in zip(dates, values):
            if value is None:
                continue
            records.append(
                {
                    "date": date,
                    "country_or_group": entity,
                    "entity_type": tic_entity_type(entity),
                    "value_usd_billions": value,
                    "source_file": "slt_table5.txt",
                }
            )
    result = pd.DataFrame(records)
    if result.empty:
        raise ValueError("No observations parsed from TIC recent file")
    return result


def fetch_country_data() -> pd.DataFrame:
    history_text = fetch_text(TIC_HISTORY)
    recent_text = fetch_text(TIC_RECENT)
    (RAW_DIR / "tic_mfhhis01.csv").write_text(history_text, encoding="utf-8")
    (RAW_DIR / "tic_slt_table5.txt").write_text(recent_text, encoding="utf-8")

    history = parse_tic_history(history_text)
    recent = parse_tic_recent(recent_text)
    combined = pd.concat([history, recent], ignore_index=True)
    # The current table includes the latest revisions for overlapping months.
    combined = combined.drop_duplicates(
        ["date", "country_or_group"], keep="last"
    ).sort_values(["date", "country_or_group"])
    combined["source_url"] = TIC_PAGE
    combined["query_date"] = QUERY_DATE
    combined["frequency"] = "Monthly, end of period"
    combined["units"] = "Billions of U.S. dollars"

    totals = (
        combined.loc[combined["country_or_group"].eq("Grand Total"), ["date", "value_usd_billions"]]
        .rename(columns={"value_usd_billions": "foreign_total_usd_billions"})
        .drop_duplicates("date")
    )
    combined = combined.merge(totals, on="date", how="left", validate="many_to_one")
    combined["share_of_foreign_total"] = (
        combined["value_usd_billions"] / combined["foreign_total_usd_billions"]
    )
    return combined.reset_index(drop=True)


def configure_matplotlib() -> None:
    plt.rcParams.update(
        {
            "figure.dpi": 140,
            "savefig.dpi": 240,
            "font.family": "sans-serif",
            "font.sans-serif": ["Helvetica Neue", "Helvetica", "Arial", "DejaVu Sans"],
            "axes.spines.top": False,
            "axes.spines.right": False,
            "axes.edgecolor": "#667085",
            "axes.labelcolor": "#344054",
            "axes.titleweight": "semibold",
            "axes.titlesize": 13,
            "axes.labelsize": 10,
            "xtick.color": "#475467",
            "ytick.color": "#475467",
            "grid.color": "#D0D5DD",
            "grid.linewidth": 0.6,
            "grid.alpha": 0.65,
            "legend.frameon": False,
        }
    )


def save_figure(fig: plt.Figure, stem: str) -> None:
    fig.savefig(FIGURE_DIR / f"{stem}.png", bbox_inches="tight", facecolor="white")
    fig.savefig(FIGURE_DIR / f"{stem}.pdf", bbox_inches="tight", facecolor="white")
    plt.close(fig)


def make_sector_figures(sector_data: pd.DataFrame, sector_rank: pd.DataFrame) -> None:
    latest_date = pd.Timestamp(sector_rank["date"].iloc[0])
    top = sector_rank.head(12).sort_values("value_usd_billions")
    colors = ["#B42318" if x == "Rest of world" else "#175CD3" for x in top["holder"]]
    fig, ax = plt.subplots(figsize=(9.2, 6.4))
    bars = ax.barh(top["holder"], top["value_usd_billions"] / 1000, color=colors)
    ax.set_title(f"Largest holders of marketable U.S. Treasury securities, {latest_date.to_period('Q')}", loc="left")
    ax.set_xlabel("Trillions of U.S. dollars")
    ax.grid(axis="x")
    ax.set_axisbelow(True)
    for bar, value, share in zip(bars, top["value_usd_billions"] / 1000, top["share_of_total_assets"]):
        ax.text(
            value + 0.08,
            bar.get_y() + bar.get_height() / 2,
            f"${value:.2f}T  ({share:.1%})",
            va="center",
            fontsize=8.7,
            color="#344054",
        )
    ax.set_xlim(0, max(top["value_usd_billions"] / 1000) * 1.25)
    fig.text(
        0.01,
        -0.02,
        "Source: Federal Reserve Financial Accounts, Table L.210. Rest of world highlighted.",
        fontsize=8.5,
        color="#667085",
    )
    fig.tight_layout()
    save_figure(fig, "01_latest_sector_holders")

    selected = [
        "Rest of world",
        "Federal Reserve",
        "Money market funds",
        "Households and nonprofits",
        "U.S.-chartered banks",
        "Mutual funds",
        "State and local governments",
    ]
    colors_map = {
        "Rest of world": "#B42318",
        "Federal Reserve": "#175CD3",
        "Money market funds": "#F79009",
        "Households and nonprofits": "#039855",
        "U.S.-chartered banks": "#7F56D9",
        "Mutual funds": "#06AED4",
        "State and local governments": "#667085",
    }
    fig, ax = plt.subplots(figsize=(10.2, 6.2))
    for holder in selected:
        frame = sector_data.loc[sector_data["holder"].eq(holder)].dropna(subset=["value_usd_billions"])
        ax.plot(
            frame["date"],
            frame["value_usd_billions"] / 1000,
            label=holder,
            color=colors_map[holder],
            linewidth=2.1 if holder == "Rest of world" else 1.65,
        )
    ax.set_title("U.S. Treasury holdings by major sector", loc="left")
    ax.set_ylabel("Trillions of U.S. dollars")
    ax.grid(axis="y")
    ax.set_axisbelow(True)
    ax.xaxis.set_major_locator(mdates.YearLocator(5))
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y"))
    ax.legend(ncol=2, loc="upper left", fontsize=8.6)
    fig.text(
        0.01,
        -0.02,
        "Quarterly end-of-period positions; latest available 2026Q1. Source: Federal Reserve Financial Accounts, Table L.210.",
        fontsize=8.5,
        color="#667085",
    )
    fig.tight_layout()
    save_figure(fig, "02_sector_holdings_history")

    total = sector_data.loc[sector_data["holder"].eq("Total assets"), ["date", "value_usd_billions"]].rename(
        columns={"value_usd_billions": "total"}
    )
    foreign = sector_data.loc[sector_data["holder"].eq("Rest of world"), ["date", "value_usd_billions"]].rename(
        columns={"value_usd_billions": "foreign"}
    )
    shares = total.merge(foreign, on="date", how="inner").dropna()
    shares["foreign_share"] = shares["foreign"] / shares["total"]
    shares["domestic_share"] = 1 - shares["foreign_share"]
    fig, ax = plt.subplots(figsize=(9.8, 5.2))
    ax.plot(shares["date"], shares["foreign_share"], color="#B42318", linewidth=2.2, label="Rest of world")
    ax.plot(shares["date"], shares["domestic_share"], color="#175CD3", linewidth=2.0, label="All domestic sectors")
    ax.set_title("Domestic and foreign shares of reported Treasury holdings", loc="left")
    ax.set_ylabel("Share of total sector assets")
    ax.set_ylim(0, 1)
    ax.yaxis.set_major_formatter(lambda x, _: f"{x:.0%}")
    ax.xaxis.set_major_locator(mdates.YearLocator(5))
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y"))
    ax.grid(axis="y")
    ax.legend(loc="best")
    fig.text(
        0.01,
        -0.02,
        "Domestic share equals one minus the rest-of-world share. Source: Federal Reserve Financial Accounts, Table L.210.",
        fontsize=8.5,
        color="#667085",
    )
    fig.tight_layout()
    save_figure(fig, "03_domestic_foreign_shares")


def make_country_figures(country_data: pd.DataFrame, country_rank: pd.DataFrame) -> None:
    latest_date = pd.Timestamp(country_rank["date"].iloc[0])
    top = country_rank.head(15).sort_values("value_usd_billions")
    fig, ax = plt.subplots(figsize=(9.2, 6.6))
    bars = ax.barh(top["country_or_group"], top["value_usd_billions"], color="#175CD3")
    ax.set_title(f"Largest foreign holders of U.S. Treasury securities, {latest_date:%B %Y}", loc="left")
    ax.set_xlabel("Billions of U.S. dollars")
    ax.grid(axis="x")
    ax.set_axisbelow(True)
    for bar, value, share in zip(bars, top["value_usd_billions"], top["share_of_foreign_total"]):
        ax.text(
            value + 13,
            bar.get_y() + bar.get_height() / 2,
            f"${value:,.1f}B  ({share:.1%})",
            va="center",
            fontsize=8.5,
            color="#344054",
        )
    ax.set_xlim(0, max(top["value_usd_billions"]) * 1.28)
    fig.text(
        0.01,
        -0.035,
        "Source: U.S. Treasury TIC, Major Foreign Holders. Country attribution reflects custody location and may not equal beneficial ownership.",
        fontsize=8.4,
        color="#667085",
    )
    fig.tight_layout()
    save_figure(fig, "04_latest_foreign_country_holders")

    top_names = country_rank.head(6)["country_or_group"].tolist()
    palette = ["#175CD3", "#B42318", "#039855", "#F79009", "#7F56D9", "#06AED4"]
    fig, ax = plt.subplots(figsize=(10.2, 6.0))
    for name, color in zip(top_names, palette):
        frame = country_data.loc[
            country_data["country_or_group"].eq(name)
            & country_data["date"].ge("2000-01-01")
        ].dropna(subset=["value_usd_billions"])
        ax.plot(frame["date"], frame["value_usd_billions"], label=name, color=color, linewidth=1.9)
    ax.set_title("Treasury holdings of the largest foreign economies", loc="left")
    ax.set_ylabel("Billions of U.S. dollars")
    ax.grid(axis="y")
    ax.set_axisbelow(True)
    ax.xaxis.set_major_locator(mdates.YearLocator(5))
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y"))
    ax.legend(ncol=2, loc="upper left", fontsize=8.8)
    fig.text(
        0.01,
        -0.035,
        "Monthly end-of-period positions. Breaks and changing custody attribution limit country-level interpretation. Source: U.S. Treasury TIC.",
        fontsize=8.4,
        color="#667085",
    )
    fig.tight_layout()
    save_figure(fig, "05_foreign_country_history")

    pivot = country_data.pivot_table(
        index="date", columns="country_or_group", values="value_usd_billions", aggfunc="last"
    )
    if {"Grand Total", "Foreign official"}.issubset(pivot.columns):
        official = pivot[["Grand Total", "Foreign official"]].dropna().copy()
        official["Private and other foreign"] = official["Grand Total"] - official["Foreign official"]
        official["Official share"] = official["Foreign official"] / official["Grand Total"]
        fig, ax = plt.subplots(figsize=(9.8, 5.4))
        ax.plot(official.index, official["Foreign official"] / 1000, color="#175CD3", linewidth=2.0, label="Foreign official")
        ax.plot(official.index, official["Private and other foreign"] / 1000, color="#B54708", linewidth=2.0, label="Private and other foreign")
        ax.set_title("Foreign official and other foreign Treasury holdings", loc="left")
        ax.set_ylabel("Trillions of U.S. dollars")
        ax.grid(axis="y")
        ax.legend(loc="upper left")
        ax.xaxis.set_major_locator(mdates.YearLocator(5))
        ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y"))
        fig.text(
            0.01,
            -0.03,
            "Private and other foreign is the TIC grand total less the foreign-official memorandum item.",
            fontsize=8.5,
            color="#667085",
        )
        fig.tight_layout()
        save_figure(fig, "06_foreign_official_private_history")


def write_query_log() -> None:
    log = {
        "query_date": QUERY_DATE,
        "attribution": "Data by OpenEcon — https://data.openecon.ai",
        "broad_query_attempts": [
            {
                "subject": "Federal Reserve Financial Accounts Table L.210 by holder sector",
                "status": "timed out after 120 seconds",
            },
            {
                "subject": "Treasury TIC Major Foreign Holders by country",
                "status": "timed out after 120 seconds",
            },
        ],
        "successful_query": {
            "request": "FRED series BOGZ1LM263061105Q, Rest of the world holdings of U.S. Treasury securities, quarterly, 1990 through latest",
            "resolved_provider": "FRED",
            "resolved_series_id": "ROWTSEQ027S",
            "indicator": "Rest of the World; Treasury Securities; Asset, Level",
            "frequency": "Quarterly, end of period",
            "unit": "Millions of U.S. Dollars",
            "seasonal_adjustment": "Not Seasonally Adjusted",
            "source_url": "https://fred.stlouisfed.org/series/ROWTSEQ027S",
            "openecon_reported_start": "1945-10-01",
            "openecon_reported_end": "2026-01-01",
            "openecon_last_updated": "2026-06-11 21:17:05-05",
            "observations_requested_from": "1990-01-01",
            "observations_in_saved_sector_panel": 145,
        },
        "bulk_retrieval_note": (
            "After OpenEcon resolved the key rest-of-world series, the complete "
            "sector panel and country tables were downloaded from the original "
            "Federal Reserve/FRED and U.S. Treasury TIC endpoints for reproducibility."
        ),
    }
    (ROOT / "openecon_query_log.json").write_text(
        json.dumps(log, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def main() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    PLOT_DATA_DIR.mkdir(parents=True, exist_ok=True)

    sector_data, sector_metadata = fetch_sector_data()
    country_data = fetch_country_data()

    latest_sector_date = sector_data.loc[
        sector_data["holder"].eq("Rest of world") & sector_data["value_usd_billions"].notna(),
        "date",
    ].max()
    sector_rank = sector_data.loc[
        sector_data["date"].eq(latest_sector_date)
        & ~sector_data["holder"].eq("Total assets")
        & sector_data["value_usd_billions"].notna()
    ].copy()
    sector_rank["rank"] = sector_rank["value_usd_billions"].rank(
        method="first", ascending=False
    ).astype(int)
    sector_rank = sector_rank.sort_values("rank")

    latest_country_date = country_data.loc[
        country_data["country_or_group"].eq("Grand Total"), "date"
    ].max()
    country_rank = country_data.loc[
        country_data["date"].eq(latest_country_date)
        & country_data["entity_type"].eq("Country or economy")
        & country_data["value_usd_billions"].notna()
    ].copy()
    country_rank["rank"] = country_rank["value_usd_billions"].rank(
        method="first", ascending=False
    ).astype(int)
    country_rank = country_rank.sort_values("rank")

    sector_data.to_csv(ROOT / "us_treasury_sector_positions_quarterly.csv", index=False)
    sector_metadata.to_csv(ROOT / "us_treasury_sector_series_metadata.csv", index=False)
    sector_rank.to_csv(ROOT / "latest_us_treasury_sector_ranking.csv", index=False)
    country_data.to_csv(ROOT / "foreign_treasury_holdings_monthly.csv", index=False)
    country_rank.to_csv(ROOT / "latest_foreign_country_ranking.csv", index=False)

    sector_data.to_csv(PLOT_DATA_DIR / "sector_history.tsv", sep="\t", index=False)
    sector_rank.to_csv(PLOT_DATA_DIR / "sector_ranking.tsv", sep="\t", index=False)
    country_data.to_csv(PLOT_DATA_DIR / "country_history.tsv", sep="\t", index=False)
    country_rank.to_csv(PLOT_DATA_DIR / "country_ranking.tsv", sep="\t", index=False)
    write_query_log()

    latest_sector = sector_rank.iloc[0]
    latest_domestic = sector_rank.loc[~sector_rank["holder_category"].eq("Foreign")].iloc[0]
    latest_country = country_rank.iloc[0]
    latest_total_foreign = country_data.loc[
        country_data["date"].eq(latest_country_date)
        & country_data["country_or_group"].eq("Grand Total")
    ].iloc[0]
    latest_official = country_data.loc[
        country_data["date"].eq(latest_country_date)
        & country_data["country_or_group"].eq("Foreign official")
    ].iloc[0]

    summary = {
        "query_date": QUERY_DATE,
        "latest_sector_date": latest_sector_date.strftime("%Y-%m-%d"),
        "largest_sector_holder": latest_sector["holder"],
        "largest_sector_value_usd_billions": round(float(latest_sector["value_usd_billions"]), 3),
        "largest_sector_share_of_reported_assets": round(float(latest_sector["share_of_total_assets"]), 6),
        "largest_domestic_sector_holder": latest_domestic["holder"],
        "largest_domestic_sector_value_usd_billions": round(float(latest_domestic["value_usd_billions"]), 3),
        "latest_country_date": latest_country_date.strftime("%Y-%m-%d"),
        "largest_foreign_country_holder": latest_country["country_or_group"],
        "largest_foreign_country_value_usd_billions": round(float(latest_country["value_usd_billions"]), 3),
        "largest_foreign_country_share_of_foreign_total": round(float(latest_country["share_of_foreign_total"]), 6),
        "foreign_total_usd_billions": round(float(latest_total_foreign["value_usd_billions"]), 3),
        "foreign_official_usd_billions": round(float(latest_official["value_usd_billions"]), 3),
        "foreign_official_share": round(
            float(latest_official["value_usd_billions"] / latest_total_foreign["value_usd_billions"]), 6
        ),
    }
    (ROOT / "summary_statistics.json").write_text(
        json.dumps(summary, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
