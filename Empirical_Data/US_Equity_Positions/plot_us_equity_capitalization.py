#!/usr/bin/env python3
"""Plot the domestic/foreign decomposition of U.S. equity capitalization."""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.ticker import PercentFormatter


ROOT = Path(__file__).resolve().parent
DATA_FILE = ROOT / "us_equity_capitalization_domestic_foreign_quarterly.csv"
FIGURE_DIR = ROOT / "figures"
STEM = "10_us_equity_capitalization_domestic_foreign"
DOMESTIC = "#175CD3"
FOREIGN = "#F79009"
TOTAL = "#101828"


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
            "legend.fontsize": 9,
        }
    )


def add_ahp_periods(ax: plt.Axes, start: pd.Timestamp, end: pd.Timestamp, label: bool) -> None:
    period2 = pd.Timestamp("2002-01-01")
    period3 = pd.Timestamp("2008-01-01")
    post = pd.Timestamp("2023-10-01")
    ax.axvspan(max(start, period2), min(end, period3), color="#F5C66A", alpha=0.10, zorder=0)
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
    y0, y1 = ax.get_ylim()
    y = y1 - 0.045 * (y1 - y0)
    labels = [
        (start, period2, "1990-2001"),
        (period2, period3, "2002-2007"),
        (period3, post, "2008-2023Q3"),
        (post, end, "post-AHP"),
    ]
    for left, right, text in labels:
        if left >= right:
            continue
        midpoint = left + (right - left) / 2
        ax.text(midpoint, y, text, ha="center", va="top", fontsize=7.5, color="#475467")


def main() -> None:
    configure_matplotlib()
    data = pd.read_csv(DATA_FILE, parse_dates=["date"])
    dates = data["date"]
    start, end = dates.iloc[0], dates.iloc[-1]
    domestic = data["domestic_holdings_usd_trillions"]
    foreign = data["foreign_holdings_usd_trillions"]
    total = data["us_equity_capitalization_usd_trillions"]

    fig, axes = plt.subplots(
        2,
        1,
        figsize=(11.4, 7.8),
        sharex=True,
        gridspec_kw={"height_ratios": [1.35, 1.0], "hspace": 0.16},
    )
    fig.suptitle(
        "Who holds U.S. corporate equity capitalization?",
        x=0.08,
        y=0.985,
        ha="left",
        fontsize=16,
        fontweight="bold",
        color="#101828",
    )

    ax = axes[0]
    ax.stackplot(
        dates,
        domestic,
        foreign,
        labels=["Domestic residents", "Foreign residents"],
        colors=[DOMESTIC, FOREIGN],
        alpha=0.88,
        linewidth=0,
    )
    ax.plot(dates, total, color=TOTAL, linewidth=1.25, label="Total capitalization", zorder=4)
    ax.set_title("A. Market value outstanding", loc="left", pad=8)
    ax.set_ylabel("Trillions of U.S. dollars")
    ax.set_ylim(0, total.max() * 1.13)
    ax.grid(axis="y")
    add_ahp_periods(ax, start, end, label=True)
    handles, labels = ax.get_legend_handles_labels()
    ax.legend(handles, labels, loc="upper left", ncol=3, bbox_to_anchor=(0, 0.885))

    latest = data.iloc[-1]
    annotation = (
        f"{latest['quarter']}\n"
        f"Total  ${latest['us_equity_capitalization_usd_trillions']:.1f}tn\n"
        f"Domestic  ${latest['domestic_holdings_usd_trillions']:.1f}tn "
        f"({latest['domestic_share_percent']:.1f}%)\n"
        f"Foreign  ${latest['foreign_holdings_usd_trillions']:.1f}tn "
        f"({latest['foreign_share_percent']:.1f}%)"
    )
    ax.annotate(
        annotation,
        xy=(end, total.iloc[-1]),
        xytext=(-132, -48),
        textcoords="offset points",
        ha="left",
        va="top",
        fontsize=8.7,
        color="#101828",
        bbox={"boxstyle": "round,pad=0.45", "fc": "white", "ec": "#D0D5DD", "alpha": 0.96},
        arrowprops={"arrowstyle": "-", "color": "#667085", "lw": 0.8},
        zorder=6,
    )

    ax = axes[1]
    ax.stackplot(
        dates,
        data["domestic_share_percent"],
        data["foreign_share_percent"],
        labels=["Domestic residents", "Foreign residents"],
        colors=[DOMESTIC, FOREIGN],
        alpha=0.88,
        linewidth=0,
    )
    ax.set_title("B. Holder-residence shares", loc="left", pad=8)
    ax.set_ylabel("Percent of capitalization")
    ax.set_ylim(0, 100)
    ax.yaxis.set_major_formatter(PercentFormatter(xmax=100, decimals=0))
    ax.grid(axis="y")
    add_ahp_periods(ax, start, end, label=False)
    ax.xaxis.set_major_locator(mdates.YearLocator(5))
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y"))
    ax.set_xlim(start, end)

    note = (
        "Domestic holdings are the exact residual: LM883164105 − LM263064105. Market value, quarter-end. "
        "The capitalization measure includes public and closely held U.S. corporate equity; mutual-fund shares "
        "are excluded. Period divisions follow AHP_NFA. Source: Federal Reserve Financial Accounts, "
        "Table L.224 (formerly L.223), via OpenEcon/FRED."
    )
    fig.text(0.08, 0.012, note, ha="left", va="bottom", fontsize=7.8, color="#475467", wrap=True)
    fig.subplots_adjust(left=0.08, right=0.98, top=0.91, bottom=0.105)

    FIGURE_DIR.mkdir(parents=True, exist_ok=True)
    fig.savefig(FIGURE_DIR / f"{STEM}.png", bbox_inches="tight", facecolor="white")
    fig.savefig(FIGURE_DIR / f"{STEM}.pdf", bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"Saved {STEM}.png and {STEM}.pdf")


if __name__ == "__main__":
    main()
