using Pkg

# Zero-nu_b replication of the common-growth Notebook 19 workflow.  The
# source calibration artifacts are read only as immutable benchmarks; all
# model code and all newly written artifacts live in this sibling directory.

function nb19_find_project_dir(start_dir=pwd())
    dir = abspath(start_dir)
    while true
        for candidate in (dir, joinpath(dir, "Codes"))
            project = joinpath(candidate, "Project.toml")
            model = joinpath(candidate, "Two_country_proudction_zero_nu_b",
                             "TwoCountryProductionOLG.jl")
            isfile(project) && isfile(model) && return candidate
        end
        parent = dirname(dir)
        parent == dir && error(
            "Could not locate Codes/Project.toml and TwoCountryProductionOLG.jl from $(start_dir)",
        )
        dir = parent
    end
end

const NB19_PROJECT_DIR = nb19_find_project_dir()
Pkg.activate(NB19_PROJECT_DIR)
cd(NB19_PROJECT_DIR)

const NB19_MODEL_FILE = joinpath(
    NB19_PROJECT_DIR, "Two_country_proudction_zero_nu_b", "TwoCountryProductionOLG.jl",
)
if @isdefined ProductionParams
    @isdefined(_require_zero_nu_b) || error(
        "A non-zero-exponent TwoCountryProductionOLG solver is already loaded. " *
        "Restart the Julia kernel before running Notebook 03.",
    )
else
    include(NB19_MODEL_FILE)
end

using DelimitedFiles
using Plots, Printf, Statistics
using Plots.PlotMeasures

gr()
default(
    size=(950, 520), framestyle=:box, grid=:y, legend=:best,
    fontfamily="Computer Modern", linewidth=2,
    titlefontsize=11, guidefontsize=10, tickfontsize=9, legendfontsize=8,
    left_margin=9mm, right_margin=7mm, top_margin=7mm, bottom_margin=8mm,
)

# Keep the requested name explicit in the notebook namespace.
const SOURCE_REQUESTED_T = 110
const T_solved = 78
const NB19_AHP_TARGET_END = 15
const NB19_N_BUFFER = 0
const NB19_BRANCH_ITER_SCHEDULE = [60, 200, 500]
const NB19_CONTINUATION_HORIZONS = [30, 45, 60, 70, 75, 76, 77, T_solved]
const NB19_FRONTIER_PROBE_HORIZONS = [79, 80, 81]
const NB19_FIRST_NONINTERIOR_T = 79
const NB19_FIRST_RESIDUAL_UNSAFE_T = 81
const NB19_RUN_FRONTIER_AUDIT = lowercase(get(
    ENV, "NB03_ZERO_NU_B_RUN_FRONTIER_AUDIT", "false",
)) in ("1", "true", "yes")
const NB19_FRONTIER_BRANCH_ITERS = parse(Int, get(
    ENV, "NB03_ZERO_NU_B_FRONTIER_BRANCH_ITERS", "500",
))

const NB19_RESID_TOL = 1e-5
const NB19_PSI_INTERIOR_TOL = 0.02
const NB19_EQUITY_INTERIOR_TOL = 0.01
const NB19_THETA_INTERIOR_TOL = 0.01
const NB19_ACCOUNTING_SCALED_TOL = 1e-7
const NB19_ABSORBING_INVARIANCE_TOL = 1e-10
const NB19_PHI_INTERIOR_MARGIN = 1e-8
const NB19_PHI_FLOOR = 1e-3
const NB19_FIRST_WINDOW_MATCH_TOL = 2e-5

const NB19_OUTDIR = get(
    ENV, "NB03_ZERO_NU_B_OUTDIR",
    joinpath(
        NB19_PROJECT_DIR, "Two_country_proudction_zero_nu_b", "outputs_zero_nu_b",
        "03_ahp_pattern_source_T110_resolved_T78",
    ),
)
const NB19_NB15_DIR = joinpath(
    NB19_PROJECT_DIR, "Two_country_production_common_growth", "outputs_v43",
    "ahp_pattern_first_window_common_growth_search",
)
mkpath(NB19_OUTDIR)

println("Project directory:             ", NB19_PROJECT_DIR)
println("Output directory:              ", NB19_OUTDIR)
println("Certified zero-case horizon:   ", T_solved)
println("Scratch buffer:                ", NB19_N_BUFFER)
println("Zero nu_b = xi_W:             0.0")
println("Common-growth equation:        absent (1 = 1 identity)")
println("Source requested horizon:       ", SOURCE_REQUESTED_T)
println("Frontier probes:                ", NB19_FRONTIER_PROBE_HORIZONS)
println("Run expensive frontier audit:  ", NB19_RUN_FRONTIER_AUDIT)
println("Source calibration benchmark:  ", NB19_NB15_DIR)
println("Warm-continuation horizons:    ", NB19_CONTINUATION_HORIZONS)
println("Branch-iteration schedule:     ", NB19_BRANCH_ITER_SCHEDULE)

# -----------------------------------------------------------------------------
# CSV helpers and Notebook 15 targets
# -----------------------------------------------------------------------------

function nb19_read_csv_any(path::AbstractString)
    isfile(path) || error("Required CSV not found: $(path)")
    data, header = readdlm(path, ',', Any, '\n'; header=true, quotes=true)
    matrix = ndims(data) == 1 ? reshape(data, 1, :) : data
    names = String.(vec(header))
    size(matrix, 2) == length(names) || error("CSV header mismatch: $(path)")
    return matrix, names
end

function nb19_col_index(names, name)
    idx = findfirst(==(name), names)
    idx === nothing && error("Missing CSV column $(name)")
    return idx
end

nb19_float(x) = x isa Number ? Float64(x) : parse(Float64, string(x))

function nb19_csv_cell(x)
    s = x === missing ? "" : string(x)
    if occursin(',', s) || occursin('"', s) || occursin('\n', s)
        return "\"" * replace(s, "\"" => "\"\"") * "\""
    end
    return s
end

function nb19_row_value(row, column::String)
    if row isa NamedTuple
        return hasproperty(row, Symbol(column)) ? getproperty(row, Symbol(column)) : missing
    end
    return get(row, column, missing)
end

function nb19_write_rows_csv(path, rows, columns)
    open(path, "w") do io
        println(io, join(columns, ','))
        for row in rows
            println(io, join((nb19_csv_cell(nb19_row_value(row, c)) for c in columns), ','))
        end
    end
    return path
end

# -----------------------------------------------------------------------------
# Notebook 17's long-horizon numerical method
# -----------------------------------------------------------------------------

# This is Notebook 17's local log-linear artificial successor.  It is installed
# notebook-locally so the T=78 solve does not depend on whatever closure another
# notebook may have left in the Julia session.
nb19_phi_clamp(x) = clamp(Float64(x), NB19_PHI_FLOOR, 1 - NB19_PHI_FLOOR)

function nb19_local_loglinear_phi(pol::Matrix{Float64}, i::Int, T::Int)
    if T >= 2
        a, b = pol[i, T - 1], pol[i, T]
        if isfinite(a) && isfinite(b) && a > 0 && b > 0
            return nb19_phi_clamp(b * b / a)
        end
    end
    return nb19_phi_clamp(pol[i, T])
end

function _extrapolate_terminal!(pol::Matrix{Float64}, T::Int)
    pol[:, T + 1] .= pol[:, T]
    pol[1, T + 1] = nb19_local_loglinear_phi(pol, 1, T)
    pol[2, T + 1] = nb19_local_loglinear_phi(pol, 2, T)
    return pol
end

function nb19_params(T::Int, branch_iters::Int)
    return ProductionParams(
        T_max=T, n_buffer=NB19_N_BUFFER, common_world_growth=false,
        β=0.45, γ=0.25, π_persist=0.75,
        a_US=0.20, ϑ_US=0.85,
        a_W=0.06, H_W=3.0, L_W=3.0,
        A_X_US_u=15.0, A_L_US_u=1.5,
        ν_b=0.00, ν_u=1.75, ξ_u=2.25, ξ_W=0.00,
        ω̄=0.50, ω̄_star=0.25,
        κ=1.00, χ=0.0002, η=0.010,
        φ_floor=NB19_PHI_FLOOR,
        branch_iters=branch_iters, do_global_polish=false,
    )
end

function nb19_model_residual_safe(result)
    return result.branch_converged &&
           isfinite(result.max_u_residual) &&
           isfinite(result.max_bgp_residual) &&
           result.max_u_residual <= NB19_RESID_TOL &&
           result.max_bgp_residual <= NB19_RESID_TOL
end

nb19_solve_rows = Dict{String,Any}[]
nb19_warm_result = nothing
nb19_warm_T = missing

for T in NB19_CONTINUATION_HORIZONS
    solved_here = nothing
    seed_result = nb19_warm_result
    seed_T = nb19_warm_T
    for branch_iters in NB19_BRANCH_ITER_SCHEDULE
        @printf(
            "Solving T=%d, buffer=%d, branch_iters=%d, warm_T=%s\n",
            T, NB19_N_BUFFER, branch_iters,
            seed_T === missing ? "" : string(seed_T),
        )
        started = time()
        try
            result = run_production_simulation(
                nb19_params(T, branch_iters);
                verbose=false,
                initial_u_path=seed_result === nothing ? nothing : seed_result.u_path_extended,
            )
            safe = nb19_model_residual_safe(result)
            push!(nb19_solve_rows, Dict{String,Any}(
                "T_solved"=>T,
                "n_buffer"=>NB19_N_BUFFER,
                "branch_iters"=>branch_iters,
                "warm_start_T"=>seed_T,
                "status"=>"ok",
                "elapsed_sec"=>time() - started,
                "branch_converged"=>result.branch_converged,
                "max_u_residual"=>result.max_u_residual,
                "max_bgp_residual"=>result.max_bgp_residual,
                "residual_safe"=>safe,
                "error"=>"",
            ))
            if safe
                solved_here = result
                break
            end
            seed_result = result
            seed_T = T
        catch err
            push!(nb19_solve_rows, Dict{String,Any}(
                "T_solved"=>T,
                "n_buffer"=>NB19_N_BUFFER,
                "branch_iters"=>branch_iters,
                "warm_start_T"=>seed_T,
                "status"=>"error",
                "elapsed_sec"=>time() - started,
                "branch_converged"=>missing,
                "max_u_residual"=>missing,
                "max_bgp_residual"=>missing,
                "residual_safe"=>false,
                "error"=>sprint(showerror, err),
            ))
        end
    end
    solved_here === nothing && error(
        "No residual-safe solve at T=$(T) under iteration schedule $(NB19_BRANCH_ITER_SCHEDULE)",
    )
    global nb19_warm_result = solved_here
    global nb19_warm_T = T
end

best_result = nb19_warm_result
length(best_result.u_path) == T_solved || error("Final reported path is not T=78")

nb19_solve_columns = [
    "T_solved", "n_buffer", "branch_iters", "warm_start_T", "status",
    "elapsed_sec", "branch_converged", "max_u_residual", "max_bgp_residual",
    "residual_safe", "error",
]
nb19_write_rows_csv(
    joinpath(NB19_OUTDIR, "continuation_solve_summary.csv"),
    nb19_solve_rows, nb19_solve_columns,
)

# -----------------------------------------------------------------------------
# Notebook 15's AHP accounting, without its obsolete fundamental-value call
# -----------------------------------------------------------------------------

nb19_path_vector(result, field::Symbol) =
    Float64[getfield(s, field) for s in result.u_path]

function nb19_ahp_accounting(result::ProductionSimulationResult)
    T = length(result.u_path)
    T >= 3 || error("AHP accounting needs at least three periods")

    q_US = nb19_path_vector(result, :q_US)
    q_W = nb19_path_vector(result, :q_W)
    Y_US = nb19_path_vector(result, :Y_US)
    e_US = nb19_path_vector(result, :e_US)
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
    delta_NFA = zeros(T)
    RES = zeros(T)
    for t in 2:T
        delta_NFA[t] = NFA[t] - NFA[t - 1]
        RES[t] = delta_NFA[t] - CA[t] - VA[t]
    end

    cum_VA_asset = cumsum(VA_asset)
    cum_VA_liability = cumsum(VA_liability)
    cum_CA_asset = cumsum(CA_asset)
    cum_CA_liability = cumsum(CA_liability)
    cum_CA_bond = cumsum(CA_bond)
    cum_VA = cumsum(VA)
    cum_CA = cumsum(CA)
    cum_RES = cumsum(RES)

    # Notebook 15 called nfa_decomposition only to recover this identity, but
    # that function also triggers a terminal fundamental-value recursion.  The
    # direct equilibrium identity is the same object and is safe at T=78.
    equilibrium_NFA = Float64[s.A - s.Q_US for s in result.u_path]

    return (
        T=T, q_US=q_US, q_W=q_W, Y_US=Y_US, e_US=e_US,
        n_W=n_W, n_US_star=n_US_star, bond=bond,
        asset_position=asset_position, liability_position=liability_position,
        NFA=NFA, delta_NFA=delta_NFA,
        VA_asset=VA_asset, VA_liability=VA_liability, VA=VA,
        CA_asset=CA_asset, CA_liability=CA_liability, CA_bond=CA_bond, CA=CA,
        RES=RES,
        cum_VA_asset=cum_VA_asset, cum_VA_liability=cum_VA_liability,
        cum_CA_asset=cum_CA_asset, cum_CA_liability=cum_CA_liability,
        cum_CA_bond=cum_CA_bond, cum_VA=cum_VA, cum_CA=cum_CA,
        cum_RES=cum_RES,
        residual_max=maximum(abs.(RES[2:end])),
        nfa_identity_error=maximum(abs.(NFA .- equilibrium_NFA)),
    )
end

function nb19_metrics(a; target_end=NB19_AHP_TARGET_END)
    e = min(target_end, a.T)
    Y_e = a.Y_US[e]
    evidence = 2:e
    rebased_path = (a.NFA .- a.NFA[1]) ./ a.Y_US
    target_asset_va = a.cum_VA_asset[e] / Y_e
    target_liability_va = a.cum_VA_liability[e] / Y_e
    target_net_va = a.cum_VA[e] / Y_e
    target_ca = a.cum_CA[e] / Y_e
    return (
        target_end=e,
        target_rebased_nfa=(a.NFA[e] - a.NFA[1]) / Y_e,
        target_asset_va=target_asset_va,
        target_liability_va=target_liability_va,
        target_net_va=target_net_va,
        target_ca=target_ca,
        target_foreign_exposure=mean(a.liability_position[evidence] ./ a.Y_US[evidence]),
        liability_share_of_gross_va=abs(target_liability_va) /
            max(abs(target_liability_va) + abs(target_asset_va), 1e-12),
        post_target_rebased_change=rebased_path[end] - rebased_path[e],
        endpoint_rebased_nfa=rebased_path[end],
    )
end

function nb19_absorbing_normalization_diagnostics(result)
    p = result.params
    bgps = result.bgp_seq_extended
    reference = first(bgps)
    policy_fields = (:φ_US, :φ_W, :ω, :ω_star, :θ, :θ_US_star, :R_f, :R_f_W)
    aggregate_fields = (:Y_US, :Y_W, :e_US, :e_W, :Q_US, :Q_W,
                        :I_US, :I_W, :R_US, :R_W, :R_p, :R_A,
                        :R_p_star, :R_A_star, :G_N_US, :G_N_W, :Psi)
    rows = Dict{String,Any}[]
    for (j, b) in enumerate(bgps)
        policy_error = maximum(abs(getfield(b, f) - getfield(reference, f))
            for f in policy_fields)
        aggregate_error = maximum(abs(getfield(b, f) - getfield(reference, f))
            for f in aggregate_fields)
        scaling_error = max(
            abs(b.N_US * b.q_US - reference.N_US * reference.q_US),
            abs(b.N_US * b.d_US - reference.N_US * reference.d_US),
            abs(b.N_W * b.q_W - reference.N_W * reference.q_W),
            abs(b.N_W * b.d_W - reference.N_W * reference.d_W),
        )
        push!(rows, Dict{String,Any}(
            "switch_index"=>j - 1,
            "N_US"=>b.N_US, "N_W"=>b.N_W,
            "q_US"=>b.q_US, "d_US"=>b.d_US,
            "q_W"=>b.q_W, "d_W"=>b.d_W,
            "Nq_US"=>b.N_US * b.q_US, "Nd_US"=>b.N_US * b.d_US,
            "Nq_W"=>b.N_W * b.q_W, "Nd_W"=>b.N_W * b.d_W,
            "Q_US"=>b.Q_US, "Q_W"=>b.Q_W,
            "nu_b_compatibility_constant"=>b.ν_b_eff,
            "policy_invariance_error"=>policy_error,
            "aggregate_invariance_error"=>aggregate_error,
            "per_variety_scaling_error"=>scaling_error,
            "automatic_growth_identity_error"=>max(
                abs(b.G_N_US^p.ν_b - 1.0), abs(b.G_N_W^p.ξ_W - 1.0)),
            "bgp_converged"=>b.converged,
            "bgp_residual_norm"=>b.residual_norm,
        ))
    end
    return rows
end

function nb19_absorbing_normalization_summary(result)
    rows = nb19_absorbing_normalization_diagnostics(result)
    return (
        policy_invariance_error=maximum(Float64(r["policy_invariance_error"]) for r in rows),
        aggregate_invariance_error=maximum(Float64(r["aggregate_invariance_error"]) for r in rows),
        per_variety_scaling_error=maximum(Float64(r["per_variety_scaling_error"]) for r in rows),
        exponent_compatibility_error=maximum(abs(Float64(r["nu_b_compatibility_constant"])) for r in rows),
        automatic_growth_identity_error=maximum(Float64(r["automatic_growth_identity_error"]) for r in rows),
        all_extended_bgp_converged=all(Bool(r["bgp_converged"]) for r in rows),
        max_extended_bgp_residual=maximum(Float64(r["bgp_residual_norm"]) for r in rows),
    )
end

function nb19_hard_validity(result, a, absorbing)
    theta_US_star = nb19_path_vector(result, :θ_US_star)
    finite_accounting = all(isfinite, a.NFA) && all(isfinite, a.CA) &&
                        all(isfinite, a.VA) && all(isfinite, a.Y_US)
    model_residuals = nb19_model_residual_safe(result)
    psi_interior = result.diagnostics.psi_ok &&
        isfinite(result.diagnostics.psi_min) &&
        result.diagnostics.psi_min >= NB19_PSI_INTERIOR_TOL
    equity_interior = result.diagnostics.equity_weights_ok &&
        isfinite(result.diagnostics.equity_weight_min) &&
        result.diagnostics.equity_weight_min >= NB19_EQUITY_INTERIOR_TOL
    theta_interior = all(
        x -> isfinite(x) && NB19_THETA_INTERIOR_TOL <= x < 0.9,
        theta_US_star,
    )
    positive_foreign_claims = all(x -> isfinite(x) && x > 0, a.n_US_star) &&
                              all(x -> isfinite(x) && x > 0, a.liability_position)
    return_fields = (:R_A_u, :R_A_b, :R_A_star_u, :R_A_star_b, :R_f, :R_f_W)
    positive_returns = all(
        field -> all(x -> isfinite(x) && x > 0, nb19_path_vector(result, field)),
        return_fields,
    )
    accounting_scale = max(
        1.0, maximum(abs.(a.NFA)), maximum(abs.(a.CA)), maximum(abs.(a.VA)),
    )
    accounting_exact = isfinite(a.residual_max) && a.residual_max <= NB19_RESID_TOL &&
        a.residual_max / accounting_scale <= NB19_ACCOUNTING_SCALED_TOL &&
        isfinite(a.nfa_identity_error) &&
        a.nfa_identity_error / accounting_scale <= NB19_ACCOUNTING_SCALED_TOL
    phi_values = vcat(nb19_path_vector(result, :φ_US), nb19_path_vector(result, :φ_W))
    phi_lower_slack = minimum(phi_values) - result.params.φ_floor
    phi_upper_slack = (1 - result.params.φ_floor) - maximum(phi_values)
    phi_interior = min(phi_lower_slack, phi_upper_slack) >= NB19_PHI_INTERIOR_MARGIN
    extended_bgp_valid = absorbing.all_extended_bgp_converged &&
                         absorbing.max_extended_bgp_residual <= NB19_RESID_TOL
    normalization_valid = maximum((absorbing.policy_invariance_error,
        absorbing.aggregate_invariance_error, absorbing.per_variety_scaling_error,
        absorbing.exponent_compatibility_error,
        absorbing.automatic_growth_identity_error)) <= NB19_ABSORBING_INVARIANCE_TOL
    p = result.params
    exponent_ordering = p.ξ_u > p.ν_u > p.ν_b >= 0 &&
                        p.ν_b == 0.0 && p.ξ_W == 0.0
    valid = model_residuals && psi_interior && equity_interior && theta_interior &&
        phi_interior && positive_foreign_claims && positive_returns &&
        accounting_exact && finite_accounting && extended_bgp_valid &&
        normalization_valid && exponent_ordering
    return (
        valid=valid,
        model_residuals=model_residuals,
        psi_interior=psi_interior,
        equity_interior=equity_interior,
        theta_interior=theta_interior,
        positive_foreign_claims=positive_foreign_claims,
        positive_returns=positive_returns,
        accounting_exact=accounting_exact,
        finite_accounting=finite_accounting,
        phi_interior=phi_interior,
        phi_lower_slack=phi_lower_slack,
        phi_upper_slack=phi_upper_slack,
        extended_bgp_valid=extended_bgp_valid,
        normalization_valid=normalization_valid,
        exponent_ordering=exponent_ordering,
        accounting_scale=accounting_scale,
    )
end

best_accounting = nb19_ahp_accounting(best_result)
best_metrics = nb19_metrics(best_accounting)
best_absorbing_diagnostics = nb19_absorbing_normalization_diagnostics(best_result)
best_absorbing_summary = nb19_absorbing_normalization_summary(best_result)
best_validity = nb19_hard_validity(best_result, best_accounting, best_absorbing_summary)

best_validity.valid || error("The zero-nu-b T=78 continuation failed a model hard gate")
isapprox(best_result.params.ν_b, 0.0; atol=0.0, rtol=0.0) ||
    error("The zero-nu-b solver did not preserve nu_b=0.0")
isapprox(best_result.params.ξ_W, 0.0; atol=0.0, rtol=0.0) ||
    error("The zero-nu-b calibration did not preserve xi_W=0.0")
best_absorbing_summary.automatic_growth_identity_error == 0.0 ||
    error("The automatic zero-exponent identity failed")

# The high-budget frontier audit is deliberately optional because failed
# horizons can consume tens of CPU-minutes. It is never used in a reported
# equilibrium object. The default records the previously audited qualitative
# outcomes and makes their provenance explicit; setting
# NB03_ZERO_NU_B_RUN_FRONTIER_AUDIT=true reproduces the sequential probes.
nb19_frontier_rows = Dict{String,Any}[]
nb19_frontier_results = Dict{Int,Any}()
if NB19_RUN_FRONTIER_AUDIT
    nb19_frontier_warm = best_result
    for T in NB19_FRONTIER_PROBE_HORIZONS
        warm_T = length(nb19_frontier_warm.u_path)
        started = time()
        probe = run_production_simulation(
            nb19_params(T, NB19_FRONTIER_BRANCH_ITERS);
            verbose=false,
            initial_u_path=nb19_frontier_warm.u_path_extended,
        )
        phi_values = vcat(
            nb19_path_vector(probe, :φ_US), nb19_path_vector(probe, :φ_W),
        )
        phi_lower_slack = minimum(phi_values) - probe.params.φ_floor
        phi_upper_slack = (1 - probe.params.φ_floor) - maximum(phi_values)
        phi_interior = min(phi_lower_slack, phi_upper_slack) >= NB19_PHI_INTERIOR_MARGIN
        residual_safe = nb19_model_residual_safe(probe)
        @printf(
            "Frontier audit T=%d: residual_safe=%s, phi_interior=%s, max_u=%.3e\n",
            T, residual_safe, phi_interior, probe.max_u_residual,
        )
        push!(nb19_frontier_rows, Dict{String,Any}(
            "T_probe"=>T,
            "audit_status"=>"fresh_sequential_solve",
            "documented_outcome"=>"",
            "warm_start_T"=>warm_T,
            "branch_iters"=>NB19_FRONTIER_BRANCH_ITERS,
            "elapsed_sec"=>time() - started,
            "branch_converged"=>probe.branch_converged,
            "max_u_residual"=>probe.max_u_residual,
            "max_bgp_residual"=>probe.max_bgp_residual,
            "phi_lower_slack"=>phi_lower_slack,
            "phi_upper_slack"=>phi_upper_slack,
            "phi_interior"=>phi_interior,
            "residual_safe"=>residual_safe,
        ))
        nb19_frontier_results[T] = (
            result=probe, phi_interior=phi_interior, residual_safe=residual_safe,
        )
        global nb19_frontier_warm = probe
    end

    nb19_frontier_results[NB19_FIRST_NONINTERIOR_T].residual_safe ||
        error("The first non-interior probe must still be residual-safe")
    !nb19_frontier_results[NB19_FIRST_NONINTERIOR_T].phi_interior ||
        error("Expected T=$(NB19_FIRST_NONINTERIOR_T) to touch a labour bound")
    !nb19_frontier_results[NB19_FIRST_RESIDUAL_UNSAFE_T].residual_safe ||
        error("Expected T=$(NB19_FIRST_RESIDUAL_UNSAFE_T) to be residual-unsafe")
else
    documented = Dict(
        79=>"residual-safe but non-interior at the upper labour cap",
        80=>"residual-safe but non-interior",
        81=>"residual-unsafe within the 500-iteration audit budget",
    )
    for T in NB19_FRONTIER_PROBE_HORIZONS
        push!(nb19_frontier_rows, Dict{String,Any}(
            "T_probe"=>T,
            "audit_status"=>"not_rerun; prior zero-case sequential audit",
            "documented_outcome"=>documented[T],
            "warm_start_T"=>T - 1,
            "branch_iters"=>500,
            "elapsed_sec"=>missing,
            "branch_converged"=>missing,
            "max_u_residual"=>missing,
            "max_bgp_residual"=>missing,
            "phi_lower_slack"=>missing,
            "phi_upper_slack"=>missing,
            "phi_interior"=>T < NB19_FIRST_NONINTERIOR_T,
            "residual_safe"=>T < NB19_FIRST_RESIDUAL_UNSAFE_T,
        ))
    end
end

nb19_write_rows_csv(
    joinpath(NB19_OUTDIR, "frontier_probe_summary.csv"),
    nb19_frontier_rows,
    [
        "T_probe", "audit_status", "documented_outcome", "warm_start_T",
        "branch_iters", "elapsed_sec", "branch_converged",
        "max_u_residual", "max_bgp_residual", "phi_lower_slack",
        "phi_upper_slack", "phi_interior", "residual_safe",
    ],
)

# -----------------------------------------------------------------------------
# First-window replication check and machine-readable exports
# -----------------------------------------------------------------------------

nb15_data, nb15_names = nb19_read_csv_any(
    joinpath(NB19_NB15_DIR, "best_ahp_decomposition.csv"),
)
nb15_t_col = nb19_col_index(nb15_names, "t")
nb15_rows_by_t = Dict(
    Int(round(nb19_float(nb15_data[i, nb15_t_col]))) => i
    for i in axes(nb15_data, 1)
)

nb19_replication_series = Dict(
    "rebased_NFA_change_current_Y" =>
        (best_accounting.NFA .- best_accounting.NFA[1]) ./ best_accounting.Y_US,
    "cum_VA_current_Y" => best_accounting.cum_VA ./ best_accounting.Y_US,
    "cum_CA_current_Y" => best_accounting.cum_CA ./ best_accounting.Y_US,
    "cum_RES_current_Y" => best_accounting.cum_RES ./ best_accounting.Y_US,
)

nb19_first_window_errors = Dict{String,Float64}()
for (column, current) in nb19_replication_series
    col = nb19_col_index(nb15_names, column)
    nb19_first_window_errors[column] = maximum(
        abs(current[t] - nb19_float(nb15_data[nb15_rows_by_t[t], col]))
        for t in 1:NB19_AHP_TARGET_END
    )
end
nb19_max_first_window_error = maximum(values(nb19_first_window_errors))
nb19_first_window_matches_source =
    nb19_max_first_window_error <= NB19_FIRST_WINDOW_MATCH_TOL

a = best_accounting
nb19_path_rows = Dict{String,Any}[]
for t in 1:a.T
    push!(nb19_path_rows, Dict{String,Any}(
        "t"=>t,
        "evidence_window"=>t <= NB19_AHP_TARGET_END,
        "Y_US"=>a.Y_US[t],
        "e_US"=>a.e_US[t],
        "q_US"=>a.q_US[t],
        "q_W"=>a.q_W[t],
        "n_W"=>a.n_W[t],
        "n_US_star"=>a.n_US_star[t],
        "bond"=>a.bond[t],
        "asset_position"=>a.asset_position[t],
        "liability_position"=>a.liability_position[t],
        "foreign_liability_exposure_Y"=>a.liability_position[t] / a.Y_US[t],
        "NFA"=>a.NFA[t],
        "NFA_over_Y"=>a.NFA[t] / a.Y_US[t],
        "rebased_NFA_change_current_Y"=>(a.NFA[t] - a.NFA[1]) / a.Y_US[t],
        "VA_asset"=>a.VA_asset[t],
        "VA_liability"=>a.VA_liability[t],
        "VA"=>a.VA[t],
        "CA_asset"=>a.CA_asset[t],
        "CA_liability"=>a.CA_liability[t],
        "CA_bond"=>a.CA_bond[t],
        "CA"=>a.CA[t],
        "RES"=>a.RES[t],
        "cum_VA_asset_current_Y"=>a.cum_VA_asset[t] / a.Y_US[t],
        "cum_VA_liability_current_Y"=>a.cum_VA_liability[t] / a.Y_US[t],
        "cum_VA_current_Y"=>a.cum_VA[t] / a.Y_US[t],
        "cum_CA_asset_current_Y"=>a.cum_CA_asset[t] / a.Y_US[t],
        "cum_CA_liability_current_Y"=>a.cum_CA_liability[t] / a.Y_US[t],
        "cum_CA_bond_current_Y"=>a.cum_CA_bond[t] / a.Y_US[t],
        "cum_CA_current_Y"=>a.cum_CA[t] / a.Y_US[t],
        "cum_RES_current_Y"=>a.cum_RES[t] / a.Y_US[t],
    ))
end

nb19_path_columns = [
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
nb19_write_rows_csv(joinpath(NB19_OUTDIR, "best_path.csv"), nb19_path_rows, nb19_path_columns)
nb19_write_rows_csv(
    joinpath(NB19_OUTDIR, "best_ahp_decomposition.csv"),
    nb19_path_rows,
    [
        "t", "evidence_window", "Y_US", "NFA", "NFA_over_Y",
        "rebased_NFA_change_current_Y", "VA_asset", "VA_liability", "VA",
        "CA_asset", "CA_liability", "CA_bond", "CA", "RES",
        "cum_VA_asset_current_Y", "cum_VA_liability_current_Y",
        "cum_VA_current_Y", "cum_CA_asset_current_Y",
        "cum_CA_liability_current_Y", "cum_CA_bond_current_Y",
        "cum_CA_current_Y", "cum_RES_current_Y",
    ],
)
nb19_write_rows_csv(
    joinpath(NB19_OUTDIR, "best_zero_nu_b_growth_identity.csv"),
    best_absorbing_diagnostics,
    [
        "switch_index", "N_US", "N_W", "q_US", "d_US", "q_W", "d_W",
        "Nq_US", "Nd_US", "Nq_W", "Nd_W", "Q_US", "Q_W",
        "nu_b_compatibility_constant", "policy_invariance_error",
        "aggregate_invariance_error", "per_variety_scaling_error",
        "automatic_growth_identity_error", "bgp_converged", "bgp_residual_norm",
    ],
)

nb19_validation_rows = Dict{String,Any}[
    Dict("metric"=>"source_requested_T", "value"=>SOURCE_REQUESTED_T),
    Dict("metric"=>"T_solved", "value"=>T_solved),
    Dict("metric"=>"first_noninterior_T", "value"=>NB19_FIRST_NONINTERIOR_T),
    Dict("metric"=>"first_residual_unsafe_T", "value"=>NB19_FIRST_RESIDUAL_UNSAFE_T),
    Dict("metric"=>"frontier_audit_rerun", "value"=>NB19_RUN_FRONTIER_AUDIT),
    Dict("metric"=>"n_buffer", "value"=>NB19_N_BUFFER),
    Dict("metric"=>"hard_valid", "value"=>best_validity.valid),
    Dict("metric"=>"zero_nu_b", "value"=>best_result.params.ν_b),
    Dict("metric"=>"xi_W", "value"=>best_result.params.ξ_W),
    Dict("metric"=>"common_growth_equation_present", "value"=>false),
    Dict("metric"=>"branch_converged", "value"=>best_result.branch_converged),
    Dict("metric"=>"max_u_residual", "value"=>best_result.max_u_residual),
    Dict("metric"=>"max_bgp_residual", "value"=>best_result.max_bgp_residual),
    Dict("metric"=>"accounting_residual_max", "value"=>a.residual_max),
    Dict("metric"=>"nfa_identity_error", "value"=>a.nfa_identity_error),
    Dict("metric"=>"absorbing_policy_invariance_error", "value"=>best_absorbing_summary.policy_invariance_error),
    Dict("metric"=>"absorbing_aggregate_invariance_error", "value"=>best_absorbing_summary.aggregate_invariance_error),
    Dict("metric"=>"absorbing_per_variety_scaling_error", "value"=>best_absorbing_summary.per_variety_scaling_error),
    Dict("metric"=>"automatic_growth_identity_error", "value"=>best_absorbing_summary.automatic_growth_identity_error),
    Dict("metric"=>"max_extended_bgp_residual", "value"=>best_absorbing_summary.max_extended_bgp_residual),
    Dict("metric"=>"max_first_window_replication_error", "value"=>nb19_max_first_window_error),
    Dict("metric"=>"first_window_matches_source_common_growth", "value"=>nb19_first_window_matches_source),
    Dict("metric"=>"target_rebased_nfa_t15", "value"=>best_metrics.target_rebased_nfa),
    Dict("metric"=>"target_net_va_t15", "value"=>best_metrics.target_net_va),
    Dict("metric"=>"target_ca_t15", "value"=>best_metrics.target_ca),
]
for (name, value) in sort(collect(nb19_first_window_errors); by=first)
    push!(nb19_validation_rows, Dict(
        "metric"=>"first_window_max_abs_error__$(name)", "value"=>value,
    ))
end
nb19_write_rows_csv(
    joinpath(NB19_OUTDIR, "validation_summary.csv"),
    nb19_validation_rows, ["metric", "value"],
)

# -----------------------------------------------------------------------------
# Notebook 15 figures, now evaluated on the full T=78 solution
# -----------------------------------------------------------------------------

tt = collect(1:a.T)
e = min(NB19_AHP_TARGET_END, a.T)
evidence_range = 1:e

function nb19_evidence_series!(plt, x, y; color, label, lw=2.5, ls=:solid)
    plot!(
        plt, x, y;
        color=color, alpha=0.24, lw=max(1.4, lw - 0.7), ls=ls, label="",
    )
    plot!(
        plt, x[evidence_range], y[evidence_range];
        color=color, alpha=1.0, lw=lw, ls=ls, label=label,
    )
    return plt
end

rebased_nfa = (a.NFA .- a.NFA[1]) ./ a.Y_US
cum_ca_y = a.cum_CA ./ a.Y_US
cum_va_y = a.cum_VA ./ a.Y_US
cum_res_y = a.cum_RES ./ a.Y_US

p_ahp = plot(
    xlabel="period t", ylabel="fraction of current U.S. output",
    title="Zero nu_b=0 AHP counterfactual at T=78: t=1:$(e) is the evidence window",
    legend=:outerbottom, legend_columns=2,
)
nb19_evidence_series!(p_ahp, tt, rebased_nfa; color=:navy,
    label="rebased NFA change / current Y", lw=2.8)
nb19_evidence_series!(p_ahp, tt, cum_ca_y; color=:crimson,
    label="cumulative CA / current Y", lw=2.4)
nb19_evidence_series!(p_ahp, tt, cum_va_y; color=:seagreen,
    label="cumulative VA / current Y", lw=2.4)
nb19_evidence_series!(p_ahp, tt, cum_res_y; color=:purple,
    label="cumulative residual / current Y", lw=1.8, ls=:dot)
hline!(p_ahp, [0.0], color=:gray55, ls=:dot, label="")
vline!(p_ahp, [e], color=:gray35, ls=:dash, lw=1.5, label="evidence endpoint")

nfa_ratio = a.NFA ./ a.Y_US
p_ratio = plot(
    xlabel="period t", ylabel="fraction of current U.S. output",
    title="Zero nu_b=0: NFA/current Y (full T=78 tail)", legend=:outerbottom,
)
nb19_evidence_series!(p_ratio, tt, nfa_ratio; color=:navy,
    label="NFA / current Y", lw=2.8)
hline!(p_ratio, [nfa_ratio[1]], color=:gray45, ls=:dot, label="initial NFA / Y")
vline!(p_ratio, [e], color=:gray35, ls=:dash, lw=1.5, label="evidence endpoint")

fig_ahp_two_panel = plot(p_ahp, p_ratio, layout=(1, 2), size=(1450, 540), margin=9mm)
savefig(fig_ahp_two_panel, joinpath(NB19_OUTDIR, "best_ahp_two_panel.png"))

p_va = plot(
    xlabel="period t", ylabel="fraction of current U.S. output",
    title="Cumulative valuation components from t=1",
    legend=:outerbottom, legend_columns=2,
)
nb19_evidence_series!(p_va, tt, a.cum_VA_asset ./ a.Y_US; color=:steelblue,
    label="RoW-equity asset VA", lw=2.4)
nb19_evidence_series!(p_va, tt, a.cum_VA_liability ./ a.Y_US; color=:tomato,
    label="foreign-held U.S.-equity liability VA", lw=2.6)
nb19_evidence_series!(p_va, tt, a.cum_VA ./ a.Y_US; color=:black,
    label="net VA", lw=2.1, ls=:dash)
hline!(p_va, [0.0], color=:gray55, ls=:dot, label="")
vline!(p_va, [e], color=:gray35, ls=:dash, lw=1.5, label="evidence endpoint")

p_ca = plot(
    xlabel="period t", ylabel="fraction of current U.S. output",
    title="Cumulative quantity-flow components from t=1",
    legend=:outerbottom, legend_columns=2,
)
nb19_evidence_series!(p_ca, tt, a.cum_CA_asset ./ a.Y_US; color=:steelblue,
    label="RoW-equity quantity CA", lw=2.3)
nb19_evidence_series!(p_ca, tt, a.cum_CA_liability ./ a.Y_US; color=:tomato,
    label="U.S.-equity liability quantity CA", lw=2.3)
nb19_evidence_series!(p_ca, tt, a.cum_CA_bond ./ a.Y_US; color=:darkgreen,
    label="bond-position CA", lw=2.3)
nb19_evidence_series!(p_ca, tt, a.cum_CA ./ a.Y_US; color=:black,
    label="total CA", lw=2.1, ls=:dash)
hline!(p_ca, [0.0], color=:gray55, ls=:dot, label="")
vline!(p_ca, [e], color=:gray35, ls=:dash, lw=1.5, label="evidence endpoint")

fig_subcomponents = plot(p_va, p_ca, layout=(1, 2), size=(1500, 540), margin=9mm)
savefig(fig_subcomponents, joinpath(NB19_OUTDIR, "best_va_ca_subcomponents.png"))

p_prices = plot(
    xlabel="period t", ylabel="index, t=1 equals 1",
    title="Equity prices", legend=:outerbottom, legend_columns=2,
)
nb19_evidence_series!(p_prices, tt, a.q_US ./ a.q_US[1]; color=:tomato,
    label="U.S. equity price index", lw=2.6)
nb19_evidence_series!(p_prices, tt, a.q_W ./ a.q_W[1]; color=:steelblue,
    label="RoW equity price index", lw=2.5)
vline!(p_prices, [e], color=:gray35, ls=:dash, lw=1.5, label="evidence endpoint")

p_exposure = plot(
    xlabel="period t", ylabel="fraction of current U.S. output",
    title="Gross equity exposures and NFA", legend=:outerbottom, legend_columns=2,
)
nb19_evidence_series!(p_exposure, tt, a.liability_position ./ a.Y_US; color=:tomato,
    label="foreign-held U.S. equity claims", lw=2.6)
nb19_evidence_series!(p_exposure, tt, a.asset_position ./ a.Y_US; color=:steelblue,
    label="U.S.-held RoW equity", lw=2.4)
nb19_evidence_series!(p_exposure, tt, a.NFA ./ a.Y_US; color=:black,
    label="NFA / current Y", lw=2.1, ls=:dash)
hline!(p_exposure, [0.0], color=:gray55, ls=:dot, label="")
vline!(p_exposure, [e], color=:gray35, ls=:dash, lw=1.5, label="evidence endpoint")

fig_prices_exposures = plot(
    p_prices, p_exposure, layout=(1, 2), size=(1450, 520), margin=9mm,
)
savefig(fig_prices_exposures, joinpath(NB19_OUTDIR, "best_prices_exposures.png"))

switch_t = Float64[r["switch_index"] for r in best_absorbing_diagnostics]
Nq_US = Float64[r["Nq_US"] for r in best_absorbing_diagnostics]
Nd_US = Float64[r["Nd_US"] for r in best_absorbing_diagnostics]
Nq_W = Float64[r["Nq_W"] for r in best_absorbing_diagnostics]
Nd_W = Float64[r["Nd_W"] for r in best_absorbing_diagnostics]
normalization_error = Float64[max(
    r["policy_invariance_error"], r["aggregate_invariance_error"],
    r["per_variety_scaling_error"], r["automatic_growth_identity_error"],
) for r in best_absorbing_diagnostics]

p_us_norm = plot(switch_t, Nq_US; color=:navy, lw=2.6, label="N_US q_US",
    xlabel="switch-state index", ylabel="normalized level",
    title="US 1/N price and dividend scaling")
plot!(p_us_norm, switch_t, Nd_US; color=:red3, ls=:dash, lw=2.2, label="N_US d_US")
p_w_norm = plot(switch_t, Nq_W; color=:navy, lw=2.6, label="N_W q_W",
    xlabel="switch-state index", ylabel="normalized level",
    title="RoW 1/N price and dividend scaling")
plot!(p_w_norm, switch_t, Nd_W; color=:red3, ls=:dash, lw=2.2, label="N_W d_W")
p_norm_error = plot(switch_t, max.(normalization_error, eps()); color=:black,
    lw=2.2, yscale=:log10, label="max invariant error",
    xlabel="switch-state index", ylabel="absolute error (log)",
    title="Solve-once normalization verification")
fig_absorbing_normalization = plot(
    p_us_norm, p_w_norm, p_norm_error, layout=(1, 3), size=(1550, 460))
savefig(fig_absorbing_normalization,
    joinpath(NB19_OUTDIR, "best_zero_nu_b_absorbing_normalization.png"))

println("\n" * repeat("=", 88))
println("NOTEBOOK 03 — ZERO-EXPONENT AHP FIGURES ON THE T=78 FRONTIER")
println(repeat("=", 88))
@printf("Final max u residual:             %.3e\n", best_result.max_u_residual)
@printf("Final max BGP residual:           %.3e\n", best_result.max_bgp_residual)
@printf("Max first-window replication err: %.3e\n", nb19_max_first_window_error)
println("Matches source common-growth path: ", nb19_first_window_matches_source)
@printf("t=15 rebased NFA:                 %+.6f\n", best_metrics.target_rebased_nfa)
@printf("t=15 net VA / cumulative CA:      %+.6f / %+.6f\n",
        best_metrics.target_net_va, best_metrics.target_ca)
@printf("|VA| / |CA|:                      %.3f\n",
        abs(best_metrics.target_net_va) / max(abs(best_metrics.target_ca), 1e-12))
@printf("Absorbing policy invariance error:  %.3e\n",
        best_absorbing_summary.policy_invariance_error)
@printf("Per-variety 1/N scaling error:      %.3e\n",
        best_absorbing_summary.per_variety_scaling_error)
@printf("Automatic growth-identity error:    %.3e\n",
        best_absorbing_summary.automatic_growth_identity_error)
println("Hard-valid T=78 solution:         ", best_validity.valid)
println("Source requested T=110 available: false")
println("First non-interior probe:         T=", NB19_FIRST_NONINTERIOR_T)
println("First residual-unsafe probe:      T=", NB19_FIRST_RESIDUAL_UNSAFE_T)
println("Frontier audit rerun this time:   ", NB19_RUN_FRONTIER_AUDIT)
println("Artifacts written to:             ", NB19_OUTDIR)

nothing
