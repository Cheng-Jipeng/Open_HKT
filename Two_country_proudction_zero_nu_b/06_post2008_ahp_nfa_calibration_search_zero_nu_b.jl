# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:percent
#     text_representation:
#       extension: .jl
#       format_name: percent
#       format_version: '1.3'
#       jupytext_version: 1.19.5
#   kernelspec:
#     display_name: Julia 1.12.1
#     language: julia
#     name: julia-1.12
#   language_info:
#     file_extension: .jl
#     mimetype: application/julia
#     name: julia
#     version: 1.12.1
# ---

# %% [markdown]
# # 06 — Post-2008 AHP calibration search with \(\nu_b=\xi_W=0\)
#
# This notebook asks whether the zero-absorbing-exponent model can reproduce the
# post-2008 U.S. net foreign asset (NFA) pattern emphasized by Atkeson, Heathcote,
# and Perri (2025):
#
# 1. U.S. NFA deteriorates;
# 2. valuation effects are quantitatively important;
# 3. the main equity-valuation loss comes from price gains on **RoW-held U.S.
#    equity liabilities**, not losses on U.S.-held RoW equity;
# 4. U.S. equity prices outperform RoW equity prices; and
# 5. the liability channel operates on a large gross position.
#
# The primary data window is 2008Q1–2023Q3, the endpoint of the cited paper.
# Price growth is calculated from the accounting-implied dollar indexes in
# `Codes/Empirical_Data` over the same dates. One model period is used as an episode index; this timing map is a
# plotting convention, not a separately calibrated model frequency.
#
# **Interpretive guardrail.** Matching these NFA accounting moments would not by
# itself identify a rational bubble. Empirical valuation effects, model equity
# values, and bubble-attributed values are distinct objects.

# %%
using Pkg

function nb06_find_project_dir(start_dir=pwd())
    dir = abspath(start_dir)
    while true
        for candidate in (dir, joinpath(dir, "Codes"))
            project = joinpath(candidate, "Project.toml")
            model = joinpath(candidate, "Two_country_proudction_zero_nu_b",
                             "TwoCountryProductionOLG.jl")
            isfile(project) && isfile(model) && return candidate
        end
        parent = dirname(dir)
        parent == dir && error("Could not locate Codes/Project.toml from $(start_dir)")
        dir = parent
    end
end

const NB06_PROJECT_DIR = nb06_find_project_dir()
Pkg.activate(NB06_PROJECT_DIR)
cd(NB06_PROJECT_DIR)

const NB06_MODEL_FILE = joinpath(
    NB06_PROJECT_DIR, "Two_country_proudction_zero_nu_b", "TwoCountryProductionOLG.jl",
)
if @isdefined ProductionParams
    @isdefined(_require_zero_nu_b) || error(
        "A different TwoCountryProductionOLG solver is loaded. Restart the Julia kernel.",
    )
else
    include(NB06_MODEL_FILE)
end

using DelimitedFiles
if !isdefined(Main, :IJulia)
    ENV["GKSwstype"] = get(ENV, "GKSwstype", "100")
end
using Plots, Printf, Statistics
using Plots.PlotMeasures

gr()
default(
    size=(950, 520), framestyle=:box, grid=:y, legend=:best,
    fontfamily="Computer Modern", linewidth=2,
    titlefontsize=11, guidefontsize=10, tickfontsize=9, legendfontsize=8,
    left_margin=9mm, right_margin=7mm, top_margin=7mm, bottom_margin=8mm,
)

const NB06_SEARCH_T = 16
const NB06_N_BUFFER = 0
const NB06_BRANCH_ITERS = 500
const NB06_RESID_TOL = 1e-5
const NB06_ACCOUNTING_SCALED_TOL = 1e-7
const NB06_PSI_INTERIOR_TOL = 0.02
const NB06_EQUITY_INTERIOR_TOL = 0.01
const NB06_THETA_INTERIOR_TOL = 0.01
const NB06_PHI_INTERIOR_MARGIN = 1e-8
const NB06_ABSORBING_TOL = 1e-10
const NB06_MIN_NFA_DETERIORATION = 1e-3
const NB06_MIN_VA_CA_RATIO = 1.10
const NB06_MIN_LIABILITY_GROSS_VA_SHARE = 0.90
const NB06_MIN_Q_W_GROWTH = 0.95
const NB06_RUN_LONG_HORIZON_AUDIT = lowercase(get(
    ENV, "NB06_RUN_LONG_HORIZON_AUDIT", "false",
)) in ("1", "true", "yes")
const NB06_RUN_DIRECT_COLD_CHECK = lowercase(get(
    ENV, "NB06_RUN_DIRECT_COLD_CHECK", "false",
)) in ("1", "true", "yes")

const NB06_EMPIRICAL_DIR = joinpath(NB06_PROJECT_DIR, "Empirical_Data")
const NB06_PERIOD_CSV = joinpath(NB06_EMPIRICAL_DIR, "ahp_us_nfa_period_summary.csv")
const NB06_LATEST_CSV = joinpath(NB06_EMPIRICAL_DIR, "ahp_us_nfa_decomposition_latest.csv")
const NB06_OUTDIR = joinpath(
    NB06_PROJECT_DIR, "Two_country_proudction_zero_nu_b", "outputs_zero_nu_b",
    "06_post2008_ahp_nfa_calibration_search",
)
mkpath(NB06_OUTDIR)

println("Project directory:       ", NB06_PROJECT_DIR)
println("Output directory:        ", NB06_OUTDIR)
println("Search horizon:          T = ", NB06_SEARCH_T)
println("Fixed exponents:         nu_b = xi_W = 0")
println("Empirical primary window: 2008Q1-2023Q3")

# %% [markdown]
# ## 1. Empirical targets and sign conventions
#
# From the U.S. perspective,
#
# \[
# \Delta NFA_t=CA_t+VA_t+RES_t,
# \qquad
# VA_t^{eq}=G_t^{A,eq}-G_t^{L,eq}.
# \]
#
# A gain on U.S.-held RoW equity, \(G_t^{A,eq}\), raises U.S. NFA. A gain on
# RoW-held U.S. equity, \(G_t^{L,eq}\), raises U.S. liabilities and therefore
# enters U.S. NFA with a minus sign. Period flows are divided by end-period
# corporate GVA; the empirical \(\Delta NFA/GVA\) target is not the difference
# between two separately normalized NFA ratios.

# %%
function nb06_read_csv_any(path::AbstractString)
    isfile(path) || error("Required CSV not found: $(path)")
    data, header = readdlm(path, ',', Any, '\n'; header=true, quotes=true)
    matrix = ndims(data) == 1 ? reshape(data, 1, :) : data
    names = String.(vec(header))
    size(matrix, 2) == length(names) || error("CSV header mismatch in $(path)")
    return matrix, names
end

function nb06_col(names, name)
    j = findfirst(==(name), names)
    j === nothing && error("Missing CSV column $(name)")
    return j
end

nb06_float(x) = x isa Number ? Float64(x) : parse(Float64, string(x))

function nb06_period_value(data, names, period, term)
    jp = nb06_col(names, "period")
    jt = nb06_col(names, "term")
    jv = nb06_col(names, "total_over_end_period_gva")
    i = findfirst(r -> string(data[r, jp]) == period && string(data[r, jt]) == term,
                  axes(data, 1))
    i === nothing && error("Missing empirical period target $(period), $(term)")
    return nb06_float(data[i, jv])
end

function nb06_quarter_value(data, names, quarter, column)
    jq = nb06_col(names, "quarter")
    jv = nb06_col(names, column)
    i = findfirst(r -> string(data[r, jq]) == quarter, axes(data, 1))
    i === nothing && error("Missing empirical quarter $(quarter)")
    return nb06_float(data[i, jv])
end

period_data, period_names = nb06_read_csv_any(NB06_PERIOD_CSV)
latest_data, latest_names = nb06_read_csv_any(NB06_LATEST_CSV)

const NB06_PRIMARY_WINDOW = "2008Q1-2023Q3"
const NB06_PRICE_BASE = "2008Q1"
const NB06_PRIMARY_ENDPOINT = "2023Q3"

emp_delta_nfa = nb06_period_value(period_data, period_names, NB06_PRIMARY_WINDOW,
                                  "delta_nfa_musd")
emp_total_va = nb06_period_value(period_data, period_names, NB06_PRIMARY_WINDOW,
                                 "total_valuation_us_musd")
emp_ca = nb06_period_value(period_data, period_names, NB06_PRIMARY_WINDOW,
                           "current_account_us_musd")
emp_res = nb06_period_value(period_data, period_names, NB06_PRIMARY_WINDOW,
                            "ahp_residual_musd")
emp_asset_va = nb06_period_value(period_data, period_names, NB06_PRIMARY_WINDOW,
                                 "gain_us_held_row_equity_musd")
emp_liability_gain = nb06_period_value(
    period_data, period_names, NB06_PRIMARY_WINDOW,
    "gain_foreign_held_us_equity_musd",
)
emp_net_equity_va = nb06_period_value(period_data, period_names, NB06_PRIMARY_WINDOW,
                                      "net_equity_valuation_musd")

emp_q_us_end = nb06_quarter_value(latest_data, latest_names, NB06_PRIMARY_ENDPOINT,
                                  "equity_liability_price_index")
emp_q_w_end = nb06_quarter_value(latest_data, latest_names, NB06_PRIMARY_ENDPOINT,
                                 "equity_asset_price_index")
emp_q_us_base = nb06_quarter_value(latest_data, latest_names, NB06_PRICE_BASE,
                                   "equity_liability_price_index")
emp_q_w_base = nb06_quarter_value(latest_data, latest_names, NB06_PRICE_BASE,
                                  "equity_asset_price_index")
emp_liability_exposure = nb06_quarter_value(
    latest_data, latest_names, NB06_PRIMARY_ENDPOINT,
    "equity_liabilities_us_over_gva",
)
emp_asset_exposure = nb06_quarter_value(
    latest_data, latest_names, NB06_PRIMARY_ENDPOINT,
    "equity_assets_us_over_gva",
)
emp_initial_liability_exposure = nb06_quarter_value(
    latest_data, latest_names, NB06_PRICE_BASE, "equity_liabilities_us_over_gva",
)
emp_initial_asset_exposure = nb06_quarter_value(
    latest_data, latest_names, NB06_PRICE_BASE, "equity_assets_us_over_gva",
)

const NB06_TARGET = (
    delta_nfa=emp_delta_nfa,
    total_va=emp_total_va,
    ca=emp_ca,
    residual=emp_res,
    asset_va=emp_asset_va,
    liability_va=-emp_liability_gain,
    net_equity_va=emp_net_equity_va,
    q_us_growth=emp_q_us_end / emp_q_us_base,
    q_w_growth=emp_q_w_end / emp_q_w_base,
    relative_price_growth=(emp_q_us_end / emp_q_us_base) /
                          (emp_q_w_end / emp_q_w_base),
    liability_exposure=emp_liability_exposure,
    asset_exposure=emp_asset_exposure,
    initial_liability_exposure=emp_initial_liability_exposure,
    initial_asset_exposure=emp_initial_asset_exposure,
    liability_share_gross_va=abs(-emp_liability_gain) /
        (abs(-emp_liability_gain) + abs(emp_asset_va)),
)

@printf("Empirical Delta NFA / end GVA:    %+.6f\n", NB06_TARGET.delta_nfa)
@printf("Empirical total VA / end GVA:    %+.6f\n", NB06_TARGET.total_va)
@printf("Empirical net equity VA:         %+.6f\n", NB06_TARGET.net_equity_va)
@printf("  asset / liability components:  %+.6f / %+.6f\n",
        NB06_TARGET.asset_va, NB06_TARGET.liability_va)
@printf("Empirical CA / end GVA:           %+.6f\n", NB06_TARGET.ca)
@printf("US / RoW price growth:            %.3f / %.3f (relative %.3f)\n",
        NB06_TARGET.q_us_growth, NB06_TARGET.q_w_growth,
        NB06_TARGET.relative_price_growth)
@printf("Endpoint gross asset/liability:  %.3f / %.3f of GVA\n",
        NB06_TARGET.asset_exposure, NB06_TARGET.liability_exposure)

# %% [markdown]
# ## 2. Exact model-side NFA accounting
#
# For each all-\(u\) state, model gross holdings are
#
# \[
# n_{W,t}=\frac{(1-\omega_t)(1-\theta_t)A_t}{q_{W,t}},\qquad
# n^\ast_{US,t}=\frac{\omega_t^\ast(1-\theta_{US,t}^\ast)A_t^\ast}{q_{US,t}},
# \]
#
# \[
# NFA_t=q_{W,t}n_{W,t}+\theta_tA_t-q_{US,t}n^\ast_{US,t}.
# \]
#
# Valuation uses lagged quantities and current-account flows use current prices.
# The direct equilibrium check is \(NFA_t=A_t-Q_{US,t}\); no terminal
# fundamental-value recursion is invoked.

# %%
nb06_path(result, field::Symbol) = Float64[getfield(s, field) for s in result.u_path]

function nb06_accounting(result::ProductionSimulationResult)
    T = length(result.u_path)
    q_us = nb06_path(result, :q_US)
    q_w = nb06_path(result, :q_W)
    y_us = nb06_path(result, :Y_US)
    n_w = Float64[(1-s.ω)*(1-s.θ)*s.A/s.q_W for s in result.u_path]
    n_us_star = Float64[
        s.ω_star*(1-s.θ_US_star)*s.A_star/s.q_US for s in result.u_path
    ]
    bond = Float64[s.θ*s.A for s in result.u_path]
    asset = q_w .* n_w
    liability = q_us .* n_us_star
    nfa = asset .+ bond .- liability

    va_asset = zeros(T); va_liability = zeros(T)
    ca_asset = zeros(T); ca_liability = zeros(T); ca_bond = zeros(T)
    for t in 2:T
        va_asset[t] = n_w[t-1] * (q_w[t] - q_w[t-1])
        va_liability[t] = -n_us_star[t-1] * (q_us[t] - q_us[t-1])
        ca_asset[t] = q_w[t] * (n_w[t] - n_w[t-1])
        ca_liability[t] = -q_us[t] * (n_us_star[t] - n_us_star[t-1])
        ca_bond[t] = bond[t] - bond[t-1]
    end
    va = va_asset .+ va_liability
    ca = ca_asset .+ ca_liability .+ ca_bond
    delta_nfa = zeros(T); residual = zeros(T)
    for t in 2:T
        delta_nfa[t] = nfa[t] - nfa[t-1]
        residual[t] = delta_nfa[t] - va[t] - ca[t]
    end
    equilibrium_nfa = Float64[s.A - s.Q_US for s in result.u_path]
    return (
        T=T, q_us=q_us, q_w=q_w, y_us=y_us,
        n_w=n_w, n_us_star=n_us_star, bond=bond,
        asset=asset, liability=liability, nfa=nfa,
        va_asset=va_asset, va_liability=va_liability, va=va,
        ca_asset=ca_asset, ca_liability=ca_liability, ca_bond=ca_bond, ca=ca,
        delta_nfa=delta_nfa, residual=residual,
        cum_va_asset=cumsum(va_asset), cum_va_liability=cumsum(va_liability),
        cum_va=cumsum(va), cum_ca=cumsum(ca), cum_residual=cumsum(residual),
        residual_max=maximum(abs.(residual[2:end])),
        nfa_identity_error=maximum(abs.(nfa .- equilibrium_nfa)),
    )
end

function nb06_metrics(a)
    e = a.T
    ye = a.y_us[e]
    evidence = 2:e
    asset_va = a.cum_va_asset[e] / ye
    liability_va = a.cum_va_liability[e] / ye
    net_va = a.cum_va[e] / ye
    ca = a.cum_ca[e] / ye
    delta_nfa = (a.nfa[e] - a.nfa[1]) / ye
    return (
        delta_nfa=delta_nfa,
        asset_va=asset_va,
        liability_va=liability_va,
        net_va=net_va,
        ca=ca,
        residual=a.cum_residual[e] / ye,
        q_us_growth=a.q_us[e] / a.q_us[1],
        q_w_growth=a.q_w[e] / a.q_w[1],
        relative_price_growth=(a.q_us[e]/a.q_us[1])/(a.q_w[e]/a.q_w[1]),
        endpoint_liability_exposure=a.liability[e] / ye,
        endpoint_asset_exposure=a.asset[e] / ye,
        mean_liability_exposure=mean(a.liability[evidence] ./ a.y_us[evidence]),
        mean_asset_exposure=mean(a.asset[evidence] ./ a.y_us[evidence]),
        liability_asset_ratio=a.liability[e] / max(a.asset[e], 1e-12),
        liability_share_gross_va=abs(liability_va) /
            max(abs(liability_va) + abs(asset_va), 1e-12),
        va_to_ca=abs(net_va) / max(abs(ca), 1e-12),
        va_share_nfa=delta_nfa < 0 ? -net_va / max(-delta_nfa, 1e-12) : missing,
    )
end

function nb06_absorbing_summary(result)
    bgps = result.bgp_seq_extended
    ref = first(bgps)
    policy_fields = (:φ_US, :φ_W, :ω, :ω_star, :θ, :θ_US_star, :R_f, :R_f_W)
    aggregate_fields = (:Y_US, :Y_W, :e_US, :e_W, :Q_US, :Q_W,
                        :I_US, :I_W, :R_US, :R_W, :R_p, :R_A,
                        :R_p_star, :R_A_star, :G_N_US, :G_N_W, :Psi)
    policy_error = maximum(maximum(abs(getfield(b,f)-getfield(ref,f)) for f in policy_fields)
                           for b in bgps)
    aggregate_error = maximum(maximum(abs(getfield(b,f)-getfield(ref,f)) for f in aggregate_fields)
                              for b in bgps)
    scaling_error = maximum(maximum((
        abs(b.N_US*b.q_US - ref.N_US*ref.q_US),
        abs(b.N_US*b.d_US - ref.N_US*ref.d_US),
        abs(b.N_W*b.q_W - ref.N_W*ref.q_W),
        abs(b.N_W*b.d_W - ref.N_W*ref.d_W),
    )) for b in bgps)
    growth_identity_error = maximum(max(
        abs(b.G_N_US^result.params.ν_b - 1.0),
        abs(b.G_N_W^result.params.ξ_W - 1.0),
    ) for b in bgps)
    return (
        policy_error=policy_error,
        aggregate_error=aggregate_error,
        scaling_error=scaling_error,
        growth_identity_error=growth_identity_error,
        all_bgp_converged=all(b.converged for b in bgps),
        max_bgp_residual=maximum(b.residual_norm for b in bgps),
    )
end

function nb06_validity(result, a, absorbing)
    theta = nb06_path(result, :θ_US_star)
    phi = vcat(nb06_path(result, :φ_US), nb06_path(result, :φ_W))
    p = result.params
    model_residuals = result.branch_converged &&
        result.max_u_residual <= NB06_RESID_TOL &&
        result.max_bgp_residual <= NB06_RESID_TOL
    accounting_scale = max(1.0, maximum(abs.(a.nfa)), maximum(abs.(a.ca)),
                           maximum(abs.(a.va)))
    accounting_exact = a.residual_max <= NB06_RESID_TOL &&
        a.residual_max/accounting_scale <= NB06_ACCOUNTING_SCALED_TOL &&
        a.nfa_identity_error/accounting_scale <= NB06_ACCOUNTING_SCALED_TOL
    psi_interior = result.diagnostics.psi_ok &&
        result.diagnostics.psi_min >= NB06_PSI_INTERIOR_TOL
    equity_interior = result.diagnostics.equity_weights_ok &&
        result.diagnostics.equity_weight_min >= NB06_EQUITY_INTERIOR_TOL
    theta_interior = all(x -> NB06_THETA_INTERIOR_TOL <= x < 0.9, theta)
    phi_slack = min(minimum(phi)-p.φ_floor, (1-p.φ_floor)-maximum(phi))
    phi_interior = phi_slack >= NB06_PHI_INTERIOR_MARGIN
    positive_claims = all(>(0.0), a.n_us_star) && all(>(0.0), a.liability)
    return_fields = (:R_A_u, :R_A_b, :R_A_star_u, :R_A_star_b, :R_f, :R_f_W)
    positive_returns = all(f -> all(>(0.0), nb06_path(result, f)), return_fields)
    absorbing_valid = absorbing.all_bgp_converged &&
        absorbing.max_bgp_residual <= NB06_RESID_TOL &&
        maximum((absorbing.policy_error, absorbing.aggregate_error,
                 absorbing.scaling_error, absorbing.growth_identity_error)) <= NB06_ABSORBING_TOL
    exponent_ordering = p.ξ_u > p.ν_u > p.ν_b && p.ν_b == 0.0 && p.ξ_W == 0.0
    valid = model_residuals && accounting_exact && psi_interior && equity_interior &&
        theta_interior && phi_interior && positive_claims && positive_returns &&
        absorbing_valid && exponent_ordering
    return (
        valid=valid, model_residuals=model_residuals,
        accounting_exact=accounting_exact, psi_interior=psi_interior,
        equity_interior=equity_interior, theta_interior=theta_interior,
        phi_interior=phi_interior, phi_slack=phi_slack,
        positive_claims=positive_claims, positive_returns=positive_returns,
        absorbing_valid=absorbing_valid, exponent_ordering=exponent_ordering,
        theta_min=minimum(theta), theta_max=maximum(theta),
    )
end

# %% [markdown]
# ## 3. Directed continuation search
#
# A brute-force Cartesian grid is both numerically wasteful and economically
# hard to interpret here. The search instead follows a declared continuation
# path:
#
# 1. raise regime persistence \(\pi\), which strengthens the value of the
#    all-\(u\) continuation;
# 2. raise the U.S. home-equity target \(\bar\omega\), the main lever for
#    absolute U.S. price appreciation;
# 3. raise the bond-issuance cost \(\eta\), which changes the bond/equity
#    current-account margin and can turn NFA growth negative; and
# 4. sweep the RoW target weight on U.S. equity \(\bar\omega^\ast\) to expose
#    the tradeoff between gross liability scale and U.S. price appreciation.
#
# All production primitives and \(\nu_b=\xi_W=0\) remain fixed at the zero-case
# AHP baseline. A candidate is scored only after passing the numerical,
# accounting, interiority, and zero-exponent normalization gates above.

# %%
Base.@kwdef struct NB06Candidate
    label::String
    stage::String
    note::String
    pi::Float64 = 0.75
    omega::Float64 = 0.50
    omega_star::Float64 = 0.25
    eta::Float64 = 0.010
end

function nb06_params(spec::NB06Candidate; T=NB06_SEARCH_T)
    return ProductionParams(
        T_max=T, n_buffer=NB06_N_BUFFER, common_world_growth=false,
        β=0.45, γ=0.25, π_persist=spec.pi,
        a_US=0.20, ϑ_US=0.85,
        a_W=0.06, H_W=3.0, L_W=3.0,
        A_X_US_u=15.0, A_L_US_u=1.5,
        ν_b=0.0, ν_u=1.75, ξ_u=2.25, ξ_W=0.0,
        ω̄=spec.omega, ω̄_star=spec.omega_star,
        κ=1.00, χ=0.0002, η=spec.eta,
        branch_iters=NB06_BRANCH_ITERS, do_global_polish=false,
    )
end

specs = NB06Candidate[
    NB06Candidate(label="baseline", stage="baseline",
                  note="Zero-exponent AHP baseline."),
]
for pi in (0.80, 0.90, 0.95, 0.97)
    push!(specs, NB06Candidate(
        label=@sprintf("pi_%03d", round(Int,100*pi)), stage="persistence",
        pi=pi, note="Raises all-u regime persistence.",
    ))
end
for omega in (0.60, 0.70, 0.80, 0.85, 0.90, 0.93, 0.95)
    push!(specs, NB06Candidate(
        label=@sprintf("omega_%03d", round(Int,100*omega)), stage="US price",
        pi=0.97, omega=omega,
        note="Raises the U.S. target home-equity weight after setting pi=0.97.",
    ))
end
for eta in (0.02, 0.03, 0.04, 0.05, 0.06, 0.07)
    push!(specs, NB06Candidate(
        label=@sprintf("eta_%03d", round(Int,1000*eta)), stage="NFA margin",
        pi=0.97, omega=0.95, eta=eta,
        note="Changes bond issuance and the equity/bond current-account margin.",
    ))
end
for omega_star in (0.275, 0.300, 0.325, 0.350, 0.375, 0.400, 0.425, 0.450)
    push!(specs, NB06Candidate(
        label=@sprintf("omega_star_%03d", round(Int,1000*omega_star)),
        stage="gross liability", pi=0.97, omega=0.95,
        omega_star=omega_star, eta=0.07,
        note="Raises RoW target demand for U.S. equity at the mechanism-matching center.",
    ))
end
for eta in (0.072, 0.074, 0.076, 0.078, 0.080, 0.082, 0.084, 0.086)
    push!(specs, NB06Candidate(
        label=@sprintf("omega_star_425_eta_%03d", round(Int,1000*eta)),
        stage="local refinement", pi=0.97, omega=0.95,
        omega_star=0.425, eta=eta,
        note="Local eta refinement at the liability-dominant center.",
    ))
end

function nb06_mechanism_pass(m)
    return m.delta_nfa <= -NB06_MIN_NFA_DETERIORATION &&
        m.net_va < 0 && m.liability_va < 0 &&
        m.q_us_growth > 1 && m.relative_price_growth > 1 &&
        m.q_w_growth >= NB06_MIN_Q_W_GROWTH &&
        m.va_to_ca >= NB06_MIN_VA_CA_RATIO &&
        m.liability_share_gross_va >= NB06_MIN_LIABILITY_GROSS_VA_SHARE
end

function nb06_scale_pass(m)
    return abs(m.delta_nfa) >= 0.5*abs(NB06_TARGET.delta_nfa) &&
        abs(m.net_va) >= 0.5*abs(NB06_TARGET.net_equity_va) &&
        m.endpoint_liability_exposure >= 0.5*NB06_TARGET.liability_exposure
end

nb06_relative_distance(x, target) = abs(x-target)/max(abs(target), 1e-8)
nb06_log_distance(x, target) = abs(log(max(x,1e-12)/max(target,1e-12)))

function nb06_score(m)
    distance =
        2.0*nb06_relative_distance(m.delta_nfa, NB06_TARGET.delta_nfa) +
        2.0*nb06_relative_distance(m.net_va, NB06_TARGET.net_equity_va) +
        2.0*nb06_relative_distance(m.liability_va, NB06_TARGET.liability_va) +
        0.5*nb06_relative_distance(m.asset_va, NB06_TARGET.asset_va) +
        0.25*nb06_relative_distance(m.ca, NB06_TARGET.ca) +
        1.5*nb06_log_distance(m.q_us_growth, NB06_TARGET.q_us_growth) +
        0.75*nb06_log_distance(m.q_w_growth, NB06_TARGET.q_w_growth) +
        1.0*nb06_log_distance(m.relative_price_growth,
                              NB06_TARGET.relative_price_growth) +
        1.0*nb06_log_distance(m.endpoint_liability_exposure,
                              NB06_TARGET.liability_exposure) +
        2.5*nb06_relative_distance(m.liability_share_gross_va,
                                   NB06_TARGET.liability_share_gross_va)
    penalty =
        (m.delta_nfa >= 0 ? 12.0 : 0.0) +
        (m.net_va >= 0 ? 8.0 : 0.0) +
        (m.liability_va >= 0 ? 8.0 : 0.0) +
        (m.q_us_growth <= 1 ? 5.0 : 0.0) +
        (m.relative_price_growth <= 1 ? 5.0 : 0.0) +
        (abs(m.net_va) <= abs(m.ca) ? 4.0 : 0.0) +
        (abs(m.liability_va) < abs(m.asset_va) ? 4.0 : 0.0)
    return distance + penalty
end

function nb06_classification(m)
    if nb06_mechanism_pass(m) && nb06_scale_pass(m)
        return "mechanism_and_scale_match"
    elseif nb06_mechanism_pass(m)
        return "qualitative_mechanism_match_scale_miss"
    elseif m.net_va < 0 && m.liability_va < 0 && m.q_us_growth > 1
        return "mechanism_near_miss"
    end
    return "wrong_mechanism"
end

# %%
function nb06_evaluate(spec; warm=nothing, T=NB06_SEARCH_T)
    result = run_production_simulation(
        nb06_params(spec; T=T); verbose=false,
        initial_u_path=warm === nothing ? nothing : warm.u_path_extended,
    )
    accounting = nb06_accounting(result)
    metrics = nb06_metrics(accounting)
    absorbing = nb06_absorbing_summary(result)
    validity = nb06_validity(result, accounting, absorbing)
    score = validity.valid ? nb06_score(metrics) : Inf
    return (spec=spec, result=result, accounting=accounting, metrics=metrics,
            absorbing=absorbing, validity=validity, score=score)
end

function nb06_run_search(specs)
    records = Any[]
    failures = Dict{String,Any}[]
    warm_result = nothing
    for (j, spec) in enumerate(specs)
        @printf("[%02d/%02d] %-28s", j, length(specs), spec.label)
        try
            record = nb06_evaluate(spec; warm=warm_result)
            push!(records, record)
            warm_result = record.result
            m = record.metrics
            @printf(" NFA=%+.4f VA=%+.4f [A=%+.4f L=%+.4f] q=(%.3f,%.3f) valid=%s score=%.2f\n",
                    m.delta_nfa, m.net_va, m.asset_va, m.liability_va,
                    m.q_us_growth, m.q_w_growth, record.validity.valid, record.score)
        catch err
            push!(failures, Dict(
                "sequence"=>j, "label"=>spec.label, "stage"=>spec.stage,
                "error"=>sprint(showerror, err),
            ))
            @printf(" ERROR: %s\n", sprint(showerror, err))
        end
    end
    return records, failures
end

search_records, search_failures = nb06_run_search(specs)

valid_records = [r for r in search_records if r.validity.valid]
isempty(valid_records) && error("No hard-valid search candidate")
mechanism_records = [r for r in valid_records if nb06_mechanism_pass(r.metrics)]
if isempty(mechanism_records)
    sort!(valid_records; by=r -> r.score)
    best_search = first(valid_records)
else
    # Conditional on clearing the declared mechanism thresholds, privilege the
    # empirical liability-dominance moment; use the continuous score as tie-breaker.
    sort!(mechanism_records; by=r -> (-r.metrics.liability_share_gross_va, r.score))
    best_search = first(mechanism_records)
end

println("\nSelected search candidate: ", best_search.spec.label)
println("Search classification:     ", nb06_classification(best_search.metrics))
@printf("Search score:              %.4f\n", best_search.score)

# Verification status is recorded explicitly because this local branch is
# reached by declared nested continuation.
# The solution is continuation-resolved. A direct jump to the finalist can be
# much slower and is not equivalent to an economic nonexistence test. The
# default therefore reports the independently gated continuation solution and
# makes a direct cold jump an explicit opt-in diagnostic.
function nb06_optional_cold_check(best_search)
    if !NB06_RUN_DIRECT_COLD_CHECK
        return best_search, "not_run_continuation_solution_reported"
    end
    try
        cold_candidate = nb06_evaluate(best_search.spec; warm=nothing)
        status = cold_candidate.validity.valid ? "hard_valid" : "hard_invalid"
        return cold_candidate.validity.valid ? cold_candidate : best_search, status
    catch err
        return best_search, "error: " * sprint(showerror, err)
    end
end

best, cold_check_status = nb06_optional_cold_check(best_search)

@printf("Selected Delta NFA/Y:      %+.6f\n", best.metrics.delta_nfa)
@printf("Selected net VA/Y:         %+.6f (asset %+.6f, liability %+.6f)\n",
        best.metrics.net_va, best.metrics.asset_va, best.metrics.liability_va)
@printf("Selected CA/Y:             %+.6f\n", best.metrics.ca)
@printf("Selected q growth:         US %.3f, RoW %.3f, relative %.3f\n",
        best.metrics.q_us_growth, best.metrics.q_w_growth,
        best.metrics.relative_price_growth)
@printf("Liability exposure:        endpoint %.3f, mean %.3f of model Y\n",
        best.metrics.endpoint_liability_exposure,
        best.metrics.mean_liability_exposure)

# %% [markdown]
# ## 4. Machine-readable results and calibration comparison
#
# The score is a ranking device, not an estimator with a sampling distribution.
# The classification is deliberately stricter: a qualitative mechanism match
# requires an NFA deterioration of at least 0.1% of model output, negative net
# and liability valuation effects, absolute U.S. price appreciation, no more
# than a 5% RoW price decline, valuation at least 10% larger than current-account
# flows, and at least a 90% liability share of gross absolute VA. Among cases
# clearing those thresholds, the reported finalist maximizes liability
# dominance; the continuous score breaks ties. The separate scale gate prevents a tiny-position
# mechanism match from being called a quantitative calibration.

# %%
function nb06_csv_cell(x)
    s = x === missing ? "" : string(x)
    if occursin(',',s) || occursin('"',s) || occursin('\n',s)
        return "\"" * replace(s, "\""=>"\"\"") * "\""
    end
    return s
end

function nb06_row_value(row, column)
    row isa NamedTuple && return hasproperty(row, Symbol(column)) ? getproperty(row, Symbol(column)) : missing
    return get(row, column, missing)
end

function nb06_write_rows(path, rows, columns)
    open(path, "w") do io
        println(io, join(columns, ','))
        for row in rows
            println(io, join((nb06_csv_cell(nb06_row_value(row,c)) for c in columns), ','))
        end
    end
    return path
end

candidate_rows = Dict{String,Any}[]
for (sequence, r) in enumerate(search_records)
    s, m, v = r.spec, r.metrics, r.validity
    push!(candidate_rows, Dict{String,Any}(
        "sequence"=>sequence, "label"=>s.label, "stage"=>s.stage, "note"=>s.note,
        "pi"=>s.pi, "omega_bar"=>s.omega, "omega_bar_star"=>s.omega_star,
        "eta"=>s.eta, "nu_b"=>r.result.params.ν_b, "xi_W"=>r.result.params.ξ_W,
        "hard_valid"=>v.valid, "classification"=>nb06_classification(m),
        "mechanism_pass"=>nb06_mechanism_pass(m), "scale_pass"=>nb06_scale_pass(m),
        "score"=>r.score, "delta_nfa"=>m.delta_nfa,
        "net_va"=>m.net_va, "asset_va"=>m.asset_va,
        "liability_va"=>m.liability_va, "ca"=>m.ca,
        "q_us_growth"=>m.q_us_growth, "q_w_growth"=>m.q_w_growth,
        "relative_price_growth"=>m.relative_price_growth,
        "endpoint_liability_exposure"=>m.endpoint_liability_exposure,
        "mean_liability_exposure"=>m.mean_liability_exposure,
        "endpoint_asset_exposure"=>m.endpoint_asset_exposure,
        "liability_asset_ratio"=>m.liability_asset_ratio,
        "liability_share_gross_va"=>m.liability_share_gross_va,
        "va_to_ca"=>m.va_to_ca,
        "theta_min"=>v.theta_min, "theta_max"=>v.theta_max,
        "phi_slack"=>v.phi_slack,
        "max_u_residual"=>r.result.max_u_residual,
        "max_bgp_residual"=>r.result.max_bgp_residual,
        "accounting_residual"=>r.accounting.residual_max,
        "nfa_identity_error"=>r.accounting.nfa_identity_error,
    ))
end

candidate_columns = [
    "sequence", "label", "stage", "note", "pi", "omega_bar", "omega_bar_star",
    "eta", "nu_b", "xi_W", "hard_valid", "classification", "mechanism_pass",
    "scale_pass", "score", "delta_nfa", "net_va", "asset_va", "liability_va",
    "ca", "q_us_growth", "q_w_growth", "relative_price_growth",
    "endpoint_liability_exposure", "mean_liability_exposure",
    "endpoint_asset_exposure", "liability_asset_ratio",
    "liability_share_gross_va", "va_to_ca", "theta_min", "theta_max", "phi_slack",
    "max_u_residual", "max_bgp_residual", "accounting_residual", "nfa_identity_error",
]
nb06_write_rows(joinpath(NB06_OUTDIR, "candidate_summary.csv"),
                candidate_rows, candidate_columns)
nb06_write_rows(joinpath(NB06_OUTDIR, "candidate_failures.csv"),
                search_failures, ["sequence", "label", "stage", "error"])

target_rows = Dict{String,Any}[
    Dict("metric"=>"delta_nfa", "empirical"=>NB06_TARGET.delta_nfa,
         "model"=>best.metrics.delta_nfa),
    Dict("metric"=>"net_equity_va", "empirical"=>NB06_TARGET.net_equity_va,
         "model"=>best.metrics.net_va),
    Dict("metric"=>"asset_va", "empirical"=>NB06_TARGET.asset_va,
         "model"=>best.metrics.asset_va),
    Dict("metric"=>"liability_va", "empirical"=>NB06_TARGET.liability_va,
         "model"=>best.metrics.liability_va),
    Dict("metric"=>"current_account", "empirical"=>NB06_TARGET.ca,
         "model"=>best.metrics.ca),
    Dict("metric"=>"q_us_growth", "empirical"=>NB06_TARGET.q_us_growth,
         "model"=>best.metrics.q_us_growth),
    Dict("metric"=>"q_w_growth", "empirical"=>NB06_TARGET.q_w_growth,
         "model"=>best.metrics.q_w_growth),
    Dict("metric"=>"relative_price_growth", "empirical"=>NB06_TARGET.relative_price_growth,
         "model"=>best.metrics.relative_price_growth),
    Dict("metric"=>"liability_exposure", "empirical"=>NB06_TARGET.liability_exposure,
         "model"=>best.metrics.endpoint_liability_exposure),
    Dict("metric"=>"asset_exposure", "empirical"=>NB06_TARGET.asset_exposure,
         "model"=>best.metrics.endpoint_asset_exposure),
    Dict("metric"=>"liability_share_gross_va",
         "empirical"=>NB06_TARGET.liability_share_gross_va,
         "model"=>best.metrics.liability_share_gross_va),
]
for row in target_rows
    row["model_over_empirical"] = row["model"] / row["empirical"]
    row["magnitude_ratio"] = abs(row["model"]) / max(abs(row["empirical"]),1e-12)
end
nb06_write_rows(joinpath(NB06_OUTDIR, "model_empirical_comparison.csv"),
                target_rows,
                ["metric", "empirical", "model", "model_over_empirical", "magnitude_ratio"])

a = best.accounting
path_rows = Dict{String,Any}[]
for t in 1:a.T
    push!(path_rows, Dict{String,Any}(
        "t"=>t, "Y_US"=>a.y_us[t], "q_US"=>a.q_us[t], "q_W"=>a.q_w[t],
        "q_US_index"=>a.q_us[t]/a.q_us[1], "q_W_index"=>a.q_w[t]/a.q_w[1],
        "asset_position"=>a.asset[t], "liability_position"=>a.liability[t],
        "asset_exposure_Y"=>a.asset[t]/a.y_us[t],
        "liability_exposure_Y"=>a.liability[t]/a.y_us[t],
        "NFA"=>a.nfa[t], "NFA_change_current_Y"=>(a.nfa[t]-a.nfa[1])/a.y_us[t],
        "cum_VA_asset_current_Y"=>a.cum_va_asset[t]/a.y_us[t],
        "cum_VA_liability_current_Y"=>a.cum_va_liability[t]/a.y_us[t],
        "cum_VA_current_Y"=>a.cum_va[t]/a.y_us[t],
        "cum_CA_current_Y"=>a.cum_ca[t]/a.y_us[t],
        "cum_residual_current_Y"=>a.cum_residual[t]/a.y_us[t],
        "theta_US_star"=>best.result.u_path[t].θ_US_star,
        "phi_US"=>best.result.u_path[t].φ_US,
        "phi_W"=>best.result.u_path[t].φ_W,
    ))
end
path_columns = [
    "t", "Y_US", "q_US", "q_W", "q_US_index", "q_W_index",
    "asset_position", "liability_position", "asset_exposure_Y", "liability_exposure_Y",
    "NFA", "NFA_change_current_Y", "cum_VA_asset_current_Y",
    "cum_VA_liability_current_Y", "cum_VA_current_Y", "cum_CA_current_Y",
    "cum_residual_current_Y", "theta_US_star", "phi_US", "phi_W",
]
nb06_write_rows(joinpath(NB06_OUTDIR, "best_candidate_path.csv"), path_rows, path_columns)

absorbing_rows = Dict{String,Any}[
    Dict("metric"=>"policy_invariance_error", "value"=>best.absorbing.policy_error),
    Dict("metric"=>"aggregate_invariance_error", "value"=>best.absorbing.aggregate_error),
    Dict("metric"=>"per_variety_scaling_error", "value"=>best.absorbing.scaling_error),
    Dict("metric"=>"automatic_growth_identity_error", "value"=>best.absorbing.growth_identity_error),
    Dict("metric"=>"max_extended_bgp_residual", "value"=>best.absorbing.max_bgp_residual),
]
nb06_write_rows(joinpath(NB06_OUTDIR, "best_absorbing_normalization.csv"),
                absorbing_rows, ["metric", "value"])

# %%
labels = ["Delta NFA", "net equity VA", "asset VA", "liability VA", "CA",
          "q_US growth", "q_W growth", "relative q", "liability/GVA", "asset/GVA",
          "liability share VA"]
ratios = Float64[row["model_over_empirical"] for row in target_rows]
p_compare = bar(
    labels, ratios, orientation=:vertical, legend=false,
    ylabel="model / empirical target", title="Selected model relative to empirical targets",
    xrotation=35, color=:steelblue, size=(1050,540),
)
hline!(p_compare, [1.0], color=:black, ls=:dash, lw=1.5, label=false)
hline!(p_compare, [0.0], color=:gray45, lw=1, label=false)
savefig(p_compare, joinpath(NB06_OUTDIR, "model_empirical_target_ratios.png"))
display(p_compare)

# %%
t = 1:a.T
nfa_path = (a.nfa .- a.nfa[1]) ./ a.y_us
va_path = a.cum_va ./ a.y_us
ca_path = a.cum_ca ./ a.y_us
p_account = plot(t, nfa_path, label="Delta NFA / current Y", color=:navy,
                 xlabel="model episode index", ylabel="ratio to current model Y",
                 title="Selected finite-prefix NFA accounting")
plot!(p_account, t, va_path, label="cumulative equity VA / current Y", color=:firebrick)
plot!(p_account, t, ca_path, label="cumulative CA / current Y", color=:darkgreen)
hline!(p_account, [0.0], color=:gray45, ls=:dot, label=false)
savefig(p_account, joinpath(NB06_OUTDIR, "best_nfa_va_ca_paths.png"))
display(p_account)

p_va = plot(t, a.cum_va_asset ./ a.y_us, label="asset VA: US-held RoW equity",
            color=:royalblue, xlabel="model episode index",
            ylabel="cumulative contribution / current model Y",
            title="Selected equity valuation decomposition")
plot!(p_va, t, a.cum_va_liability ./ a.y_us,
      label="liability VA: RoW-held US equity", color=:firebrick)
plot!(p_va, t, a.cum_va ./ a.y_us, label="net equity VA", color=:black, lw=2.5)
hline!(p_va, [0.0], color=:gray45, ls=:dot, label=false)
savefig(p_va, joinpath(NB06_OUTDIR, "best_equity_va_decomposition.png"))
display(p_va)

# %%
model_q_us = a.q_us ./ a.q_us[1]
model_q_w = a.q_w ./ a.q_w[1]
emp_q_us_path = collect(range(1.0, NB06_TARGET.q_us_growth; length=a.T))
emp_q_w_path = collect(range(1.0, NB06_TARGET.q_w_growth; length=a.T))
p_prices = plot(t, model_q_us, label="model US q", color=:firebrick,
                xlabel="model episode index", ylabel="index, initial = 1",
                title="Equity-price performance")
plot!(p_prices, t, model_q_w, label="model RoW q", color=:royalblue)
plot!(p_prices, t, emp_q_us_path, label="empirical US endpoint guide",
      color=:firebrick, ls=:dash, alpha=.6)
plot!(p_prices, t, emp_q_w_path, label="empirical RoW endpoint guide",
      color=:royalblue, ls=:dash, alpha=.6)

model_asset_exp = a.asset ./ a.y_us
model_liability_exp = a.liability ./ a.y_us
emp_asset_path = collect(range(NB06_TARGET.initial_asset_exposure,
                               NB06_TARGET.asset_exposure; length=a.T))
emp_liability_path = collect(range(NB06_TARGET.initial_liability_exposure,
                                   NB06_TARGET.liability_exposure; length=a.T))
p_exposure = plot(t, model_liability_exp, label="model RoW-held US equity",
                  color=:firebrick, xlabel="model episode index",
                  ylabel="gross position / output or GVA",
                  title="Gross equity positions")
plot!(p_exposure, t, model_asset_exp, label="model US-held RoW equity", color=:royalblue)
plot!(p_exposure, t, emp_liability_path, label="empirical liability guide",
      color=:firebrick, ls=:dash, alpha=.6)
plot!(p_exposure, t, emp_asset_path, label="empirical asset guide",
      color=:royalblue, ls=:dash, alpha=.6)

p_price_exposure = plot(p_prices, p_exposure, layout=(1,2), size=(1200,480))
savefig(p_price_exposure, joinpath(NB06_OUTDIR, "best_prices_and_gross_positions.png"))
display(p_price_exposure)

# %%
frontier_records = [r for r in search_records if r.validity.valid]
x_frontier = [r.metrics.q_us_growth for r in frontier_records]
y_frontier = [r.metrics.delta_nfa for r in frontier_records]
pass_frontier = [nb06_mechanism_pass(r.metrics) for r in frontier_records]
p_frontier = scatter(
    x_frontier[.!pass_frontier], y_frontier[.!pass_frontier],
    label="hard-valid near miss", color=:gray55, marker=:circle,
    xlabel="model US equity-price growth", ylabel="Delta NFA / endpoint model Y",
    title="Directed-search frontier",
)
if any(pass_frontier)
    scatter!(p_frontier, x_frontier[pass_frontier], y_frontier[pass_frontier],
             label="qualitative mechanism pass", color=:firebrick, marker=:diamond)
end
scatter!(p_frontier, [best.metrics.q_us_growth], [best.metrics.delta_nfa],
         label="selected continuation solution", color=:navy, marker=:star5, markersize=9)
hline!(p_frontier, [0.0], color=:black, ls=:dash, lw=1, label=false)
vline!(p_frontier, [1.0], color=:black, ls=:dot, lw=1, label=false)
savefig(p_frontier, joinpath(NB06_OUTDIR, "directed_search_frontier.png"))
display(p_frontier)

# %% [markdown]
# ## 5. Horizon audit of the selected finite-prefix candidate
#
# The empirical-prefix fit is not automatically a valid long-horizon
# equilibrium. The default run records only the certified \(T=16\) prefix.
# Setting `NB06_RUN_LONG_HORIZON_AUDIT=true` continues the same primitives to
# \(T\in\{20,24,30\}\); residual safety and portfolio interiority are then
# reported separately. A longer solve that violates \(\theta_{US}^\ast<0.9\)
# is retained as a diagnostic but is not called a valid calibration.

# %%
horizon_grid = NB06_RUN_LONG_HORIZON_AUDIT ? (NB06_SEARCH_T, 20, 24, 30) : (NB06_SEARCH_T,)
function nb06_run_horizon_audit(best, horizon_grid)
    rows = Dict{String,Any}[]
    horizon_result = best.result
    for T in horizon_grid
        if T == NB06_SEARCH_T
            record = best
            status = "ok"
            errtext = ""
        else
            try
                record = nb06_evaluate(best.spec; warm=horizon_result, T=T)
                horizon_result = record.result
                status = "ok"
                errtext = ""
            catch err
                record = nothing
                status = "error"
                errtext = sprint(showerror, err)
            end
        end
        if record === nothing
            push!(rows, Dict(
                "T"=>T, "status"=>status, "hard_valid"=>false,
                "residual_safe"=>false, "theta_interior"=>false,
                "error"=>errtext,
            ))
        else
            push!(rows, Dict(
                "T"=>T, "status"=>status, "hard_valid"=>record.validity.valid,
                "residual_safe"=>record.validity.model_residuals,
                "theta_interior"=>record.validity.theta_interior,
                "theta_min"=>record.validity.theta_min,
                "theta_max"=>record.validity.theta_max,
                "phi_slack"=>record.validity.phi_slack,
                "max_u_residual"=>record.result.max_u_residual,
                "max_bgp_residual"=>record.result.max_bgp_residual,
                "delta_nfa"=>record.metrics.delta_nfa,
                "net_va"=>record.metrics.net_va,
                "liability_va"=>record.metrics.liability_va,
                "q_us_growth"=>record.metrics.q_us_growth,
                "q_w_growth"=>record.metrics.q_w_growth,
                "error"=>errtext,
            ))
        end
    end
    return rows
end

horizon_rows = nb06_run_horizon_audit(best, horizon_grid)

horizon_columns = [
    "T", "status", "hard_valid", "residual_safe", "theta_interior",
    "theta_min", "theta_max", "phi_slack", "max_u_residual", "max_bgp_residual",
    "delta_nfa", "net_va", "liability_va", "q_us_growth", "q_w_growth", "error",
]
nb06_write_rows(joinpath(NB06_OUTDIR, "selected_horizon_audit.csv"),
                horizon_rows, horizon_columns)

println("\nSelected-candidate horizon audit")
for row in horizon_rows
    @printf("  T=%2d status=%-5s residual_safe=%-5s theta_max=%s hard_valid=%s\n",
            row["T"], row["status"], get(row,"residual_safe",false),
            haskey(row,"theta_max") ? @sprintf("%.3f",row["theta_max"]) : "n/a",
            get(row,"hard_valid",false))
end

ok_horizon = [r for r in horizon_rows if haskey(r,"theta_max")]
horizon_plot_path = joinpath(NB06_OUTDIR, "selected_horizon_interiority.png")
if length(ok_horizon) > 1
    p_horizon = plot(
        [r["T"] for r in ok_horizon], [r["theta_max"] for r in ok_horizon],
        marker=:circle, label="max theta_US_star", color=:firebrick,
        xlabel="solved horizon T", ylabel="maximum portfolio share",
        title="Selected-calibration interiority frontier",
    )
    hline!(p_horizon, [0.9], color=:black, ls=:dash, label="hard gate 0.9")
    savefig(p_horizon, horizon_plot_path)
    display(p_horizon)
else
    isfile(horizon_plot_path) && rm(horizon_plot_path)
    println("Long-horizon audit not run; set NB06_RUN_LONG_HORIZON_AUDIT=true to add the frontier plot.")
end

# %% [markdown]
# ## 6. Economic reading
#
# The bounded search identifies a **finite-prefix qualitative mechanism match**,
# not a full quantitative calibration. High persistence and a high U.S.
# home-equity target make \(q_{US}\) appreciate. A larger issuance cost shifts
# the bond/equity current-account margin enough for NFA to deteriorate, while
# the foreign-held-U.S.-equity liability valuation becomes slightly larger in
# absolute value than the RoW-asset valuation term.
#
# Three failures remain visible in the exported comparison:
#
# 1. NFA and valuation magnitudes are far below the empirical ratios;
# 2. the empirical gross U.S. equity liability is much larger than the model
#    liability relative to output; and
# 3. the selected path eventually violates the foreign portfolio-interiority
#    gate at longer horizons.
#
# Increasing \(\bar\omega^\ast\) helps stabilize the RoW price path but dampens
# U.S. appreciation and reverses the NFA sign before it closes the gross-position
# gap. Thus the next model-development question is not a smaller local parameter
# tweak; it is whether the financial block needs an additional gross-position
# scale or portfolio-demand margin that can raise RoW-held U.S. equity without
# undoing the price and NFA mechanism.

# %%
selected_manifest = Dict{String,Any}[
    Dict("field"=>"selected_label", "value"=>best.spec.label),
    Dict("field"=>"classification", "value"=>nb06_classification(best.metrics)),
    Dict("field"=>"mechanism_pass", "value"=>nb06_mechanism_pass(best.metrics)),
    Dict("field"=>"scale_pass", "value"=>nb06_scale_pass(best.metrics)),
    Dict("field"=>"pi", "value"=>best.spec.pi),
    Dict("field"=>"omega_bar", "value"=>best.spec.omega),
    Dict("field"=>"omega_bar_star", "value"=>best.spec.omega_star),
    Dict("field"=>"eta", "value"=>best.spec.eta),
    Dict("field"=>"nu_b", "value"=>best.result.params.ν_b),
    Dict("field"=>"xi_W", "value"=>best.result.params.ξ_W),
    Dict("field"=>"search_T", "value"=>NB06_SEARCH_T),
    Dict("field"=>"n_buffer", "value"=>NB06_N_BUFFER),
    Dict("field"=>"branch_iters", "value"=>NB06_BRANCH_ITERS),
    Dict("field"=>"direct_cold_check", "value"=>cold_check_status),
    Dict("field"=>"long_horizon_audit_run", "value"=>NB06_RUN_LONG_HORIZON_AUDIT),
    Dict("field"=>"primary_empirical_window", "value"=>NB06_PRIMARY_WINDOW),
    Dict("field"=>"price_index_base", "value"=>NB06_PRICE_BASE),
    Dict("field"=>"empirical_endpoint", "value"=>NB06_PRIMARY_ENDPOINT),
    Dict("field"=>"period_summary_source", "value"=>NB06_PERIOD_CSV),
    Dict("field"=>"quarterly_source", "value"=>NB06_LATEST_CSV),
]
nb06_write_rows(joinpath(NB06_OUTDIR, "run_manifest.csv"),
                selected_manifest, ["field", "value"])

println("\nFinal assessment")
println("  Selected parameters: pi=$(best.spec.pi), omega_bar=$(best.spec.omega), " *
        "omega_bar_star=$(best.spec.omega_star), eta=$(best.spec.eta)")
println("  Classification:      ", nb06_classification(best.metrics))
println("  Mechanism pass:       ", nb06_mechanism_pass(best.metrics))
println("  Quantitative scale:   ", nb06_scale_pass(best.metrics))
println("  Interpretation: finite-prefix mechanism match; gross-position scale remains unresolved.")
println("  Outputs:             ", NB06_OUTDIR)

@assert best.validity.valid
@assert best.result.params.ν_b == 0.0 && best.result.params.ξ_W == 0.0
@assert nb06_mechanism_pass(best.metrics)
@assert best.accounting.residual_max <= NB06_RESID_TOL
@assert best.accounting.nfa_identity_error <= 1e-7
println("NO_NOTEBOOK_ERRORS")
