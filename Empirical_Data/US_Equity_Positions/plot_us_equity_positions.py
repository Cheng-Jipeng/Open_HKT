#!/usr/bin/env python3
"""Create the nine equity-position figures in PNG and PDF formats."""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.ticker import PercentFormatter


ROOT = Path(__file__).resolve().parent
FIGURE_DIR = ROOT / "figures"

ASSET_SIDE = "U.S. portfolio equity assets abroad"
LIABILITY_SIDE = "U.S. portfolio equity liabilities to foreigners"

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
FUNCTIONAL_COLORS = {
    "All other foreign": "#98A2B3",
    "Canada & other advanced": "#06AED4",
    "Commodity exporters": "#F79009",
    "Core EU-27 (identifiable)": "#039855",
    "Financial/offshore centres": "#C11574",
    "Other East Asian exporters": "#2E90A6",
    "United Kingdom": "#7F56D9",
    "Mainland China": "#B42318",
    "Japan": "#175CD3",
}
STABLE_GROUPS = [
    "All other foreign", "South Korea", "Singapore", "Taiwan", "Hong Kong",
    "Canada", "United Kingdom", "Mainland China", "Japan",
]
STABLE_COLORS = {
    "All other foreign": "#98A2B3",
    "South Korea": "#2A7F62",
    "Singapore": "#06AED4",
    "Taiwan": "#C11574",
    "Hong Kong": "#F79009",
    "Canada": "#344054",
    "United Kingdom": "#7F56D9",
    "Mainland China": "#B42318",
    "Japan": "#175CD3",
}


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
            "axes.titlesize": 12.5,
            "axes.labelsize": 10,
            "xtick.color": "#475467",
            "ytick.color": "#475467",
            "grid.color": "#D0D5DD",
            "grid.linewidth": 0.6,
            "grid.alpha": 0.65,
            "legend.frameon": False,
            "legend.fontsize": 8.5,
        }
    )


def save_figure(fig: plt.Figure, stem: str) -> None:
    FIGURE_DIR.mkdir(parents=True, exist_ok=True)
    fig.savefig(FIGURE_DIR / f"{stem}.png", bbox_inches="tight", facecolor="white")
    fig.savefig(FIGURE_DIR / f"{stem}.pdf", bbox_inches="tight", facecolor="white")
    plt.close(fig)


def format_year_axis(ax: plt.Axes, spacing: int = 5) -> None:
    ax.xaxis.set_major_locator(mdates.YearLocator(spacing))
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y"))


def add_ahp_periods(ax: plt.Axes, start: pd.Timestamp, end: pd.Timestamp, label: bool = True) -> None:
    period2 = pd.Timestamp("2002-01-01")
    period3 = pd.Timestamp("2008-01-01")
    post = pd.Timestamp("2023-10-01")
    if start < period3 and end > period2:
        ax.axvspan(max(start, period2), min(end, period3), color="#F5C66A", alpha=0.10, zorder=0)
    if end > period3:
        ax.axvspan(max(start, period3), end, color="#90AFC5", alpha=0.055, zorder=0)
    for date, style, color in [
        (period2, "--", "#98A2B3"),
        (period3, "--", "#98A2B3"),
        (post, ":", "#344054"),
    ]:
        if start < date < end:
            ax.axvline(date, linestyle=style, linewidth=0.9, color=color, zorder=2)
    if not label:
        return
    labels = [
        (start, min(period2, end), f"{start.year}-2001"),
        (max(start, period2), min(period3, end), "2002-2007"),
        (max(start, period3), min(post, end), "2008-2023Q3"),
        (max(start, post), end, "post-AHP"),
    ]
    y0, y1 = ax.get_ylim()
    y = y1 - 0.045 * (y1 - y0)
    for left, right, text in labels:
        if left >= right:
            continue
        midpoint = left + (right - left) / 2
        ax.text(midpoint, y, text, ha="center", va="top", fontsize=7.5, color="#475467")


def ranking_plot(
    data: pd.DataFrame,
    *,
    title: str,
    source_note: str,
    stem: str,
    color: str,
) -> None:
    top = data.head(15).sort_values("equity_value_usd_billions")
    values = top["equity_value_usd_billions"] / 1000
    fig, ax = plt.subplots(figsize=(9.4, 6.7))
    bars = ax.barh(top["country_or_group"], values, color=color)
    ax.set_title(title, loc="left")
    ax.set_xlabel("Trillions of U.S. dollars")
    ax.grid(axis="x")
    ax.set_axisbelow(True)
    ax.set_xlim(0, values.max() * 1.31)
    for bar, value, share in zip(bars, values, top["share_of_survey_equity_total"]):
        ax.text(
            value + values.max() * 0.018,
            bar.get_y() + bar.get_height() / 2,
            f"${value:.2f}T  ({share:.1%})",
            va="center",
            fontsize=8.2,
            color="#344054",
        )
    fig.text(0.01, 0.012, source_note, fontsize=8.1, color="#667085")
    fig.subplots_adjust(left=0.24, right=0.98, bottom=0.14, top=0.91)
    save_figure(fig, stem)


def prepare_group_panel(data: pd.DataFrame, side: str, groups: list[str]) -> tuple[pd.DatetimeIndex, np.ndarray, np.ndarray]:
    frame = data.loc[data["position_side"].eq(side)].copy()
    levels = frame.pivot(index="survey_date", columns="foreign_group", values="value_usd_billions").sort_index()
    shares = frame.pivot(index="survey_date", columns="foreign_group", values="share_of_side_total").sort_index()
    for group in groups:
        if group not in levels.columns:
            raise ValueError(f"Missing group {group} for {side}")
    return pd.DatetimeIndex(levels.index), levels[groups].to_numpy().T / 1000, shares[groups].to_numpy().T


def group_figure(data: pd.DataFrame, groups: list[str], colors: dict[str, str], title: str, stem: str, note: str) -> None:
    fig, axes = plt.subplots(2, 2, figsize=(15.5, 10.2), sharex="col")
    side_specs = [
        (ASSET_SIDE, "U.S. assets: issuer residence"),
        (LIABILITY_SIDE, "U.S. liabilities: holder/custody residence"),
    ]
    handles = None
    for column, (side, side_title) in enumerate(side_specs):
        dates, levels, shares = prepare_group_panel(data, side, groups)
        palette = [colors[group] for group in groups]
        for row, (matrix, ylabel) in enumerate(
            [(levels, "Trillions of U.S. dollars"), (shares, "Share of survey-side total")]
        ):
            ax = axes[row, column]
            add_ahp_periods(ax, dates.min(), dates.max(), label=False)
            stack = ax.stackplot(
                dates,
                matrix,
                labels=groups,
                colors=palette,
                alpha=0.90,
                edgecolor="white",
                linewidth=0.35,
                zorder=1,
            )
            handles = stack
            ax.set_ylabel(ylabel if column == 0 else "")
            ax.grid(axis="y")
            ax.set_axisbelow(True)
            format_year_axis(ax, 5)
            if row == 1:
                ax.set_ylim(0, 1)
                ax.yaxis.set_major_formatter(PercentFormatter(1.0, decimals=0))
            else:
                ax.set_ylim(bottom=0)
            add_ahp_periods(ax, dates.min(), dates.max(), label=True)
        axes[0, column].set_title(f"A{column + 1}. {side_title}", loc="left")
        axes[1, column].set_title(f"B{column + 1}. Composition shares", loc="left")

    fig.suptitle(title, fontsize=17, y=0.985)
    fig.legend(handles, groups, loc="center left", bbox_to_anchor=(0.875, 0.52), ncol=1, frameon=True)
    fig.text(0.01, 0.012, note, fontsize=8.0, color="#667085")
    fig.tight_layout(rect=(0, 0.035, 0.865, 0.96), h_pad=2.0, w_pad=1.6)
    save_figure(fig, stem)


def main() -> None:
    configure_matplotlib()
    aggregate = pd.read_csv(ROOT / "us_cross_border_equity_positions_quarterly.csv", parse_dates=["date"])
    assets = pd.read_csv(ROOT / "us_portfolio_equity_assets_by_country.csv", parse_dates=["survey_date"])
    liabilities = pd.read_csv(ROOT / "us_portfolio_equity_liabilities_by_country.csv", parse_dates=["survey_date"])
    asset_rank = pd.read_csv(ROOT / "latest_equity_asset_country_ranking.csv", parse_dates=["survey_date"])
    liability_rank = pd.read_csv(ROOT / "latest_equity_liability_country_ranking.csv", parse_dates=["survey_date"])
    holder_sectors = pd.read_csv(ROOT / "latest_us_holder_sector_equity_assets.csv", parse_dates=["as_of"])
    functional = pd.read_csv(ROOT / "long_run_equity_functional_decomposition.csv", parse_dates=["survey_date"])
    stable = pd.read_csv(ROOT / "long_run_equity_stable_panel_decomposition.csv", parse_dates=["survey_date"])

    # 1. Private U.S. holder sectors of foreign portfolio equity.
    sector_plot = holder_sectors.loc[holder_sectors["value_usd_billions"].gt(0.05)].copy()
    sector_plot = sector_plot.sort_values("value_usd_billions")
    sector_colors = ["#175CD3", "#7F56D9", "#039855", "#F79009"][-len(sector_plot):]
    fig, ax = plt.subplots(figsize=(9.3, 5.3))
    bars = ax.barh(sector_plot["holder_sector"], sector_plot["value_usd_billions"] / 1000, color=sector_colors)
    ax.set_title("Private U.S. holders of foreign portfolio equity, June 2025", loc="left")
    ax.set_xlabel("Trillions of U.S. dollars")
    ax.grid(axis="x")
    ax.set_axisbelow(True)
    ax.set_xlim(0, (sector_plot["value_usd_billions"] / 1000).max() * 1.28)
    for bar, value, share in zip(
        bars,
        sector_plot["value_usd_billions"] / 1000,
        sector_plot["share_of_private_portfolio_equity_assets"],
    ):
        ax.text(value + 0.15, bar.get_y() + bar.get_height() / 2, f"${value:.2f}T ({share:.1%})", va="center", fontsize=8.5)
    fig.text(
        0.01,
        -0.025,
        "Source: Treasury/CPIS table 3_1. Private cross-border portfolio claims only; government and direct investment are outside this sector panel.",
        fontsize=8.2,
        color="#667085",
    )
    fig.tight_layout()
    save_figure(fig, "01_latest_us_holder_sectors_foreign_equity")

    # 2. Aggregate gross equity positions.
    fig, ax = plt.subplots(figsize=(10.2, 6.0))
    ax.plot(aggregate["date"], aggregate["us_equity_assets_abroad_usd_billions"] / 1000, label="U.S. equity assets abroad", color="#175CD3", linewidth=2.2)
    ax.plot(aggregate["date"], aggregate["us_equity_liabilities_to_foreigners_usd_billions"] / 1000, label="U.S. equity liabilities", color="#B42318", linewidth=2.2)
    ax.set_title("U.S. cross-border equity positions", loc="left")
    ax.set_ylabel("Trillions of U.S. dollars")
    ax.grid(axis="y")
    ax.legend(loc="upper left")
    format_year_axis(ax, 5)
    fig.text(0.01, -0.02, "Quarterly end-of-period IMA positions. Source: Federal Reserve Financial Accounts via FRED.", fontsize=8.3, color="#667085")
    fig.tight_layout()
    save_figure(fig, "02_gross_equity_positions_history")

    # 3. Gross shares and the net position.
    fig, axes = plt.subplots(2, 1, figsize=(10.3, 8.0), sharex=True)
    axes[0].plot(aggregate["date"], aggregate["asset_share_of_gross"], label="Asset share", color="#175CD3", linewidth=2.1)
    axes[0].plot(aggregate["date"], aggregate["liability_share_of_gross"], label="Liability share", color="#B42318", linewidth=2.1)
    axes[0].set_title("A. Shares of gross cross-border equity", loc="left")
    axes[0].set_ylabel("Share")
    axes[0].set_ylim(0, 1)
    axes[0].yaxis.set_major_formatter(PercentFormatter(1.0, decimals=0))
    axes[0].legend(loc="best")
    axes[0].grid(axis="y")
    net = aggregate["net_foreign_equity_position_usd_billions"] / 1000
    axes[1].plot(aggregate["date"], net, color="#344054", linewidth=2.2)
    axes[1].fill_between(aggregate["date"], 0, net, where=net.lt(0), color="#B42318", alpha=0.18)
    axes[1].fill_between(aggregate["date"], 0, net, where=net.ge(0), color="#175CD3", alpha=0.18)
    axes[1].axhline(0, color="#667085", linewidth=0.9)
    axes[1].set_title("B. Net foreign equity position: assets minus liabilities", loc="left")
    axes[1].set_ylabel("Trillions of U.S. dollars")
    axes[1].grid(axis="y")
    format_year_axis(axes[1], 5)
    fig.suptitle("Composition and net position of U.S. cross-border equity", fontsize=16, y=0.985)
    fig.tight_layout(rect=(0, 0, 1, 0.96), h_pad=1.8)
    save_figure(fig, "03_equity_asset_liability_shares")

    # 4-5. Latest country rankings.
    asset_date = asset_rank["survey_date"].iloc[0]
    ranking_plot(
        asset_rank,
        title=f"U.S. portfolio equity assets by issuer location, {asset_date.year} preliminary",
        source_note="Source: Treasury TIC preliminary SHC, released August 31, 2026. Issuer residence; direct investment excluded.",
        stem="04_latest_equity_asset_country_ranking",
        color="#175CD3",
    )
    liability_date = liability_rank["survey_date"].iloc[0]
    ranking_plot(
        liability_rank,
        title=f"Foreign portfolio holdings of U.S. equity, June {liability_date.year}",
        source_note="Source: Treasury TIC SHL. Reported holder/custody residence may differ from ultimate beneficial ownership.",
        stem="05_latest_equity_liability_country_ranking",
        color="#B42318",
    )

    # 6. Country histories on each side.
    fig, axes = plt.subplots(2, 1, figsize=(11.0, 9.1), sharex=True)
    palette = ["#175CD3", "#B42318", "#039855", "#F79009", "#7F56D9", "#06AED4"]
    for ax, data, rank, panel_title in [
        (axes[0], assets, asset_rank, "A. U.S. portfolio equity assets: largest current issuer locations"),
        (axes[1], liabilities, liability_rank, "B. U.S. portfolio equity liabilities: largest current holder locations"),
    ]:
        top_names = rank.head(6)["country_or_group"].tolist()
        for name, color in zip(top_names, palette):
            frame = data.loc[
                data["country_or_group"].eq(name)
                & data["entity_type"].eq("Country or economy")
                & data["survey_date"].ge("1994-01-01")
            ].dropna(subset=["equity_value_usd_billions"]).drop_duplicates("survey_date").sort_values("survey_date")
            ax.plot(frame["survey_date"], frame["equity_value_usd_billions"] / 1000, label=name, color=color, linewidth=1.9)
        ax.set_title(panel_title, loc="left")
        ax.set_ylabel("Trillions of U.S. dollars")
        ax.grid(axis="y")
        ax.legend(ncol=3, loc="upper left", fontsize=8.2)
        format_year_axis(ax, 5)
    fig.suptitle("Country composition of U.S. cross-border portfolio equity", fontsize=16, y=0.99)
    fig.text(0.01, 0.005, "Annual survey dates are irregular before 2003. Asset 2025 values are preliminary; liability 2025 values are final.", fontsize=8.1, color="#667085")
    fig.tight_layout(rect=(0, 0.025, 1, 0.965), h_pad=1.8)
    save_figure(fig, "06_country_histories_assets_liabilities")

    # 7. AHP-period gross and net aggregate positions.
    clean = aggregate.dropna(subset=["us_equity_assets_abroad_usd_billions", "us_equity_liabilities_to_foreigners_usd_billions"])
    fig, axes = plt.subplots(2, 1, figsize=(11.2, 8.8), sharex=True)
    for ax in axes:
        add_ahp_periods(ax, clean["date"].min(), clean["date"].max(), label=False)
    axes[0].plot(clean["date"], clean["us_equity_assets_abroad_usd_billions"] / 1000, color="#175CD3", label="Assets", linewidth=2.2)
    axes[0].plot(clean["date"], clean["us_equity_liabilities_to_foreigners_usd_billions"] / 1000, color="#B42318", label="Liabilities", linewidth=2.2)
    axes[0].plot(clean["date"], clean["net_foreign_equity_position_usd_billions"] / 1000, color="#344054", label="Net: assets - liabilities", linewidth=1.8)
    axes[0].axhline(0, color="#667085", linewidth=0.8)
    axes[0].set_title("A. Market-value positions", loc="left")
    axes[0].set_ylabel("Trillions of U.S. dollars")
    axes[0].legend(loc="upper left", ncol=3)
    axes[0].grid(axis="y")
    axes[1].plot(clean["date"], clean["equity_assets_over_corporate_gva"], color="#175CD3", label="Assets / corporate GVA", linewidth=2.2)
    axes[1].plot(clean["date"], clean["equity_liabilities_over_corporate_gva"], color="#B42318", label="Liabilities / corporate GVA", linewidth=2.2)
    axes[1].plot(clean["date"], clean["net_equity_position_over_corporate_gva"], color="#344054", label="Net / corporate GVA", linewidth=1.8)
    axes[1].axhline(0, color="#667085", linewidth=0.8)
    axes[1].set_title("B. Positions relative to quarterly corporate GVA at annual rate", loc="left")
    axes[1].set_ylabel("Ratio")
    axes[1].grid(axis="y")
    format_year_axis(axes[1], 5)
    for ax in axes:
        add_ahp_periods(ax, clean["date"].min(), clean["date"].max(), label=True)
    fig.suptitle("Long-run U.S. gross and net foreign equity positions", fontsize=16, y=0.99)
    fig.tight_layout(rect=(0, 0, 1, 0.965), h_pad=1.8)
    save_figure(fig, "07_long_run_gross_net_equity_positions")

    # 8-9. Proposed functional and stable-panel decompositions on both sides.
    group_figure(
        functional,
        FUNCTIONAL_GROUPS,
        FUNCTIONAL_COLORS,
        "Cross-border portfolio equity by economic function and reported location",
        "08_long_run_equity_functional_decomposition",
        "Source: Treasury TIC SHC/SHL. Survey-side totals add exactly. Asset locations are issuer residence; liability locations are holder/custody residence.",
    )
    group_figure(
        stable,
        STABLE_GROUPS,
        STABLE_COLORS,
        "Stable-panel cross-border portfolio equity decomposition",
        "09_long_run_equity_stable_panel_decomposition",
        "Source: Treasury TIC SHC/SHL. Eight economies are separately reported at every retained date; all other foreign is the exact residual.",
    )

    print(f"Saved nine PNG and nine PDF figures to {FIGURE_DIR}")


if __name__ == "__main__":
    main()
