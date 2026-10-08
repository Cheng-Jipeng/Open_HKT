#!/usr/bin/env python3
"""Reproduce the 15 SYNTHETIC-ONLY production-inversion checks.

Run from any working directory:
    python3 /absolute/path/to/check_production_formulas.py

The default output is production_formula_checks.json beside this script.
Use --output PATH to choose another destination. Only Python's standard library
is needed. The inputs are invented, deterministic numbers, not empirical data.
The skilled-production shares are imposed, not solved equilibrium policies.
This checks algebraic rearrangements and normalization invariance; it does not
solve the Julia equilibrium, estimate parameters, establish empirical mappings,
or prove global identification. It reproduces the existing 15 checks recorded
in production_analysis.json without adding new tests.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path


PARAMETERS = {
    "a": 0.16,
    "H": 1.3,
    "L": 2.1,
    "theta": 0.63,
    "alpha": 0.43,
    "rho": 2.2,
    "AX0": 0.9,
    "AL0": 1.3,
    "xi": 0.8,
    "nu": 0.2,
}
PRODUCTION_SHARES = [0.71, 0.62, 0.57, 0.48, 0.43]
INITIAL_KNOWLEDGE = 1.7
ALTERNATIVE_ALPHA = 0.71
ABSOLUTE_TOLERANCE = 1e-11


def synthetic_observations(p):
    """Evaluate CES and entry/accounting equations at imposed interior shares."""
    rows = []
    knowledge = INITIAL_KNOWLEDGE
    for phi in PRODUCTION_SHARES:
        ax = p["AX0"] * knowledge ** p["xi"]
        al = p["AL0"] * knowledge ** p["nu"]
        x = phi * p["H"]
        y = (
            p["alpha"] * (ax * x) ** (1 - p["rho"])
            + (1 - p["alpha"]) * (al * p["L"]) ** (1 - p["rho"])
        ) ** (1 / (1 - p["rho"]))
        wh = (
            p["theta"] * p["alpha"] * ax ** (1 - p["rho"])
            * (y / x) ** p["rho"]
        )
        wl = (
            (1 - p["alpha"]) * al ** (1 - p["rho"])
            * (y / p["L"]) ** p["rho"]
        )
        bh, bl = wh * p["H"], wl * p["L"]
        issuance = (1 - phi) * bh
        growth = 1 + p["a"] * (1 - phi) * p["H"]
        capitalization = growth * wh / p["a"]
        dividends = (1 - p["theta"]) / p["theta"] * wh * x
        rows.append({
            "N": knowledge, "AX": ax, "AL": al, "X": x, "Y": y,
            "wH": wh, "wL": wl, "BH": bh, "BL": bl,
            "I": issuance, "G": growth, "Q": capitalization,
            "D": dividends, "phi": phi,
        })
        knowledge *= growth
    return rows


def check_formulas():
    p = PARAMETERS
    rows = synthetic_observations(p)
    errors = {}

    def record(name, expected, actual):
        errors[name] = max(errors.get(name, 0.0), abs(actual - expected))

    for r in rows:
        record("a_from_Q_I", p["a"], r["wH"] / (r["Q"] - r["I"]))
        record("G_from_Q_I", r["G"], r["Q"] / (r["Q"] - r["I"]))
        issuance_from_accounts = r["BH"] + r["BL"] + r["D"] - r["Y"]
        record("I_accounting", r["I"], issuance_from_accounts)
        record(
            "theta_from_Y_BL_D", p["theta"],
            1 - r["D"] / (r["Y"] - r["BL"]),
        )
        phi_external = p["theta"] * (r["Y"] - r["BL"]) / r["BH"]
        issuance_external = r["BH"] - p["theta"] * (r["Y"] - r["BL"])
        record("phi_external_theta", r["phi"], phi_external)
        record("a_external_theta", p["a"], r["wH"] / (r["Q"] - issuance_external))

        sx, sl = 1 - r["BL"] / r["Y"], r["BL"] / r["Y"]
        ax = r["Y"] / r["X"] * (sx / p["alpha"]) ** (1 / (1 - p["rho"]))
        al = r["Y"] / p["L"] * (sl / (1 - p["alpha"])) ** (1 / (1 - p["rho"]))
        record("AX_conditional_inversion", r["AX"], ax)
        record("AL_conditional_inversion", r["AL"], al)

        # Change alpha and both augmentation scales, preserving effective CES
        # coefficients. The separate levels cannot be identified by these data.
        alpha2 = ALTERNATIVE_ALPHA
        ax2 = r["AX"] * (p["alpha"] / alpha2) ** (1 / (1 - p["rho"]))
        al2 = r["AL"] * ((1 - p["alpha"]) / (1 - alpha2)) ** (1 / (1 - p["rho"]))
        y2 = (
            alpha2 * (ax2 * r["X"]) ** (1 - p["rho"])
            + (1 - alpha2) * (al2 * p["L"]) ** (1 - p["rho"])
        ) ** (1 / (1 - p["rho"]))
        wh2 = p["theta"] * alpha2 * ax2 ** (1 - p["rho"]) * (y2 / r["X"]) ** p["rho"]
        wl2 = (1 - alpha2) * al2 ** (1 - p["rho"]) * (y2 / p["L"]) ** p["rho"]
        record("alpha_invariance_Y", r["Y"], y2)
        record("alpha_invariance_wH", r["wH"], wh2)
        record("alpha_invariance_wL", r["wL"], wl2)

    for r, s in zip(rows[:-1], rows[1:]):
        dh = math.log(s["wH"] / r["wH"])
        dl = math.log(s["wL"] / r["wL"])
        dyx = math.log((s["Y"] / s["X"]) / (r["Y"] / r["X"]))
        dyl = math.log(s["Y"] / r["Y"])  # L is fixed in this synthetic model.
        # Reconstruct knowledge growth from values, without using stored N.
        k = math.log(r["Q"] / (r["Q"] - r["I"]))
        record("xi_N_free", p["xi"], (dh - p["rho"] * dyx) / ((1 - p["rho"]) * k))
        record("nu_N_free", p["nu"], (dl - p["rho"] * dyl) / ((1 - p["rho"]) * k))

    x = [(r["Y"] - r["BL"]) / r["wH"] for r in rows]
    y = [r["Q"] / r["wH"] - p["H"] for r in rows]
    theta_hat = -(y[1] - y[0]) / (x[1] - x[0])
    inverse_a = y[0] + theta_hat * x[0]
    record("joint_theta_from_two_dates", p["theta"], theta_hat)
    record("joint_a_from_two_dates", p["a"], 1 / inverse_a)

    return {
        "label": "SYNTHETIC ALGEBRA CHECKS ONLY — NOT EMPIRICAL ESTIMATES",
        "method": (
            "Independent Python scalar evaluation of CES, factor-price, knowledge "
            "and capitalization equations. Imposed interior production shares; "
            "not a Julia equilibrium solve, empirical calibration, or proof of "
            "global identification. Reproduces the original 15 checks only."
        ),
        "uses_empirical_data": False,
        "solves_equilibrium": False,
        "parameters": p,
        "initial_knowledge": INITIAL_KNOWLEDGE,
        "imposed_production_shares": PRODUCTION_SHARES,
        "alternative_alpha": ALTERNATIVE_ALPHA,
        "number_observations": len(rows),
        "number_checks": len(errors),
        "absolute_tolerance": ABSOLUTE_TOLERANCE,
        "max_absolute_errors": errors,
        "max_absolute_error": max(errors.values()),
        "joint_a_theta_x_values": x,
        "joint_a_theta_estimates": {"a": 1 / inverse_a, "theta": theta_hat},
        "synthetic_observations": rows,
        "passed": all(math.isfinite(e) and e < ABSOLUTE_TOLERANCE for e in errors.values()),
    }


def main():
    script = Path(__file__).resolve()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=script.with_name("production_formula_checks.json"))
    args = parser.parse_args()
    report = check_formulas()
    report["script_sha256"] = hashlib.sha256(script.read_bytes()).hexdigest()
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({
        "label": report["label"],
        "output": str(args.output.resolve()),
        "number_checks": report["number_checks"],
        "max_absolute_error": report["max_absolute_error"],
        "passed": report["passed"],
    }, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
