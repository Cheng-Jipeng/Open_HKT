#!/usr/bin/env python3
"""Build an exact domestic/foreign decomposition of U.S. equity capitalization.

The matched accounting object is U.S.-issued corporate equity in the Federal
Reserve Financial Accounts.  Foreign holdings are the rest-of-world asset in
U.S. corporate equities; domestic holdings are the exact residual.
"""

from __future__ import annotations

import io
import json
import subprocess
import tempfile
import time
from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parent
RAW_DIR = ROOT / "raw"
QUERY_DATE = "2026-09-04"
START_DATE = pd.Timestamp("1990-01-01")
FRED_GRAPH = (
    "https://fred.stlouisfed.org/graph/fredgraph.csv?cosd=1990-01-01&id={series_id}"
)
FRED_PAGE = "https://fred.stlouisfed.org/series/{series_id}"
FED_TABLE = "https://www.federalreserve.gov/releases/z1/20250911/html/l224.htm"

SERIES = {
    "BOGZ1LM883164105Q": {
        "column": "us_equity_capitalization_usd_millions",
        "title": "All Domestic Sectors; Corporate Equities; Liability, Market Value Levels",
        "role": "Total market value of U.S.-issued corporate equity outstanding",
    },
    "BOGZ1LM263064105Q": {
        "column": "foreign_holdings_usd_millions",
        "title": "Rest of the World; U.S. Corporate Equities; Asset, Market Value Levels",
        "role": "Foreign-resident holdings of U.S.-issued corporate equity",
    },
}


def fetch_bytes(url: str, retries: int = 3) -> bytes:
    last_error: Exception | None = None
    for attempt in range(retries):
        try:
            with tempfile.TemporaryDirectory(prefix="fred_equity_") as tmpdir:
                target = Path(tmpdir) / "download.csv"
                result = subprocess.run(
                    [
                        "curl",
                        "--location",
                        "--http2",
                        "--fail",
                        "--silent",
                        "--show-error",
                        "--retry",
                        "5",
                        "--retry-all-errors",
                        "--retry-delay",
                        "1",
                        "--max-time",
                        "90",
                        "--output",
                        str(target),
                        url,
                    ],
                    check=False,
                    capture_output=True,
                    timeout=95,
                )
                content = target.read_bytes() if target.exists() else b""
                if result.returncode == 0 and content.startswith(b"observation_date,"):
                    return content
                error_text = result.stderr.decode("utf-8", errors="replace").strip()
                raise RuntimeError(f"curl exit {result.returncode}: {error_text}")
        except Exception as exc:  # pragma: no cover - network-dependent
            last_error = exc
            if attempt + 1 < retries:
                time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"Failed to download {url}: {last_error}")


def ahp_period(date: pd.Timestamp) -> str:
    if date < pd.Timestamp("2002-01-01"):
        return "1990Q1-2001Q4"
    if date < pd.Timestamp("2008-01-01"):
        return "2002Q1-2007Q4"
    if date < pd.Timestamp("2023-10-01"):
        return "2008Q1-2023Q3"
    return "Post-AHP 2023Q4-present"


def download_series(series_id: str, column: str) -> pd.DataFrame:
    url = FRED_GRAPH.format(series_id=series_id)
    content = fetch_bytes(url)
    (RAW_DIR / f"fred_{series_id}.csv").write_bytes(content)
    frame = pd.read_csv(io.BytesIO(content), na_values=["."])
    frame = frame.rename(columns={"observation_date": "date", series_id: column})
    frame["date"] = pd.to_datetime(frame["date"])
    frame[column] = pd.to_numeric(frame[column], errors="coerce")
    return frame.loc[frame["date"] >= START_DATE, ["date", column]].dropna()


def main() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    frames = [download_series(series_id, spec["column"]) for series_id, spec in SERIES.items()]
    data = frames[0].merge(frames[1], on="date", how="inner", validate="one_to_one")
    data = data.sort_values("date").reset_index(drop=True)

    total = data["us_equity_capitalization_usd_millions"]
    foreign = data["foreign_holdings_usd_millions"]
    data["domestic_holdings_usd_millions"] = total - foreign
    data["us_equity_capitalization_usd_trillions"] = total / 1_000_000
    data["domestic_holdings_usd_trillions"] = data["domestic_holdings_usd_millions"] / 1_000_000
    data["foreign_holdings_usd_trillions"] = foreign / 1_000_000
    data["domestic_share_percent"] = 100 * data["domestic_holdings_usd_millions"] / total
    data["foreign_share_percent"] = 100 * foreign / total
    data["accounting_residual_usd_millions"] = (
        total - data["domestic_holdings_usd_millions"] - foreign
    )
    data.insert(1, "quarter", data["date"].dt.to_period("Q").astype(str))
    data.insert(2, "ahp_period", data["date"].map(ahp_period))
    data["total_source_series"] = "BOGZ1LM883164105Q"
    data["foreign_source_series"] = "BOGZ1LM263064105Q"
    data["source_vintage_date"] = QUERY_DATE

    if data.empty:
        raise ValueError("No overlapping observations were downloaded")
    if data["date"].iloc[0] != START_DATE:
        raise ValueError(f"Expected series to begin at {START_DATE.date()} in the analysis window")
    if (data["domestic_holdings_usd_millions"] < 0).any():
        raise ValueError("Foreign holdings exceed total capitalization in at least one quarter")
    max_residual = data["accounting_residual_usd_millions"].abs().max()
    max_share_error = (data["domestic_share_percent"] + data["foreign_share_percent"] - 100).abs().max()
    if max_residual > 1e-9 or max_share_error > 1e-9:
        raise ValueError("The domestic/foreign decomposition fails the accounting identity")

    output = ROOT / "us_equity_capitalization_domestic_foreign_quarterly.csv"
    data.to_csv(output, index=False, float_format="%.6f")

    metadata = pd.DataFrame(
        [
            {
                "dataset": "U.S. corporate-equity capitalization by holder residence",
                "series_id": series_id,
                "title": spec["title"],
                "economic_role": spec["role"],
                "frequency": "Quarterly, end of period",
                "units": "Millions of U.S. dollars",
                "seasonal_adjustment": "Not seasonally adjusted",
                "valuation": "Market value",
                "source": "Federal Reserve Financial Accounts, via FRED and OpenEcon",
                "financial_accounts_table": "L.224 Corporate Equities (formerly L.223)",
                "fred_page": FRED_PAGE.format(series_id=series_id),
                "fred_csv": FRED_GRAPH.format(series_id=series_id),
                "federal_reserve_table": FED_TABLE,
                "downloaded_on": QUERY_DATE,
            }
            for series_id, spec in SERIES.items()
        ]
    )
    metadata.to_csv(ROOT / "us_equity_capitalization_source_metadata.csv", index=False)

    query_log = {
        "query_date": QUERY_DATE,
        "attribution": "Data by OpenEcon — https://data.openecon.ai",
        "request": (
            "Retrieve exact quarterly FRED series BOGZ1LM883164105Q and "
            "BOGZ1LM263064105Q, 1990Q1-latest, without substitution."
        ),
        "conversation_id": "us-equity-capitalization-20260904",
        "status": "OpenEcon returned both exact series with data through 2026Q1.",
        "returned_series_ids": list(SERIES),
        "note": (
            "OpenEcon also returned one duplicate copy of the foreign series because of semantic "
            "country parsing. The package keys observations by exact series ID and verifies them "
            "against the official FRED downloads; no duplicate enters the decomposition."
        ),
    }
    (ROOT / "openecon_equity_capitalization_query_log.json").write_text(
        json.dumps(query_log, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )

    latest = data.iloc[-1]
    summary = {
        "latest_quarter": latest["quarter"],
        "us_equity_capitalization_usd_trillions": round(
            float(latest["us_equity_capitalization_usd_trillions"]), 6
        ),
        "domestic_holdings_usd_trillions": round(
            float(latest["domestic_holdings_usd_trillions"]), 6
        ),
        "foreign_holdings_usd_trillions": round(
            float(latest["foreign_holdings_usd_trillions"]), 6
        ),
        "domestic_share_percent": round(float(latest["domestic_share_percent"]), 4),
        "foreign_share_percent": round(float(latest["foreign_share_percent"]), 4),
        "maximum_accounting_residual_usd_millions": float(max_residual),
        "maximum_share_sum_error_percentage_points": float(max_share_error),
    }
    (ROOT / "us_equity_capitalization_summary.json").write_text(
        json.dumps(summary, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
