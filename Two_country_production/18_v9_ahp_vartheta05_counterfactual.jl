using Pkg

const NB18_PROJECT_DIR = dirname(@__DIR__)
Pkg.activate(NB18_PROJECT_DIR)
include(joinpath(@__DIR__, "TwoCountryProductionOLG.jl"))

using Dates
using DelimitedFiles
using Markdown
using Plots
using Printf
using SHA
using Statistics
using Plots.PlotMeasures

if !isdefined(Main, :IJulia)
    ENV["GKSwstype"] = get(ENV, "GKSwstype", "100")
end
gr()

const NB18_OUTDIR = get(
    ENV, "NB18_OUTDIR",
    joinpath(@__DIR__, "outputs_v43", "ahp_vartheta05_counterfactual"),
)
mkpath(NB18_OUTDIR)

const AHP_TARGET_END_18 = 15
const REPLICATION_T_18 = 30
const REPLICATION_BUFFER_18 = 10
const TAIL_T_18 = parse(Int, get(ENV, "NB18_TAIL_T", "60"))
const TAIL_BUFFER_18 = parse(Int, get(ENV, "NB18_TAIL_BUFFER", "0"))
const BRANCH_ITER_SCHEDULE_18 = [60, 200]

const RESID_TOL_18 = 1e-5
const PSI_INTERIOR_TOL_18 = 0.02
const EQUITY_INTERIOR_TOL_18 = 0.01
const THETA_INTERIOR_TOL_18 = 0.01
const ACCOUNTING_SCALED_TOL_18 = 1e-7
const COMMON_GROWTH_TOL_18 = 1e-7
const NU_ORDER_BUFFER_18 = 1e-3
const NU_ORDER_ROBUST_BUFFER_18 = 0.02

const NB15_SOURCE_18 = joinpath(@__DIR__, "15_v9_ahp_pattern_calibration_search.jl")
const MODEL_SOURCE_18 = joinpath(@__DIR__, "TwoCountryProductionOLG.jl")
const TIME_INVARIANT_DIR_18 = joinpath(
    @__DIR__, "outputs_v43", "ahp_pattern_time_invariant_search",
)
const NB15_OUTPUT_DIR_18 = joinpath(
    @__DIR__, "outputs_v43", "ahp_pattern_first_window_common_growth_search",
)
const TARGET_CSV_18 = joinpath(TIME_INVARIANT_DIR_18, "best_ahp_decomposition.csv")
const TRACKED_NB15_PATH_18 = joinpath(NB15_OUTPUT_DIR_18, "best_ahp_decomposition.csv")

default(
    size=(980, 540), framestyle=:box, grid=:y, legend=:best,
    fontfamily="Computer Modern", linewidth=2,
    titlefontsize=11, guidefontsize=10, tickfontsize=9, legendfontsize=8,
    left_margin=9mm, right_margin=7mm, top_margin=7mm, bottom_margin=8mm,
)

println("Notebook 18: one-coordinate AHP counterfactual")
println("Project directory:          ", NB18_PROJECT_DIR)
println("Output directory:           ", NB18_OUTDIR)
println("Replication horizon/buffer: ", REPLICATION_T_18, " / ", REPLICATION_BUFFER_18)
println("Tail horizon/buffer:        ", TAIL_T_18, " / ", TAIL_BUFFER_18)

# -----------------------------------------------------------------------------
# CSV and display helpers
# -----------------------------------------------------------------------------

function read_numeric_csv_18(path::AbstractString)
    isfile(path) || error("Required CSV not found: $(path)")
    data, header = readdlm(path, ',', Float64, '\n'; header=true)
    matrix = ndims(data) == 1 ? reshape(data, 1, :) : data
    names = String.(vec(header))
    size(matrix, 2) == length(names) || error("CSV header mismatch: $(path)")
    return Dict(names[j] => Float64.(matrix[:, j]) for j in eachindex(names))
end

function read_selected_numeric_csv_18(path::AbstractString, wanted::Vector{String})
    isfile(path) || error("Required CSV not found: $(path)")
    data, header = readdlm(path, ',', Any, '\n'; header=true)
    matrix = ndims(data) == 1 ? reshape(data, 1, :) : data
    names = String.(vec(header))
    output = Dict{String,Vector{Float64}}()
    for name in wanted
        j = findfirst(==(name), names)
        j === nothing && error("Missing column $(name) in $(path)")
        output[name] = Float64[
            value isa Number ? Float64(value) : parse(Float64, string(value))
            for value in matrix[:, j]
        ]
    end
    return output
end

function csv_cell_18(x)
    s = x === missing ? "" : string(x)
    if occursin(',', s) || occursin('"', s) || occursin('\n', s)
        return "\"" * replace(s, "\"" => "\"\"") * "\""
    end
    return s
end

function write_rows_csv_18(path, rows, columns)
    open(path, "w") do io
        println(io, join(columns, ','))
        for row in rows
            println(io, join((csv_cell_18(get(row, c, missing)) for c in columns), ','))
        end
    end
    return path
end

function markdown_table_18(rows, columns; digits=6)
    fmt(x) = x === missing ? "" :
             x isa AbstractFloat ? @sprintf("%.*f", digits, x) : string(x)
    esc(x) = replace(fmt(x), "|" => "&#124;")
    lines = String[]
    push!(lines, "| " * join(columns, " | ") * " |")
    push!(lines, "| " * join(fill("---", length(columns)), " | ") * " |")
    for row in rows
        push!(lines, "| " * join((esc(get(row, c, missing)) for c in columns), " | ") * " |")
    end
    return Markdown.parse(join(lines, "\n"))
end

file_sha256_18(path) = bytes2hex(sha256(read(path)))

# -----------------------------------------------------------------------------
# Notebook 15 target and exact AHP accounting
# -----------------------------------------------------------------------------

target_table_18 = read_numeric_csv_18(TARGET_CSV_18)
target_t_18 = Int.(round.(target_table_18["t"]))
target_index_18 = findfirst(==(AHP_TARGET_END_18), target_t_18)
target_index_18 === nothing && error("AHP target has no t=$(AHP_TARGET_END_18) row")
target_Y_18 = target_table_18["Y_US"][target_index_18]

const AHP_TARGET_18 = (
    rebased_nfa=target_table_18["ahp_rebased_NFA_change_current_Y"][target_index_18],
    net_va=target_table_18["ahp_cum_VA_current_Y"][target_index_18],
    ca=target_table_18["ahp_cum_CA_current_Y"][target_index_18],
    asset_va=target_table_18["cum_VA_row_equity_asset"][target_index_18] / target_Y_18,
    liability_va=target_table_18["cum_VA_us_equity_liability"][target_index_18] / target_Y_18,
)

path_vector_18(result, field::Symbol) = Float64[getfield(s, field) for s in result.u_path]

function ahp_accounting_18(result::ProductionSimulationResult)
    T = length(result.u_path)
    T >= 3 || error("AHP accounting needs at least three periods")
    u = result.u_path
    q_US = path_vector_18(result, :q_US)
    q_W = path_vector_18(result, :q_W)
    Y_US = path_vector_18(result, :Y_US)
    e_US = path_vector_18(result, :e_US)
    n_W = Float64[(1 - s.ω) * (1 - s.θ) * s.A / s.q_W for s in u]
    n_US_star = Float64[s.ω_star * (1 - s.θ_US_star) * s.A_star / s.q_US for s in u]
    bond = Float64[s.θ * s.A for s in u]
    asset_position = q_W .* n_W
    liability_position = q_US .* n_US_star
    NFA = asset_position .+ bond .- liability_position

    VA_asset = zeros(T); VA_liability = zeros(T)
    CA_asset = zeros(T); CA_liability = zeros(T); CA_bond = zeros(T)
    for t in 2:T
        VA_asset[t] = n_W[t - 1] * (q_W[t] - q_W[t - 1])
        VA_liability[t] = -n_US_star[t - 1] * (q_US[t] - q_US[t - 1])
        CA_asset[t] = q_W[t] * (n_W[t] - n_W[t - 1])
        CA_liability[t] = -q_US[t] * (n_US_star[t] - n_US_star[t - 1])
        CA_bond[t] = bond[t] - bond[t - 1]
    end
    VA = VA_asset .+ VA_liability
    CA = CA_asset .+ CA_liability .+ CA_bond
    RES = zeros(T)
    for t in 2:T
        RES[t] = NFA[t] - NFA[t - 1] - VA[t] - CA[t]
    end
    module_NFA = nfa_decomposition(result).NFA
    return (;
        T, q_US, q_W, Y_US, e_US, n_W, n_US_star, bond,
        asset_position, liability_position, NFA,
        VA_asset, VA_liability, VA, CA_asset, CA_liability, CA_bond, CA, RES,
        cum_VA_asset=cumsum(VA_asset), cum_VA_liability=cumsum(VA_liability),
        cum_VA=cumsum(VA), cum_CA_asset=cumsum(CA_asset),
        cum_CA_liability=cumsum(CA_liability), cum_CA_bond=cumsum(CA_bond),
        cum_CA=cumsum(CA), cum_RES=cumsum(RES),
        residual_max=maximum(abs.(RES[2:end])),
        nfa_identity_error=maximum(abs.(NFA .- module_NFA)),
    )
end

function candidate_metrics_18(a; target_end=AHP_TARGET_END_18)
    e = min(target_end, a.T)
    Y_e = a.Y_US[e]
    evidence = 2:e
    rebased_path = (a.NFA .- a.NFA[1]) ./ a.Y_US
    target_rebased_nfa = (a.NFA[e] - a.NFA[1]) / Y_e
    target_asset_va = a.cum_VA_asset[e] / Y_e
    target_liability_va = a.cum_VA_liability[e] / Y_e
    target_net_va = a.cum_VA[e] / Y_e
    target_ca = a.cum_CA[e] / Y_e
    target_residual = a.cum_RES[e] / Y_e
    target_foreign_exposure = mean(a.liability_position[evidence] ./ a.Y_US[evidence])
    return (;
        target_end=e, target_rebased_nfa, target_asset_va, target_liability_va,
        target_net_va, target_ca, target_residual, target_foreign_exposure,
        target_Y_growth=Y_e / a.Y_US[1],
        target_q_US_growth=a.q_US[e] / a.q_US[1],
        target_q_W_growth=a.q_W[e] / a.q_W[1],
        post_target_rebased_change=a.T > e ? rebased_path[end] - rebased_path[e] : missing,
    )
end

function first_window_pattern_pass_18(m)
    return m.target_rebased_nfa < 0 && m.target_net_va < 0 &&
           m.target_liability_va < 0 && abs(m.target_net_va) > abs(m.target_ca) &&
           m.target_foreign_exposure >= 0.15
end

function first_window_classification_18(m)
    strong = m.target_rebased_nfa <= -0.03 && m.target_net_va <= -0.03 &&
             m.target_liability_va <= -0.025 &&
             abs(m.target_net_va) >= 1.5 * abs(m.target_ca) &&
             m.target_foreign_exposure >= 0.15
    return strong ? "first_window_common_growth_strong_partial_match" :
           first_window_pattern_pass_18(m) ? "first_window_common_growth_partial_match" :
           "first_window_common_growth_near_miss"
end

relative_distance_18(x, target) = abs(x - target) / max(abs(target), 1e-8)
function first_window_score_18(m)
    distance =
        2.5 * relative_distance_18(m.target_rebased_nfa, AHP_TARGET_18.rebased_nfa) +
        3.0 * relative_distance_18(m.target_net_va, AHP_TARGET_18.net_va) +
        1.5 * relative_distance_18(m.target_liability_va, AHP_TARGET_18.liability_va) +
        0.15 * relative_distance_18(m.target_ca, AHP_TARGET_18.ca) +
        0.10 * relative_distance_18(m.target_asset_va, AHP_TARGET_18.asset_va)
    sign_penalty =
        20 * max(0.0, m.target_rebased_nfa) / abs(AHP_TARGET_18.rebased_nfa) +
        20 * max(0.0, m.target_net_va) / abs(AHP_TARGET_18.net_va) +
        15 * max(0.0, m.target_liability_va) / abs(AHP_TARGET_18.liability_va)
    dominance_penalty = 3 * max(0.0, abs(m.target_ca) - abs(m.target_net_va)) /
                        abs(AHP_TARGET_18.net_va)
    exposure_penalty = 2 * max(0.0, 0.15 - m.target_foreign_exposure) / 0.15
    return distance + sign_penalty + dominance_penalty + exposure_penalty
end

# -----------------------------------------------------------------------------
# Exact Notebook 15 hard gates
# -----------------------------------------------------------------------------

function common_growth_summary_18(result)
    p = result.params
    bgps = result.bgp_seq_extended
    nu_eff = Float64[b.ν_b_eff for b in bgps]
    log_gaps = Float64[b.ν_b_eff * log(b.G_N_US) - p.ξ_W * log(b.G_N_W) for b in bgps]
    level_gaps = Float64[b.G_N_US^b.ν_b_eff - b.G_N_W^p.ξ_W for b in bgps]
    return (;
        nu_b_eff_min=minimum(nu_eff), nu_b_eff_max=maximum(nu_eff),
        nu_b_eff_std=std(nu_eff),
        max_log_gap=maximum(abs.(log_gaps)), max_level_gap=maximum(abs.(level_gaps)),
        all_extended_bgp_converged=all(b.converged for b in bgps),
        max_extended_bgp_residual=maximum(b.residual_norm for b in bgps),
    )
end

function hard_validity_18(result, a)
    theta_US_star = path_vector_18(result, :θ_US_star)
    finite_accounting = all(isfinite, a.NFA) && all(isfinite, a.CA) &&
                        all(isfinite, a.VA) && all(isfinite, a.Y_US)
    model_residuals = result.branch_converged &&
        isfinite(result.max_u_residual) && isfinite(result.max_bgp_residual) &&
        result.max_u_residual <= RESID_TOL_18 && result.max_bgp_residual <= RESID_TOL_18
    psi_interior = result.diagnostics.psi_ok && isfinite(result.diagnostics.psi_min) &&
                   result.diagnostics.psi_min >= PSI_INTERIOR_TOL_18
    equity_interior = result.diagnostics.equity_weights_ok &&
        isfinite(result.diagnostics.equity_weight_min) &&
        result.diagnostics.equity_weight_min >= EQUITY_INTERIOR_TOL_18
    theta_interior = all(x -> isfinite(x) && THETA_INTERIOR_TOL_18 <= x < 0.9,
                         theta_US_star)
    positive_foreign_claims = all(x -> isfinite(x) && x > 0, a.n_US_star) &&
                              all(x -> isfinite(x) && x > 0, a.liability_position)
    accounting_scale = max(1.0, maximum(abs.(a.NFA)), maximum(abs.(a.CA)), maximum(abs.(a.VA)))
    accounting_exact = isfinite(a.residual_max) && a.residual_max <= RESID_TOL_18 &&
        a.residual_max / accounting_scale <= ACCOUNTING_SCALED_TOL_18 &&
        isfinite(a.nfa_identity_error) &&
        a.nfa_identity_error / accounting_scale <= ACCOUNTING_SCALED_TOL_18
    return_fields = (:R_A_u, :R_A_b, :R_A_star_u, :R_A_star_b, :R_f, :R_f_W)
    positive_returns = all(
        field -> all(x -> isfinite(x) && x > 0, path_vector_18(result, field)),
        return_fields,
    )
    positive_output = all(x -> isfinite(x) && x > 0, a.Y_US)
    valid = model_residuals && psi_interior && equity_interior && theta_interior &&
            positive_foreign_claims && positive_returns && accounting_exact &&
            positive_output && finite_accounting
    return (; valid, model_residuals, psi_interior, equity_interior, theta_interior,
            positive_foreign_claims, positive_returns, accounting_exact,
            positive_output, finite_accounting, accounting_scale)
end

function pathwise_validity_18(result, a)
    base = hard_validity_18(result, a)
    common = common_growth_summary_18(result)
    exact_common = common.max_level_gap <= COMMON_GROWTH_TOL_18 &&
                   common.max_log_gap <= COMMON_GROWTH_TOL_18
    extended_bgp_valid = common.all_extended_bgp_converged &&
                         common.max_extended_bgp_residual <= RESID_TOL_18
    exponent_ordering = isfinite(common.nu_b_eff_min) && isfinite(common.nu_b_eff_max) &&
        common.nu_b_eff_min > 0 && common.nu_b_eff_max <= result.params.ν_u - NU_ORDER_BUFFER_18
    robust_ordering = common.nu_b_eff_max <= result.params.ν_u - NU_ORDER_ROBUST_BUFFER_18
    return merge(base, (; common, exact_common, extended_bgp_valid, exponent_ordering,
        robust_ordering, valid=base.valid && exact_common && extended_bgp_valid && exponent_ordering))
end

# -----------------------------------------------------------------------------
# One-coordinate calibration and solves
# -----------------------------------------------------------------------------

const BASELINE_VARTTHETA_18 = 0.85
const COUNTERFACTUAL_VARTTHETA_18 = 0.50

function ahp_params_18(vartheta_US; T, n_buffer, branch_iters)
    return ProductionParams(
        T_max=T, n_buffer=n_buffer, common_world_growth=true,
        β=0.45, γ=0.25, π_persist=0.75,
        a_US=0.20, ϑ_US=vartheta_US,
        a_W=0.06, H_W=3.0, L_W=3.0,
        A_X_US_u=15.0, A_L_US_u=1.5,
        ν_b=0.10, ν_u=1.75, ξ_u=2.25, ξ_W=1.00,
        ω̄=0.50, ω̄_star=0.25,
        κ=1.00, χ=0.0002, η=0.010,
        branch_iters=branch_iters, do_global_polish=false,
    )
end

p_config_baseline_18 = ahp_params_18(
    BASELINE_VARTTHETA_18; T=REPLICATION_T_18,
    n_buffer=REPLICATION_BUFFER_18, branch_iters=first(BRANCH_ITER_SCHEDULE_18),
)
p_config_counterfactual_18 = ahp_params_18(
    COUNTERFACTUAL_VARTTHETA_18; T=REPLICATION_T_18,
    n_buffer=REPLICATION_BUFFER_18, branch_iters=first(BRANCH_ITER_SCHEDULE_18),
)
primitive_differences_18 = Symbol[
    field for field in fieldnames(ProductionParams)
    if getfield(p_config_baseline_18, field) != getfield(p_config_counterfactual_18, field)
]
primitive_differences_18 == [:ϑ_US] ||
    error("Counterfactual changes fields other than vartheta_US: $(primitive_differences_18)")

function package_case_18(label, vartheta_US, result)
    accounting = ahp_accounting_18(result)
    metrics = candidate_metrics_18(accounting)
    validity = pathwise_validity_18(result, accounting)
    return (; label, vartheta_US, result, accounting, metrics, validity,
            score=first_window_score_18(metrics))
end

function solve_case_18(label, vartheta_US; T, n_buffer, initial_u_path=nothing)
    last_case = nothing
    warm = initial_u_path
    for branch_iters in BRANCH_ITER_SCHEDULE_18
        @printf("Solving %-24s T=%d buffer=%d branch_iters=%d\n",
                label, T, n_buffer, branch_iters)
        p = ahp_params_18(vartheta_US; T=T, n_buffer=n_buffer, branch_iters=branch_iters)
        result = run_production_simulation(p; verbose=false, initial_u_path=warm)
        last_case = package_case_18(label, vartheta_US, result)
        @printf("  max residuals u/bgp = %.3e / %.3e; hard-valid=%s\n",
                result.max_u_residual, result.max_bgp_residual, last_case.validity.valid)
        last_case.validity.valid && return last_case
        warm = result.u_path_extended
    end
    return last_case
end

baseline_30_18 = solve_case_18(
    "baseline_vartheta085", BASELINE_VARTTHETA_18;
    T=REPLICATION_T_18, n_buffer=REPLICATION_BUFFER_18,
)
counterfactual_30_18 = solve_case_18(
    "counterfactual_vartheta050", COUNTERFACTUAL_VARTTHETA_18;
    T=REPLICATION_T_18, n_buffer=REPLICATION_BUFFER_18,
)

baseline_30_18.validity.valid || error("Notebook 15 baseline replication failed a hard gate")

baseline_60_18 = solve_case_18(
    "baseline_vartheta085_tail", BASELINE_VARTTHETA_18;
    T=TAIL_T_18, n_buffer=TAIL_BUFFER_18,
    initial_u_path=baseline_30_18.result.u_path_extended,
)
counterfactual_60_18 = solve_case_18(
    "counterfactual_vartheta050_tail", COUNTERFACTUAL_VARTTHETA_18;
    T=TAIL_T_18, n_buffer=TAIL_BUFFER_18,
    initial_u_path=counterfactual_30_18.result.u_path_extended,
)

# Reproduce Notebook 15's tracked first-window path under the baseline value.
tracked_nb15_18 = read_selected_numeric_csv_18(TRACKED_NB15_PATH_18, [
    "t", "rebased_NFA_change_current_Y", "cum_VA_current_Y", "cum_CA_current_Y",
])
tracked_len_18 = min(AHP_TARGET_END_18, length(tracked_nb15_18["t"]))
baseline_rebased_18 = (baseline_30_18.accounting.NFA .- baseline_30_18.accounting.NFA[1]) ./
                      baseline_30_18.accounting.Y_US
baseline_replication_errors_18 = Dict(
    "rebased_NFA_change_current_Y" => maximum(abs.(
        baseline_rebased_18[1:tracked_len_18] .-
        tracked_nb15_18["rebased_NFA_change_current_Y"][1:tracked_len_18])),
    "cum_VA_current_Y" => maximum(abs.(
        baseline_30_18.accounting.cum_VA[1:tracked_len_18] ./
        baseline_30_18.accounting.Y_US[1:tracked_len_18] .-
        tracked_nb15_18["cum_VA_current_Y"][1:tracked_len_18])),
    "cum_CA_current_Y" => maximum(abs.(
        baseline_30_18.accounting.cum_CA[1:tracked_len_18] ./
        baseline_30_18.accounting.Y_US[1:tracked_len_18] .-
        tracked_nb15_18["cum_CA_current_Y"][1:tracked_len_18])),
)
maximum(values(baseline_replication_errors_18)) <= 1e-5 ||
    error("Baseline does not reproduce Notebook 15 within tolerance")

# -----------------------------------------------------------------------------
# Paths, summaries, and figures
# -----------------------------------------------------------------------------

function case_path_rows_18(case, horizon_kind)
    p = case.result.params
    a = case.accounting
    rows = Dict{String,Any}[]
    for (t, s) in enumerate(case.result.u_path)
        G_US = G_N_US(p, s.φ_US)
        G_W = G_N_W(p, s.φ_W)
        push!(rows, Dict{String,Any}(
            "case"=>case.label, "horizon_kind"=>horizon_kind,
            "vartheta_US"=>case.vartheta_US, "t"=>t,
            "evidence_window"=>t <= AHP_TARGET_END_18,
            "phi_US"=>s.φ_US, "phi_W"=>s.φ_W,
            "rd_share_US"=>1 - s.φ_US,
            "N_US"=>s.N_US, "N_W"=>s.N_W,
            "G_N_US"=>G_US, "G_N_W"=>G_W,
            "US_real_scale_growth"=>G_US^p.ν_u,
            "W_real_scale_growth"=>G_W^p.ξ_W,
            "relative_real_scale_growth"=>G_US^p.ν_u / G_W^p.ξ_W,
            "zeta"=>s.Q_US / (p.β * s.e_US),
            "e_W_over_e_US"=>s.e_W / s.e_US,
            "Q_W_over_e_US"=>s.Q_W / s.e_US,
            "q_US"=>s.q_US, "q_W"=>s.q_W,
            "Y_US"=>s.Y_US,
            "NFA"=>a.NFA[t],
            "rebased_NFA_change_current_Y"=>(a.NFA[t] - a.NFA[1]) / a.Y_US[t],
            "cum_VA_current_Y"=>a.cum_VA[t] / a.Y_US[t],
            "cum_CA_current_Y"=>a.cum_CA[t] / a.Y_US[t],
            "residual_norm"=>s.residual_norm,
        ))
    end
    return rows
end

replication_cases_18 = [baseline_30_18, counterfactual_30_18]
tail_cases_18 = [baseline_60_18, counterfactual_60_18]
replication_path_rows_18 = reduce(vcat,
    [case_path_rows_18(c, "replication_T30_buffer10") for c in replication_cases_18];
    init=Dict{String,Any}[])
tail_path_rows_18 = reduce(vcat,
    [case_path_rows_18(c, "tail_T60_no_buffer") for c in tail_cases_18];
    init=Dict{String,Any}[])
all_path_rows_18 = vcat(replication_path_rows_18, tail_path_rows_18)

path_columns_18 = [
    "case", "horizon_kind", "vartheta_US", "t", "evidence_window",
    "phi_US", "phi_W", "rd_share_US", "N_US", "N_W", "G_N_US", "G_N_W",
    "US_real_scale_growth", "W_real_scale_growth", "relative_real_scale_growth",
    "zeta", "e_W_over_e_US", "Q_W_over_e_US", "q_US", "q_W", "Y_US",
    "NFA", "rebased_NFA_change_current_Y", "cum_VA_current_Y",
    "cum_CA_current_Y", "residual_norm",
]
write_rows_csv_18(joinpath(NB18_OUTDIR, "counterfactual_paths.csv"),
                  all_path_rows_18, path_columns_18)

function first_below_18(values, threshold)
    idx = findfirst(<(threshold), values)
    return idx === nothing ? missing : idx
end

function tail_log_slope_18(values; k=8)
    n = length(values); kk = min(k, n)
    x = collect(1.0:kk); y = log.(values[(n - kk + 1):n])
    return sum((x .- mean(x)) .* (y .- mean(y))) / sum((x .- mean(x)).^2)
end

function summary_row_18(rep_case, tail_case)
    m = rep_case.metrics
    phi = path_vector_18(tail_case.result, :φ_US)
    growth = Float64[
        G_N_US(tail_case.result.params, s.φ_US)^tail_case.result.params.ν_u
        for s in tail_case.result.u_path
    ]
    last_t = length(phi)
    return Dict{String,Any}(
        "case"=>rep_case.label, "vartheta_US"=>rep_case.vartheta_US,
        "configured_primitive_difference"=>rep_case.vartheta_US == BASELINE_VARTTHETA_18 ?
            "baseline" : "vartheta_US_only",
        "replication_hard_valid"=>rep_case.validity.valid,
        "tail_hard_valid"=>tail_case.validity.valid,
        "AHP_pattern_pass"=>first_window_pattern_pass_18(m),
        "classification"=>first_window_classification_18(m),
        "score"=>rep_case.score,
        "target_rebased_NFA"=>m.target_rebased_nfa,
        "target_net_VA"=>m.target_net_va,
        "target_liability_VA"=>m.target_liability_va,
        "target_CA"=>m.target_ca,
        "VA_over_CA_abs"=>abs(m.target_net_va) / max(abs(m.target_ca), 1e-12),
        "foreign_exposure"=>m.target_foreign_exposure,
        "NFA_target_magnitude_share"=>abs(m.target_rebased_nfa / AHP_TARGET_18.rebased_nfa),
        "net_VA_target_magnitude_share"=>abs(m.target_net_va / AHP_TARGET_18.net_va),
        "phi_US_t1"=>phi[1], "phi_US_t15"=>phi[min(15, last_t)],
        "phi_US_t30"=>phi[min(30, last_t)], "phi_US_tail_end"=>phi[end],
        "phi_US_tail_log_slope"=>tail_log_slope_18(phi),
        "first_t_phi_below_050"=>first_below_18(phi, 0.50),
        "first_t_phi_below_020"=>first_below_18(phi, 0.20),
        "US_growth_t1"=>growth[1], "US_growth_t15"=>growth[min(15, last_t)],
        "US_growth_t30"=>growth[min(30, last_t)], "US_growth_tail_end"=>growth[end],
        "zeta_tail_end"=>tail_case.result.u_path[end].Q_US /
                         (tail_case.result.params.β * tail_case.result.u_path[end].e_US),
        "e_W_over_e_US_tail_end"=>tail_case.result.u_path[end].e_W /
                                   tail_case.result.u_path[end].e_US,
        "max_u_residual_replication"=>rep_case.result.max_u_residual,
        "max_u_residual_tail"=>tail_case.result.max_u_residual,
        "max_bgp_residual_tail"=>tail_case.result.max_bgp_residual,
        "nu_b_runtime_replication"=>rep_case.result.params.ν_b,
        "nu_b_eff_min_replication"=>rep_case.validity.common.nu_b_eff_min,
        "nu_b_eff_max_replication"=>rep_case.validity.common.nu_b_eff_max,
    )
end

summary_rows_18 = [
    summary_row_18(baseline_30_18, baseline_60_18),
    summary_row_18(counterfactual_30_18, counterfactual_60_18),
]
summary_columns_18 = [
    "case", "vartheta_US", "configured_primitive_difference",
    "replication_hard_valid", "tail_hard_valid", "AHP_pattern_pass",
    "classification", "score", "target_rebased_NFA", "target_net_VA",
    "target_liability_VA", "target_CA", "VA_over_CA_abs", "foreign_exposure",
    "NFA_target_magnitude_share", "net_VA_target_magnitude_share",
    "phi_US_t1", "phi_US_t15", "phi_US_t30", "phi_US_tail_end",
    "phi_US_tail_log_slope", "first_t_phi_below_050", "first_t_phi_below_020",
    "US_growth_t1", "US_growth_t15", "US_growth_t30", "US_growth_tail_end",
    "zeta_tail_end", "e_W_over_e_US_tail_end",
    "max_u_residual_replication", "max_u_residual_tail", "max_bgp_residual_tail",
    "nu_b_runtime_replication", "nu_b_eff_min_replication", "nu_b_eff_max_replication",
]
write_rows_csv_18(joinpath(NB18_OUTDIR, "counterfactual_summary.csv"),
                  summary_rows_18, summary_columns_18)

parameter_rows_18 = Dict{String,Any}[]
for field in fieldnames(ProductionParams)
    baseline_value = getfield(p_config_baseline_18, field)
    counterfactual_value = getfield(p_config_counterfactual_18, field)
    push!(parameter_rows_18, Dict{String,Any}(
        "parameter"=>string(field), "baseline_configured"=>baseline_value,
        "counterfactual_configured"=>counterfactual_value,
        "configured_changed"=>baseline_value != counterfactual_value,
        "baseline_resolved_T30"=>getfield(baseline_30_18.result.params, field),
        "counterfactual_resolved_T30"=>getfield(counterfactual_30_18.result.params, field),
        "origin"=>field == :ϑ_US ? "user_counterfactual" :
                  field == :ν_b ? "same_seed_then_endogenous_common_growth_recalibration" :
                  "held_at_Notebook_15_selected_value_or_shared_default",
    ))
end
write_rows_csv_18(joinpath(NB18_OUTDIR, "parameter_comparison.csv"), parameter_rows_18,
    ["parameter", "baseline_configured", "counterfactual_configured",
     "configured_changed", "baseline_resolved_T30", "counterfactual_resolved_T30", "origin"])

replication_check_rows_18 = Dict{String,Any}[
    Dict("metric"=>k, "max_abs_error"=>v, "tolerance"=>1e-5,
         "passed"=>v <= 1e-5) for (k, v) in sort(collect(baseline_replication_errors_18))
]
write_rows_csv_18(joinpath(NB18_OUTDIR, "baseline_replication_check.csv"),
    replication_check_rows_18, ["metric", "max_abs_error", "tolerance", "passed"])

function series_for_18(case_label, horizon_kind, field)
    rows = filter(r -> r["case"] == case_label && r["horizon_kind"] == horizon_kind,
                  all_path_rows_18)
    return Float64[r[field] for r in rows]
end

tt30_18 = collect(1:REPLICATION_T_18)
p_nfa_18 = plot(title="AHP first-window NFA pattern", xlabel="period t",
    ylabel="rebased NFA change / current Y", legend=:bottomleft)
p_decomp_18 = plot(title="AHP mechanism at vartheta_US = 0.50", xlabel="period t",
    ylabel="fraction of current U.S. output", legend=:bottomleft)
colors_18 = Dict("baseline_vartheta085"=>:navy, "counterfactual_vartheta050"=>:darkorange)
labels_18 = Dict("baseline_vartheta085"=>"baseline vartheta=0.85",
                 "counterfactual_vartheta050"=>"counterfactual vartheta=0.50")
for c in replication_cases_18
    rebased = (c.accounting.NFA .- c.accounting.NFA[1]) ./ c.accounting.Y_US
    plot!(p_nfa_18, tt30_18, rebased; color=colors_18[c.label], lw=2.6,
          label=labels_18[c.label])
end
cf_a_18 = counterfactual_30_18.accounting
plot!(p_decomp_18, tt30_18, (cf_a_18.NFA .- cf_a_18.NFA[1]) ./ cf_a_18.Y_US,
      color=:navy, lw=2.7, label="rebased NFA")
plot!(p_decomp_18, tt30_18, cf_a_18.cum_VA ./ cf_a_18.Y_US,
      color=:seagreen, lw=2.3, label="cumulative VA")
plot!(p_decomp_18, tt30_18, cf_a_18.cum_CA ./ cf_a_18.Y_US,
      color=:crimson, lw=2.3, label="cumulative CA")
for p in (p_nfa_18, p_decomp_18)
    vline!(p, [AHP_TARGET_END_18], color=:gray35, ls=:dash, label="evidence endpoint")
    hline!(p, [0.0], color=:gray60, ls=:dot, label="")
end
fig_ahp_18 = plot(p_nfa_18, p_decomp_18, layout=(1, 2), size=(1450, 520), margin=8mm)
savefig(fig_ahp_18, joinpath(NB18_OUTDIR, "ahp_pattern_counterfactual.png"))
isdefined(Main, :IJulia) && display(fig_ahp_18)

tt_tail_18 = collect(1:TAIL_T_18)
p_phi_18 = plot(title="U.S. production share", xlabel="period t", ylabel="phi_US",
                legend=:topright)
p_growth_18 = plot(title="U.S. real-scale growth", xlabel="period t",
                   ylabel="G_N_US ^ nu_u", legend=:bottomright)
p_zeta_18 = plot(title="U.S. stock-funding ratio", xlabel="period t",
                 ylabel="zeta", legend=:bottomright)
p_dom_18 = plot(title="RoW/U.S. income ratio", xlabel="period t",
                ylabel="e_W / e_US", yscale=:log10, legend=:bottomleft)
for c in tail_cases_18
    source_label = startswith(c.label, "baseline") ? "baseline_vartheta085" :
                   "counterfactual_vartheta050"
    color = colors_18[source_label]; label = labels_18[source_label]
    phi = path_vector_18(c.result, :φ_US)
    growth = Float64[G_N_US(c.result.params, s.φ_US)^c.result.params.ν_u for s in c.result.u_path]
    zeta = Float64[s.Q_US / (c.result.params.β * s.e_US) for s in c.result.u_path]
    dominance = Float64[s.e_W / s.e_US for s in c.result.u_path]
    plot!(p_phi_18, tt_tail_18, phi; color, lw=2.6, label)
    plot!(p_growth_18, tt_tail_18, growth; color, lw=2.6, label)
    plot!(p_zeta_18, tt_tail_18, zeta; color, lw=2.6, label)
    plot!(p_dom_18, tt_tail_18, dominance; color, lw=2.6, label)
end
hline!(p_zeta_18, [1.0], color=:gray40, ls=:dash, label="HKT limit")
vline!(p_phi_18, [AHP_TARGET_END_18], color=:gray35, ls=:dash, label="evidence endpoint")
fig_tail_18 = plot(p_phi_18, p_growth_18, p_zeta_18, p_dom_18,
                   layout=(2, 2), size=(1450, 930), margin=8mm)
savefig(fig_tail_18, joinpath(NB18_OUTDIR, "phi_growth_funding_counterfactual.png"))
isdefined(Main, :IJulia) && display(fig_tail_18)

run_manifest_rows_18 = Dict{String,Any}[
    Dict("field"=>"run_completed_utc", "value"=>Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")),
    Dict("field"=>"experiment", "value"=>"one_coordinate_vartheta_US_counterfactual"),
    Dict("field"=>"configured_primitive_differences", "value"=>join(string.(primitive_differences_18), ',')),
    Dict("field"=>"baseline_vartheta_US", "value"=>BASELINE_VARTTHETA_18),
    Dict("field"=>"counterfactual_vartheta_US", "value"=>COUNTERFACTUAL_VARTTHETA_18),
    Dict("field"=>"AHP_evidence_endpoint", "value"=>AHP_TARGET_END_18),
    Dict("field"=>"replication_T", "value"=>REPLICATION_T_18),
    Dict("field"=>"replication_buffer", "value"=>REPLICATION_BUFFER_18),
    Dict("field"=>"tail_T", "value"=>TAIL_T_18),
    Dict("field"=>"tail_buffer", "value"=>TAIL_BUFFER_18),
    Dict("field"=>"branch_iter_schedule", "value"=>join(BRANCH_ITER_SCHEDULE_18, ',')),
    Dict("field"=>"baseline_replication_max_error", "value"=>maximum(values(baseline_replication_errors_18))),
    Dict("field"=>"model_sha256", "value"=>file_sha256_18(MODEL_SOURCE_18)),
    Dict("field"=>"notebook15_source_sha256", "value"=>file_sha256_18(NB15_SOURCE_18)),
    Dict("field"=>"AHP_target_csv_sha256", "value"=>file_sha256_18(TARGET_CSV_18)),
    Dict("field"=>"tracked_notebook15_path_sha256", "value"=>file_sha256_18(TRACKED_NB15_PATH_18)),
]
write_rows_csv_18(joinpath(NB18_OUTDIR, "run_manifest.csv"), run_manifest_rows_18,
                  ["field", "value"])

counterfactual_pattern_retained_18 = first_window_pattern_pass_18(counterfactual_30_18.metrics)
counterfactual_faster_phi_decay_18 =
    summary_rows_18[2]["phi_US_tail_end"] < summary_rows_18[1]["phi_US_tail_end"] &&
    summary_rows_18[2]["phi_US_tail_log_slope"] < summary_rows_18[1]["phi_US_tail_log_slope"]
joint_objective_retained_18 = counterfactual_30_18.validity.valid &&
    counterfactual_pattern_retained_18 && counterfactual_faster_phi_decay_18

println("\n" * repeat("=", 88))
println("NOTEBOOK 18 — VARTTHETA_US = 0.50 ONE-COORDINATE COUNTERFACTUAL")
println(repeat("=", 88))
println("Configured primitive differences: ", primitive_differences_18)
@printf("Baseline replication max error:    %.3e\n", maximum(values(baseline_replication_errors_18)))
println("Counterfactual hard-valid at T30:  ", counterfactual_30_18.validity.valid)
println("Counterfactual hard-valid at tail: ", counterfactual_60_18.validity.valid)
println("AHP mechanism retained:            ", counterfactual_pattern_retained_18)
println("Faster phi decay than baseline:    ", counterfactual_faster_phi_decay_18)
println("Joint objective retained:          ", joint_objective_retained_18)
println("Artifacts written to:              ", NB18_OUTDIR)

display(markdown_table_18(summary_rows_18, [
    "case", "vartheta_US", "replication_hard_valid", "tail_hard_valid",
    "AHP_pattern_pass", "target_rebased_NFA", "target_net_VA", "target_CA",
    "phi_US_t15", "phi_US_t30", "phi_US_tail_end", "US_growth_tail_end",
]))

fig_tail_18
