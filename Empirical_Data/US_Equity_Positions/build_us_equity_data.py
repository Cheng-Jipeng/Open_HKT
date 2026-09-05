#!/usr/bin/env python3
"""Build reproducible U.S. cross-border equity-position datasets.

The package deliberately separates three statistical objects:

1. Quarterly Integrated Macroeconomic Accounts (IMA) gross equity positions.
2. TIC SHC/SHL portfolio-equity positions by foreign economy.
3. CPIS/TIC private U.S. holder sectors for foreign portfolio equity.

Country survey totals do not reconcile to the broader IMA positions because the
coverage and statistical frameworks differ.  All values are market-value stocks.
"""

from __future__ import annotations

import csv
import io
import json
import re
import time
import urllib.request
import zipfile
from calendar import monthrange
from pathlib import Path

import numpy as np
import pandas as pd
from lxml import html


ROOT = Path(__file__).resolve().parent
RAW_DIR = ROOT / "raw"
QUERY_DATE = "2026-09-04"

FRED_GRAPH = "https://fred.stlouisfed.org/graph/fredgraph.csv?id={series_id}"
FRED_PAGE = "https://fred.stlouisfed.org/series/{series_id}"
FRED_SERIES = {
    "ROWEISQ027S": {
        "column": "us_equity_assets_abroad_usd_millions",
        "title": (
            "Rest of the World; Equity and Investment Fund Shares Excluding "
            "Mutual Fund Shares and Money Market Fund Shares; Liability (IMA), Level"
        ),
        "interpretation": "U.S. gross foreign equity assets (ROW liability)",
    },
    "ROWEINQ027S": {
        "column": "us_equity_liabilities_to_foreigners_usd_millions",
        "title": "Rest of the World; Equity and Investment Fund Shares; Asset (IMA), Level",
        "interpretation": "U.S. gross foreign equity liabilities (ROW asset)",
    },
    "A451RC1Q027SBEA": {
        "column": "corporate_gva_usd_billions_saar",
        "title": "Gross Value Added of Corporate Business",
        "interpretation": "Corporate GVA normalization denominator",
    },
}

SHC_HISTORY_URL = (
    "https://ticdata.treasury.gov/resource-center/data-chart-center/tic/"
    "Documents/shchistdat.csv"
)
SHL_HISTORY_URL = (
    "https://ticdata.treasury.gov/resource-center/data-chart-center/tic/"
    "Documents/shlhistdat.txt"
)
SHC_PRELIM_2025_URL = (
    "https://ticdata.treasury.gov/resource-center/data-chart-center/tic/"
    "Documents/shcprelim.html"
)
CPIS_2025M06_URL = (
    "https://ticdata.treasury.gov/resource-center/data-chart-center/tic/"
    "Documents/cpis_treas_202506_slt.zip"
)
SHC_PAGE = (
    "https://home.treasury.gov/data/treasury-international-capital-tic-system/"
    "tic-forms-instructions/us-claims-on-foreigners-from-holdings-of-foreign-securities"
)
SHL_PAGE = (
    "https://home.treasury.gov/data/treasury-international-capital-tic-system/"
    "us-liabilities-to-foreigners-from-holdings-of-us-securities"
)
CPIS_PAGE = (
    "https://home.treasury.gov/data/treasury-international-capital-tic-system-home-page/"
    "tic-forms-instructions/securities-c-annual-cross-us-border-portfolio-holdings"
)

EU27_2026 = {
    "Austria", "Belgium", "Bulgaria", "Croatia", "Cyprus", "Czech Republic",
    "Denmark", "Estonia", "Finland", "France", "Germany", "Greece", "Hungary",
    "Ireland", "Italy", "Latvia", "Lithuania", "Luxembourg", "Malta",
    "Netherlands", "Poland", "Portugal", "Romania", "Slovakia", "Slovenia",
    "Spain", "Sweden",
}
FINANCIAL_EU = {"Belgium", "Luxembourg", "Ireland", "Netherlands"}
CORE_EU = EU27_2026 - FINANCIAL_EU
FINANCIAL_CENTRES = {
    "Belgium", "Luxembourg", "Ireland", "Netherlands", "Switzerland",
    "Hong Kong", "Singapore", "Cayman Islands", "Bahamas", "Bermuda",
    "British Virgin Islands", "Jersey", "Guernsey", "Isle of Man",
    "Liechtenstein", "Panama", "Curacao", "Sint Maarten",
    "Bonaire, Sint Eustatius and Saba",
}
FINANCIAL_BRIDGES = {
    "Belgium-Luxembourg": {"Belgium", "Luxembourg"},
    "British West Indies": {
        "Anguilla", "British Virgin Islands", "Cayman Islands", "Montserrat",
        "Turks and Caicos Islands",
    },
    "Channel Islands": {"Guernsey", "Jersey"},
    "Netherlands Antilles": {"Curacao", "Sint Maarten", "Bonaire, Sint Eustatius and Saba"},
}
GULF_AND_REGIONAL_OIL = {
    "Bahrain", "Iran", "Iraq", "Kuwait", "Oman", "Qatar", "Saudi Arabia",
    "United Arab Emirates",
}
COMMODITY_BRIDGES = {"Middle Eastern Oil Exporters", "Middle East Oil-Exporters"}
OTHER_ADVANCED = {"Canada", "Australia", "New Zealand", "Norway", "Israel"}
OTHER_EAST_ASIA = {"Taiwan", "South Korea"}

FUNCTIONAL_GROUPS = [
    "All other foreign",
    "Canada & other advanced",
    "Commodity exporters",
    "Core EU-27 (identifiable)",
    "Financial/offshore centres",
    "Other East Asian exporters",
    "United Kingdom",
    "Mainland China",
    "Japan",
]
STABLE_PANEL_GROUPS = [
    "All other foreign",
    "South Korea",
    "Singapore",
    "Taiwan",
    "Hong Kong",
    "Canada",
    "United Kingdom",
    "Mainland China",
    "Japan",
]


def fetch_bytes(url: str, retries: int = 3) -> bytes:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "Academic research replication; Treasury/Federal Reserve data"},
    )
    error: Exception | None = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                return response.read()
        except Exception as exc:  # pragma: no cover - network-dependent
            error = exc
            if attempt + 1 < retries:
                time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"Failed to download {url}: {error}")


def ahp_period(date: pd.Timestamp) -> str:
    if date < pd.Timestamp("1990-01-01"):
        return "Pre-1990 (outside requested window)"
    if date < pd.Timestamp("2002-01-01"):
        return "1990Q1-2001Q4"
    if date < pd.Timestamp("2008-01-01"):
        return "2002Q1-2007Q4"
    if date < pd.Timestamp("2023-10-01"):
        return "2008Q1-2023Q3"
    return "Post-AHP 2023Q4-present"


def parse_numeric(text: object) -> tuple[float | None, str]:
    value = str(text).strip().replace(",", "")
    if value in {"", "n.a.", "n.a", "na", "N/A", "--"}:
        return None, "not_available"
    if value == "*":
        # TIC defines an asterisk as greater than zero but below $0.5 million.
        return 0.25, "suppressed_midpoint_lt_0_5m"
    value = re.sub(r"[a-zA-Z]+/$", "", value).strip()
    try:
        return float(value), "reported"
    except ValueError:
        return None, "not_available"


def normalize_country(label: str) -> str:
    value = re.sub(r"\s+", " ", label.replace("\xa0", " ")).strip()
    value = re.sub(r"\s+r$", "", value).strip()
    value = re.sub(r"\s*\(\d+(?:\s*,\s*\d+)*\)\s*$", "", value).strip()
    aliases = {
        "China": "Mainland China",
        "China, mainland": "Mainland China",
        "China, Mainland": "Mainland China",
        "China, P.R.: Mainland": "Mainland China",
        "China, P.R.: Hong Kong": "Hong Kong",
        "China, P.R.: Macao": "Macau",
        "Korea, South": "South Korea",
        "Taiwan Province of China": "Taiwan",
        "Bahamas, The": "Bahamas",
        "Curacao": "Curacao",
        "Curaçao": "Curacao",
        "Czechia": "Czech Republic",
        "Belgium and Luxembourg": "Belgium-Luxembourg",
        "Belgium-Luxembourg": "Belgium-Luxembourg",
        "MIDDLE EAST OIL-EXPORTERS": "Middle East Oil-Exporters",
        "Middle Eastern Oil Exporters": "Middle Eastern Oil Exporters",
        "INTERNATIONAL & REGIONAL ORGS.": "International & Regional Orgs.",
        "International Organizations": "International & Regional Orgs.",
        "Virgin Islands, British": "British Virgin Islands",
        "Bonaire Sint Eustatius and Saba": "Bonaire, Sint Eustatius and Saba",
        "West Bank and Gaza Strip": "West Bank and Gaza",
    }
    return aliases.get(value, value)


def entity_type(code: str, label: str) -> str:
    if code.strip() == "99996" or label == "Total":
        return "Total"
    aggregate_phrases = (
        "Total ", "Of which:", "All Other", "Country unknown",
        "International & Regional Orgs.", "African Oil Exporters",
        "Middle Eastern Oil Exporters", "Middle East Oil-Exporters",
    )
    if label.startswith(aggregate_phrases) or label in {
        "British West Indies", "Channel Islands", "Netherlands Antilles",
    }:
        return "Aggregate or historical bridge"
    return "Country or economy"


def parse_period_token(token: str) -> pd.Timestamp | None:
    token = token.strip()
    if re.fullmatch(r"\d{4}", token):
        return pd.Timestamp(year=int(token), month=12, day=31)
    match = re.fullmatch(r"([A-Za-z]{3})-(\d{2})", token)
    if match:
        month_lookup = {"Mar": 3, "Jun": 6, "Dec": 12}
        month = month_lookup.get(match.group(1).title())
        if month is None:
            return None
        short_year = int(match.group(2))
        year = 1900 + short_year if short_year >= 70 else 2000 + short_year
        return pd.Timestamp(year=year, month=month, day=monthrange(year, month)[1])
    return None


def parse_survey_history(
    content: bytes,
    *,
    delimiter: str,
    side: str,
    source_file: str,
    source_url: str,
) -> pd.DataFrame:
    text = content.decode("utf-8-sig", errors="replace")
    rows = list(csv.reader(io.StringIO(text), delimiter=delimiter))
    header_index = next(
        i for i, row in enumerate(rows)
        if row and row[0].strip() == "Country code"
    )
    header = rows[header_index]
    equity_columns: list[tuple[int, pd.Timestamp]] = []
    for column in range(2, len(header)):
        if header[column].strip().lower() != "equity":
            continue
        period = None
        for preceding in range(header_index - 1, -1, -1):
            if column < len(rows[preceding]):
                period = parse_period_token(rows[preceding][column])
                if period is not None:
                    break
        if period is None:
            raise ValueError(f"No survey period found for {source_file}, column {column}")
        equity_columns.append((column, period))

    records: list[dict[str, object]] = []
    for row in rows[header_index + 1 :]:
        if len(row) < 2:
            continue
        code = row[0].strip()
        raw_label = row[1].strip()
        if not code or not raw_label:
            continue
        label = normalize_country(raw_label)
        kind = entity_type(code, label)
        for column, survey_date in equity_columns:
            raw_value = row[column] if column < len(row) else ""
            value, status = parse_numeric(raw_value)
            records.append(
                {
                    "survey_date": survey_date,
                    "survey_year": survey_date.year,
                    "AHP_period": ahp_period(survey_date),
                    "position_side": side,
                    "country_code": code,
                    "country_or_group": label,
                    "entity_type": kind,
                    "equity_value_usd_millions": value,
                    "equity_value_usd_billions": None if value is None else value / 1000,
                    "observation_status": status,
                    "survey_status": "Final historical survey",
                    "source_file": source_file,
                    "source_url": source_url,
                    "query_date": QUERY_DATE,
                }
            )
        if code == "99996":
            break
    result = pd.DataFrame(records)
    if result.empty:
        raise ValueError(f"No observations parsed from {source_file}")
    return result


def parse_shc_preliminary_2025(content: bytes) -> pd.DataFrame:
    document = html.fromstring(content.decode("cp1252", errors="replace"))
    records: list[dict[str, object]] = []
    seen: set[tuple[str, str]] = set()
    for table_row in document.xpath("//tr"):
        cells = [
            " ".join(cell.text_content().replace("\xa0", " ").split())
            for cell in table_row.xpath("./th|./td")
        ]
        if len(cells) < 6 or not cells[0].strip().isdigit():
            continue
        code, raw_label = cells[0].strip(), cells[1].strip()
        key = (code, raw_label)
        if key in seen:
            continue
        seen.add(key)
        label = normalize_country(raw_label)
        value, status = parse_numeric(cells[3])
        date = pd.Timestamp("2025-12-31")
        records.append(
            {
                "survey_date": date,
                "survey_year": date.year,
                "AHP_period": ahp_period(date),
                "position_side": "U.S. portfolio equity assets abroad",
                "country_code": code,
                "country_or_group": label,
                "entity_type": entity_type(code, label),
                "equity_value_usd_millions": value,
                "equity_value_usd_billions": None if value is None else value / 1000,
                "observation_status": status,
                "survey_status": "Preliminary; released 2026-08-31",
                "source_file": "shcprelim_2025.html",
                "source_url": SHC_PRELIM_2025_URL,
                "query_date": QUERY_DATE,
            }
        )
    result = pd.DataFrame(records)
    if result.empty or not result["entity_type"].eq("Total").any():
        raise ValueError("No usable observations parsed from preliminary 2025 SHC page")
    return result


def attach_survey_totals(data: pd.DataFrame) -> pd.DataFrame:
    totals = (
        data.loc[data["entity_type"].eq("Total"), ["survey_date", "equity_value_usd_millions"]]
        .dropna()
        .drop_duplicates("survey_date", keep="last")
        .rename(columns={"equity_value_usd_millions": "survey_total_equity_usd_millions"})
    )
    result = data.merge(totals, on="survey_date", how="left", validate="many_to_one")
    result["share_of_survey_equity_total"] = (
        result["equity_value_usd_millions"] / result["survey_total_equity_usd_millions"]
    )
    return result.sort_values(["survey_date", "entity_type", "country_or_group"]).reset_index(drop=True)


def fetch_ima_positions() -> tuple[pd.DataFrame, pd.DataFrame]:
    frames: list[pd.DataFrame] = []
    metadata: list[dict[str, object]] = []
    for series_id, definition in FRED_SERIES.items():
        content = fetch_bytes(FRED_GRAPH.format(series_id=series_id))
        (RAW_DIR / f"fred_{series_id}.csv").write_bytes(content)
        frame = pd.read_csv(io.BytesIO(content))
        if frame.shape[1] != 2 or frame.columns[0] != "observation_date":
            raise ValueError(f"Unexpected FRED response for {series_id}")
        frame = frame.rename(columns={frame.columns[1]: definition["column"]})
        frame["date"] = pd.to_datetime(frame["observation_date"], errors="coerce")
        frame[definition["column"]] = pd.to_numeric(frame[definition["column"]], errors="coerce")
        frames.append(frame[["date", definition["column"]]])
        metadata.append(
            {
                "dataset": "Quarterly IMA gross equity positions" if series_id != "A451RC1Q027SBEA" else "Corporate GVA",
                "series_id": series_id,
                "title": definition["title"],
                "interpretation": definition["interpretation"],
                "frequency": "Quarterly, end of period" if series_id != "A451RC1Q027SBEA" else "Quarterly, SAAR",
                "units": "Millions of U.S. dollars" if series_id != "A451RC1Q027SBEA" else "Billions of U.S. dollars, SAAR",
                "source_url": FRED_PAGE.format(series_id=series_id),
                "download_url": FRED_GRAPH.format(series_id=series_id),
                "query_date": QUERY_DATE,
            }
        )

    combined = frames[0]
    for frame in frames[1:]:
        combined = combined.merge(frame, on="date", how="outer", validate="one_to_one")
    asset_col = "us_equity_assets_abroad_usd_millions"
    liability_col = "us_equity_liabilities_to_foreigners_usd_millions"
    combined = (
        combined.loc[combined["date"].ge("1990-01-01")]
        .dropna(subset=[asset_col, liability_col])
        .sort_values("date")
    )
    combined["net_foreign_equity_position_usd_millions"] = combined[asset_col] - combined[liability_col]
    combined["gross_cross_border_equity_usd_millions"] = combined[asset_col] + combined[liability_col]
    combined["asset_share_of_gross"] = combined[asset_col] / combined["gross_cross_border_equity_usd_millions"]
    combined["liability_share_of_gross"] = combined[liability_col] / combined["gross_cross_border_equity_usd_millions"]
    for column in [asset_col, liability_col, "net_foreign_equity_position_usd_millions", "gross_cross_border_equity_usd_millions"]:
        combined[column.replace("_usd_millions", "_usd_billions")] = combined[column] / 1000
    gva_millions = 1000 * combined["corporate_gva_usd_billions_saar"]
    combined["equity_assets_over_corporate_gva"] = combined[asset_col] / gva_millions
    combined["equity_liabilities_over_corporate_gva"] = combined[liability_col] / gva_millions
    combined["net_equity_position_over_corporate_gva"] = combined["net_foreign_equity_position_usd_millions"] / gva_millions
    combined["quarter"] = combined["date"].dt.to_period("Q").astype(str)
    combined["AHP_period"] = combined["date"].map(ahp_period)
    ordered = [
        "date", "quarter", "AHP_period", asset_col,
        "us_equity_assets_abroad_usd_billions", liability_col,
        "us_equity_liabilities_to_foreigners_usd_billions",
        "net_foreign_equity_position_usd_millions",
        "net_foreign_equity_position_usd_billions",
        "gross_cross_border_equity_usd_millions",
        "gross_cross_border_equity_usd_billions",
        "asset_share_of_gross", "liability_share_of_gross",
        "corporate_gva_usd_billions_saar", "equity_assets_over_corporate_gva",
        "equity_liabilities_over_corporate_gva", "net_equity_position_over_corporate_gva",
    ]
    return combined[ordered].reset_index(drop=True), pd.DataFrame(metadata)


def parse_cpis_holder_sectors(content: bytes) -> pd.DataFrame:
    with zipfile.ZipFile(io.BytesIO(content)) as archive:
        member = next(name for name in archive.namelist() if name.endswith("/3_1_slt.txt"))
        raw = archive.read(member)
    (RAW_DIR / "cpis_2025m06_3_1_slt.txt").write_bytes(raw)
    data = pd.read_csv(io.BytesIO(raw), sep="\t")
    numeric_columns = [
        "Position", "Central Bank(CB)", "Dep inst", "other fin",
        "Insurance and Pension", "mmf", "other", "Government", "Nonfinancial",
    ]
    for column in numeric_columns:
        data[column] = pd.to_numeric(data[column], errors="coerce")
    data = data.loc[data["imf_code"].notna() & ~data["imf_code"].isin(["_X", "ZZ"])].copy()
    totals = data[numeric_columns].sum()
    groups = {
        "Other financial corporations": totals["other"],
        "Insurance and pension funds": totals["Insurance and Pension"],
        "Nonfinancial sector": totals["Nonfinancial"],
        "Depository institutions": totals["Dep inst"],
        "Money market funds": totals["mmf"],
        "Central bank and government": totals["Central Bank(CB)"] + totals["Government"],
    }
    group_sum = sum(groups.values())
    rounding_residual = float(totals["Position"] - group_sum)
    if abs(rounding_residual) > 25:
        raise ValueError(f"CPIS holder sectors fail to add: {group_sum} versus {totals['Position']}")
    groups["Survey rounding residual"] = rounding_residual
    rows = []
    for group, value in groups.items():
        rows.append(
            {
                "rank": 0,
                "holder_sector": group,
                "value_usd_millions": value,
                "value_usd_billions": value / 1000,
                "share_of_private_portfolio_equity_assets": value / totals["Position"],
                "as_of": pd.Timestamp("2025-06-30"),
                "coverage": "Private U.S. cross-border portfolio equity claims",
                "source_file": "cpis_treas_202506_slt.zip: 3_1_slt.txt",
                "source_url": CPIS_PAGE,
            }
        )
    result = pd.DataFrame(rows).sort_values("value_usd_millions", ascending=False).reset_index(drop=True)
    result["rank"] = np.arange(1, len(result) + 1)
    return result


def value_map(frame: pd.DataFrame) -> dict[str, float]:
    usable = frame.dropna(subset=["equity_value_usd_millions"])
    return usable.groupby("country_or_group")["equity_value_usd_millions"].last().to_dict()


def sum_named(values: dict[str, float], names: set[str]) -> float:
    return float(sum(values.get(name, 0.0) for name in names))


def bridge_or_members(
    values: dict[str, float],
    bridge: str,
    members: set[str],
) -> float:
    """Use one non-overlapping representation of a historically bridged region.

    TIC history files retain obsolete aggregate rows after constituent economies
    begin reporting separately.  Some obsolete rows contain an asterisk, which
    parses to the $0.25 million suppression midpoint.  Whenever at least one
    constituent has a usable observation, the constituents are therefore the
    active representation and the obsolete bridge is ignored.
    """
    if any(member in values for member in members):
        return sum_named(values, members)
    return float(values.get(bridge, 0.0))


def build_group_decomposition(data: pd.DataFrame, classification: str) -> pd.DataFrame:
    output: list[dict[str, object]] = []
    side = str(data["position_side"].iloc[0])
    for date, frame in data.groupby("survey_date", sort=True):
        if date < pd.Timestamp("1990-01-01"):
            continue
        values = value_map(frame)
        if "Total" not in values or not np.isfinite(values["Total"]):
            continue
        total = float(values["Total"])
        if classification == "Economic-function and location-role grouping":
            bridged_members = set().union(*FINANCIAL_BRIDGES.values())
            financial = sum_named(values, FINANCIAL_CENTRES - bridged_members)
            for bridge, members in FINANCIAL_BRIDGES.items():
                financial += bridge_or_members(values, bridge, members)
            commodity = sum_named(values, GULF_AND_REGIONAL_OIL)
            for bridge in COMMODITY_BRIDGES:
                if bridge in values:
                    commodity = float(values[bridge])
                    break
            grouped = {
                "Japan": values.get("Japan", 0.0),
                "Mainland China": values.get("Mainland China", 0.0),
                "United Kingdom": values.get("United Kingdom", 0.0),
                "Other East Asian exporters": sum_named(values, OTHER_EAST_ASIA),
                "Financial/offshore centres": financial,
                "Core EU-27 (identifiable)": sum_named(values, CORE_EU),
                "Commodity exporters": commodity,
                "Canada & other advanced": sum_named(values, OTHER_ADVANCED),
            }
            group_order = FUNCTIONAL_GROUPS
        elif classification == "Stable panel of separately reported economies":
            source_names = {
                "Japan": "Japan",
                "Mainland China": "Mainland China",
                "United Kingdom": "United Kingdom",
                "Canada": "Canada",
                "Hong Kong": "Hong Kong",
                "Taiwan": "Taiwan",
                "Singapore": "Singapore",
                "South Korea": "South Korea",
            }
            if not all(name in values for name in source_names.values()):
                continue
            grouped = {group: values[source] for group, source in source_names.items()}
            group_order = STABLE_PANEL_GROUPS
        else:  # pragma: no cover - internal contract
            raise ValueError(classification)

        residual = total - sum(grouped.values())
        if residual < -5:
            raise ValueError(f"Negative residual for {side} at {date:%Y-%m-%d}: {residual}")
        grouped["All other foreign"] = max(residual, 0.0)
        status = str(frame["survey_status"].iloc[-1])
        for group in group_order:
            value = float(grouped[group])
            output.append(
                {
                    "survey_date": date,
                    "survey_year": date.year,
                    "AHP_period": ahp_period(date),
                    "position_side": side,
                    "foreign_group": group,
                    "value_usd_millions": value,
                    "value_usd_billions": value / 1000,
                    "share_of_side_total": value / total,
                    "side_total_usd_millions": total,
                    "side_total_usd_billions": total / 1000,
                    "classification": classification,
                    "survey_status": status,
                }
            )
    result = pd.DataFrame(output)
    if result.empty:
        raise ValueError(f"No observations for {classification}: {side}")
    return result


def build_crosswalks() -> tuple[pd.DataFrame, pd.DataFrame]:
    functional_rows: list[dict[str, str]] = []

    def add(group: str, member: str, treatment: str) -> None:
        functional_rows.append(
            {
                "foreign_group": group,
                "member_or_rule": member,
                "treatment": treatment,
                "applies_to": "Both portfolio assets and portfolio liabilities",
            }
        )

    for member in sorted({"Japan"}):
        add("Japan", member, "Separately reported economy")
    add("Mainland China", "Mainland China", "Hong Kong and Macau excluded")
    add("United Kingdom", "United Kingdom", "Crown dependencies excluded when separately reported")
    for member in sorted(OTHER_EAST_ASIA):
        add("Other East Asian exporters", member, "Separately reported economy")
    for member in sorted(FINANCIAL_CENTRES):
        add("Financial/offshore centres", member, "Separately reported financial or offshore location")
    for bridge, members in FINANCIAL_BRIDGES.items():
        add(
            "Financial/offshore centres",
            bridge,
            (
                "Historical bridge used only when separately reported members are unavailable; "
                f"otherwise sum: {', '.join(sorted(members))}"
            ),
        )
    for member in sorted(CORE_EU):
        add("Core EU-27 (identifiable)", member, "2026 EU-27 member outside designated financial-centre subset")
    for member in sorted(GULF_AND_REGIONAL_OIL):
        add("Commodity exporters", member, "Separately reported Middle Eastern oil exporter")
    for bridge in sorted(COMMODITY_BRIDGES):
        add("Commodity exporters", bridge, "Historical aggregate bridge used when separately reported members are unavailable")
    for member in sorted(OTHER_ADVANCED):
        add("Canada & other advanced", member, "Separately reported advanced economy")
    add("All other foreign", "Residual", "Official survey equity total less all named groups; preserves exact adding-up")

    stable_rows = [
        {
            "foreign_group": group,
            "member_or_rule": "Residual" if group == "All other foreign" else group,
            "treatment": (
                "Official survey equity total less the eight named economies"
                if group == "All other foreign"
                else "Separately reported economy required for every retained survey date"
            ),
            "applies_to": "Both portfolio assets and portfolio liabilities",
        }
        for group in STABLE_PANEL_GROUPS
    ]
    return pd.DataFrame(functional_rows), pd.DataFrame(stable_rows)


def latest_country_ranking(data: pd.DataFrame) -> pd.DataFrame:
    latest_date = data.loc[data["entity_type"].eq("Total"), "survey_date"].max()
    rank = data.loc[
        data["survey_date"].eq(latest_date)
        & data["entity_type"].eq("Country or economy")
        & data["equity_value_usd_millions"].notna()
    ].copy()
    rank = rank.drop_duplicates(["country_code", "country_or_group"], keep="last")
    rank = rank.sort_values("equity_value_usd_millions", ascending=False).reset_index(drop=True)
    rank.insert(0, "rank", np.arange(1, len(rank) + 1))
    return rank


def write_openecon_log() -> None:
    log = {
        "query_date": QUERY_DATE,
        "attribution": "Data by OpenEcon — https://data.openecon.ai",
        "query_attempts": [
            {
                "request": "FRED series ROWEISQ027S exact metadata and observations, 1990-latest",
                "conversation_id": "34c149e4-5e60-4cc9-b589-8b647207e5bb",
                "status": "No exact candidate returned; data field was null",
            },
            {
                "request": "FRED series ROWEINQ027S exact metadata and observations, 1990-latest",
                "conversation_id": "893dd37c-3eb1-462b-a1f5-3fc31f90a940",
                "status": "No exact candidate returned; data field was null",
            },
        ],
        "fallback": (
            "Exact official FRED series and Treasury TIC/CPIS files were downloaded directly. "
            "OpenEcon failures were not treated as observations."
        ),
    }
    (ROOT / "openecon_query_log.json").write_text(
        json.dumps(log, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def main() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)

    ima, metadata = fetch_ima_positions()

    shc_history_raw = fetch_bytes(SHC_HISTORY_URL)
    shl_history_raw = fetch_bytes(SHL_HISTORY_URL)
    shc_prelim_raw = fetch_bytes(SHC_PRELIM_2025_URL)
    cpis_raw = fetch_bytes(CPIS_2025M06_URL)
    (RAW_DIR / "tic_shchistdat.csv").write_bytes(shc_history_raw)
    (RAW_DIR / "tic_shlhistdat.txt").write_bytes(shl_history_raw)
    (RAW_DIR / "tic_shcprelim_2025.html").write_bytes(shc_prelim_raw)
    (RAW_DIR / "tic_cpis_treas_202506_slt.zip").write_bytes(cpis_raw)

    assets_final = parse_survey_history(
        shc_history_raw,
        delimiter=",",
        side="U.S. portfolio equity assets abroad",
        source_file="shchistdat.csv",
        source_url=SHC_PAGE,
    )
    assets_preliminary = parse_shc_preliminary_2025(shc_prelim_raw)
    assets = attach_survey_totals(pd.concat([assets_final, assets_preliminary], ignore_index=True))
    liabilities = attach_survey_totals(
        parse_survey_history(
            shl_history_raw,
            delimiter="\t",
            side="U.S. portfolio equity liabilities to foreigners",
            source_file="shlhistdat.txt",
            source_url=SHL_PAGE,
        )
    )
    holder_sectors = parse_cpis_holder_sectors(cpis_raw)

    asset_rank = latest_country_ranking(assets)
    liability_rank = latest_country_ranking(liabilities)

    functional = pd.concat(
        [
            build_group_decomposition(assets, "Economic-function and location-role grouping"),
            build_group_decomposition(liabilities, "Economic-function and location-role grouping"),
        ],
        ignore_index=True,
    )
    stable = pd.concat(
        [
            build_group_decomposition(assets, "Stable panel of separately reported economies"),
            build_group_decomposition(liabilities, "Stable panel of separately reported economies"),
        ],
        ignore_index=True,
    )
    functional_crosswalk, stable_crosswalk = build_crosswalks()

    metadata = pd.concat(
        [
            metadata,
            pd.DataFrame(
                [
                    {
                        "dataset": "U.S. portfolio equity assets by issuer economy",
                        "series_id": "TIC SHC/SHCA",
                        "title": "U.S. Holdings of Foreign Securities at Market Value",
                        "interpretation": "Portfolio equity assets; issuer residence",
                        "frequency": "Annual benchmark/survey dates; 2025 preliminary",
                        "units": "Millions of U.S. dollars",
                        "source_url": SHC_PAGE,
                        "download_url": SHC_HISTORY_URL,
                        "query_date": QUERY_DATE,
                    },
                    {
                        "dataset": "U.S. portfolio equity liabilities by holder economy",
                        "series_id": "TIC SHL/SHLA",
                        "title": "Foreign Holdings of U.S. Securities",
                        "interpretation": "Portfolio equity liabilities; foreign holder/custody residence",
                        "frequency": "Annual benchmark/survey dates",
                        "units": "Millions of U.S. dollars",
                        "source_url": SHL_PAGE,
                        "download_url": SHL_HISTORY_URL,
                        "query_date": QUERY_DATE,
                    },
                    {
                        "dataset": "Private U.S. holder sectors of foreign portfolio equity",
                        "series_id": "CPIS/TIC 2025M06 table 3_1",
                        "title": "Equity Securities by Sector of Resident Holder",
                        "interpretation": "Private U.S. cross-border portfolio equity claims",
                        "frequency": "Semiannual snapshot",
                        "units": "Millions of U.S. dollars",
                        "source_url": CPIS_PAGE,
                        "download_url": CPIS_2025M06_URL,
                        "query_date": QUERY_DATE,
                    },
                ]
            ),
        ],
        ignore_index=True,
    )

    ima.to_csv(ROOT / "us_cross_border_equity_positions_quarterly.csv", index=False)
    assets.to_csv(ROOT / "us_portfolio_equity_assets_by_country.csv", index=False)
    liabilities.to_csv(ROOT / "us_portfolio_equity_liabilities_by_country.csv", index=False)
    asset_rank.to_csv(ROOT / "latest_equity_asset_country_ranking.csv", index=False)
    liability_rank.to_csv(ROOT / "latest_equity_liability_country_ranking.csv", index=False)
    holder_sectors.to_csv(ROOT / "latest_us_holder_sector_equity_assets.csv", index=False)
    functional.to_csv(ROOT / "long_run_equity_functional_decomposition.csv", index=False)
    stable.to_csv(ROOT / "long_run_equity_stable_panel_decomposition.csv", index=False)
    functional_crosswalk.to_csv(ROOT / "equity_functional_crosswalk.csv", index=False)
    stable_crosswalk.to_csv(ROOT / "equity_stable_panel_crosswalk.csv", index=False)
    metadata.to_csv(ROOT / "us_equity_positions_source_metadata.csv", index=False)
    write_openecon_log()

    latest_ima = ima.dropna(
        subset=[
            "us_equity_assets_abroad_usd_billions",
            "us_equity_liabilities_to_foreigners_usd_billions",
        ]
    ).iloc[-1]
    asset_total_latest = assets.loc[
        assets["survey_date"].eq(assets["survey_date"].max()) & assets["entity_type"].eq("Total")
    ].iloc[0]
    liability_total_latest = liabilities.loc[
        liabilities["survey_date"].eq(liabilities["survey_date"].max()) & liabilities["entity_type"].eq("Total")
    ].iloc[0]
    summary = {
        "query_date": QUERY_DATE,
        "latest_ima_date": latest_ima["date"].strftime("%Y-%m-%d"),
        "ima_us_equity_assets_abroad_usd_billions": round(float(latest_ima["us_equity_assets_abroad_usd_billions"]), 3),
        "ima_us_equity_liabilities_to_foreigners_usd_billions": round(float(latest_ima["us_equity_liabilities_to_foreigners_usd_billions"]), 3),
        "ima_net_foreign_equity_position_usd_billions": round(float(latest_ima["net_foreign_equity_position_usd_billions"]), 3),
        "latest_asset_survey_date": asset_total_latest["survey_date"].strftime("%Y-%m-%d"),
        "latest_asset_survey_status": asset_total_latest["survey_status"],
        "portfolio_equity_assets_total_usd_billions": round(float(asset_total_latest["equity_value_usd_billions"]), 3),
        "largest_asset_issuer_location": asset_rank.iloc[0]["country_or_group"],
        "largest_asset_issuer_value_usd_billions": round(float(asset_rank.iloc[0]["equity_value_usd_billions"]), 3),
        "latest_liability_survey_date": liability_total_latest["survey_date"].strftime("%Y-%m-%d"),
        "portfolio_equity_liabilities_total_usd_billions": round(float(liability_total_latest["equity_value_usd_billions"]), 3),
        "largest_liability_holder_location": liability_rank.iloc[0]["country_or_group"],
        "largest_liability_holder_value_usd_billions": round(float(liability_rank.iloc[0]["equity_value_usd_billions"]), 3),
        "latest_private_us_holder_sector_date": holder_sectors.iloc[0]["as_of"].strftime("%Y-%m-%d"),
        "largest_private_us_holder_sector": holder_sectors.iloc[0]["holder_sector"],
        "largest_private_us_holder_sector_value_usd_billions": round(float(holder_sectors.iloc[0]["value_usd_billions"]), 3),
    }
    (ROOT / "summary_statistics.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(json.dumps(summary, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
