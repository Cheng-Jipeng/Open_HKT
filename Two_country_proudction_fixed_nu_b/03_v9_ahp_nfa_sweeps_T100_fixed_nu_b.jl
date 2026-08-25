# Included after 03_v9_ahp_pattern_T110_replication_fixed_nu_b.jl. This file
# runs the requested T=100 comparative statics in the two AHP portfolio-weight
# parameters and plots the complete U.S. NFA accounting decomposition.

const NB19_NFA_SWEEP_T = 100
const NB19_NFA_SWEEP_HORIZONS = [30, 45, 60, 70, 80, 90, 100]
const NB19_NFA_SWEEP_BRANCH_ITER_SCHEDULE = [60, 200]
const NB19_NFA_OMEGA_STAR_GRID = [0.25, 0.30, 0.40, 0.50]
const NB19_NFA_OMEGA_GRID = [0.40, 0.50, 0.60, 0.70]
const NB19_NFA_OMEGA_STAR_CONTINUATION_GRID = Float64.(
    round.(collect(0.26:0.01:0.50); digits=2),
)
const NB19_NFA_OMEGA_UPPER_CONTINUATION_GRID = Float64.(
    round.(collect(0.51:0.01:0.70); digits=2),
)

println("\nFixed-nu_b T=100 parameter sweeps for the U.S. NFA decomposition")
println("Fixed nu_b = xi_W:             1.0")
println("Common-growth restriction:     disabled")
println("Warm-continuation horizons:    ", NB19_NFA_SWEEP_HORIZONS)
println("omega_bar_star grid:          ", NB19_NFA_OMEGA_STAR_GRID)
println("omega_bar grid:               ", NB19_NFA_OMEGA_GRID)
println("Fine parameter step:           0.01")

function nb19_nfa_sweep_params(T::Int, branch_iters::Int;
                               omega_case::Float64,
                               omega_star_case::Float64,
                               global_polish::Bool=false)
    return ProductionParams(
        T_max=T, n_buffer=0, common_world_growth=false,
        β=0.45, γ=0.25, π_persist=0.75,
        a_US=0.20, ϑ_US=0.85,
        a_W=0.06, H_W=3.0, L_W=3.0,
        A_X_US_u=15.0, A_L_US_u=1.5,
        ν_b=1.00, ν_u=1.75, ξ_u=2.25, ξ_W=1.00,
        ω̄=omega_case, ω̄_star=omega_star_case,
        κ=1.00, χ=0.0002, η=0.010,
        branch_iters=branch_iters, do_global_polish=global_polish,
    )
end

function nb19_nfa_sweep_case_id(omega_case::Float64,
                                omega_star_case::Float64)
    omega_text = replace(@sprintf("%.2f", omega_case), "."=>"p")
    star_text = replace(@sprintf("%.2f", omega_star_case), "."=>"p")
    return "omega_$(omega_text)_omega_star_$(star_text)"
end

function nb19_nfa_strict_equity_feasible(result)
    weights = Float64[]
    for s in result.u_path
        append!(weights, (s.ω, s.ω_star))
    end
    for b in result.bgp_seq
        append!(weights, (b.ω, b.ω_star))
    end
    return all(x -> isfinite(x) && 0 < x < 1, weights)
end

function nb19_nfa_plot_feasible(result, validity)
    theta_US_star = nb19_path_vector(result, :θ_US_star)
    theta_feasible = all(x -> isfinite(x) && 0 < x < 1, theta_US_star)
    return validity.model_residuals && validity.psi_interior &&
           nb19_nfa_strict_equity_feasible(result) && theta_feasible &&
           validity.positive_foreign_claims && validity.positive_returns &&
           validity.accounting_exact && validity.finite_accounting &&
           validity.extended_bgp_valid &&
           validity.exponent_ordering
end

function nb19_solve_nfa_sweep_case(omega_case::Float64,
                                   omega_star_case::Float64;
                                   sweep_kind::String,
                                   sweep_value::Float64,
                                   label::String,
                                   initial_by_T::Dict{Int,Any}=Dict{Int,Any}(),
                                   horizons::Vector{Int}=NB19_NFA_SWEEP_HORIZONS)
    NB19_NFA_SWEEP_T in horizons || error("The NFA sweep must solve T=100")
    attempts = Dict{String,Any}[]
    solved_by_T = Dict{Int,Any}()
    warm_result = nothing
    warm_T = missing

    for T in horizons
        solved_here = nothing
        structural_failure = false
        parameter_seed = get(initial_by_T, T, nothing)
        seed_result = parameter_seed === nothing ? warm_result : parameter_seed
        seed_T = parameter_seed === nothing ? warm_T : T
        seed_kind = parameter_seed === nothing ?
            (warm_result === nothing ? "none" : "horizon") : "parameter"

        for branch_iters in NB19_NFA_SWEEP_BRANCH_ITER_SCHEDULE
            @printf("NFA %-12s %-25s T=%3d iter=%3d seed=%s:%s\n",
                    sweep_kind, label, T, branch_iters, seed_kind,
                    seed_T === missing ? "" : string(seed_T))
            started = time()
            try
                result = run_production_simulation(
                    nb19_nfa_sweep_params(
                        T, branch_iters;
                        omega_case=omega_case,
                        omega_star_case=omega_star_case,
                        global_polish=false,
                    );
                    verbose=false,
                    initial_u_path=seed_result === nothing ? nothing :
                        seed_result.u_path_extended,
                    initial_bgp_seq=seed_result === nothing ? nothing :
                        seed_result.bgp_seq_extended,
                )
                residual_safe = nb19_model_residual_safe(result)
                push!(attempts, Dict{String,Any}(
                    "sweep_kind"=>sweep_kind,
                    "sweep_value"=>sweep_value,
                    "case_id"=>nb19_nfa_sweep_case_id(
                        omega_case, omega_star_case,
                    ),
                    "label"=>label,
                    "omega_bar"=>omega_case,
                    "omega_bar_star"=>omega_star_case,
                    "T_max"=>T,
                    "branch_iters"=>branch_iters,
                    "warm_start_T"=>seed_T,
                    "seed_kind"=>seed_kind,
                    "global_polish"=>false,
                    "status"=>"ok",
                    "elapsed_sec"=>time() - started,
                    "branch_converged"=>result.branch_converged,
                    "max_u_residual"=>result.max_u_residual,
                    "max_bgp_residual"=>result.max_bgp_residual,
                    "residual_safe"=>residual_safe,
                    "error"=>"",
                ))
                if residual_safe
                    solved_here = result
                    break
                end
                seed_result = result
                seed_T = T
                seed_kind = "iteration"
            catch err
                error_text = sprint(showerror, err)
                push!(attempts, Dict{String,Any}(
                    "sweep_kind"=>sweep_kind,
                    "sweep_value"=>sweep_value,
                    "case_id"=>nb19_nfa_sweep_case_id(
                        omega_case, omega_star_case,
                    ),
                    "label"=>label,
                    "omega_bar"=>omega_case,
                    "omega_bar_star"=>omega_star_case,
                    "T_max"=>T,
                    "branch_iters"=>branch_iters,
                    "warm_start_T"=>seed_T,
                    "seed_kind"=>seed_kind,
                    "global_polish"=>false,
                    "status"=>"error",
                    "elapsed_sec"=>time() - started,
                    "branch_converged"=>missing,
                    "max_u_residual"=>missing,
                    "max_bgp_residual"=>missing,
                    "residual_safe"=>false,
                    "error"=>error_text,
                ))
                structural_failure = occursin(
                    "required terminal successor", error_text,
                )
                structural_failure && break
            end
        end

        # Use the model's own simultaneous 7T-equation polish only after the
        # standard 60/200 forward-backward passes fail. The final residual
        # rebuild remains the authoritative convergence test.
        if solved_here === nothing && seed_result !== nothing && !structural_failure
            polish_iters = 5
            started = time()
            try
                result = run_production_simulation(
                    nb19_nfa_sweep_params(
                        T, polish_iters;
                        omega_case=omega_case,
                        omega_star_case=omega_star_case,
                        global_polish=true,
                    );
                    verbose=false,
                    initial_u_path=seed_result.u_path_extended,
                    initial_bgp_seq=seed_result.bgp_seq_extended,
                )
                residual_safe = nb19_model_residual_safe(result)
                push!(attempts, Dict{String,Any}(
                    "sweep_kind"=>sweep_kind,
                    "sweep_value"=>sweep_value,
                    "case_id"=>nb19_nfa_sweep_case_id(
                        omega_case, omega_star_case,
                    ),
                    "label"=>label,
                    "omega_bar"=>omega_case,
                    "omega_bar_star"=>omega_star_case,
                    "T_max"=>T,
                    "branch_iters"=>polish_iters,
                    "warm_start_T"=>T,
                    "seed_kind"=>"global_polish",
                    "global_polish"=>true,
                    "status"=>"ok",
                    "elapsed_sec"=>time() - started,
                    "branch_converged"=>result.branch_converged,
                    "max_u_residual"=>result.max_u_residual,
                    "max_bgp_residual"=>result.max_bgp_residual,
                    "residual_safe"=>residual_safe,
                    "error"=>"",
                ))
                residual_safe && (solved_here = result)
            catch err
                push!(attempts, Dict{String,Any}(
                    "sweep_kind"=>sweep_kind,
                    "sweep_value"=>sweep_value,
                    "case_id"=>nb19_nfa_sweep_case_id(
                        omega_case, omega_star_case,
                    ),
                    "label"=>label,
                    "omega_bar"=>omega_case,
                    "omega_bar_star"=>omega_star_case,
                    "T_max"=>T,
                    "branch_iters"=>polish_iters,
                    "warm_start_T"=>T,
                    "seed_kind"=>"global_polish",
                    "global_polish"=>true,
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

        if solved_here === nothing
            last_attempt = last(attempts)
            reason = isempty(string(last_attempt["error"])) ?
                "no residual-safe solution within the standard and polish schedules" :
                string(last_attempt["error"])
            return (;
                status=:failed, failure_T=T, failure_reason=reason,
                sweep_kind, sweep_value, label,
                omega_case, omega_star_case,
                case_id=nb19_nfa_sweep_case_id(
                    omega_case, omega_star_case,
                ),
                result=nothing, accounting=nothing, common=nothing,
                validity=nothing, plot_feasible=false,
                solved_by_T, attempts,
            )
        end
        solved_by_T[T] = solved_here
        warm_result = solved_here
        warm_T = T
    end

    result = solved_by_T[NB19_NFA_SWEEP_T]
    accounting = nb19_ahp_accounting(result)
    common = nb19_common_growth_summary(result)
    validity = nb19_hard_validity(result, accounting, common)
    plot_feasible = nb19_nfa_plot_feasible(result, validity)
    return (;
        status=plot_feasible ? :ok : :failed_feasibility,
        failure_T=plot_feasible ? missing : NB19_NFA_SWEEP_T,
        failure_reason=plot_feasible ? "" :
            "failed a strict economic-feasibility or accounting gate",
        sweep_kind, sweep_value, label,
        omega_case, omega_star_case,
        case_id=nb19_nfa_sweep_case_id(omega_case, omega_star_case),
        result, accounting, common, validity, plot_feasible,
        solved_by_T, attempts,
    )
end

function nb19_nfa_unavailable_case(omega_case::Float64,
                                   omega_star_case::Float64;
                                   sweep_kind::String,
                                   sweep_value::Float64,
                                   label::String,
                                   frontier_description::String)
    return (;
        status=:unavailable_continuation_frontier,
        failure_T=NB19_NFA_SWEEP_T,
        failure_reason="unavailable beyond the residual-safe continuation frontier; " *
                       "the first failed fine step was $(frontier_description)",
        sweep_kind, sweep_value, label, omega_case, omega_star_case,
        case_id=nb19_nfa_sweep_case_id(omega_case, omega_star_case),
        result=nothing, accounting=nothing, common=nothing,
        validity=nothing, plot_feasible=false,
        solved_by_T=Dict{Int,Any}(), attempts=Dict{String,Any}[],
    )
end

function nb19_nfa_domain_case(omega_case::Float64,
                              omega_star_case::Float64;
                              sweep_kind::String,
                              sweep_value::Float64,
                              label::String,
                              failure_reason::String)
    return (;
        status=:unavailable_model_domain,
        failure_T=NB19_NFA_SWEEP_T, failure_reason,
        sweep_kind, sweep_value, label, omega_case, omega_star_case,
        case_id=nb19_nfa_sweep_case_id(omega_case, omega_star_case),
        result=nothing, accounting=nothing, common=nothing,
        validity=nothing, plot_feasible=false,
        solved_by_T=Dict{Int,Any}(), attempts=Dict{String,Any}[],
    )
end

function nb19_build_omega_nfa_cases()
    baseline = nb19_solve_nfa_sweep_case(
        0.50, 0.25;
        sweep_kind="omega_star", sweep_value=0.25,
        label="omega_bar* = 0.25 (AHP)",
    )
    baseline.plot_feasible || error("The AHP T=100 baseline is unavailable")
    baseline_seed = Dict{Int,Any}(NB19_NFA_SWEEP_T=>baseline.result)
    attempt_cases = Any[baseline]

    omega_star_by_value = Dict{Float64,Any}(0.25=>baseline)
    star_seed = baseline_seed
    star_frontier = nothing
    for value in NB19_NFA_OMEGA_STAR_CONTINUATION_GRID
        requested = any(v -> isapprox(value, v; atol=1e-12),
                        NB19_NFA_OMEGA_STAR_GRID)
        case = nb19_solve_nfa_sweep_case(
            0.50, Float64(value);
            sweep_kind=requested ? "omega_star" : "omega_star_continuation",
            sweep_value=Float64(value),
            label=requested ? @sprintf("omega_bar* = %.2g", value) :
                @sprintf("omega_bar* continuation = %.2f", value),
            initial_by_T=star_seed,
            horizons=[NB19_NFA_SWEEP_T],
        )
        push!(attempt_cases, case)
        # If a direct T=100 parameter continuation loses its terminal BGP
        # successor, rebuild the same parameter case through the validated
        # horizon ladder. This gives the new case its own T=30,...,T=90 path
        # before asking it to solve T=100.
        if !case.plot_feasible && case.status == :failed && value <= 0.27
            retry_case = nb19_solve_nfa_sweep_case(
                0.50, Float64(value);
                sweep_kind=requested ? "omega_star" :
                    "omega_star_continuation",
                sweep_value=Float64(value),
                label=requested ? @sprintf("omega_bar* = %.2g", value) :
                    @sprintf("omega_bar* continuation = %.2f", value),
                initial_by_T=baseline.solved_by_T,
                horizons=NB19_NFA_SWEEP_HORIZONS,
            )
            push!(attempt_cases, retry_case)
            case = retry_case
        end
        requested && (omega_star_by_value[Float64(value)] = case)
        if !case.plot_feasible
            star_frontier = case
            break
        end
        star_seed = Dict{Int,Any}(NB19_NFA_SWEEP_T=>case.result)
    end
    for value in NB19_NFA_OMEGA_STAR_GRID
        haskey(omega_star_by_value, Float64(value)) && continue
        frontier = star_frontier === nothing ? "not reached" :
            @sprintf("omega_bar*=%.2f", star_frontier.omega_star_case)
        omega_star_by_value[Float64(value)] = nb19_nfa_unavailable_case(
            0.50, Float64(value);
            sweep_kind="omega_star", sweep_value=Float64(value),
            label=@sprintf("omega_bar* = %.2g", value),
            frontier_description=frontier,
        )
    end
    omega_star_cases = [
        omega_star_by_value[Float64(v)] for v in NB19_NFA_OMEGA_STAR_GRID
    ]

    omega_by_value = Dict{Float64,Any}()
    omega_by_value[0.50] = merge(
        baseline,
        (;
            sweep_kind="omega", sweep_value=0.50,
            label="omega_bar = 0.5 (AHP)",
        ),
    )
    # The maintained primitive domain in validate_params is omega_bar in
    # [1/2, 1]. Report 0.40 explicitly rather than treating it as a numerical
    # continuation failure or changing the model to manufacture a curve.
    omega_by_value[0.40] = nb19_nfa_domain_case(
        0.40, 0.25;
        sweep_kind="omega", sweep_value=0.40,
        label="omega_bar = 0.4",
        failure_reason="outside the maintained primitive domain omega_bar in [0.5, 1]",
    )

    upper_seed = baseline_seed
    upper_frontier = nothing
    for value in NB19_NFA_OMEGA_UPPER_CONTINUATION_GRID
        requested = any(v -> isapprox(value, v; atol=1e-12), (0.60, 0.70))
        case = nb19_solve_nfa_sweep_case(
            Float64(value), 0.25;
            sweep_kind=requested ? "omega" : "omega_continuation",
            sweep_value=Float64(value),
            label=requested ? @sprintf("omega_bar = %.2g", value) :
                @sprintf("omega_bar continuation = %.2f", value),
            initial_by_T=upper_seed,
            horizons=[NB19_NFA_SWEEP_T],
        )
        push!(attempt_cases, case)
        requested && (omega_by_value[Float64(value)] = case)
        if !case.plot_feasible
            upper_frontier = case
            break
        end
        upper_seed = Dict{Int,Any}(NB19_NFA_SWEEP_T=>case.result)
    end
    for value in (0.60, 0.70)
        haskey(omega_by_value, Float64(value)) && continue
        frontier = upper_frontier === nothing ? "not reached" :
            @sprintf("omega_bar=%.2f", upper_frontier.omega_case)
        omega_by_value[Float64(value)] = nb19_nfa_unavailable_case(
            Float64(value), 0.25;
            sweep_kind="omega", sweep_value=Float64(value),
            label=@sprintf("omega_bar = %.2g", value),
            frontier_description=frontier,
        )
    end
    omega_cases = [omega_by_value[Float64(v)] for v in NB19_NFA_OMEGA_GRID]
    return (; omega_star_cases, omega_cases, attempt_cases)
end

nb19_omega_nfa_build = nb19_build_omega_nfa_cases()
omega_star_nfa_sweep_cases = nb19_omega_nfa_build.omega_star_cases
omega_nfa_sweep_cases = nb19_omega_nfa_build.omega_cases
omega_star_nfa_sweep_results = filter(c -> c.plot_feasible,
                                      omega_star_nfa_sweep_cases)
omega_nfa_sweep_results = filter(c -> c.plot_feasible, omega_nfa_sweep_cases)

nb19_nfa_attempt_columns = [
    "sweep_kind", "sweep_value", "case_id", "label",
    "omega_bar", "omega_bar_star", "T_max", "branch_iters",
    "warm_start_T", "seed_kind", "global_polish", "status",
    "elapsed_sec", "branch_converged", "max_u_residual",
    "max_bgp_residual", "residual_safe", "error",
]
nb19_nfa_attempt_rows = reduce(
    vcat,
    (c.attempts for c in nb19_omega_nfa_build.attempt_cases);
    init=Dict{String,Any}[],
)
nb19_write_rows_csv(
    joinpath(NB19_OUTDIR, "nfa_sweep_T100_solve_summary.csv"),
    nb19_nfa_attempt_rows, nb19_nfa_attempt_columns,
)

function nb19_nfa_sweep_series(accounting)
    a = accounting
    return (
        rebased_nfa=(a.NFA .- a.NFA[1]) ./ a.Y_US,
        cum_va=a.cum_VA ./ a.Y_US,
        cum_va_asset=a.cum_VA_asset ./ a.Y_US,
        cum_va_liability=a.cum_VA_liability ./ a.Y_US,
        cum_ca=a.cum_CA ./ a.Y_US,
        cum_ca_asset=a.cum_CA_asset ./ a.Y_US,
        cum_ca_liability=a.cum_CA_liability ./ a.Y_US,
        cum_ca_bond=a.cum_CA_bond ./ a.Y_US,
        q_us_index=a.q_US ./ a.q_US[1],
        q_row_index=a.q_W ./ a.q_W[1],
        row_equity_asset=a.asset_position ./ a.Y_US,
        us_equity_liability=a.liability_position ./ a.Y_US,
    )
end

function nb19_nfa_decomposition_error(accounting)
    s = nb19_nfa_sweep_series(accounting)
    residual = accounting.cum_RES ./ accounting.Y_US
    return maximum(abs.(
        s.rebased_nfa .- s.cum_va .- s.cum_ca .- residual,
    ))
end

function nb19_nfa_path_rows(cases)
    rows = Dict{String,Any}[]
    for case in cases
        case.plot_feasible || continue
        a = case.accounting
        s = nb19_nfa_sweep_series(a)
        for t in 1:a.T
            push!(rows, Dict{String,Any}(
                "sweep_kind"=>case.sweep_kind,
                "sweep_value"=>case.sweep_value,
                "case_id"=>case.case_id,
                "label"=>case.label,
                "omega_bar"=>case.omega_case,
                "omega_bar_star"=>case.omega_star_case,
                "T_max"=>NB19_NFA_SWEEP_T,
                "t"=>t,
                "model_t"=>t - 1,
                "US_NFA_change_current_Y"=>s.rebased_nfa[t],
                "cum_VA_current_Y"=>s.cum_va[t],
                "cum_VA_RoW_equity_asset_current_Y"=>s.cum_va_asset[t],
                "cum_VA_US_equity_liability_current_Y"=>s.cum_va_liability[t],
                "cum_CA_current_Y"=>s.cum_ca[t],
                "cum_CA_RoW_equity_quantity_current_Y"=>s.cum_ca_asset[t],
                "cum_CA_US_equity_liability_quantity_current_Y"=>s.cum_ca_liability[t],
                "cum_CA_bond_position_current_Y"=>s.cum_ca_bond[t],
                "US_equity_price_index"=>s.q_us_index[t],
                "RoW_equity_price_index"=>s.q_row_index[t],
                "US_held_RoW_equity_current_Y"=>s.row_equity_asset[t],
                "foreign_held_US_equity_claim_current_Y"=>s.us_equity_liability[t],
            ))
        end
    end
    return rows
end

nb19_nfa_path_columns = [
    "sweep_kind", "sweep_value", "case_id", "label",
    "omega_bar", "omega_bar_star", "T_max", "t", "model_t",
    "US_NFA_change_current_Y", "cum_VA_current_Y",
    "cum_VA_RoW_equity_asset_current_Y",
    "cum_VA_US_equity_liability_current_Y", "cum_CA_current_Y",
    "cum_CA_RoW_equity_quantity_current_Y",
    "cum_CA_US_equity_liability_quantity_current_Y",
    "cum_CA_bond_position_current_Y", "US_equity_price_index",
    "RoW_equity_price_index", "US_held_RoW_equity_current_Y",
    "foreign_held_US_equity_claim_current_Y",
]
nb19_write_rows_csv(
    joinpath(NB19_OUTDIR, "nfa_sweep_T100_omega_star_paths.csv"),
    nb19_nfa_path_rows(omega_star_nfa_sweep_cases), nb19_nfa_path_columns,
)
nb19_write_rows_csv(
    joinpath(NB19_OUTDIR, "nfa_sweep_T100_omega_paths.csv"),
    nb19_nfa_path_rows(omega_nfa_sweep_cases), nb19_nfa_path_columns,
)

function nb19_nfa_case_summary_rows(cases)
    rows = Dict{String,Any}[]
    for case in cases
        solved = case.result !== nothing
        a = case.accounting
        theta = solved ? nb19_path_vector(case.result, :θ_US_star) : Float64[]
        push!(rows, Dict{String,Any}(
            "sweep_kind"=>case.sweep_kind,
            "sweep_value"=>case.sweep_value,
            "case_id"=>case.case_id,
            "label"=>case.label,
            "omega_bar"=>case.omega_case,
            "omega_bar_star"=>case.omega_star_case,
            "T_max"=>NB19_NFA_SWEEP_T,
            "solve_status"=>String(case.status),
            "failure_T"=>case.failure_T,
            "failure_reason"=>case.failure_reason,
            "plot_feasible"=>case.plot_feasible,
            "hard_valid_one_percent_gates"=>
                solved ? case.validity.valid : false,
            "equity_interior_one_percent"=>
                solved ? case.validity.equity_interior : false,
            "theta_interior_one_percent"=>
                solved ? case.validity.theta_interior : false,
            "min_equity_weight"=>
                solved ? case.result.diagnostics.equity_weight_min : missing,
            "min_theta_US_star"=>solved ? minimum(theta) : missing,
            "max_theta_US_star"=>solved ? maximum(theta) : missing,
            "max_u_residual"=>solved ? case.result.max_u_residual : missing,
            "max_bgp_residual"=>solved ? case.result.max_bgp_residual : missing,
            "accounting_residual_max"=>solved ? a.residual_max : missing,
            "nfa_level_identity_error"=>solved ? a.nfa_identity_error : missing,
            "normalized_cumulative_decomposition_error"=>
                solved ? nb19_nfa_decomposition_error(a) : missing,
            "max_common_growth_log_gap_diagnostic"=>
                solved ? case.common.max_log_gap : missing,
        ))
    end
    return rows
end

nb19_nfa_case_summary_columns = [
    "sweep_kind", "sweep_value", "case_id", "label",
    "omega_bar", "omega_bar_star", "T_max", "solve_status",
    "failure_T", "failure_reason", "plot_feasible",
    "hard_valid_one_percent_gates", "equity_interior_one_percent",
    "theta_interior_one_percent", "min_equity_weight",
    "min_theta_US_star", "max_theta_US_star", "max_u_residual",
    "max_bgp_residual", "accounting_residual_max",
    "nfa_level_identity_error", "normalized_cumulative_decomposition_error",
    "max_common_growth_log_gap_diagnostic",
]
nb19_write_rows_csv(
    joinpath(NB19_OUTDIR, "nfa_sweep_T100_case_summary.csv"),
    nb19_nfa_case_summary_rows(vcat(
        omega_star_nfa_sweep_cases, omega_nfa_sweep_cases,
    )),
    nb19_nfa_case_summary_columns,
)

const NB19_NFA_PANEL_SPECS = [
    (key=:rebased_nfa, title="U.S. NFA change (rebased)",
     ylabel="fraction of current U.S. output"),
    (key=:cum_va, title="Cumulative valuation effect",
     ylabel="fraction of current U.S. output"),
    (key=:cum_va_asset, title="RoW-equity asset VA",
     ylabel="fraction of current U.S. output"),
    (key=:cum_va_liability, title="U.S.-equity liability VA",
     ylabel="fraction of current U.S. output"),
    (key=:cum_ca, title="Cumulative current account",
     ylabel="fraction of current U.S. output"),
    (key=:cum_ca_asset, title="RoW-equity quantity CA",
     ylabel="fraction of current U.S. output"),
    (key=:cum_ca_liability, title="U.S.-equity liability quantity CA",
     ylabel="fraction of current U.S. output"),
    (key=:cum_ca_bond, title="Bond-position CA",
     ylabel="fraction of current U.S. output"),
    (key=:q_us_index, title="U.S. equity price",
     ylabel="index, initial date = 1"),
    (key=:q_row_index, title="RoW equity price",
     ylabel="index, initial date = 1"),
    (key=:row_equity_asset, title="U.S.-held RoW equity",
     ylabel="fraction of current U.S. output"),
    (key=:us_equity_liability, title="Foreign-held U.S. equity claim",
     ylabel="fraction of current U.S. output"),
]

function nb19_nfa_sweep_color(i::Int)
    colors = [:black, :steelblue, :darkorange, :forestgreen, :purple]
    return colors[mod1(i, length(colors))]
end

function nb19_plot_nfa_sweep(cases;
                             sweep_title::String,
                             filename::String)
    results = filter(c -> c.plot_feasible, cases)
    unavailable = filter(c -> !c.plot_feasible, cases)
    isempty(results) && error("No feasible cases to plot for $(sweep_title)")
    panels = Any[]
    for (panel_index, spec) in enumerate(NB19_NFA_PANEL_SPECS)
        panel_title = spec.title
        if panel_index == 1 && !isempty(unavailable)
            panel_title *= "\nUnavailable: " *
                join((c.label for c in unavailable), ", ")
        end
        plt = plot(
            xlabel="model date t", ylabel=spec.ylabel, title=panel_title,
            legend=panel_index == 1 ? :outerbottom : false,
            legend_columns=min(2, length(results)),
        )
        for (i, case) in enumerate(results)
            series = getproperty(nb19_nfa_sweep_series(case.accounting), spec.key)
            baseline = isapprox(case.omega_case, 0.50; atol=1e-12) &&
                       isapprox(case.omega_star_case, 0.25; atol=1e-12)
            plot!(
                plt, 0:(length(series) - 1), series;
                color=nb19_nfa_sweep_color(i),
                lw=baseline ? 2.8 : 1.9,
                ls=baseline ? :dash : :solid,
                label=panel_index == 1 ? case.label : "",
            )
        end
        if spec.key in (
            :rebased_nfa, :cum_va, :cum_va_asset, :cum_va_liability,
            :cum_ca, :cum_ca_asset, :cum_ca_liability, :cum_ca_bond,
        )
            hline!(plt, [0.0], color=:gray55, ls=:dot, lw=0.9, label="")
        end
        push!(panels, plt)
    end
    fig = plot(
        panels...;
        layout=(4, 3), size=(1800, 1850), plot_title=sweep_title,
        left_margin=7mm, right_margin=5mm,
        top_margin=6mm, bottom_margin=7mm,
    )
    savefig(fig, joinpath(NB19_OUTDIR, filename))
    return fig
end

omega_star_nfa_sweep_figure = nb19_plot_nfa_sweep(
    omega_star_nfa_sweep_cases;
    sweep_title="AHP-calibrated U.S. NFA decomposition: omega_bar* sweep, T=100",
    filename="nfa_sweep_T100_omega_star_12_panels.png",
)

omega_nfa_sweep_figure = nb19_plot_nfa_sweep(
    omega_nfa_sweep_cases;
    sweep_title="AHP-calibrated U.S. NFA decomposition: omega_bar sweep, T=100",
    filename="nfa_sweep_T100_omega_12_panels.png",
)

println("\nT=100 U.S. NFA sweep validation")
@printf("%-12s %-25s %9s %9s %12s %12s\n",
        "sweep", "case", "plotted", "hard gate", "max u res", "decomp err")
for case in vcat(omega_star_nfa_sweep_cases, omega_nfa_sweep_cases)
    if case.result === nothing
        @printf("%-12s %-25s %9s %9s %12s %12s\n",
                case.sweep_kind, case.label, "false", "false", "", "")
    else
        @printf("%-12s %-25s %9s %9s %12.3e %12.3e\n",
                case.sweep_kind, case.label, string(case.plot_feasible),
                string(case.validity.valid), case.result.max_u_residual,
                nb19_nfa_decomposition_error(case.accounting))
    end
end
println("Detailed diagnostics: ",
        joinpath(NB19_OUTDIR, "nfa_sweep_T100_case_summary.csv"))

nothing
