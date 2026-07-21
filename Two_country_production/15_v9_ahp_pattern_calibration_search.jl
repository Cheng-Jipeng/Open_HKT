using Pkg

const NB15_PROJECT_DIR = dirname(@__DIR__)
Pkg.activate(NB15_PROJECT_DIR)
include(joinpath(@__DIR__, "TwoCountryProductionOLG.jl"))

using DelimitedFiles
if !isdefined(Main, :IJulia)
    ENV["GKSwstype"] = get(ENV, "GKSwstype", "100")
end
using Plots, Printf, Statistics
using Plots.PlotMeasures

gr()

# The empirical comparison is deliberately fixed at t=15.  A longer model
# horizon is retained only to expose (and not score) the late-path behavior.
const NB15_SMOKE_MODE = get(ENV, "NB15_SMOKE", "0") == "1"
const AHP_TARGET_END = NB15_SMOKE_MODE ? 10 : 15
const SEARCH_T = NB15_SMOKE_MODE ? 10 : 15
const FINAL_T = NB15_SMOKE_MODE ? 10 : 30
const SEARCH_BUFFER = NB15_SMOKE_MODE ? 4 : 6
const FINAL_BUFFER = NB15_SMOKE_MODE ? 4 : 10
const FINALIST_COUNT = NB15_SMOKE_MODE ? 1 : 2

const DEFAULT_OUTDIR = joinpath(
    @__DIR__, "outputs_v43",
    NB15_SMOKE_MODE ? "ahp_pattern_first_window_common_growth_search_smoke" :
                      "ahp_pattern_first_window_common_growth_search",
)
const OUTDIR = get(ENV, "NB15_OUTDIR", DEFAULT_OUTDIR)
const TIME_INVARIANT_DIR = joinpath(
    @__DIR__, "outputs_v43", "ahp_pattern_time_invariant_search",
)
mkpath(OUTDIR)

const RESID_TOL = 1e-5
const PSI_INTERIOR_TOL = 0.02
const EQUITY_INTERIOR_TOL = 0.01
const THETA_INTERIOR_TOL = 0.01
const ACCOUNTING_SCALED_TOL = 1e-7
const COMMON_GROWTH_TOL = 1e-7
const NU_ORDER_BUFFER = 1e-3
const NU_ORDER_ROBUST_BUFFER = 0.02

default(
    size=(950, 520), framestyle=:box, grid=:y, legend=:best,
    fontfamily="Computer Modern", linewidth=2,
    titlefontsize=11, guidefontsize=10, tickfontsize=9, legendfontsize=8,
    left_margin=9mm, right_margin=7mm, top_margin=7mm, bottom_margin=8mm,
)

println("Julia version:              ", VERSION)
println("Project directory:          ", NB15_PROJECT_DIR)
println("Time-invariant benchmark:   ", TIME_INVARIANT_DIR)
println("Output directory:           ", OUTDIR)
println("Execution mode:             ", NB15_SMOKE_MODE ? "SMOKE" : "FULL")
println("AHP evidence endpoint:      t=", AHP_TARGET_END)
println("Search/reporting horizons:  ", SEARCH_T, " / ", FINAL_T)

# -----------------------------------------------------------------------------
# Benchmark recovery and CSV helpers
# -----------------------------------------------------------------------------

function read_numeric_csv(path::AbstractString)
    isfile(path) || error("Required CSV not found: $(path)")
    data, header = readdlm(path, ',', Float64, '\n'; header=true)
    matrix = ndims(data) == 1 ? reshape(data, 1, :) : data
    names = String.(vec(header))
    size(matrix, 2) == length(names) || error("CSV header mismatch: $(path)")
    return Dict(names[j] => Float64.(matrix[:, j]) for j in eachindex(names))
end

function require_columns(table, names, label)
    missing_names = filter(name -> !haskey(table, name), names)
    isempty(missing_names) ||
        error("Missing columns in $(label): $(join(missing_names, ", "))")
end

function csv_cell(x)
    s = x === missing ? "" : string(x)
    if occursin(',', s) || occursin('"', s) || occursin('\n', s)
        return "\"" * replace(s, "\"" => "\"\"") * "\""
    end
    return s
end

function write_rows_csv(path, rows, columns)
    open(path, "w") do io
        println(io, join(columns, ','))
        for row in rows
            println(io, join((csv_cell(get(row, c, missing)) for c in columns), ','))
        end
    end
    return path
end

benchmark_csv = joinpath(TIME_INVARIANT_DIR, "best_ahp_decomposition.csv")
benchmark = read_numeric_csv(benchmark_csv)
require_columns(
    benchmark,
    ["t", "Y_US", "ahp_rebased_NFA_change_current_Y",
     "ahp_cum_CA_current_Y", "ahp_cum_VA_current_Y",
     "cum_VA_row_equity_asset", "cum_VA_us_equity_liability"],
    "time-invariant AHP benchmark",
)

benchmark_t = Int.(round.(benchmark["t"]))
benchmark_index = findfirst(==(AHP_TARGET_END), benchmark_t)
benchmark_index === nothing &&
    error("The time-invariant benchmark has no t=$(AHP_TARGET_END) row.")
benchmark_Y = benchmark["Y_US"][benchmark_index]

const AHP_TARGET = (
    rebased_nfa=benchmark["ahp_rebased_NFA_change_current_Y"][benchmark_index],
    net_va=benchmark["ahp_cum_VA_current_Y"][benchmark_index],
    ca=benchmark["ahp_cum_CA_current_Y"][benchmark_index],
    asset_va=benchmark["cum_VA_row_equity_asset"][benchmark_index] / benchmark_Y,
    liability_va=benchmark["cum_VA_us_equity_liability"][benchmark_index] / benchmark_Y,
)

@printf("\nTime-invariant target at t=%d\n", AHP_TARGET_END)
@printf("  rebased NFA change/current Y: %+.6f\n", AHP_TARGET.rebased_nfa)
@printf("  cumulative net VA/current Y: %+.6f\n", AHP_TARGET.net_va)
@printf("  cumulative CA/current Y:     %+.6f\n", AHP_TARGET.ca)
@printf("  asset/liability VA:          %+.6f / %+.6f\n\n",
        AHP_TARGET.asset_va, AHP_TARGET.liability_va)

# -----------------------------------------------------------------------------
# Exact AHP accounting
# -----------------------------------------------------------------------------

path_vector(result, field::Symbol) = Float64[getfield(s, field) for s in result.u_path]

function ahp_accounting(result::ProductionSimulationResult)
    T = length(result.u_path)
    T >= 3 || error("AHP accounting needs at least three periods.")

    q_US = path_vector(result, :q_US)
    q_W = path_vector(result, :q_W)
    Y_US = path_vector(result, :Y_US)
    e_US = path_vector(result, :e_US)
    n_W = Float64[(1 - s.ω) * (1 - s.θ) * s.A / s.q_W for s in result.u_path]
    n_US_star = Float64[
        s.ω_star * (1 - s.θ_US_star) * s.A_star / s.q_US for s in result.u_path
    ]
    bond = Float64[s.θ * s.A for s in result.u_path]

    asset_position = q_W .* n_W
    liability_position = q_US .* n_US_star
    NFA = asset_position .+ bond .- liability_position

    VA_asset = zeros(T)
    VA_liability = zeros(T)
    CA_asset = zeros(T)
    CA_liability = zeros(T)
    CA_bond = zeros(T)
    for t in 2:T
        VA_asset[t] = n_W[t - 1] * (q_W[t] - q_W[t - 1])
        VA_liability[t] = -n_US_star[t - 1] * (q_US[t] - q_US[t - 1])
        CA_asset[t] = q_W[t] * (n_W[t] - n_W[t - 1])
        CA_liability[t] = -q_US[t] * (n_US_star[t] - n_US_star[t - 1])
        CA_bond[t] = bond[t] - bond[t - 1]
    end

    VA = VA_asset .+ VA_liability
    CA = CA_asset .+ CA_liability .+ CA_bond
    ΔNFA = zeros(T)
    RES = zeros(T)
    for t in 2:T
        ΔNFA[t] = NFA[t] - NFA[t - 1]
        RES[t] = ΔNFA[t] - CA[t] - VA[t]
    end

    cum_VA_asset = cumsum(VA_asset)
    cum_VA_liability = cumsum(VA_liability)
    cum_CA_asset = cumsum(CA_asset)
    cum_CA_liability = cumsum(CA_liability)
    cum_CA_bond = cumsum(CA_bond)
    cum_VA = cumsum(VA)
    cum_CA = cumsum(CA)
    cum_RES = cumsum(RES)
    module_NFA = nfa_decomposition(result).NFA

    return (
        T=T, q_US=q_US, q_W=q_W, Y_US=Y_US, e_US=e_US,
        n_W=n_W, n_US_star=n_US_star, bond=bond,
        asset_position=asset_position, liability_position=liability_position,
        NFA=NFA, ΔNFA=ΔNFA,
        VA_asset=VA_asset, VA_liability=VA_liability, VA=VA,
        CA_asset=CA_asset, CA_liability=CA_liability, CA_bond=CA_bond, CA=CA,
        RES=RES,
        cum_VA_asset=cum_VA_asset, cum_VA_liability=cum_VA_liability,
        cum_CA_asset=cum_CA_asset, cum_CA_liability=cum_CA_liability,
        cum_CA_bond=cum_CA_bond, cum_VA=cum_VA, cum_CA=cum_CA,
        cum_RES=cum_RES,
        residual_max=maximum(abs.(RES[2:end])),
        nfa_identity_error=maximum(abs.(NFA .- module_NFA)),
    )
end

function candidate_metrics(a; target_end=AHP_TARGET_END)
    e = min(target_end, a.T)
    e >= 2 || error("The evidence window must contain at least two periods.")
    Y_e = a.Y_US[e]
    evidence = 2:e
    rebased_path = (a.NFA .- a.NFA[1]) ./ a.Y_US

    target_rebased_nfa = (a.NFA[e] - a.NFA[1]) / Y_e
    target_asset_va = a.cum_VA_asset[e] / Y_e
    target_liability_va = a.cum_VA_liability[e] / Y_e
    target_net_va = a.cum_VA[e] / Y_e
    target_ca_asset = a.cum_CA_asset[e] / Y_e
    target_ca_liability = a.cum_CA_liability[e] / Y_e
    target_ca_bond = a.cum_CA_bond[e] / Y_e
    target_ca = a.cum_CA[e] / Y_e
    target_residual = a.cum_RES[e] / Y_e
    target_decomposition_error = abs(
        target_rebased_nfa - target_net_va - target_ca - target_residual
    )
    target_foreign_exposure = mean(a.liability_position[evidence] ./ a.Y_US[evidence])
    target_asset_exposure = mean(a.asset_position[evidence] ./ a.Y_US[evidence])
    va_driver_share = abs(target_net_va) /
        max(abs(target_net_va) + abs(target_ca), 1e-12)
    liability_share_of_gross_va = abs(target_liability_va) /
        max(abs(target_liability_va) + abs(target_asset_va), 1e-12)

    # These are transparent tail diagnostics only.  Neither enters the score.
    tail_observed = a.T > e
    post_target_rebased_change = tail_observed ?
        rebased_path[end] - rebased_path[e] : missing
    post_target_nfa_level_move_over_Ye = tail_observed ?
        (a.NFA[end] - a.NFA[e]) / Y_e : missing
    tail_rebound = tail_observed ?
        maximum(rebased_path[e:end]) - rebased_path[e] : missing

    return (
        target_end=e,
        target_rebased_nfa=target_rebased_nfa,
        target_ratio_change=a.NFA[e] / Y_e - a.NFA[1] / a.Y_US[1],
        target_asset_va=target_asset_va,
        target_liability_va=target_liability_va,
        target_net_va=target_net_va,
        target_ca_asset=target_ca_asset,
        target_ca_liability=target_ca_liability,
        target_ca_bond=target_ca_bond,
        target_ca=target_ca,
        target_residual=target_residual,
        target_decomposition_error=target_decomposition_error,
        target_foreign_exposure=target_foreign_exposure,
        target_asset_exposure=target_asset_exposure,
        va_driver_share=va_driver_share,
        liability_share_of_gross_va=liability_share_of_gross_va,
        target_Y_growth=Y_e / a.Y_US[1],
        target_q_US_growth=a.q_US[e] / a.q_US[1],
        target_q_W_growth=a.q_W[e] / a.q_W[1],
        tail_observed=tail_observed,
        post_target_rebased_change=post_target_rebased_change,
        post_target_nfa_level_move_over_Ye=post_target_nfa_level_move_over_Ye,
        tail_rebound=tail_rebound,
        endpoint_rebased_nfa=rebased_path[end],
        endpoint_nfa_over_Y=a.NFA[end] / a.Y_US[end],
    )
end

# -----------------------------------------------------------------------------
# Hard model and pathwise common-growth gates
# -----------------------------------------------------------------------------

function hard_validity(result, a)
    theta_US_star = path_vector(result, :θ_US_star)
    finite_accounting = all(isfinite, a.NFA) && all(isfinite, a.CA) &&
                        all(isfinite, a.VA) && all(isfinite, a.Y_US)
    model_residuals = result.branch_converged &&
                      isfinite(result.max_u_residual) &&
                      isfinite(result.max_bgp_residual) &&
                      result.max_u_residual <= RESID_TOL &&
                      result.max_bgp_residual <= RESID_TOL
    psi_interior = result.diagnostics.psi_ok &&
                   isfinite(result.diagnostics.psi_min) &&
                   result.diagnostics.psi_min >= PSI_INTERIOR_TOL
    equity_interior = result.diagnostics.equity_weights_ok &&
                      isfinite(result.diagnostics.equity_weight_min) &&
                      result.diagnostics.equity_weight_min >= EQUITY_INTERIOR_TOL
    theta_interior = all(
        x -> isfinite(x) && THETA_INTERIOR_TOL <= x < 0.9, theta_US_star,
    )
    positive_foreign_claims = all(x -> isfinite(x) && x > 0.0, a.n_US_star) &&
                              all(x -> isfinite(x) && x > 0.0, a.liability_position)
    accounting_scale = max(
        1.0, maximum(abs.(a.NFA)), maximum(abs.(a.CA)), maximum(abs.(a.VA)),
    )
    accounting_exact = isfinite(a.residual_max) && a.residual_max <= RESID_TOL &&
                       a.residual_max / accounting_scale <= ACCOUNTING_SCALED_TOL &&
                       isfinite(a.nfa_identity_error) &&
                       a.nfa_identity_error / accounting_scale <= ACCOUNTING_SCALED_TOL
    return_fields = (:R_A_u, :R_A_b, :R_A_star_u, :R_A_star_b, :R_f, :R_f_W)
    positive_returns = all(
        field -> all(x -> isfinite(x) && x > 0.0, path_vector(result, field)),
        return_fields,
    )
    positive_output = all(x -> isfinite(x) && x > 0.0, a.Y_US)

    valid = model_residuals && psi_interior && equity_interior &&
            theta_interior && positive_foreign_claims && positive_returns &&
            accounting_exact && positive_output && finite_accounting
    return (
        valid=valid, model_residuals=model_residuals,
        psi_interior=psi_interior, equity_interior=equity_interior,
        theta_interior=theta_interior,
        positive_foreign_claims=positive_foreign_claims,
        positive_returns=positive_returns, accounting_exact=accounting_exact,
        positive_output=positive_output, finite_accounting=finite_accounting,
    )
end

function common_growth_diagnostics(result)
    p = result.params
    rows = Dict{String,Any}[]
    for (j, b) in enumerate(result.bgp_seq_extended)
        G_b = b.G_N_US^b.ν_b_eff
        G_W = b.G_N_W^p.ξ_W
        push!(rows, Dict{String,Any}(
            "switch_index"=>j - 1,
            "G_N_US"=>b.G_N_US, "G_N_W"=>b.G_N_W,
            "nu_b_eff"=>b.ν_b_eff,
            "bgp_converged"=>b.converged,
            "bgp_residual_norm"=>b.residual_norm,
            "G_b"=>G_b, "G_W"=>G_W,
            "level_gap"=>G_b - G_W,
            "log_gap"=>b.ν_b_eff * log(b.G_N_US) - p.ξ_W * log(b.G_N_W),
        ))
    end
    return rows
end

function common_growth_summary(result)
    rows = common_growth_diagnostics(result)
    ν_eff = Float64[r["nu_b_eff"] for r in rows]
    return (
        max_level_gap=maximum(abs(Float64(r["level_gap"])) for r in rows),
        max_log_gap=maximum(abs(Float64(r["log_gap"])) for r in rows),
        nu_b_eff_min=minimum(ν_eff), nu_b_eff_max=maximum(ν_eff),
        nu_b_eff_std=std(ν_eff),
        all_extended_bgp_converged=all(Bool(r["bgp_converged"]) for r in rows),
        max_extended_bgp_residual=maximum(
            Float64(r["bgp_residual_norm"]) for r in rows
        ),
    )
end

function pathwise_common_validity(result, accounting)
    base = hard_validity(result, accounting)
    common = common_growth_summary(result)
    exact_common = common.max_level_gap <= COMMON_GROWTH_TOL &&
                   common.max_log_gap <= COMMON_GROWTH_TOL
    extended_bgp_valid = common.all_extended_bgp_converged &&
                         common.max_extended_bgp_residual <= RESID_TOL
    exponent_ordering = isfinite(common.nu_b_eff_min) &&
                        isfinite(common.nu_b_eff_max) &&
                        common.nu_b_eff_min > 0.0 &&
                        common.nu_b_eff_max <= result.params.ν_u - NU_ORDER_BUFFER
    robust_ordering = common.nu_b_eff_max <=
                      result.params.ν_u - NU_ORDER_ROBUST_BUFFER
    return merge(
        base,
        (exact_common=exact_common, extended_bgp_valid=extended_bgp_valid,
         exponent_ordering=exponent_ordering, robust_ordering=robust_ordering,
         common=common,
         valid=base.valid && exact_common && extended_bgp_valid && exponent_ordering),
    )
end

# -----------------------------------------------------------------------------
# Search centered on the preferred time-invariant financial block
# -----------------------------------------------------------------------------

Base.@kwdef struct CandidateSpec
    label::String
    family::String
    note::String
    a_W::Float64 = 0.10
    ξ_W::Float64 = 1.00
    β::Float64 = 0.45
    κ::Float64 = 1.00
    ωbar::Float64 = 0.50
    ωbar_star::Float64 = 0.25
    χ::Float64 = 0.0002
    η::Float64 = 0.010
    π::Float64 = 0.80
    ϑ_US::Float64 = 0.80
    ν_u::Float64 = 1.40
    ξ_u::Float64 = 1.90
    us_u_level::Float64 = 1.00
    ν_b_seed::Float64 = 0.10
end

function candidate_params(spec::CandidateSpec; T::Int, n_buffer::Int)
    return ProductionParams(
        T_max=T, n_buffer=n_buffer, common_world_growth=true,
        β=spec.β, γ=0.25, π_persist=spec.π,
        a_US=0.20, ϑ_US=spec.ϑ_US,
        a_W=spec.a_W, H_W=3.0, L_W=3.0,
        A_X_US_u=10.0 * spec.us_u_level,
        A_L_US_u=1.0 * spec.us_u_level,
        ν_b=spec.ν_b_seed, ν_u=spec.ν_u, ξ_u=spec.ξ_u, ξ_W=spec.ξ_W,
        ω̄=spec.ωbar, ω̄_star=spec.ωbar_star,
        κ=spec.κ, χ=spec.χ, η=spec.η,
        branch_iters=60, do_global_polish=false,
    )
end

# These retain every old-F primitive except the stated RoW pair.  They are run
# first and must fail economically before the broader joint search is activated.
const GROWTH_ONLY_SPECS = CandidateSpec[
    CandidateSpec(
        label="row_only_low_xiw", family="RoW growth only",
        a_W=0.10, ξ_W=0.20,
        note="Low xi_W makes common growth feasible but collapses q_W and produces an asset-led decomposition.",
    ),
    CandidateSpec(
        label="row_only_stable_qw", family="RoW growth only",
        a_W=0.05, ξ_W=1.00,
        note="Lower a_W stabilizes q_W but does not generate sufficient U.S.-liability revaluation.",
    ),
]

# Local, mechanism-directed search.  The old-F financial block is retained in
# the successful center; perturbations document which changes help or hurt.
const HYBRID_SPECS = CandidateSpec[
    CandidateSpec(
        label="prior_common_growth_winner", family="prior common-growth benchmark",
        a_W=0.05, ξ_W=1.00, β=0.35, κ=0.75,
        ν_u=1.895, ξ_u=1.90, us_u_level=1.11,
        note="Previous notebook-15 winner; included to measure the magnitude gain from the new objective.",
    ),
    CandidateSpec(
        label="oldF_level150_v080", family="time-invariant-centered joint search",
        a_W=0.05, ξ_W=1.00, us_u_level=1.50,
        note="Raises U.S. unbalanced productivity while retaining the old-F financial and exponent blocks.",
    ),
    CandidateSpec(
        label="oldF_level150_v085", family="time-invariant-centered joint search",
        a_W=0.05, ξ_W=1.00, ϑ_US=0.85, us_u_level=1.50,
        note="Adds stronger transmission from U.S. growth news to equity value.",
    ),
    CandidateSpec(
        label="oldF_level180_v080", family="time-invariant-centered joint search",
        a_W=0.05, ξ_W=1.00, us_u_level=1.80,
        note="Checks whether a larger level shift alone can recover the target magnitude.",
    ),
    CandidateSpec(
        label="pathwise_hi_exp_pi080", family="time-invariant-centered joint search",
        a_W=0.06, ξ_W=1.00, ϑ_US=0.85,
        ν_u=1.75, ξ_u=2.25, us_u_level=1.50,
        note="Raises both U.S. exponents equally, preserving the old 0.50 gap while making room for every effective nu_b.",
    ),
    CandidateSpec(
        label="pathwise_hi_exp_pi075", family="time-invariant-centered joint search",
        a_W=0.06, ξ_W=1.00, π=0.75, ϑ_US=0.85,
        ν_u=1.75, ξ_u=2.25, us_u_level=1.50,
        note="Preferred center: preserves the financial block and exponent gap, with slightly faster transition timing.",
    ),
    CandidateSpec(
        label="pathwise_hi_exp_omega055", family="financial perturbation",
        a_W=0.06, ξ_W=1.00, π=0.75, ϑ_US=0.85,
        ν_u=1.75, ξ_u=2.25, us_u_level=1.50, ωbar=0.55,
        note="Tests whether a higher home U.S. equity target improves the decomposition.",
    ),
    CandidateSpec(
        label="pathwise_hi_exp_omegastar030", family="financial perturbation",
        a_W=0.06, ξ_W=1.00, π=0.75, ϑ_US=0.85,
        ν_u=1.75, ξ_u=2.25, us_u_level=1.50, ωbar_star=0.30,
        note="Tests whether a higher foreign U.S.-equity target improves the decomposition.",
    ),
]

active_growth_specs = NB15_SMOKE_MODE ? GROWTH_ONLY_SPECS[1:1] : GROWTH_ONLY_SPECS
active_hybrid_specs = NB15_SMOKE_MODE ? HYBRID_SPECS[5:6] : HYBRID_SPECS

function first_window_pattern_pass(m)
    return m.target_rebased_nfa < 0.0 &&
           m.target_net_va < 0.0 &&
           m.target_liability_va < 0.0 &&
           abs(m.target_net_va) > abs(m.target_ca) &&
           m.target_foreign_exposure >= 0.15
end

function first_window_classification(m)
    strong_partial = m.target_rebased_nfa <= -0.03 &&
                     m.target_net_va <= -0.03 &&
                     m.target_liability_va <= -0.025 &&
                     abs(m.target_net_va) >= 1.5 * abs(m.target_ca) &&
                     m.target_foreign_exposure >= 0.15
    partial = first_window_pattern_pass(m)
    return strong_partial ? "first_window_common_growth_strong_partial_match" :
           partial ? "first_window_common_growth_partial_match" :
           "first_window_common_growth_near_miss"
end

relative_distance(x, target) = abs(x - target) / max(abs(target), 1e-8)

function first_window_score(m)
    # Magnitudes are matched against the preferred time-invariant result.  CA
    # receives a deliberately small weight: sign and monotonicity are second
    # order once valuation dominates quantity flows in the evidence window.
    target_distance =
        2.5 * relative_distance(m.target_rebased_nfa, AHP_TARGET.rebased_nfa) +
        3.0 * relative_distance(m.target_net_va, AHP_TARGET.net_va) +
        1.5 * relative_distance(m.target_liability_va, AHP_TARGET.liability_va) +
        0.15 * relative_distance(m.target_ca, AHP_TARGET.ca) +
        0.10 * relative_distance(m.target_asset_va, AHP_TARGET.asset_va)

    sign_penalty =
        20.0 * max(0.0, m.target_rebased_nfa) / abs(AHP_TARGET.rebased_nfa) +
        20.0 * max(0.0, m.target_net_va) / abs(AHP_TARGET.net_va) +
        15.0 * max(0.0, m.target_liability_va) / abs(AHP_TARGET.liability_va)
    dominance_penalty = 3.0 * max(
        0.0, abs(m.target_ca) - abs(m.target_net_va),
    ) / abs(AHP_TARGET.net_va)
    exposure_penalty = 2.0 * max(0.0, 0.15 - m.target_foreign_exposure) / 0.15
    return target_distance + sign_penalty + dominance_penalty + exposure_penalty
end

function candidate_row(spec, result, metrics, validity, score, horizon)
    return Dict{String,Any}(
        "label"=>spec.label, "family"=>spec.family, "note"=>spec.note,
        "status"=>"ok", "horizon"=>horizon,
        "hard_valid"=>validity.valid,
        "classification"=>first_window_classification(metrics), "score"=>score,
        "a_W"=>spec.a_W, "xi_W"=>spec.ξ_W,
        "beta"=>spec.β, "kappa"=>spec.κ,
        "omega_bar"=>spec.ωbar, "omega_bar_star"=>spec.ωbar_star,
        "chi"=>spec.χ, "eta"=>spec.η, "pi"=>spec.π,
        "vartheta_US"=>spec.ϑ_US, "nu_u"=>spec.ν_u, "xi_u"=>spec.ξ_u,
        "us_u_level"=>spec.us_u_level, "nu_b_seed"=>spec.ν_b_seed,
        "nu_b_calibrated"=>result.params.ν_b,
        "nu_b_eff_min"=>validity.common.nu_b_eff_min,
        "nu_b_eff_max"=>validity.common.nu_b_eff_max,
        "nu_b_eff_std"=>validity.common.nu_b_eff_std,
        "max_common_growth_level_gap"=>validity.common.max_level_gap,
        "max_common_growth_log_gap"=>validity.common.max_log_gap,
        "exact_common"=>validity.exact_common,
        "extended_bgp_valid"=>validity.extended_bgp_valid,
        "max_extended_bgp_residual"=>validity.common.max_extended_bgp_residual,
        "exponent_ordering"=>validity.exponent_ordering,
        "robust_ordering_002"=>validity.robust_ordering,
        "model_residuals"=>validity.model_residuals,
        "psi_interior"=>validity.psi_interior,
        "equity_interior"=>validity.equity_interior,
        "theta_interior"=>validity.theta_interior,
        "accounting_exact"=>validity.accounting_exact,
        "target_end"=>metrics.target_end,
        "target_rebased_NFA"=>metrics.target_rebased_nfa,
        "target_ratio_change"=>metrics.target_ratio_change,
        "target_VA_asset"=>metrics.target_asset_va,
        "target_VA_liability"=>metrics.target_liability_va,
        "target_VA_net"=>metrics.target_net_va,
        "target_CA"=>metrics.target_ca,
        "target_CA_asset"=>metrics.target_ca_asset,
        "target_CA_liability"=>metrics.target_ca_liability,
        "target_CA_bond"=>metrics.target_ca_bond,
        "target_residual"=>metrics.target_residual,
        "VA_driver_share"=>metrics.va_driver_share,
        "liability_share_of_gross_VA"=>metrics.liability_share_of_gross_va,
        "foreign_exposure"=>metrics.target_foreign_exposure,
        "target_Y_growth"=>metrics.target_Y_growth,
        "target_q_US_growth"=>metrics.target_q_US_growth,
        "target_q_W_growth"=>metrics.target_q_W_growth,
        "tail_observed"=>metrics.tail_observed,
        "post_target_rebased_change"=>metrics.post_target_rebased_change,
        "post_target_NFA_level_move_over_Ye"=>metrics.post_target_nfa_level_move_over_Ye,
        "tail_rebound"=>metrics.tail_rebound,
        "max_u_residual"=>result.max_u_residual,
        "max_bgp_residual"=>result.max_bgp_residual,
    )
end

function evaluate_candidate(spec::CandidateSpec; T::Int, n_buffer::Int)
    p = candidate_params(spec; T=T, n_buffer=n_buffer)
    result = run_production_simulation(p; verbose=false)
    accounting = ahp_accounting(result)
    metrics = candidate_metrics(accounting)
    validity = pathwise_common_validity(result, accounting)
    score = validity.valid ? first_window_score(metrics) : Inf
    row = candidate_row(spec, result, metrics, validity, score, T)
    return (
        spec=spec, result=result, accounting=accounting, metrics=metrics,
        validity=validity, score=score, row=row,
    )
end

function run_candidate_catalog(specs; stage_label)
    records = Any[]
    for spec in specs
        @printf("%-24s %-32s", stage_label * ":", spec.label)
        try
            record = evaluate_candidate(spec; T=SEARCH_T, n_buffer=SEARCH_BUFFER)
            push!(records, record)
            @printf(
                " NFA=%+.4f VA=%+.4f [A=%+.4f L=%+.4f] CA=%+.4f exp=%.3f score=%.3f valid=%s\n",
                record.metrics.target_rebased_nfa, record.metrics.target_net_va,
                record.metrics.target_asset_va, record.metrics.target_liability_va,
                record.metrics.target_ca, record.metrics.target_foreign_exposure,
                record.score, record.validity.valid,
            )
        catch err
            push!(records, (
                spec=spec, score=Inf,
                row=Dict{String,Any}(
                    "label"=>spec.label, "family"=>spec.family,
                    "note"=>spec.note, "status"=>"error",
                    "horizon"=>SEARCH_T, "hard_valid"=>false, "score"=>Inf,
                    "failure_reason"=>sprint(showerror, err),
                ),
            ))
            @printf(" ERROR: %s\n", sprint(showerror, err))
        end
    end
    return records
end

println("\nStage A: representative RoW-growth-only confirmation")
growth_only_records = run_candidate_catalog(
    active_growth_specs; stage_label="RoW-only",
)
valid_growth_only = [
    r for r in growth_only_records
    if get(r.row, "status", "") == "ok" && Bool(r.row["hard_valid"])
]
row_only_failure_confirmed =
    length(valid_growth_only) == length(active_growth_specs) &&
    all(!first_window_pattern_pass(r.metrics) for r in valid_growth_only)
row_only_failure_confirmed || error(
    "The joint search is blocked: the bounded RoW-only audit did not confirm failure.",
)
println("Confirmed: every hard-valid RoW-only case misses the first-window AHP mechanism.")

println("\nStage B: time-invariant-centered joint search with pathwise common growth")
hybrid_search_records = run_candidate_catalog(
    active_hybrid_specs; stage_label="Joint search",
)
search_records = vcat(growth_only_records, hybrid_search_records)
valid_hybrid_records = [
    r for r in hybrid_search_records
    if get(r.row, "status", "") == "ok" && Bool(r.row["hard_valid"])
]
isempty(valid_hybrid_records) && error("No hard-valid joint-search candidate.")
sort!(valid_hybrid_records; by=r -> r.score)

# Promote a declared top-two finalist set.  Each finalist starts cold at T=30;
# the hard-valid final records are then re-ranked by their T=30 first-window
# scores.  Post-target behavior is checked but never enters candidate rank.
final_records = Any[]
finalist_search_records = valid_hybrid_records[
    1:min(FINALIST_COUNT, length(valid_hybrid_records))
]
println("\nCold full-horizon verification:")
for search_record in finalist_search_records
    spec = search_record.spec
    @printf("  %-32s", spec.label)
    try
        record = evaluate_candidate(spec; T=FINAL_T, n_buffer=FINAL_BUFFER)
        push!(final_records, record)
        tail_text = record.metrics.tail_observed ?
            @sprintf("%+.4f", record.metrics.post_target_rebased_change) : "n/a"
        @printf(
            " NFA=%+.4f VA=%+.4f L=%+.4f CA=%+.4f tail=%s valid=%s\n",
            record.metrics.target_rebased_nfa, record.metrics.target_net_va,
            record.metrics.target_liability_va, record.metrics.target_ca,
            tail_text, record.validity.valid,
        )
    catch err
        @printf(" ERROR: %s\n", sprint(showerror, err))
    end
end
valid_final_records = [r for r in final_records if r.validity.valid]
isempty(valid_final_records) &&
    error("No promoted candidate remained hard-valid at T=$(FINAL_T).")
sort!(valid_final_records; by=r -> r.score)
best = first(valid_final_records)

best_result = best.result
best_accounting = best.accounting
best_metrics = best.metrics
best_validity = best.validity
best_classification = first_window_classification(best_metrics)
best_common_diagnostics = common_growth_diagnostics(best_result)

# -----------------------------------------------------------------------------
# Machine-readable exports
# -----------------------------------------------------------------------------

benchmark_rows = Dict{String,Any}[
    Dict("metric"=>"target_end", "time_invariant_value"=>AHP_TARGET_END,
         "selected_value"=>best_metrics.target_end),
    Dict("metric"=>"rebased_NFA_change_current_Y",
         "time_invariant_value"=>AHP_TARGET.rebased_nfa,
         "selected_value"=>best_metrics.target_rebased_nfa),
    Dict("metric"=>"cumulative_net_VA_current_Y",
         "time_invariant_value"=>AHP_TARGET.net_va,
         "selected_value"=>best_metrics.target_net_va),
    Dict("metric"=>"cumulative_liability_VA_current_Y",
         "time_invariant_value"=>AHP_TARGET.liability_va,
         "selected_value"=>best_metrics.target_liability_va),
    Dict("metric"=>"cumulative_asset_VA_current_Y",
         "time_invariant_value"=>AHP_TARGET.asset_va,
         "selected_value"=>best_metrics.target_asset_va),
    Dict("metric"=>"cumulative_CA_current_Y",
         "time_invariant_value"=>AHP_TARGET.ca,
         "selected_value"=>best_metrics.target_ca),
]
for row in benchmark_rows
    target = Float64(row["time_invariant_value"])
    selected = Float64(row["selected_value"])
    row["selected_over_target_magnitude"] =
        row["metric"] == "target_end" ? selected / target : abs(selected) / max(abs(target), 1e-12)
end
write_rows_csv(
    joinpath(OUTDIR, "benchmark_target_comparison.csv"), benchmark_rows,
    ["metric", "time_invariant_value", "selected_value", "selected_over_target_magnitude"],
)

candidate_columns = [
    "label", "family", "note", "status", "horizon", "hard_valid",
    "classification", "score", "a_W", "xi_W", "beta", "kappa",
    "omega_bar", "omega_bar_star", "chi", "eta", "pi", "vartheta_US",
    "nu_u", "xi_u", "us_u_level", "nu_b_seed", "nu_b_calibrated",
    "nu_b_eff_min", "nu_b_eff_max", "nu_b_eff_std",
    "max_common_growth_level_gap", "max_common_growth_log_gap",
    "exact_common", "extended_bgp_valid", "max_extended_bgp_residual",
    "exponent_ordering", "robust_ordering_002", "model_residuals",
    "psi_interior", "equity_interior", "theta_interior", "accounting_exact",
    "target_end", "target_rebased_NFA", "target_ratio_change",
    "target_VA_asset", "target_VA_liability", "target_VA_net", "target_CA",
    "target_CA_asset", "target_CA_liability", "target_CA_bond",
    "target_residual", "VA_driver_share", "liability_share_of_gross_VA",
    "foreign_exposure", "target_Y_growth", "target_q_US_growth",
    "target_q_W_growth", "tail_observed", "post_target_rebased_change",
    "post_target_NFA_level_move_over_Ye", "tail_rebound",
    "max_u_residual", "max_bgp_residual", "failure_reason",
]
candidate_rows = [r.row for r in search_records]
append!(candidate_rows, [r.row for r in final_records])
write_rows_csv(
    joinpath(OUTDIR, "candidate_summary.csv"), candidate_rows, candidate_columns,
)

common_columns = [
    "switch_index", "G_N_US", "G_N_W", "nu_b_eff", "bgp_converged",
    "bgp_residual_norm", "G_b", "G_W", "level_gap", "log_gap",
]
write_rows_csv(
    joinpath(OUTDIR, "best_common_growth_diagnostics.csv"),
    best_common_diagnostics, common_columns,
)

a = best_accounting
T = a.T
path_rows = Dict{String,Any}[]
for j in 1:T
    push!(path_rows, Dict{String,Any}(
        "t"=>j, "evidence_window"=>j <= AHP_TARGET_END,
        "Y_US"=>a.Y_US[j], "e_US"=>a.e_US[j],
        "q_US"=>a.q_US[j], "q_W"=>a.q_W[j],
        "n_W"=>a.n_W[j], "n_US_star"=>a.n_US_star[j], "bond"=>a.bond[j],
        "asset_position"=>a.asset_position[j],
        "liability_position"=>a.liability_position[j],
        "foreign_liability_exposure_Y"=>a.liability_position[j] / a.Y_US[j],
        "NFA"=>a.NFA[j], "NFA_over_Y"=>a.NFA[j] / a.Y_US[j],
        "rebased_NFA_change_current_Y"=>(a.NFA[j] - a.NFA[1]) / a.Y_US[j],
        "VA_asset"=>a.VA_asset[j], "VA_liability"=>a.VA_liability[j],
        "VA"=>a.VA[j], "CA_asset"=>a.CA_asset[j],
        "CA_liability"=>a.CA_liability[j], "CA_bond"=>a.CA_bond[j],
        "CA"=>a.CA[j], "RES"=>a.RES[j],
        "cum_VA_asset_current_Y"=>a.cum_VA_asset[j] / a.Y_US[j],
        "cum_VA_liability_current_Y"=>a.cum_VA_liability[j] / a.Y_US[j],
        "cum_VA_current_Y"=>a.cum_VA[j] / a.Y_US[j],
        "cum_CA_asset_current_Y"=>a.cum_CA_asset[j] / a.Y_US[j],
        "cum_CA_liability_current_Y"=>a.cum_CA_liability[j] / a.Y_US[j],
        "cum_CA_bond_current_Y"=>a.cum_CA_bond[j] / a.Y_US[j],
        "cum_CA_current_Y"=>a.cum_CA[j] / a.Y_US[j],
        "cum_RES_current_Y"=>a.cum_RES[j] / a.Y_US[j],
    ))
end
path_columns = [
    "t", "evidence_window", "Y_US", "e_US", "q_US", "q_W", "n_W",
    "n_US_star", "bond", "asset_position", "liability_position",
    "foreign_liability_exposure_Y", "NFA", "NFA_over_Y",
    "rebased_NFA_change_current_Y", "VA_asset", "VA_liability", "VA",
    "CA_asset", "CA_liability", "CA_bond", "CA", "RES",
    "cum_VA_asset_current_Y", "cum_VA_liability_current_Y",
    "cum_VA_current_Y", "cum_CA_asset_current_Y",
    "cum_CA_liability_current_Y", "cum_CA_bond_current_Y",
    "cum_CA_current_Y", "cum_RES_current_Y",
]
write_rows_csv(joinpath(OUTDIR, "best_path.csv"), path_rows, path_columns)
write_rows_csv(
    joinpath(OUTDIR, "best_ahp_decomposition.csv"), path_rows,
    ["t", "evidence_window", "Y_US", "NFA", "NFA_over_Y",
     "rebased_NFA_change_current_Y", "VA_asset", "VA_liability", "VA",
     "CA_asset", "CA_liability", "CA_bond", "CA", "RES",
     "cum_VA_asset_current_Y", "cum_VA_liability_current_Y",
     "cum_VA_current_Y", "cum_CA_asset_current_Y",
     "cum_CA_liability_current_Y", "cum_CA_bond_current_Y",
     "cum_CA_current_Y", "cum_RES_current_Y"],
)

p = best_result.params
parameter_rows = Dict{String,Any}[
    Dict("parameter"=>"common_world_growth", "time_invariant_value"=>false,
         "selected_value"=>true, "changed"=>true,
         "role"=>"Restores exact common growth at every switch-state BGP using a state-specific effective exponent."),
    Dict("parameter"=>"beta", "time_invariant_value"=>0.45,
         "selected_value"=>p.β, "changed"=>p.β != 0.45,
         "role"=>"Savings/portfolio block retained from the preferred time-invariant calibration."),
    Dict("parameter"=>"kappa", "time_invariant_value"=>1.00,
         "selected_value"=>p.κ, "changed"=>p.κ != 1.00,
         "role"=>"Portfolio adjustment strength retained; financial re-optimization did not improve the first-window match."),
    Dict("parameter"=>"omega_bar", "time_invariant_value"=>0.50,
         "selected_value"=>p.ω̄, "changed"=>p.ω̄ != 0.50,
         "role"=>"U.S. target foreign-equity weight retained."),
    Dict("parameter"=>"omega_bar_star", "time_invariant_value"=>0.25,
         "selected_value"=>p.ω̄_star, "changed"=>p.ω̄_star != 0.25,
         "role"=>"Foreign target weight in U.S. equity retained, preserving large gross U.S. liabilities."),
    Dict("parameter"=>"chi", "time_invariant_value"=>0.0002,
         "selected_value"=>p.χ, "changed"=>p.χ != 0.0002,
         "role"=>"Small portfolio-cost term retained."),
    Dict("parameter"=>"eta", "time_invariant_value"=>0.010,
         "selected_value"=>p.η, "changed"=>p.η != 0.010,
         "role"=>"Portfolio curvature term retained."),
    Dict("parameter"=>"pi_persist", "time_invariant_value"=>0.80,
         "selected_value"=>p.π_persist, "changed"=>p.π_persist != 0.80,
         "role"=>"A modest reduction advances the transition slightly and strengthens early liability revaluation."),
    Dict("parameter"=>"a_W", "time_invariant_value"=>0.10,
         "selected_value"=>p.a_W, "changed"=>p.a_W != 0.10,
         "role"=>"Lowers RoW growth pressure enough to keep the common-growth exponent feasible without collapsing q_W."),
    Dict("parameter"=>"xi_W", "time_invariant_value"=>1.00,
         "selected_value"=>p.ξ_W, "changed"=>p.ξ_W != 1.00,
         "role"=>"Retained at one; low-xi_W alternatives generated a collapsing q_W and asset-led VA."),
    Dict("parameter"=>"vartheta_US", "time_invariant_value"=>0.80,
         "selected_value"=>p.ϑ_US, "changed"=>p.ϑ_US != 0.80,
         "role"=>"Raises the transmission of U.S. growth news into q_US, enlarging liability price revaluation."),
    Dict("parameter"=>"A_X_US_u", "time_invariant_value"=>10.0,
         "selected_value"=>p.A_X_US_u, "changed"=>p.A_X_US_u != 10.0,
         "role"=>"The main magnitude lever: a time-invariant 50% level increase raises U.S. equity appreciation."),
    Dict("parameter"=>"A_L_US_u", "time_invariant_value"=>1.0,
         "selected_value"=>p.A_L_US_u, "changed"=>p.A_L_US_u != 1.0,
         "role"=>"Scaled with A_X_US_u so the unbalanced U.S. technology block shifts coherently."),
    Dict("parameter"=>"nu_u", "time_invariant_value"=>1.40,
         "selected_value"=>p.ν_u, "changed"=>p.ν_u != 1.40,
         "role"=>"Raises the ceiling above every state-specific nu_b_eff."),
    Dict("parameter"=>"xi_u", "time_invariant_value"=>1.90,
         "selected_value"=>p.ξ_u, "changed"=>p.ξ_u != 1.90,
         "role"=>"Raised one-for-one with nu_u, preserving the original xi_u-nu_u gap of 0.50 and hence the unbalanced-growth force."),
    Dict("parameter"=>"nu_b_input_seed", "time_invariant_value"=>0.10,
         "selected_value"=>best.spec.ν_b_seed, "changed"=>false,
         "role"=>"Only a numerical starting value for common-growth calibration."),
    Dict("parameter"=>"nu_b_reference_calibrated", "time_invariant_value"=>0.10,
         "selected_value"=>p.ν_b, "changed"=>true,
         "role"=>"Absorbs the remaining reference-BGP cross-country growth mismatch after the RoW adjustment."),
    Dict("parameter"=>"nu_b_eff_min", "time_invariant_value"=>"not used",
         "selected_value"=>best_validity.common.nu_b_eff_min, "changed"=>true,
         "role"=>"Minimum pathwise selector required for exact common growth."),
    Dict("parameter"=>"nu_b_eff_max", "time_invariant_value"=>"not used",
         "selected_value"=>best_validity.common.nu_b_eff_max, "changed"=>true,
         "role"=>"Maximum pathwise selector; remains below nu_u with both registered and 0.02 robustness margins."),
]
write_rows_csv(
    joinpath(OUTDIR, "best_parameters.csv"), parameter_rows,
    ["parameter", "time_invariant_value", "selected_value", "changed", "role"],
)

diagnosis_rows = Dict{String,Any}[
    Dict("metric"=>"row_only_failure_confirmed", "value"=>row_only_failure_confirmed,
         "interpretation"=>"Both representative hard-valid RoW-only cases miss the AHP mechanism before the broader search is activated."),
    Dict("metric"=>"score_uses_periods", "value"=>"1:$(AHP_TARGET_END)",
         "interpretation"=>"Only the empirical first window enters the objective."),
    Dict("metric"=>"tail_is_unscored", "value"=>true,
         "interpretation"=>"The late rebound remains visible and exported but has exactly zero score weight."),
    Dict("metric"=>"selected_candidate", "value"=>best.spec.label,
         "interpretation"=>best.spec.note),
    Dict("metric"=>"selected_classification", "value"=>best_classification,
         "interpretation"=>"Qualitative partial match; 100% empirical magnitude replication is not required."),
    Dict("metric"=>"VA_dominates_CA", "value"=>abs(best_metrics.target_net_va) > abs(best_metrics.target_ca),
         "interpretation"=>"Core AHP mechanism criterion in the first window."),
    Dict("metric"=>"VA_to_CA_magnitude_ratio",
         "value"=>abs(best_metrics.target_net_va) / max(abs(best_metrics.target_ca), 1e-12),
         "interpretation"=>"Magnitude dominance of price revaluation over quantity flows."),
    Dict("metric"=>"liability_share_of_gross_VA",
         "value"=>best_metrics.liability_share_of_gross_va,
         "interpretation"=>"Share of gross absolute VA attributable to foreign-held U.S. equity claims."),
    Dict("metric"=>"pathwise_common_growth_exact", "value"=>best_validity.exact_common,
         "interpretation"=>"Every reported-plus-buffer absorbing BGP satisfies the common-growth identity."),
    Dict("metric"=>"max_pathwise_common_log_gap", "value"=>best_validity.common.max_log_gap,
         "interpretation"=>"Numerical error in the exact growth identity."),
    Dict("metric"=>"nu_b_eff_range",
         "value"=>"[$(best_validity.common.nu_b_eff_min), $(best_validity.common.nu_b_eff_max)]",
         "interpretation"=>"State-specific selectors restore common growth while all primitives remain time invariant."),
    Dict("metric"=>"post_target_rebased_change", "value"=>best_metrics.post_target_rebased_change,
         "interpretation"=>"Late-path diagnostic only; positive values indicate rebound after the evidence endpoint."),
]
write_rows_csv(
    joinpath(OUTDIR, "diagnosis_summary.csv"), diagnosis_rows,
    ["metric", "value", "interpretation"],
)

# -----------------------------------------------------------------------------
# Rich figures: first window emphasized, late path visible but muted
# -----------------------------------------------------------------------------

tt = collect(1:a.T)
e = min(AHP_TARGET_END, a.T)
evidence_range = 1:e

function evidence_series!(plt, x, y; color, label, lw=2.5, ls=:solid)
    plot!(plt, x, y; color=color, alpha=0.24, lw=max(1.4, lw - 0.7),
          ls=ls, label="")
    plot!(plt, x[evidence_range], y[evidence_range]; color=color, alpha=1.0,
          lw=lw, ls=ls, label=label)
    return plt
end

rebased_nfa = (a.NFA .- a.NFA[1]) ./ a.Y_US
cum_ca_y = a.cum_CA ./ a.Y_US
cum_va_y = a.cum_VA ./ a.Y_US
cum_res_y = a.cum_RES ./ a.Y_US

p_ahp = plot(
    xlabel="period t", ylabel="fraction of current U.S. output",
    title="AHP decomposition: t=1:$(e) is the scored evidence window",
    legend=:outerbottom, legend_columns=2,
)
evidence_series!(p_ahp, tt, rebased_nfa; color=:navy,
                 label="rebased NFA change / current Y", lw=2.8)
evidence_series!(p_ahp, tt, cum_ca_y; color=:crimson,
                 label="cumulative CA / current Y", lw=2.4)
evidence_series!(p_ahp, tt, cum_va_y; color=:seagreen,
                 label="cumulative VA / current Y", lw=2.4)
evidence_series!(p_ahp, tt, cum_res_y; color=:purple,
                 label="cumulative residual / current Y", lw=1.8, ls=:dot)
hline!(p_ahp, [0.0], color=:gray55, ls=:dot, label="")
vline!(p_ahp, [e], color=:gray35, ls=:dash, lw=1.5,
       label="evidence endpoint")

nfa_ratio = a.NFA ./ a.Y_US
p_ratio = plot(
    xlabel="period t", ylabel="fraction of current U.S. output",
    title="NFA/current Y (tail shown, never scored)", legend=:outerbottom,
)
evidence_series!(p_ratio, tt, nfa_ratio; color=:navy, label="NFA / current Y", lw=2.8)
hline!(p_ratio, [nfa_ratio[1]], color=:gray45, ls=:dot,
       label="initial NFA / Y")
vline!(p_ratio, [e], color=:gray35, ls=:dash, lw=1.5,
       label="evidence endpoint")

fig_ahp_two_panel = plot(p_ahp, p_ratio, layout=(1, 2), size=(1450, 540), margin=9mm)
ahp_png = joinpath(OUTDIR, "best_ahp_two_panel.png")
savefig(fig_ahp_two_panel, ahp_png)
isdefined(Main, :IJulia) && display(fig_ahp_two_panel)

p_va = plot(
    xlabel="period t", ylabel="fraction of current U.S. output",
    title="Cumulative valuation components from t=1",
    legend=:outerbottom, legend_columns=2,
)
evidence_series!(p_va, tt, a.cum_VA_asset ./ a.Y_US; color=:steelblue,
                 label="RoW-equity asset VA", lw=2.4)
evidence_series!(p_va, tt, a.cum_VA_liability ./ a.Y_US; color=:tomato,
                 label="foreign-held U.S.-equity liability VA", lw=2.6)
evidence_series!(p_va, tt, a.cum_VA ./ a.Y_US; color=:black,
                 label="net VA", lw=2.1, ls=:dash)
hline!(p_va, [0.0], color=:gray55, ls=:dot, label="")
vline!(p_va, [e], color=:gray35, ls=:dash, lw=1.5, label="evidence endpoint")

p_ca = plot(
    xlabel="period t", ylabel="fraction of current U.S. output",
    title="Cumulative quantity-flow components from t=1",
    legend=:outerbottom, legend_columns=2,
)
evidence_series!(p_ca, tt, a.cum_CA_asset ./ a.Y_US; color=:steelblue,
                 label="RoW-equity quantity CA", lw=2.3)
evidence_series!(p_ca, tt, a.cum_CA_liability ./ a.Y_US; color=:tomato,
                 label="U.S.-equity liability quantity CA", lw=2.3)
evidence_series!(p_ca, tt, a.cum_CA_bond ./ a.Y_US; color=:darkgreen,
                 label="bond-position CA", lw=2.3)
evidence_series!(p_ca, tt, a.cum_CA ./ a.Y_US; color=:black,
                 label="total CA", lw=2.1, ls=:dash)
hline!(p_ca, [0.0], color=:gray55, ls=:dot, label="")
vline!(p_ca, [e], color=:gray35, ls=:dash, lw=1.5, label="evidence endpoint")

fig_subcomponents = plot(p_va, p_ca, layout=(1, 2), size=(1500, 540), margin=9mm)
subcomponents_png = joinpath(OUTDIR, "best_va_ca_subcomponents.png")
savefig(fig_subcomponents, subcomponents_png)
isdefined(Main, :IJulia) && display(fig_subcomponents)

p_prices = plot(
    xlabel="period t", ylabel="index, t=1 equals 1",
    title="Equity prices", legend=:outerbottom, legend_columns=2,
)
evidence_series!(p_prices, tt, a.q_US ./ a.q_US[1]; color=:tomato,
                 label="U.S. equity price index", lw=2.6)
evidence_series!(p_prices, tt, a.q_W ./ a.q_W[1]; color=:steelblue,
                 label="RoW equity price index", lw=2.5)
vline!(p_prices, [e], color=:gray35, ls=:dash, lw=1.5, label="evidence endpoint")

p_exposure = plot(
    xlabel="period t", ylabel="fraction of current U.S. output",
    title="Gross equity exposures and NFA", legend=:outerbottom, legend_columns=2,
)
evidence_series!(p_exposure, tt, a.liability_position ./ a.Y_US; color=:tomato,
                 label="foreign-held U.S. equity claims", lw=2.6)
evidence_series!(p_exposure, tt, a.asset_position ./ a.Y_US; color=:steelblue,
                 label="U.S.-held RoW equity", lw=2.4)
evidence_series!(p_exposure, tt, a.NFA ./ a.Y_US; color=:black,
                 label="NFA / current Y", lw=2.1, ls=:dash)
hline!(p_exposure, [0.0], color=:gray55, ls=:dot, label="")
vline!(p_exposure, [e], color=:gray35, ls=:dash, lw=1.5,
       label="evidence endpoint")

fig_prices_exposures = plot(
    p_prices, p_exposure, layout=(1, 2), size=(1450, 520), margin=9mm,
)
prices_png = joinpath(OUTDIR, "best_prices_exposures.png")
savefig(fig_prices_exposures, prices_png)
isdefined(Main, :IJulia) && display(fig_prices_exposures)

switch_t = Float64[r["switch_index"] for r in best_common_diagnostics]
G_b = Float64[r["G_b"] for r in best_common_diagnostics]
G_W = Float64[r["G_W"] for r in best_common_diagnostics]
nu_eff = Float64[r["nu_b_eff"] for r in best_common_diagnostics]
gaps = Float64[r["level_gap"] for r in best_common_diagnostics]

p_growth = plot(switch_t, G_b, color=:navy, lw=2.6, label="G_b",
                xlabel="switch-state index", ylabel="growth factor",
                title="Exact common growth at every absorbing BGP")
plot!(p_growth, switch_t, G_W, color=:red3, ls=:dash, lw=2.2, label="G_W")
p_nu = plot(switch_t, nu_eff, color=:purple, lw=2.6, label="nu_b_eff",
            xlabel="switch-state index", ylabel="effective exponent",
            title="State-specific effective exponent")
hline!(p_nu, [p.ν_u], color=:gray35, ls=:dash, label="nu_u ceiling")
p_gap = plot(switch_t, gaps, color=:black, lw=2.0, label="G_b - G_W",
             xlabel="switch-state index", ylabel="level gap",
             title="Numerical common-growth error")
fig_common_growth = plot(p_growth, p_nu, p_gap, layout=(1, 3), size=(1550, 460))
common_growth_png = joinpath(OUTDIR, "best_common_growth_diagnostics.png")
savefig(fig_common_growth, common_growth_png)
isdefined(Main, :IJulia) && display(fig_common_growth)

println("\n" * repeat("=", 88))
println("NOTEBOOK 15 — FIRST-WINDOW AHP CALIBRATION WITH PATHWISE COMMON GROWTH")
println(repeat("=", 88))
println("Selected candidate:               ", best.spec.label)
println("Classification:                   ", best_classification)
@printf("Target-window rebased NFA:        %+.6f (time-invariant target %+.6f)\n",
        best_metrics.target_rebased_nfa, AHP_TARGET.rebased_nfa)
@printf("Target-window net VA:             %+.6f (target %+.6f)\n",
        best_metrics.target_net_va, AHP_TARGET.net_va)
@printf("  asset / liability VA:           %+.6f / %+.6f\n",
        best_metrics.target_asset_va, best_metrics.target_liability_va)
@printf("Target-window cumulative CA:      %+.6f (target %+.6f)\n",
        best_metrics.target_ca, AHP_TARGET.ca)
@printf("|VA| / |CA|:                      %.3f\n",
        abs(best_metrics.target_net_va) / max(abs(best_metrics.target_ca), 1e-12))
@printf("Foreign U.S.-equity exposure:     %.3f\n",
        best_metrics.target_foreign_exposure)
@printf("Reference calibrated nu_b:        %.6f\n", best_result.params.ν_b)
@printf("State-specific nu_b_eff range:    [%.6f, %.6f]\n",
        best_validity.common.nu_b_eff_min, best_validity.common.nu_b_eff_max)
@printf("Maximum common-growth log gap:    %.3e\n",
        best_validity.common.max_log_gap)
@printf("Maximum extended-BGP residual:    %.3e\n",
        best_validity.common.max_extended_bgp_residual)
if best_metrics.tail_observed
    @printf("Unscored post-target rebound:      %+.6f\n",
            best_metrics.post_target_rebased_change)
else
    println("Unscored post-target rebound:      n/a (no simulated tail)")
end
println("Tail enters calibration score:     false")
println("Artifacts written to:              ", OUTDIR)
foreach(name -> println("  - ", name), sort(readdir(OUTDIR)))

best_validity.valid || error("Selected result failed a hard gate.")
row_only_failure_confirmed || error("RoW-only failure sequencing invariant failed.")
first_window_pattern_pass(best_metrics) ||
    error("Selected result failed the first-window AHP mechanism criterion.")

fig_ahp_two_panel
