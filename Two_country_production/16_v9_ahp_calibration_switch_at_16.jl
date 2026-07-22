using Pkg

const NB16_PROJECT_DIR = dirname(@__DIR__)
Pkg.activate(NB16_PROJECT_DIR)
include(joinpath(@__DIR__, "TwoCountryProductionOLG.jl"))

if !isdefined(Main, :IJulia)
    ENV["GKSwstype"] = get(ENV, "GKSwstype", "100")
end

using DelimitedFiles
using LaTeXStrings
using Plots, Printf, Statistics
using Plots.PlotMeasures

gr()

const SWITCH_PERIOD = 16
const FINAL_T = 30
const FINAL_BUFFER = 10
const RESID_TOL = 1e-5
const COMMON_GROWTH_TOL = 1e-7
const STATE_MATCH_TOL = 1e-7
const ORIGINAL_HELPER_MATCH_TOL = 1e-6
const NB15_RESULT_DIR = joinpath(
    @__DIR__, "outputs_v43", "ahp_pattern_first_window_common_growth_search",
)
const DEFAULT_OUTDIR = joinpath(
    @__DIR__, "outputs_v43", "ahp_calibration_switch_at_16",
)
const OUTDIR = get(ENV, "NB16_OUTDIR", DEFAULT_OUTDIR)
mkpath(OUTDIR)

default(
    size=(950, 520), framestyle=:box, grid=:y, legend=:best,
    fontfamily="Computer Modern", linewidth=2,
    titlefontsize=11, guidefontsize=10, tickfontsize=9, legendfontsize=8,
    left_margin=9mm, right_margin=7mm, top_margin=7mm, bottom_margin=8mm,
)

# -----------------------------------------------------------------------------
# Notebook 15 calibration provenance
# -----------------------------------------------------------------------------

function read_csv_any(path::AbstractString)
    isfile(path) || error("Required CSV not found: $(path)")
    data, header = readdlm(path, ',', Any, '\n'; header=true, quotes=true)
    matrix = ndims(data) == 1 ? reshape(data, 1, :) : data
    names = String.(vec(header))
    size(matrix, 2) == length(names) || error("CSV header mismatch: $(path)")
    return matrix, names
end

function column_index(names, name)
    index = findfirst(==(name), names)
    index === nothing && error("Missing CSV column: $(name)")
    return index
end

as_float(x) = x isa Number ? Float64(x) : parse(Float64, string(x))
as_int(x) = x isa Integer ? Int(x) : Int(round(as_float(x)))
as_bool(x) = lowercase(string(x)) == "true"

candidate_data, candidate_names = read_csv_any(
    joinpath(NB15_RESULT_DIR, "candidate_summary.csv"),
)
label_col = column_index(candidate_names, "label")
horizon_col = column_index(candidate_names, "horizon")
valid_col = column_index(candidate_names, "hard_valid")
score_col = column_index(candidate_names, "score")

final_candidate_indices = [
    i for i in axes(candidate_data, 1)
    if as_int(candidate_data[i, horizon_col]) == FINAL_T &&
       as_bool(candidate_data[i, valid_col])
]
isempty(final_candidate_indices) && error("Notebook 15 has no hard-valid T=30 finalist.")
final_candidate_scores = [
    as_float(candidate_data[i, score_col]) for i in final_candidate_indices
]
selected_index = final_candidate_indices[argmin(final_candidate_scores)]
selected_row = Dict(
    candidate_names[j] => candidate_data[selected_index, j]
    for j in eachindex(candidate_names)
)
const SELECTED_LABEL = string(selected_row["label"])
SELECTED_LABEL == "pathwise_hi_exp_pi075" ||
    error("Unexpected Notebook 15 winner: $(SELECTED_LABEL)")

function nb15_selected_params(; T::Int=FINAL_T, n_buffer::Int=FINAL_BUFFER)
    us_scale = as_float(selected_row["us_u_level"])
    return ProductionParams(
        T_max=T, n_buffer=n_buffer, common_world_growth=true,
        β=as_float(selected_row["beta"]), γ=0.25,
        π_persist=as_float(selected_row["pi"]),
        a_US=0.20, ϑ_US=as_float(selected_row["vartheta_US"]),
        a_W=as_float(selected_row["a_W"]), H_W=3.0, L_W=3.0,
        A_X_US_u=10.0 * us_scale, A_L_US_u=1.0 * us_scale,
        ν_b=as_float(selected_row["nu_b_seed"]),
        ν_u=as_float(selected_row["nu_u"]),
        ξ_u=as_float(selected_row["xi_u"]),
        ξ_W=as_float(selected_row["xi_W"]),
        ω̄=as_float(selected_row["omega_bar"]),
        ω̄_star=as_float(selected_row["omega_bar_star"]),
        κ=as_float(selected_row["kappa"]),
        χ=as_float(selected_row["chi"]), η=as_float(selected_row["eta"]),
        branch_iters=60, do_global_polish=false,
    )
end

input_params = nb15_selected_params()
expected_reference_nu_b = as_float(selected_row["nu_b_calibrated"])

println("Notebook 15 selected calibration: ", SELECTED_LABEL)
println("Switch convention: u for t < $(SWITCH_PERIOD), b for t >= $(SWITCH_PERIOD)")
println("Output directory: ", OUTDIR)

# -----------------------------------------------------------------------------
# Cold all-u equilibrium and checked realized switch path
# -----------------------------------------------------------------------------

result = run_production_simulation(input_params; verbose=false)
p = result.params

@printf("Cold all-u solve: converged=%s, max u residual=%.3e, max BGP residual=%.3e\n",
        result.branch_converged, result.max_u_residual, result.max_bgp_residual)
@printf("Reference calibrated nu_b: %.9f (Notebook 15 export %.9f)\n",
        p.ν_b, expected_reference_nu_b)

result.branch_converged || error("Notebook 15 all-u branch did not converge.")
result.max_u_residual <= RESID_TOL || error("All-u residual exceeds tolerance.")
result.max_bgp_residual <= RESID_TOL || error("Counterfactual BGP residual exceeds tolerance.")
isapprox(p.ν_b, expected_reference_nu_b; atol=1e-9, rtol=1e-9) ||
    error("Re-solved reference nu_b differs from Notebook 15 export.")

function augmented_u_record(s::UPeriodState)
    merge(
        _path_record(s, :u),
        (nu_b_eff=missing, bgp_converged=missing, bgp_residual=missing,
         common_growth_log_gap=missing),
    )
end

function augmented_b_record(t::Int, b::BGPResult, p::ProductionParams)
    log_gap = b.ν_b_eff * log(b.G_N_US) - p.ξ_W * log(b.G_N_W)
    merge(
        _path_record(t, b, :b),
        (nu_b_eff=b.ν_b_eff, bgp_converged=b.converged,
         bgp_residual=b.residual_norm, common_growth_log_gap=log_gap),
    )
end

"""
Notebook-05 timing with two numerical safeguards:

1. use the already-solved switch successor at tau, which is evaluated at the
   exact inherited state N_tau;
2. carry the previous absorbing state's effective exponent as the next
   common-growth calibration seed, and fail immediately on a non-finite or
   non-converged BGP.
"""
function build_checked_switch_path(
    result::ProductionSimulationResult, τ::Int; T::Int=length(result.u_path),
)
    1 <= τ <= T + 1 || error("Switch date must lie in 1:T+1.")
    T <= length(result.u_path) || error("Requested path exceeds solved horizon.")
    p = result.params
    path = NamedTuple[]
    bgp_objects = BGPResult[]

    for t in 1:min(T, τ - 1)
        push!(path, augmented_u_record(result.u_path[t]))
    end

    if τ <= T
        N_US = result.u_path[τ].N_US
        N_W = result.u_path[τ].N_W
        b = result.bgp_seq[τ]

        for t in τ:T
            if t > τ
                p_seed = ProductionParams(p; ν_b=b.ν_b_eff)
                x0 = (b.φ_US, b.φ_W, b.ω, b.θ_US_star,
                      b.ω_star, b.R_f, b.R_f_W)
                b = solve_selected_bgp_at(
                    p_seed, N_US, N_W; x0_actual=x0, verbose=false,
                )
            end

            finite_bgp = all(isfinite, (
                b.φ_US, b.φ_W, b.q_US, b.q_W, b.d_US, b.d_W,
                b.Y_US, b.Y_W, b.ν_b_eff, b.residual_norm,
            ))
            finite_bgp || error("Non-finite absorbing BGP at t=$(t).")
            b.converged || error("Absorbing BGP did not converge at t=$(t).")
            b.residual_norm <= RESID_TOL ||
                error("Absorbing BGP residual exceeds tolerance at t=$(t).")
            log_gap = b.ν_b_eff * log(b.G_N_US) - p.ξ_W * log(b.G_N_W)
            abs(log_gap) <= COMMON_GROWTH_TOL ||
                error("Common-growth gap exceeds tolerance at t=$(t).")
            0.0 < b.ν_b_eff < p.ν_u - 1e-3 ||
                error("Effective exponent violates ordering at t=$(t).")

            push!(path, augmented_b_record(t, b, p))
            push!(bgp_objects, b)
            N_US *= G_N_US(p, b.φ_US)
            N_W *= G_N_W(p, b.φ_W)
        end
    end

    return path, bgp_objects
end

sim, realized_bgps = build_checked_switch_path(result, SWITCH_PERIOD; T=FINAL_T)

# Run Notebook 05's literal helper as an audit object.  It is not used for the
# reported path because its common-growth calibration restarts from the global
# reference exponent at every post-switch state and can silently return NaNs.
# An exception in this auxiliary audit must not suppress the checked exports.
original_helper_audit = try
    (path=build_switch_path(result, SWITCH_PERIOD; T=FINAL_T), error=missing)
catch err
    (path=NamedTuple[], error=sprint(showerror, err))
end
original_helper_path = original_helper_audit.path
original_helper_completed =
    original_helper_audit.error === missing && length(original_helper_path) == FINAL_T

# -----------------------------------------------------------------------------
# Timing, equilibrium, and continuation validation
# -----------------------------------------------------------------------------

numeric_state_fields = (
    :φ_US, :φ_W, :q_US, :d_US, :q_W, :d_W, :Q_US, :Q_W,
    :e_US, :e_W, :Y_US, :Y_W, :N_US, :N_W, :I_US, :I_W,
    :ω, :ω_star, :θ, :θ_US_star, :R_f, :R_f_W, :Psi,
)

scaled_error(x, y) = abs(x - y) / max(1.0, abs(x), abs(y))

function us_nfa(s, p::ProductionParams)
    return p.β * s.e_US - s.Q_US
end

function us_nfa_from_portfolios(s, p::ProductionParams)
    A_US = p.β * s.e_US
    # RoW convenience demand for the U.S. bond changes total RoW saving.
    A_W = (p.β + p.χ) / (1 + p.χ) * s.e_W
    foreign_equity_assets = (1 - s.ω) * (1 - s.θ) * A_US
    foreign_held_US_equity = s.ω_star * (1 - s.θ_US_star) * A_W
    US_bond_position = s.θ * A_US
    return foreign_equity_assets - foreign_held_US_equity + US_bond_position
end

regime_timing_ok = all(sim[t].regime == (t < SWITCH_PERIOD ? :u : :b)
                       for t in eachindex(sim))
pre_switch_state_error = maximum(
    scaled_error(getfield(sim[t], field), getfield(result.u_path[t], field))
    for t in 1:(SWITCH_PERIOD - 1), field in numeric_state_fields
)
switch_knowledge_error = max(
    scaled_error(sim[SWITCH_PERIOD].N_US, result.u_path[SWITCH_PERIOD].N_US),
    scaled_error(sim[SWITCH_PERIOD].N_W, result.u_path[SWITCH_PERIOD].N_W),
)
switch_bgp_match_error = maximum(
    scaled_error(getfield(sim[SWITCH_PERIOD], field),
                 getfield(result.bgp_seq[SWITCH_PERIOD], field))
    for field in numeric_state_fields
)

post_knowledge_US_error = maximum(
    scaled_error(
        sim[t + 1].N_US,
        sim[t].N_US * G_N_US(p, sim[t].φ_US),
    ) for t in SWITCH_PERIOD:(FINAL_T - 1)
)
post_knowledge_W_error = maximum(
    scaled_error(
        sim[t + 1].N_W,
        sim[t].N_W * G_N_W(p, sim[t].φ_W),
    ) for t in SWITCH_PERIOD:(FINAL_T - 1)
)

all_checked_finite = all(
    s -> all(field -> isfinite(getfield(s, field)), numeric_state_fields), sim,
)
all_bgp_converged = all(b -> b.converged, realized_bgps)
max_realized_bgp_residual = maximum(b.residual_norm for b in realized_bgps)
max_common_log_gap = maximum(
    abs(s.common_growth_log_gap) for s in sim if s.regime == :b
)
nu_eff_path = Float64[s.nu_b_eff for s in sim if s.regime == :b]
nu_eff_min = minimum(nu_eff_path)
nu_eff_max = maximum(nu_eff_path)
nu_eff_span = nu_eff_max - nu_eff_min

original_finite = original_helper_completed ? Bool[
    all(field -> isfinite(getfield(s, field)), numeric_state_fields)
    for s in original_helper_path
] : fill(false, FINAL_T)
original_first_nonfinite = findfirst(!, original_finite)
original_comparison_end = something(original_first_nonfinite, FINAL_T + 1) - 1
original_match_error = original_comparison_end >= 1 ? maximum(
    scaled_error(getfield(sim[t], field), getfield(original_helper_path[t], field))
    for t in 1:original_comparison_end, field in numeric_state_fields
) : Inf
switch_price_drop_ok =
    sim[SWITCH_PERIOD].q_US < result.u_path[SWITCH_PERIOD].q_US
max_nfa_identity_error = maximum(
    scaled_error(us_nfa(s, p), us_nfa_from_portfolios(s, p)) for s in sim
)
notebook15_target_rebased_nfa = as_float(selected_row["target_rebased_NFA"])
realized_target_rebased_nfa =
    (us_nfa(sim[15], p) - us_nfa(sim[1], p)) / sim[15].Y_US
notebook15_rebased_nfa_error =
    abs(realized_target_rebased_nfa - notebook15_target_rebased_nfa)

validation_rows = Dict{String,Any}[
    Dict("check"=>"regime_timing", "value"=>regime_timing_ok,
         "tolerance"=>"exact", "passed"=>regime_timing_ok,
         "interpretation"=>"u in periods 1:15 and b in periods 16:30."),
    Dict("check"=>"pre_switch_state_match", "value"=>pre_switch_state_error,
         "tolerance"=>STATE_MATCH_TOL, "passed"=>pre_switch_state_error <= STATE_MATCH_TOL,
         "interpretation"=>"Realized path equals the solved all-u branch before the switch."),
    Dict("check"=>"switch_knowledge_inheritance", "value"=>switch_knowledge_error,
         "tolerance"=>STATE_MATCH_TOL, "passed"=>switch_knowledge_error <= STATE_MATCH_TOL,
         "interpretation"=>"Period-16 knowledge is inherited from period-15 u innovation."),
    Dict("check"=>"switch_bgp_match", "value"=>switch_bgp_match_error,
         "tolerance"=>STATE_MATCH_TOL, "passed"=>switch_bgp_match_error <= STATE_MATCH_TOL,
         "interpretation"=>"The period-16 b state equals the stored switch successor at the same state."),
    Dict("check"=>"post_switch_US_knowledge_recursion", "value"=>post_knowledge_US_error,
         "tolerance"=>STATE_MATCH_TOL, "passed"=>post_knowledge_US_error <= STATE_MATCH_TOL,
         "interpretation"=>"Post-switch U.S. knowledge uses absorbing allocations."),
    Dict("check"=>"post_switch_RoW_knowledge_recursion", "value"=>post_knowledge_W_error,
         "tolerance"=>STATE_MATCH_TOL, "passed"=>post_knowledge_W_error <= STATE_MATCH_TOL,
         "interpretation"=>"Post-switch RoW knowledge uses absorbing allocations."),
    Dict("check"=>"checked_path_all_finite", "value"=>all_checked_finite,
         "tolerance"=>"exact", "passed"=>all_checked_finite,
         "interpretation"=>"No non-finite state is allowed into the reported path."),
    Dict("check"=>"realized_bgp_convergence", "value"=>all_bgp_converged,
         "tolerance"=>"exact", "passed"=>all_bgp_converged,
         "interpretation"=>"Every realized absorbing equilibrium converges."),
    Dict("check"=>"max_realized_bgp_residual", "value"=>max_realized_bgp_residual,
         "tolerance"=>RESID_TOL, "passed"=>max_realized_bgp_residual <= RESID_TOL,
         "interpretation"=>"Maximum residual over realized b states."),
    Dict("check"=>"max_common_growth_log_gap", "value"=>max_common_log_gap,
         "tolerance"=>COMMON_GROWTH_TOL, "passed"=>max_common_log_gap <= COMMON_GROWTH_TOL,
         "interpretation"=>"Pathwise common growth at every realized b state."),
    Dict("check"=>"effective_exponent_ordering", "value"=>nu_eff_max,
         "tolerance"=>p.ν_u - 1e-3, "passed"=>nu_eff_max < p.ν_u - 1e-3,
         "interpretation"=>"Every realized nu_b_eff remains below nu_u."),
    Dict("check"=>"switch_price_below_all_u_counterfactual",
         "value"=>sim[SWITCH_PERIOD].q_US / result.u_path[SWITCH_PERIOD].q_US - 1.0,
         "tolerance"=>"< 0", "passed"=>switch_price_drop_ok,
         "interpretation"=>"At the same inherited state, the realized b equity price is below the all-u price."),
    Dict("check"=>"US_NFA_portfolio_identity", "value"=>max_nfa_identity_error,
         "tolerance"=>STATE_MATCH_TOL,
         "passed"=>max_nfa_identity_error <= STATE_MATCH_TOL,
         "interpretation"=>"NFA = beta*e_US - Q_US equals the explicit foreign-asset, equity-liability, and bond position."),
    Dict("check"=>"Notebook15_rebased_NFA_match",
         "value"=>notebook15_rebased_nfa_error,
         "tolerance"=>STATE_MATCH_TOL,
         "passed"=>notebook15_rebased_nfa_error <= STATE_MATCH_TOL,
         "interpretation"=>"The period-15 rebased NFA change uses Notebook 15's (NFA_t-NFA_1)/current Y_t definition."),
    Dict("check"=>"original_helper_audit_completed",
         "value"=>original_helper_completed, "tolerance"=>"exact",
         "passed"=>original_helper_completed,
         "interpretation"=>"The auxiliary Notebook-05 literal-helper audit returned a full-length path."),
    Dict("check"=>"original_helper_match_before_failure", "value"=>original_match_error,
         "tolerance"=>ORIGINAL_HELPER_MATCH_TOL,
         "passed"=>original_match_error <= ORIGINAL_HELPER_MATCH_TOL,
         "interpretation"=>"Checked continuation agrees within 1e-6 with Notebook 05 wherever its literal helper remains finite."),
]

for row in validation_rows
    row["required"] = row["check"] != "original_helper_audit_completed" &&
                      !(row["check"] == "original_helper_match_before_failure" &&
                        !original_helper_completed)
end
failed_required_checks = [
    string(row["check"]) for row in validation_rows
    if Bool(row["required"]) && !Bool(row["passed"])
]
isempty(failed_required_checks) ||
    error("Required switch-path validation failed: " * join(failed_required_checks, ", "))

# -----------------------------------------------------------------------------
# Notebook 05 Section 2 replication
# -----------------------------------------------------------------------------

T = length(sim)
tt = collect(1:T)
qd_path = Float64[s.q_US / s.d_US for s in sim]
QD_path = Float64[s.Q_US / (s.N_US * s.d_US) for s in sim]
φ_path = Float64[s.φ_US for s in sim]
Y_path = Float64[s.Y_US for s in sim]
rel_path = Float64[s.Y_W / s.Y_US for s in sim]
all_u_qd = Float64[s.q_US / s.d_US for s in result.u_path[1:T]]
market_cap_path = Float64[s.Q_US for s in sim]
all_u_market_cap = Float64[s.Q_US for s in result.u_path[1:T]]
labor_income_path = Float64[s.e_US for s in sim]
all_u_labor_income = Float64[s.e_US for s in result.u_path[1:T]]
nfa_path = Float64[us_nfa(s, p) for s in sim]
nfa_over_Y_path = nfa_path ./ Y_path
all_u_nfa = Float64[us_nfa(s, p) for s in result.u_path[1:T]]
all_u_Y_path = Float64[s.Y_US for s in result.u_path[1:T]]
all_u_nfa_over_Y = all_u_nfa ./ all_u_Y_path
rebased_nfa_path = (nfa_path .- nfa_path[1]) ./ Y_path
all_u_rebased_nfa_path = (all_u_nfa .- all_u_nfa[1]) ./ all_u_Y_path
switch_x = SWITCH_PERIOD - 0.5

p1 = plot(
    tt, qd_path, lw=2.2, marker=:circle,
    label=L"q_{US,t}/d_{US,t}", xlabel="period t",
    ylabel="price-dividend ratio",
    title="Per-variety U.S. price-dividend ratio (b is fundamental)",
)
plot!(p1, tt, all_u_qd, lw=1.7, ls=:dot, color=:gray45,
      label="no-switch all-u counterfactual")
vline!(p1, [switch_x], ls=:dash, color=:red,
       label="realized switch tau = $(SWITCH_PERIOD)")

p2 = plot(
    tt, φ_path, lw=2.2, marker=:circle, label=L"\varphi_{US,t}",
    xlabel="period t", ylabel=L"\varphi", title="U.S. labor allocation",
)
vline!(p2, [switch_x], ls=:dash, color=:red, label="")

p3 = plot(
    tt, Y_path, lw=2.2, marker=:circle, label=L"Y_{US,t}",
    xlabel="period t", ylabel="output (log)", yscale=:log10,
    title="U.S. output",
)
vline!(p3, [switch_x], ls=:dash, color=:red, label="")

p_market_cap = plot(
    tt, market_cap_path, lw=2.2, marker=:circle,
    label=L"Q_{US,t}", xlabel="period t", ylabel="aggregate market value",
    title="U.S. market capitalization",
)
plot!(p_market_cap, tt, all_u_market_cap, lw=1.7, ls=:dot, color=:gray45,
      label="no-switch all-u counterfactual")
vline!(p_market_cap, [switch_x], ls=:dash, color=:red, label="")

p_labor_income = plot(
    tt, labor_income_path, lw=2.2, marker=:circle,
    label=L"e_{US,t}", xlabel="period t", ylabel="labor income",
    title="U.S. labor income",
)
plot!(p_labor_income, tt, all_u_labor_income, lw=1.7, ls=:dot, color=:gray45,
      label="no-switch all-u counterfactual")
vline!(p_labor_income, [switch_x], ls=:dash, color=:red, label="")

p_nfa = plot(
    tt, rebased_nfa_path, lw=2.2, marker=:circle,
    label=L"(NFA_{US,t}-NFA_{US,1})/Y_{US,t}", xlabel="period t",
    ylabel="fraction of current U.S. output",
    title="Rebased U.S. NFA change (Notebook 15 normalization)",
)
plot!(p_nfa, tt, all_u_rebased_nfa_path, lw=1.7, ls=:dot, color=:gray45,
      label="no-switch all-u counterfactual")
hline!(p_nfa, [0.0], ls=:dot, color=:gray65, label="")
vline!(p_nfa, [switch_x], ls=:dash, color=:red, label="")

section2_plot = plot(
    p1, p2, p_market_cap, p3, p_labor_income, p_nfa,
    layout=(3, 2), size=(1200, 1180), margin=8mm,
)
section2_png = joinpath(OUTDIR, "section2_transition_t16.png")
savefig(section2_plot, section2_png)

# -----------------------------------------------------------------------------
# Switch-event diagnostics and exports
# -----------------------------------------------------------------------------

pre = sim[SWITCH_PERIOD - 1]
burst = sim[SWITCH_PERIOD]
counterfactual = result.u_path[SWITCH_PERIOD]

percent_change(new, old) = 100.0 * (new / old - 1.0)

switch_event_rows = Dict{String,Any}[
    Dict("variable"=>"q_US_over_d_US", "t15_u"=>pre.q_US / pre.d_US,
         "t16_b"=>burst.q_US / burst.d_US,
         "t16_all_u_counterfactual"=>counterfactual.q_US / counterfactual.d_US),
    Dict("variable"=>"aggregate_price_dividend", "t15_u"=>pre.Q_US / (pre.N_US * pre.d_US),
         "t16_b"=>burst.Q_US / (burst.N_US * burst.d_US),
         "t16_all_u_counterfactual"=>counterfactual.Q_US / (counterfactual.N_US * counterfactual.d_US)),
    Dict("variable"=>"q_US", "t15_u"=>pre.q_US, "t16_b"=>burst.q_US,
         "t16_all_u_counterfactual"=>counterfactual.q_US),
    Dict("variable"=>"d_US", "t15_u"=>pre.d_US, "t16_b"=>burst.d_US,
         "t16_all_u_counterfactual"=>counterfactual.d_US),
    Dict("variable"=>"phi_US", "t15_u"=>pre.φ_US, "t16_b"=>burst.φ_US,
         "t16_all_u_counterfactual"=>counterfactual.φ_US),
    Dict("variable"=>"Y_US", "t15_u"=>pre.Y_US, "t16_b"=>burst.Y_US,
         "t16_all_u_counterfactual"=>counterfactual.Y_US),
    Dict("variable"=>"Y_W_over_Y_US", "t15_u"=>pre.Y_W / pre.Y_US,
         "t16_b"=>burst.Y_W / burst.Y_US,
         "t16_all_u_counterfactual"=>counterfactual.Y_W / counterfactual.Y_US),
]
for row in switch_event_rows
    row["change_t15_to_t16_percent"] =
        percent_change(row["t16_b"], row["t15_u"])
    row["burst_vs_t16_all_u_percent"] =
        percent_change(row["t16_b"], row["t16_all_u_counterfactual"])
end

function csv_cell(x)
    if x === missing || x === nothing
        return ""
    end
    s = string(x)
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

path_rows = Dict{String,Any}[]
for t in 1:T
    s = sim[t]
    u = result.u_path[t]
    push!(path_rows, Dict{String,Any}(
        "t"=>t, "regime"=>s.regime, "is_switch"=>t == SWITCH_PERIOD,
        "N_US"=>s.N_US, "N_W"=>s.N_W,
        "e_US"=>s.e_US, "e_W"=>s.e_W,
        "phi_US"=>s.φ_US, "phi_W"=>s.φ_W,
        "q_US"=>s.q_US, "d_US"=>s.d_US, "q_US_over_d_US"=>qd_path[t],
        "Q_US"=>s.Q_US, "aggregate_price_dividend_US"=>QD_path[t],
        "Y_US"=>s.Y_US, "Y_W"=>s.Y_W, "Y_W_over_Y_US"=>rel_path[t],
        "omega"=>s.ω, "omega_star"=>s.ω_star,
        "theta"=>s.θ, "theta_US_star"=>s.θ_US_star,
        "R_f"=>s.R_f, "R_f_W"=>s.R_f_W,
        "I_US"=>s.I_US, "I_W"=>s.I_W, "Psi"=>s.Psi,
        "nu_b_eff"=>s.nu_b_eff, "bgp_converged"=>s.bgp_converged,
        "bgp_residual"=>s.bgp_residual,
        "common_growth_log_gap"=>s.common_growth_log_gap,
        "NFA_US"=>nfa_path[t], "NFA_US_over_Y"=>nfa_over_Y_path[t],
        "rebased_NFA_change_current_Y"=>rebased_nfa_path[t],
        "all_u_q_US"=>u.q_US, "all_u_d_US"=>u.d_US,
        "all_u_q_US_over_d_US"=>all_u_qd[t],
        "all_u_Y_US"=>u.Y_US, "all_u_e_US"=>u.e_US,
        "all_u_Q_US"=>u.Q_US, "all_u_NFA_US"=>all_u_nfa[t],
        "all_u_NFA_US_over_Y"=>all_u_nfa_over_Y[t],
        "all_u_rebased_NFA_change_current_Y"=>all_u_rebased_nfa_path[t],
        "original_helper_finite"=>original_finite[t],
    ))
end

path_columns = [
    "t", "regime", "is_switch", "N_US", "N_W", "e_US", "e_W",
    "phi_US", "phi_W",
    "q_US", "d_US", "q_US_over_d_US", "Q_US",
    "aggregate_price_dividend_US", "Y_US", "Y_W", "Y_W_over_Y_US",
    "omega", "omega_star", "theta", "theta_US_star", "R_f", "R_f_W",
    "I_US", "I_W", "Psi", "nu_b_eff", "bgp_converged", "bgp_residual",
    "common_growth_log_gap", "NFA_US", "NFA_US_over_Y",
    "rebased_NFA_change_current_Y",
    "all_u_q_US", "all_u_d_US", "all_u_q_US_over_d_US",
    "all_u_Y_US", "all_u_e_US", "all_u_Q_US", "all_u_NFA_US",
    "all_u_NFA_US_over_Y", "all_u_rebased_NFA_change_current_Y",
    "original_helper_finite",
]
write_rows_csv(joinpath(OUTDIR, "switch_path_t16.csv"), path_rows, path_columns)

write_rows_csv(
    joinpath(OUTDIR, "switch_event_summary.csv"), switch_event_rows,
    ["variable", "t15_u", "t16_b", "t16_all_u_counterfactual",
     "change_t15_to_t16_percent", "burst_vs_t16_all_u_percent"],
)

write_rows_csv(
    joinpath(OUTDIR, "simulation_validation.csv"), validation_rows,
    ["check", "value", "tolerance", "passed", "required", "interpretation"],
)

calibration_rows = Dict{String,Any}[
    Dict("parameter"=>"selected_candidate", "value"=>SELECTED_LABEL,
         "source"=>"Notebook 15 T=30 finalist re-ranking"),
    Dict("parameter"=>"switch_period", "value"=>SWITCH_PERIOD,
         "source"=>"User-specified realized event"),
    Dict("parameter"=>"beta", "value"=>p.β, "source"=>"Notebook 15"),
    Dict("parameter"=>"gamma", "value"=>p.γ, "source"=>"Notebook 15"),
    Dict("parameter"=>"pi_persist", "value"=>p.π_persist, "source"=>"Notebook 15"),
    Dict("parameter"=>"kappa", "value"=>p.κ, "source"=>"Notebook 15"),
    Dict("parameter"=>"omega_bar", "value"=>p.ω̄, "source"=>"Notebook 15"),
    Dict("parameter"=>"omega_bar_star", "value"=>p.ω̄_star, "source"=>"Notebook 15"),
    Dict("parameter"=>"chi", "value"=>p.χ, "source"=>"Notebook 15"),
    Dict("parameter"=>"eta", "value"=>p.η, "source"=>"Notebook 15"),
    Dict("parameter"=>"a_US", "value"=>p.a_US, "source"=>"Notebook 15"),
    Dict("parameter"=>"vartheta_US", "value"=>p.ϑ_US, "source"=>"Notebook 15"),
    Dict("parameter"=>"a_W", "value"=>p.a_W, "source"=>"Notebook 15"),
    Dict("parameter"=>"H_W", "value"=>p.H_W, "source"=>"Notebook 15"),
    Dict("parameter"=>"L_W", "value"=>p.L_W, "source"=>"Notebook 15"),
    Dict("parameter"=>"A_X_US_u", "value"=>p.A_X_US_u, "source"=>"Notebook 15"),
    Dict("parameter"=>"A_L_US_u", "value"=>p.A_L_US_u, "source"=>"Notebook 15"),
    Dict("parameter"=>"nu_u", "value"=>p.ν_u, "source"=>"Notebook 15"),
    Dict("parameter"=>"xi_u", "value"=>p.ξ_u, "source"=>"Notebook 15"),
    Dict("parameter"=>"xi_W", "value"=>p.ξ_W, "source"=>"Notebook 15"),
    Dict("parameter"=>"nu_b_input_seed", "value"=>input_params.ν_b,
         "source"=>"Notebook 15"),
    Dict("parameter"=>"nu_b_reference_calibrated", "value"=>p.ν_b,
         "source"=>"Cold re-solve"),
    Dict("parameter"=>"realized_nu_b_eff_min", "value"=>nu_eff_min,
         "source"=>"Period-16 realized b path"),
    Dict("parameter"=>"realized_nu_b_eff_max", "value"=>nu_eff_max,
         "source"=>"Period-16 realized b path"),
]
write_rows_csv(
    joinpath(OUTDIR, "calibration_provenance.csv"), calibration_rows,
    ["parameter", "value", "source"],
)

@printf("\nSwitch event at t=%d\n", SWITCH_PERIOD)
@printf("  q_US/d_US: t15 %.6f -> t16 b %.6f (%+.3f%%); t16 all-u %.6f\n",
        pre.q_US / pre.d_US, burst.q_US / burst.d_US,
        percent_change(burst.q_US / burst.d_US, pre.q_US / pre.d_US),
        counterfactual.q_US / counterfactual.d_US)
@printf("  q_US:      t15 %.6f -> t16 b %.6f (%+.3f%%)\n",
        pre.q_US, burst.q_US, percent_change(burst.q_US, pre.q_US))
@printf("  d_US:      t15 %.6f -> t16 b %.6f (%+.3f%%)\n",
        pre.d_US, burst.d_US, percent_change(burst.d_US, pre.d_US))
@printf("  Y_US:      t15 %.6f -> t16 b %.6f (%+.3f%%)\n",
        pre.Y_US, burst.Y_US, percent_change(burst.Y_US, pre.Y_US))
@printf("  rebased NFA/current Y: t15 %+.6f -> t16 b %+.6f; t16 all-u %+.6f\n",
        rebased_nfa_path[SWITCH_PERIOD - 1], rebased_nfa_path[SWITCH_PERIOD],
        all_u_rebased_nfa_path[SWITCH_PERIOD])
@printf("  realized nu_b_eff range: [%.9f, %.9f], span %.3e\n",
        nu_eff_min, nu_eff_max, nu_eff_span)
@printf("  maximum b residual: %.3e; common-growth log gap: %.3e\n",
        max_realized_bgp_residual, max_common_log_gap)
println("  literal Notebook-05 helper first non-finite period: ",
        original_first_nonfinite === nothing ? "none" : original_first_nonfinite)
original_helper_audit.error === missing ||
    println("  literal Notebook-05 helper audit error: ", original_helper_audit.error)
println("  checked continuation is finite through period ", FINAL_T)
println("\nInterpretation: period 16 is a realized, unannounced switch under hazard pi,")
println("not a date-16 event anticipated by agents when they choose earlier portfolios.")
println("The b branch is fundamental by equilibrium selection. A q/d decline is not")
println("the definition of bubble collapse: here q drops, but d drops by more, so q/d rises.")
println("\nExports:")
foreach(name -> println("  - ", name), sort(readdir(OUTDIR)))

section2_plot
