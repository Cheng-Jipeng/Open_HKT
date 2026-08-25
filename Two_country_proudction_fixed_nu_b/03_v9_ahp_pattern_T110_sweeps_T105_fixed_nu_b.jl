# This file is included after 03_v9_ahp_pattern_T110_replication_fixed_nu_b.jl.
# It uses that file's fixed-nu_b parameter factory, model-validity gates, CSV
# helpers, and plotting defaults.

const NB19_SWEEP_T_max = 105
const NB19_SWEEP_REFERENCE_T = 104
const NB19_SWEEP_BOUND_CUTOFF = 103
const NB19_SWEEP_ENDPOINT_GUARD = NB19_SWEEP_T_max - NB19_SWEEP_BOUND_CUTOFF
const NB19_SWEEP_HORIZONS = [30, 45, 60, 70, 80, 90, 100, 103, 104, 105]
const NB19_SWEEP_BRANCH_ITER_SCHEDULE = parse.(Int, strip.(split(get(
    ENV, "NB03_FIXED_NU_B_SWEEP_BRANCH_ITER_SCHEDULE", "60",
), ",")))
@assert !isempty(NB19_SWEEP_BRANCH_ITER_SCHEDULE) &&
        all(>(0), NB19_SWEEP_BRANCH_ITER_SCHEDULE)
const NB19_SWEEP_PREFIX_TOL = 1e-4
const NB19_SWEEP_CONE_MARGIN = 0.05
const NB19_SWEEP_HKT_TAIL_WINDOW = 8
const NB19_SWEEP_HKT_E_RATIO_TOL = 1e-4
const NB19_SWEEP_HKT_FUNDING_GAP_TOL = 1e-3
const NB19_SWEEP_HKT_PHI_GAP_TOL = 1e-3

# The single-country grid is retained.  π=0.75 is added because it is the
# AHP-matching two-country baseline and otherwise would be absent from the plot.
const NB19_PI_SWEEP_GRID = [0.70, 0.75, 0.80, 0.90, 0.95, 0.97, 0.99, 0.995]
const NB19_GAMMA_SWEEP_GRID = [0.05, 0.25, 0.50, 0.75, 0.90]

println("\nTwo-country fixed-nu_b AHP-calibration parameter sweeps")
println("Fixed nu_b = xi_W:             1.0")
println("Common-growth restriction:     disabled")
println("Final sweep horizon T_max:      ", NB19_SWEEP_T_max)
println("Reference horizon:              ", NB19_SWEEP_REFERENCE_T)
println("Bound cutoff K:                 ", NB19_SWEEP_BOUND_CUTOFF)
println("Endpoint guard:                 ", NB19_SWEEP_ENDPOINT_GUARD)
println("Branch-iteration retry budget:  ", NB19_SWEEP_BRANCH_ITER_SCHEDULE)
println("π grid:                         ", NB19_PI_SWEEP_GRID)
println("γ grid:                         ", NB19_GAMMA_SWEEP_GRID)

function nb19_sweep_params(T::Int, branch_iters::Int;
                           pi_case::Float64, gamma_case::Float64)
    return ProductionParams(
        T_max=T, n_buffer=0, common_world_growth=false,
        β=0.45, γ=gamma_case, π_persist=pi_case,
        a_US=0.20, ϑ_US=0.85,
        a_W=0.06, H_W=3.0, L_W=3.0,
        A_X_US_u=15.0, A_L_US_u=1.5,
        ν_b=1.00, ν_u=1.75, ξ_u=2.25, ξ_W=1.00,
        ω̄=0.50, ω̄_star=0.25,
        κ=1.00, χ=0.0002, η=0.010,
        branch_iters=branch_iters, do_global_polish=false,
    )
end

function nb19_sweep_case_id(pi_case, gamma_case)
    pi_text = replace(@sprintf("%.3f", pi_case), "."=>"p")
    gamma_text = replace(@sprintf("%.2f", gamma_case), "."=>"p")
    return "pi_$(pi_text)_gamma_$(gamma_text)"
end

function nb19_solve_sweep_case(pi_case::Float64, gamma_case::Float64;
                               sweep_kind::String, sweep_value::Float64,
                               label::String,
                               initial_by_T::Dict{Int,Any}=Dict{Int,Any}())
    attempt_rows = Dict{String,Any}[]
    solved_by_T = Dict{Int,Any}()
    warm_result = nothing
    warm_T = missing

    for T in NB19_SWEEP_HORIZONS
        solved_here = nothing
        # Use the cross-parameter seed only to enter the target case at the
        # first horizon. Thereafter, horizon continuation in the target
        # parameterization is the economically and numerically closer seed.
        parameter_seed = warm_result === nothing ? get(initial_by_T, T, nothing) : nothing
        seed_result = parameter_seed === nothing ? warm_result : parameter_seed
        seed_T = parameter_seed === nothing ? warm_T : T
        seed_kind = parameter_seed === nothing ?
            (warm_result === nothing ? "none" : "horizon") : "parameter"
        structural_failure = false
        for branch_iters in NB19_SWEEP_BRANCH_ITER_SCHEDULE
            @printf("%-12s %-21s T=%3d iter=%3d warm=%s\n",
                    sweep_kind, label, T, branch_iters,
                    seed_T === missing ? "" : string(seed_T))
            started = time()
            try
                result = run_production_simulation(
                    nb19_sweep_params(T, branch_iters;
                        pi_case=pi_case, gamma_case=gamma_case);
                    verbose=false,
                    initial_u_path=seed_result === nothing ? nothing :
                        seed_result.u_path_extended,
                    initial_bgp_seq=seed_result === nothing ? nothing :
                        seed_result.bgp_seq_extended,
                )
                safe = nb19_model_residual_safe(result)
                push!(attempt_rows, Dict{String,Any}(
                    "sweep_kind"=>sweep_kind,
                    "sweep_value"=>sweep_value,
                    "case_id"=>nb19_sweep_case_id(pi_case, gamma_case),
                    "label"=>label,
                    "pi"=>pi_case,
                    "gamma"=>gamma_case,
                    "T_max"=>T,
                    "branch_iters"=>branch_iters,
                    "warm_start_T"=>seed_T,
                    "seed_kind"=>seed_kind,
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
                error_text = sprint(showerror, err)
                push!(attempt_rows, Dict{String,Any}(
                    "sweep_kind"=>sweep_kind,
                    "sweep_value"=>sweep_value,
                    "case_id"=>nb19_sweep_case_id(pi_case, gamma_case),
                    "label"=>label,
                    "pi"=>pi_case,
                    "gamma"=>gamma_case,
                    "T_max"=>T,
                    "branch_iters"=>branch_iters,
                    "warm_start_T"=>seed_T,
                    "seed_kind"=>seed_kind,
                    "status"=>"error",
                    "elapsed_sec"=>time() - started,
                    "branch_converged"=>missing,
                    "max_u_residual"=>missing,
                    "max_bgp_residual"=>missing,
                    "residual_safe"=>false,
                    "error"=>error_text,
                ))
                # A missing required terminal BGP successor occurs before the
                # forward-backward iteration begins. A larger iteration budget
                # therefore cannot change this classification.
                structural_failure = occursin(
                    "required terminal successor", error_text,
                )
                structural_failure && break
            end
        end
        if solved_here === nothing
            last_attempt = last(attempt_rows)
            failure_reason = isempty(string(last_attempt["error"])) ?
                "no residual-safe solution within iteration schedule" :
                string(last_attempt["error"])
            return (;
                status=:failed,
                failure_T=T,
                failure_reason,
                sweep_kind, sweep_value, label, pi_case, gamma_case,
                case_id=nb19_sweep_case_id(pi_case, gamma_case),
                result=nothing, reference_result=nothing,
                accounting=nothing, common=nothing, validity=nothing,
                attempt_rows, solved_by_T,
            )
        end
        solved_by_T[T] = solved_here
        warm_result = solved_here
        warm_T = T
    end

    final_result = solved_by_T[NB19_SWEEP_T_max]
    reference_result = solved_by_T[NB19_SWEEP_REFERENCE_T]
    accounting = nb19_ahp_accounting(final_result)
    common = nb19_common_growth_summary(final_result)
    validity = nb19_hard_validity(final_result, accounting, common)
    if !validity.valid
        failed_gates = String[]
        for field in (
            :model_residuals, :psi_interior, :equity_interior,
            :theta_interior, :positive_foreign_claims, :positive_returns,
            :accounting_exact, :finite_accounting,
            :extended_bgp_valid, :exponent_ordering,
        )
            getproperty(validity, field) || push!(failed_gates, String(field))
        end
        theta_min = minimum(nb19_path_vector(final_result, :θ_US_star))
        gate_detail = validity.theta_interior ? "" :
            @sprintf("; min theta_US_star=%.6f < %.3f",
                     theta_min, NB19_THETA_INTERIOR_TOL)
        return (;
            status=:failed_hard_gate,
            failure_T=NB19_SWEEP_T_max,
            failure_reason="failed hard gate(s): $(join(failed_gates, ", "))$(gate_detail)",
            sweep_kind, sweep_value, label, pi_case, gamma_case,
            case_id=nb19_sweep_case_id(pi_case, gamma_case),
            result=final_result, reference_result,
            accounting, common, validity, attempt_rows, solved_by_T,
        )
    end

    return (;
        status=:ok,
        failure_T=missing,
        failure_reason="",
        sweep_kind, sweep_value, label, pi_case, gamma_case,
        case_id=nb19_sweep_case_id(pi_case, gamma_case),
        result=final_result, reference_result, accounting, common, validity,
        attempt_rows, solved_by_T,
    )
end

# Cache the common (π,γ) calibration because the π and γ grids share the
# baseline (0.75, 0.25).
nb19_sweep_cache = Dict{Tuple{Float64,Float64},Any}()
nb19_all_sweep_attempt_rows = Dict{String,Any}[]

# Solve the AHP point first and use its state-matched paths as parameter-
# continuation seeds at every horizon. This avoids treating a cold-start basin
# failure as an economic nonexistence result for a nearby comparative static.
nb19_baseline_sweep_case = nb19_solve_sweep_case(
    0.75, 0.25;
    sweep_kind="baseline", sweep_value=0.75,
    label="pi = 0.75, gamma = 0.25 (AHP seed)",
)
nb19_sweep_cache[(0.75, 0.25)] = nb19_baseline_sweep_case
append!(nb19_all_sweep_attempt_rows, nb19_baseline_sweep_case.attempt_rows)

function nb19_get_sweep_case(pi_case::Float64, gamma_case::Float64;
                             sweep_kind::String, sweep_value::Float64,
                             label::String)
    key = (pi_case, gamma_case)
    if haskey(nb19_sweep_cache, key)
        base = nb19_sweep_cache[key]
        return merge(base, (; sweep_kind, sweep_value, label))
    end
    case = nb19_solve_sweep_case(
        pi_case, gamma_case;
        sweep_kind=sweep_kind, sweep_value=sweep_value, label=label,
        initial_by_T=nb19_baseline_sweep_case.solved_by_T,
    )
    nb19_sweep_cache[key] = case
    append!(nb19_all_sweep_attempt_rows, case.attempt_rows)
    return case
end

pi_sweep_cases = [
    nb19_get_sweep_case(
        Float64(value), 0.25;
        sweep_kind="pi", sweep_value=Float64(value),
        label=isapprox(value, 0.75; atol=1e-12) ?
            @sprintf("π = %.3g (AHP)", value) : @sprintf("π = %.3g", value),
    ) for value in NB19_PI_SWEEP_GRID
]

gamma_sweep_cases = [
    nb19_get_sweep_case(
        0.75, Float64(value);
        sweep_kind="gamma", sweep_value=Float64(value),
        label=isapprox(value, 0.25; atol=1e-12) ?
            @sprintf("γ = %.3g (AHP)", value) : @sprintf("γ = %.3g", value),
    ) for value in NB19_GAMMA_SWEEP_GRID
]

pi_sweep_unavailable = filter(c -> c.status != :ok, pi_sweep_cases)
gamma_sweep_unavailable = filter(c -> c.status != :ok, gamma_sweep_cases)
pi_sweep_results = filter(c -> c.status == :ok, pi_sweep_cases)
gamma_sweep_results = filter(c -> c.status == :ok, gamma_sweep_cases)

nb19_sweep_attempt_columns = [
    "sweep_kind", "sweep_value", "case_id", "label", "pi", "gamma",
    "T_max", "branch_iters", "warm_start_T", "seed_kind", "status", "elapsed_sec",
    "branch_converged", "max_u_residual", "max_bgp_residual",
    "residual_safe", "error",
]
nb19_write_rows_csv(
    joinpath(NB19_OUTDIR, "sweep_solve_summary.csv"),
    nb19_all_sweep_attempt_rows, nb19_sweep_attempt_columns,
)

# -----------------------------------------------------------------------------
# a_t decomposition and HKT-entry diagnostic
# -----------------------------------------------------------------------------

function nb19_reconstruct_leakage(result::ProductionSimulationResult)
    p = result.params
    u = result.u_path
    bgp = result.bgp_seq
    T = length(u)
    a = zeros(Float64, T)
    dividend = zeros(Float64, T)
    switch_raw = zeros(Float64, T)
    switch_contribution = zeros(Float64, T)

    for k in 2:T
        prev = u[k - 1]
        current = u[k]
        b = bgp[k]
        D = current.d_US / current.q_US
        Lambda_u = prev.R_A_u / prev.R_US_u
        Lambda_b = prev.R_A_b / prev.R_US_b
        relative_switch_payoff = (b.q_US + b.d_US) / current.q_US
        L = (Lambda_u / Lambda_b)^p.γ *
            (1 + D)^p.γ * relative_switch_payoff^(1 - p.γ)
        S = (1 - p.π_persist) / p.π_persist * L
        dividend[k] = D
        switch_raw[k] = L
        switch_contribution[k] = S
        a[k] = D + S
    end
    return (; a, dividend, switch_raw, switch_contribution)
end

function nb19_tail_log_slope(values)
    idx = [i for i in eachindex(values) if isfinite(values[i]) && values[i] > 0]
    length(idx) < 2 && return NaN
    x = Float64.(idx)
    y = log.(Float64[values[i] for i in idx])
    xbar, ybar = mean(x), mean(y)
    sxx = sum(abs2, x .- xbar)
    sxx <= 0 && return NaN
    return sum((x .- xbar) .* (y .- ybar)) / sxx
end

function nb19_hkt_scalar_equation_value(p::ProductionParams, N_US::Real, phi::Real)
    aH = p.a_US * p.H_US
    B = (p.A_X_US_u * p.H_US * N_US^p.ξ_u) /
        (p.A_L_US_u * p.L_US * N_US^p.ν_u)
    c = (p.β * (1 - p.α_US)) / (p.ϑ_US * p.α_US)
    return phi - 1 + p.β + c * B^(p.ρ_US - 1) * phi^p.ρ_US - 1 / aH
end

function nb19_hkt_scalar_phi(p::ProductionParams, N_US::Real)
    f(phi) = nb19_hkt_scalar_equation_value(p, N_US, phi)
    f(1.0) <= 0 && return 1.0
    lo, hi = 1e-14, 1.0
    for _ in 1:240
        mid = 0.5 * (lo + hi)
        f(mid) > 0 ? (hi = mid) : (lo = mid)
    end
    return nb19_phi_clamp(0.5 * (lo + hi))
end

function nb19_hkt_gate_summary(result::ProductionSimulationResult;
                               last_k::Int=NB19_SWEEP_HKT_TAIL_WINDOW)
    p = result.params
    u = result.u_path
    T = length(u)
    lo = max(1, T - last_k + 1)
    tail = u[lo:T]
    e_ratios = Float64[s.e_W / s.e_US for s in tail]
    Y_ratios = Float64[s.Y_W / s.Y_US for s in tail]
    zeta_gaps = Float64[abs(s.Q_US / (p.β * s.e_US) - 1) for s in tail]

    sT = result.u_path_extended[end]
    N_US_next = G_N_US(p, sT.φ_US) * sT.N_US
    N_W_next = G_N_W(p, sT.φ_W) * sT.N_W
    phi_US_vals = Float64[s.φ_US for s in result.u_path_extended]
    phi_W_vals = Float64[s.φ_W for s in result.u_path_extended]
    phi_US_next = nb19_phi_clamp(phi_US_vals[end]^2 / phi_US_vals[end - 1])
    phi_W_next = nb19_phi_clamp(phi_W_vals[end]^2 / phi_W_vals[end - 1])
    us_next = us_block(p, :u, phi_US_next, N_US_next)
    rw_next = row_block(p, phi_W_next, N_W_next)
    hkt_phi_next = nb19_hkt_scalar_phi(p, N_US_next)
    us_hkt_next = us_block(p, :u, hkt_phi_next, N_US_next)

    max_tail_e = maximum(e_ratios)
    max_tail_Y = maximum(Y_ratios)
    e_slope = nb19_tail_log_slope(e_ratios)
    max_funding_gap = maximum(zeta_gaps)
    successor_e_ratio = rw_next.e / us_next.e
    successor_hkt_e_ratio = rw_next.e / us_hkt_next.e
    successor_phi_gap = abs(log(phi_US_next) - log(hkt_phi_next))
    hkt_phi_in_bounds = p.φ_floor <= hkt_phi_next <= 1 - p.φ_floor
    gate = nb19_model_residual_safe(result) && result.diagnostics.psi_ok &&
        max_tail_e <= NB19_SWEEP_HKT_E_RATIO_TOL &&
        max_tail_Y <= NB19_SWEEP_HKT_E_RATIO_TOL &&
        successor_e_ratio <= NB19_SWEEP_HKT_E_RATIO_TOL &&
        successor_hkt_e_ratio <= NB19_SWEEP_HKT_E_RATIO_TOL &&
        isfinite(e_slope) && e_slope < 0 &&
        max_funding_gap <= NB19_SWEEP_HKT_FUNDING_GAP_TOL &&
        successor_phi_gap <= NB19_SWEEP_HKT_PHI_GAP_TOL &&
        hkt_phi_in_bounds

    reasons = String[]
    max_tail_e <= NB19_SWEEP_HKT_E_RATIO_TOL || push!(reasons, "tail e_W/e_US")
    max_tail_Y <= NB19_SWEEP_HKT_E_RATIO_TOL || push!(reasons, "tail Y_W/Y_US")
    successor_e_ratio <= NB19_SWEEP_HKT_E_RATIO_TOL || push!(reasons, "LL successor dominance")
    successor_hkt_e_ratio <= NB19_SWEEP_HKT_E_RATIO_TOL || push!(reasons, "HKT successor dominance")
    isfinite(e_slope) && e_slope < 0 || push!(reasons, "tail dominance slope")
    max_funding_gap <= NB19_SWEEP_HKT_FUNDING_GAP_TOL || push!(reasons, "zeta convergence")
    successor_phi_gap <= NB19_SWEEP_HKT_PHI_GAP_TOL || push!(reasons, "LL-HKT phi agreement")
    hkt_phi_in_bounds || push!(reasons, "HKT phi bounds")

    return (;
        hkt_entry_gate=gate,
        hkt_entry_reason=gate ? "passed" : join(reasons, " | "),
        max_tail_e_W_over_e_US=max_tail_e,
        max_tail_Y_W_over_Y_US=max_tail_Y,
        tail_log_slope_e_W_over_e_US=e_slope,
        max_tail_abs_zeta_gap=max_funding_gap,
        successor_e_W_over_e_US=successor_e_ratio,
        successor_HKT_e_W_over_e_US=successor_hkt_e_ratio,
        successor_LL_vs_HKT_phi_log_gap=successor_phi_gap,
    )
end

# -----------------------------------------------------------------------------
# Fundamental-value-free theoretical bounds, case by case
# -----------------------------------------------------------------------------

function nb19_sweep_bound_data(case)
    result = case.result
    reference = case.reference_result
    p = result.params
    u = result.u_path
    bgp = result.bgp_seq
    T = length(u)
    K = NB19_SWEEP_BOUND_CUTOFF
    T == NB19_SWEEP_T_max || error("Sweep bound requires T_max=105")
    length(reference.u_path) == NB19_SWEEP_REFERENCE_T ||
        error("Sweep bound requires a T=104 reference")
    T >= K + 2 || error("Bound cutoff does not leave a validation segment")

    exact = Float64.(result.diagnostics.a_t[1:T])
    exact_reference = Float64.(reference.diagnostics.a_t[1:K])
    rebuilt = nb19_reconstruct_leakage(result)
    reconstruction_error = maximum(abs.(exact .- rebuilt.a))
    finite_prefix_nonnegative = all(x -> isfinite(x) && x >= 0, exact[1:K])
    continuation_dates = collect((K + 1):(T - 1))
    state_check_dates = collect(K:(T - 1))
    continuation_nonnegative = all(
        x -> isfinite(x) && x >= 0, exact[continuation_dates],
    )

    final_log_prefix = -sum(log1p(exact[k]) for k in 2:K)
    reference_log_prefix = -sum(log1p(exact_reference[k]) for k in 2:K)
    prefix_product_log_gap = abs(final_log_prefix - reference_log_prefix)
    prefix_leakage_gap = maximum(abs.(exact[1:K] .- exact_reference))
    prefix_stable = prefix_product_log_gap <= NB19_SWEEP_PREFIX_TOL &&
                    prefix_leakage_gap <= NB19_SWEEP_PREFIX_TOL

    zeta_continuation_min = minimum(
        u[k].Q_US / (p.β * u[k].e_US) for k in state_check_dates
    )
    zeta_lower = (1 - NB19_SWEEP_CONE_MARGIN) * zeta_continuation_min
    zeta_lower_ok = zeta_continuation_min >= zeta_lower

    qbar_u = p.β * p.A_L_US_u * p.L_US *
        (1 - p.α_US)^(-1 / (p.ρ_US - 1)) /
        (1 + p.a_US * p.H_US * (1 - p.β))
    q_ratio_continuation_min = minimum(
        u[k].q_US / (qbar_u * u[k].N_US^(p.ν_u - 1))
        for k in state_check_dates
    )
    q_price_epsilon = clamp(
        1 - (1 - NB19_SWEEP_CONE_MARGIN) * q_ratio_continuation_min,
        1e-6, 1 - 1e-6,
    )
    q_lower_continuation_ok = all(
        u[k].q_US >= (1 - q_price_epsilon) *
            qbar_u * u[k].N_US^(p.ν_u - 1)
        for k in state_check_dates
    )

    lambda_ratio_continuation = Float64[
        (u[k - 1].R_A_u / u[k - 1].R_US_u) /
        (u[k - 1].R_A_b / u[k - 1].R_US_b)
        for k in continuation_dates
    ]
    observed_lambda_max = maximum(lambda_ratio_continuation)
    lambda_bound = 1.05 * observed_lambda_max
    lambda_observed_within_bound = isfinite(lambda_bound) &&
                                   lambda_bound >= observed_lambda_max

    nu_b_eff_full = Float64[b.ν_b_eff for b in result.bgp_seq_extended]
    observed_nu_b_max = maximum(bgp[k].ν_b_eff for k in continuation_dates)
    # The primitive nu_b=1 is global in this model, hence it is itself the
    # future-uniform exponent bound; no common-growth path is fed to the solve.
    nu_b_bound = p.ν_b
    nu_b_ordering = 0 <= nu_b_bound < p.ν_u

    psi = (p.ξ_u - p.ν_u) * (p.ρ_US - 1)
    kappa_D = psi / p.ρ_US
    kappa_S = (p.ν_u - nu_b_bound) * (1 - p.γ)
    C0 = 1 / (p.a_US * p.H_US) + 1
    K_u = (1 - p.α_US) / (p.ϑ_US * p.α_US) *
          ((p.A_X_US_u * p.H_US) /
           (p.A_L_US_u * p.L_US))^(p.ρ_US - 1)
    C_phi = ((C0 - p.β * zeta_lower) /
             (p.β * zeta_lower * K_u))^(1 / p.ρ_US)
    C_D = p.a_US * (1 - p.ϑ_US) / p.ϑ_US * p.H_US * C_phi
    C_b = p.ϑ_US * p.α_US^(-1 / (p.ρ_US - 1)) *
        p.Abar_X_US / p.a_US *
        (1 + p.a_US * (1 - p.ϑ_US) / p.ϑ_US * p.H_US)

    N_K = u[K].N_US
    phi_upper_K = C_phi * N_K^(-kappa_D)
    G_lower = 1 + p.a_US * p.H_US * (1 - phi_upper_K)
    analytic_growth_floor_ok = phi_upper_K < 1 && G_lower > 1
    C_S = lambda_bound^p.γ *
        (1 + C_D * N_K^(-kappa_D))^p.γ *
        (C_b / ((1 - q_price_epsilon) * qbar_u))^(1 - p.γ)
    denominators_ok = analytic_growth_floor_ok &&
        isfinite(kappa_D) && kappa_D > 0 &&
        isfinite(kappa_S) && kappa_S > 0
    Abar_K = denominators_ok ?
        C_D * N_K^(-kappa_D) / (G_lower^kappa_D - 1) +
        (1 - p.π_persist) / p.π_persist *
        C_S * N_K^(-kappa_S) / (G_lower^kappa_S - 1) : Inf

    dividend_envelope = Float64[C_D * s.N_US^(-kappa_D) for s in u]
    switch_envelope = Float64[C_S * s.N_US^(-kappa_S) for s in u]
    tail_dividend_envelope_ok = all(
        rebuilt.dividend[k] <= dividend_envelope[k] * (1 + 1e-10)
        for k in continuation_dates
    )
    tail_switch_envelope_ok = all(
        rebuilt.switch_raw[k] <= switch_envelope[k] * (1 + 1e-10)
        for k in continuation_dates
    )

    finite_envelope_diagnostics_pass = finite_prefix_nonnegative &&
        reconstruction_error <= 1e-8 && continuation_nonnegative &&
        prefix_stable && lambda_observed_within_bound && nu_b_ordering &&
        denominators_ok && isfinite(Abar_K) && Abar_K >= 0 &&
        zeta_lower_ok && q_lower_continuation_ok &&
        tail_dividend_envelope_ok && tail_switch_envelope_ok
    gate = nb19_hkt_gate_summary(result)
    bound_status = !finite_envelope_diagnostics_pass ?
        "invalid_finite_envelope_diagnostics" :
        !gate.hkt_entry_gate ? "diagnostic_only_hkt_gate_failed" :
        "conditional_on_unproven_future_envelope"

    logP = zeros(Float64, K)
    for k in K:-1:2
        logP[k - 1] = logP[k] - log1p(exact[k])
    end

    rows = NamedTuple[]
    for t in 1:K
        log_upper = logP[t]
        log_lower = finite_envelope_diagnostics_pass ? logP[t] - Abar_K : missing
        lower = log_lower === missing ? missing :
            (log_lower < log(floatmin(Float64)) ? 0.0 : exp(log_lower))
        push!(rows, (;
            t=t, model_t=t - 1,
            bubble_share_upper=exp(log_upper),
            log10_bubble_share_upper=log_upper / log(10.0),
            bubble_share_lower=lower,
            log10_bubble_share_lower=log_lower === missing ? missing :
                log_lower / log(10.0),
        ))
    end

    summary = (;
        bound_status,
        hkt_entry_gate=gate.hkt_entry_gate,
        hkt_entry_reason=gate.hkt_entry_reason,
        finite_envelope_diagnostics_pass,
        future_uniform_inputs_configured=false,
        lower_bound_certified=false,
        cutoff_t=K,
        endpoint_guard=T - K,
        prefix_reference_T=NB19_SWEEP_REFERENCE_T,
        prefix_product_log_gap,
        prefix_leakage_gap,
        prefix_stable,
        leakage_reconstruction_error=reconstruction_error,
        zeta_continuation_min,
        zeta_lower_assumption=zeta_lower,
        q_ratio_continuation_min,
        q_price_epsilon,
        observed_lambda_ratio_max=observed_lambda_max,
        lambda_ratio_bound=lambda_bound,
        observed_nu_b_eff_max=observed_nu_b_max,
        nu_b_eff_constant=maximum(abs.(nu_b_eff_full .- p.ν_b)) <= 1e-12,
        nu_b_uniform_bound=nu_b_bound,
        kappa_D, kappa_S, N_K, phi_upper_K,
        analytic_growth_floor_ok, G_lower, C_D, C_S,
        omitted_tail_bound=finite_envelope_diagnostics_pass ? Abar_K : missing,
        tail_dividend_envelope_ok,
        tail_switch_envelope_ok,
        max_tail_e_W_over_e_US=gate.max_tail_e_W_over_e_US,
        max_tail_Y_W_over_Y_US=gate.max_tail_Y_W_over_Y_US,
        max_tail_abs_zeta_gap=gate.max_tail_abs_zeta_gap,
        successor_LL_vs_HKT_phi_log_gap=gate.successor_LL_vs_HKT_phi_log_gap,
    )
    return (; rows, summary, terms=rebuilt)
end

function nb19_attach_bounds(case)
    bound = nb19_sweep_bound_data(case)
    return merge(case, (; bound))
end

pi_sweep_results = nb19_attach_bounds.(pi_sweep_results)
gamma_sweep_results = nb19_attach_bounds.(gamma_sweep_results)

# Rejoin the bound-bearing successful cases with the explicitly retained
# unavailable cases.  These vectors preserve the complete requested grids.
pi_sweep_cases = [
    case.status == :ok ?
        only(filter(r -> r.case_id == case.case_id, pi_sweep_results)) : case
    for case in pi_sweep_cases
]
gamma_sweep_cases = [
    case.status == :ok ?
        only(filter(r -> r.case_id == case.case_id, gamma_sweep_results)) : case
    for case in gamma_sweep_cases
]

# -----------------------------------------------------------------------------
# Exports
# -----------------------------------------------------------------------------

function nb19_sweep_path_rows(results)
    rows = Dict{String,Any}[]
    for case in results
        bound_by_t = Dict(r.t => r for r in case.bound.rows)
        exact = Float64.(case.result.diagnostics.a_t)
        for t in eachindex(exact)
            b = get(bound_by_t, t, nothing)
            push!(rows, Dict{String,Any}(
                "sweep_kind"=>case.sweep_kind,
                "sweep_value"=>case.sweep_value,
                "case_id"=>case.case_id,
                "label"=>case.label,
                "pi"=>case.pi_case,
                "gamma"=>case.gamma_case,
                "T_max"=>NB19_SWEEP_T_max,
                "t"=>t,
                "model_t"=>t - 1,
                "bound_status"=>case.bound.summary.bound_status,
                "bubble_share_upper"=>b === nothing ? missing : b.bubble_share_upper,
                "log10_bubble_share_upper"=>b === nothing ? missing : b.log10_bubble_share_upper,
                "bubble_share_lower"=>b === nothing ? missing : b.bubble_share_lower,
                "log10_bubble_share_lower"=>b === nothing ? missing : b.log10_bubble_share_lower,
                "a_t"=>exact[t],
                "dividend_yield_d_over_q"=>case.bound.terms.dividend[t],
                "switch_term_raw"=>case.bound.terms.switch_raw[t],
                "switch_contribution_weighted"=>case.bound.terms.switch_contribution[t],
            ))
        end
    end
    return rows
end

nb19_sweep_path_columns = [
    "sweep_kind", "sweep_value", "case_id", "label", "pi", "gamma",
    "T_max", "t", "model_t", "bound_status", "bubble_share_upper",
    "log10_bubble_share_upper", "bubble_share_lower",
    "log10_bubble_share_lower", "a_t", "dividend_yield_d_over_q",
    "switch_term_raw", "switch_contribution_weighted",
]
nb19_write_rows_csv(
    joinpath(NB19_OUTDIR, "sweep_pi_five_quantities.csv"),
    nb19_sweep_path_rows(pi_sweep_results), nb19_sweep_path_columns,
)
nb19_write_rows_csv(
    joinpath(NB19_OUTDIR, "sweep_gamma_five_quantities.csv"),
    nb19_sweep_path_rows(gamma_sweep_results), nb19_sweep_path_columns,
)

function nb19_sweep_summary_rows(cases)
    rows = Dict{String,Any}[]
    for case in cases
        solved = case.status == :ok
        s = solved ? case.bound.summary : nothing
        push!(rows, Dict{String,Any}(
            "sweep_kind"=>case.sweep_kind,
            "sweep_value"=>case.sweep_value,
            "case_id"=>case.case_id,
            "label"=>case.label,
            "pi"=>case.pi_case,
            "gamma"=>case.gamma_case,
            "T_max"=>NB19_SWEEP_T_max,
            "solve_status"=>String(case.status),
            "failure_T"=>case.failure_T,
            "failure_reason"=>case.failure_reason,
            "hard_valid"=>solved ? case.validity.valid : false,
            "max_u_residual"=>solved ? case.result.max_u_residual : missing,
            "max_bgp_residual"=>solved ? case.result.max_bgp_residual : missing,
            "bound_status"=>solved ? s.bound_status : "unavailable_no_T105_solution",
            "finite_envelope_diagnostics_pass"=>solved ? s.finite_envelope_diagnostics_pass : false,
            "lower_bound_certified"=>solved ? s.lower_bound_certified : false,
            "hkt_entry_gate"=>solved ? s.hkt_entry_gate : false,
            "hkt_entry_reason"=>solved ? s.hkt_entry_reason : "not evaluated",
            "cutoff_t"=>solved ? s.cutoff_t : missing,
            "endpoint_guard"=>solved ? s.endpoint_guard : missing,
            "prefix_reference_T"=>solved ? s.prefix_reference_T : missing,
            "prefix_product_log_gap"=>solved ? s.prefix_product_log_gap : missing,
            "prefix_leakage_gap"=>solved ? s.prefix_leakage_gap : missing,
            "prefix_stable"=>solved ? s.prefix_stable : false,
            "leakage_reconstruction_error"=>solved ? s.leakage_reconstruction_error : missing,
            "omitted_tail_bound"=>solved ? s.omitted_tail_bound : missing,
            "analytic_growth_floor_ok"=>solved ? s.analytic_growth_floor_ok : false,
            "tail_dividend_envelope_ok"=>solved ? s.tail_dividend_envelope_ok : false,
            "tail_switch_envelope_ok"=>solved ? s.tail_switch_envelope_ok : false,
            "max_tail_e_W_over_e_US"=>solved ? s.max_tail_e_W_over_e_US : missing,
            "max_tail_Y_W_over_Y_US"=>solved ? s.max_tail_Y_W_over_Y_US : missing,
            "max_tail_abs_zeta_gap"=>solved ? s.max_tail_abs_zeta_gap : missing,
            "successor_LL_vs_HKT_phi_log_gap"=>solved ? s.successor_LL_vs_HKT_phi_log_gap : missing,
        ))
    end
    return rows
end

nb19_sweep_summary_columns = [
    "sweep_kind", "sweep_value", "case_id", "label", "pi", "gamma",
    "T_max", "solve_status", "failure_T", "failure_reason", "hard_valid",
    "max_u_residual", "max_bgp_residual",
    "bound_status", "finite_envelope_diagnostics_pass",
    "lower_bound_certified", "hkt_entry_gate", "hkt_entry_reason",
    "cutoff_t", "endpoint_guard", "prefix_reference_T",
    "prefix_product_log_gap", "prefix_leakage_gap", "prefix_stable",
    "leakage_reconstruction_error", "omitted_tail_bound",
    "analytic_growth_floor_ok", "tail_dividend_envelope_ok",
    "tail_switch_envelope_ok", "max_tail_e_W_over_e_US",
    "max_tail_Y_W_over_Y_US", "max_tail_abs_zeta_gap",
    "successor_LL_vs_HKT_phi_log_gap",
]
nb19_all_sweep_summary_rows = vcat(
    nb19_sweep_summary_rows(pi_sweep_cases),
    nb19_sweep_summary_rows(gamma_sweep_cases),
)
nb19_write_rows_csv(
    joinpath(NB19_OUTDIR, "sweep_case_summary.csv"),
    nb19_all_sweep_summary_rows, nb19_sweep_summary_columns,
)

# -----------------------------------------------------------------------------
# Exactly five requested quantities per sweep
# -----------------------------------------------------------------------------

function nb19_sweep_color(i)
    colors = [:steelblue, :black, :darkorange, :forestgreen, :purple,
              :goldenrod, :teal, :crimson, :brown]
    return colors[mod1(i, length(colors))]
end

function nb19_plot_five_quantity_sweep(results;
                                       sweep_title::String,
                                       filename::String,
                                       unavailable=Any[])
    p_upper = plot(
        xlabel="model date t", ylabel="log10 upper bound",
        title="Theoretical bubble-share upper bound",
        legend=:outerbottom, legend_columns=2,
    )
    p_lower = plot(
        xlabel="model date t", ylabel="log10 lower bound",
        title="Theoretical bubble-share lower bound",
        legend=false,
    )
    p_a = plot(
        xlabel="model date t", ylabel="a(t)", title="Total leakage a(t)",
        legend=false,
    )
    p_dividend = plot(
        xlabel="model date t", ylabel="dividend yield d/q",
        title="Dividend-yield contribution", legend=false,
    )
    p_switch = plot(
        xlabel="model date t", ylabel="weighted switch term",
        title="Weighted switch contribution", legend=false,
    )

    for (i, case) in enumerate(results)
        color = nb19_sweep_color(i)
        baseline = isapprox(case.pi_case, 0.75; atol=1e-12) &&
                   isapprox(case.gamma_case, 0.25; atol=1e-12)
        lw = baseline ? 3.0 : 1.9
        ls = baseline ? :dash : :solid
        bound_t = Int[r.model_t for r in case.bound.rows]
        upper = Float64[r.log10_bubble_share_upper for r in case.bound.rows]
        lower = Float64[
            r.log10_bubble_share_lower === missing ? NaN :
                r.log10_bubble_share_lower for r in case.bound.rows
        ]
        path_t = collect(0:(length(case.result.diagnostics.a_t) - 1))
        exact = Float64.(case.result.diagnostics.a_t)
        plot!(p_upper, bound_t, upper; label=case.label, color=color, lw=lw, ls=ls)
        plot!(p_lower, bound_t, lower; label="", color=color, lw=lw, ls=ls)
        plot!(p_a, path_t, exact; label="", color=color, lw=lw, ls=ls)
        plot!(p_dividend, path_t, case.bound.terms.dividend;
              label="", color=color, lw=lw, ls=ls)
        plot!(p_switch, path_t, case.bound.terms.switch_contribution;
              label="", color=color, lw=lw, ls=ls)
    end

    hline!(p_a, [0.0], color=:gray55, ls=:dot, lw=1.0, label="")
    hline!(p_dividend, [0.0], color=:gray55, ls=:dot, lw=1.0, label="")
    hline!(p_switch, [0.0], color=:gray55, ls=:dot, lw=1.0, label="")
    blank = plot(axis=false, grid=false, legend=false, ticks=false,
                 framestyle=:none, xlims=(0, 1), ylims=(0, 1))
    if !isempty(unavailable)
        short_reason(c) = c.status == :failed_hard_gate ?
            "theta* < 1%" : "no date-106 BGP"
        unavailable_text = "Unavailable at Tmax=105:\n" *
            join(["$(c.label): $(short_reason(c))" for c in unavailable], "\n")
        annotate!(blank, 0.05, 0.55, text(unavailable_text, 10, :black, :left))
    else
        annotate!(blank, 0.5, 0.55, text("All requested grid points solved", 11))
    end
    fig = plot(
        p_upper, p_lower, p_a, p_dividend, p_switch, blank,
        layout=(2, 3), size=(1650, 940), plot_title=sweep_title,
        bottom_margin=9mm, left_margin=9mm, right_margin=6mm,
    )
    savefig(fig, joinpath(NB19_OUTDIR, filename))
    return fig
end

pi_sweep_five_quantity_fig = nb19_plot_five_quantity_sweep(
    pi_sweep_results;
    sweep_title="AHP-calibrated two-country sweep over π, Tmax=105",
    filename="sweep_pi_five_quantities.png",
    unavailable=pi_sweep_unavailable,
)
gamma_sweep_five_quantity_fig = nb19_plot_five_quantity_sweep(
    gamma_sweep_results;
    sweep_title="AHP-calibrated two-country sweep over γ, Tmax=105",
    filename="sweep_gamma_five_quantities.png",
    unavailable=gamma_sweep_unavailable,
)

# -----------------------------------------------------------------------------
# U.S. NFA decomposition for the same π and γ sweep cases
# -----------------------------------------------------------------------------

function nb19_sweep_nfa_series(accounting)
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

function nb19_sweep_nfa_decomposition_error(accounting)
    a = accounting
    discrepancy = (a.NFA .- a.NFA[1]) .-
                  (a.cum_VA .+ a.cum_CA .+ a.cum_RES)
    return maximum(abs.(discrepancy ./ a.Y_US))
end

function nb19_sweep_nfa_path_rows(results)
    rows = Dict{String,Any}[]
    for case in results
        series = nb19_sweep_nfa_series(case.accounting)
        for t in eachindex(series.rebased_nfa)
            push!(rows, Dict{String,Any}(
                "sweep_kind"=>case.sweep_kind,
                "sweep_value"=>case.sweep_value,
                "case_id"=>case.case_id,
                "label"=>case.label,
                "pi"=>case.pi_case,
                "gamma"=>case.gamma_case,
                "T_max"=>NB19_SWEEP_T_max,
                "t"=>t,
                "model_t"=>t - 1,
                "rebased_nfa_current_Y"=>series.rebased_nfa[t],
                "cum_va_current_Y"=>series.cum_va[t],
                "cum_va_asset_current_Y"=>series.cum_va_asset[t],
                "cum_va_liability_current_Y"=>series.cum_va_liability[t],
                "cum_ca_current_Y"=>series.cum_ca[t],
                "cum_ca_asset_current_Y"=>series.cum_ca_asset[t],
                "cum_ca_liability_current_Y"=>series.cum_ca_liability[t],
                "cum_ca_bond_current_Y"=>series.cum_ca_bond[t],
                "q_us_index"=>series.q_us_index[t],
                "q_row_index"=>series.q_row_index[t],
                "row_equity_asset_current_Y"=>series.row_equity_asset[t],
                "us_equity_liability_current_Y"=>
                    series.us_equity_liability[t],
            ))
        end
    end
    return rows
end

nb19_sweep_nfa_path_columns = [
    "sweep_kind", "sweep_value", "case_id", "label", "pi", "gamma",
    "T_max", "t", "model_t", "rebased_nfa_current_Y",
    "cum_va_current_Y", "cum_va_asset_current_Y",
    "cum_va_liability_current_Y", "cum_ca_current_Y",
    "cum_ca_asset_current_Y", "cum_ca_liability_current_Y",
    "cum_ca_bond_current_Y", "q_us_index", "q_row_index",
    "row_equity_asset_current_Y", "us_equity_liability_current_Y",
]
nb19_write_rows_csv(
    joinpath(NB19_OUTDIR, "sweep_pi_nfa_components.csv"),
    nb19_sweep_nfa_path_rows(pi_sweep_results),
    nb19_sweep_nfa_path_columns,
)
nb19_write_rows_csv(
    joinpath(NB19_OUTDIR, "sweep_gamma_nfa_components.csv"),
    nb19_sweep_nfa_path_rows(gamma_sweep_results),
    nb19_sweep_nfa_path_columns,
)

const NB19_SWEEP_NFA_PANEL_SPECS = [
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

function nb19_plot_sweep_nfa_decomposition(results;
                                           sweep_title::String,
                                           filename::String,
                                           unavailable=Any[])
    isempty(results) && error("No hard-valid NFA cases to plot")
    panels = Any[]
    for (panel_index, spec) in enumerate(NB19_SWEEP_NFA_PANEL_SPECS)
        panel_title = spec.title
        if panel_index == 1 && !isempty(unavailable)
            panel_title *= "\nUnavailable: " *
                join((case.label for case in unavailable), ", ")
        end
        panel = plot(
            xlabel="model date t", ylabel=spec.ylabel, title=panel_title,
            legend=panel_index == 1 ? :outerbottom : false,
            legend_columns=min(3, length(results)),
        )
        for (i, case) in enumerate(results)
            series = getproperty(
                nb19_sweep_nfa_series(case.accounting), spec.key,
            )
            baseline = isapprox(case.pi_case, 0.75; atol=1e-12) &&
                       isapprox(case.gamma_case, 0.25; atol=1e-12)
            plot!(
                panel, 0:(length(series) - 1), series;
                color=nb19_sweep_color(i),
                lw=baseline ? 3.0 : 1.9,
                ls=baseline ? :dash : :solid,
                label=panel_index == 1 ? case.label : "",
            )
        end
        if spec.key in (
            :rebased_nfa, :cum_va, :cum_va_asset, :cum_va_liability,
            :cum_ca, :cum_ca_asset, :cum_ca_liability, :cum_ca_bond,
        )
            hline!(panel, [0.0], color=:gray55, ls=:dot, lw=0.9, label="")
        end
        push!(panels, panel)
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

pi_sweep_nfa_figure = nb19_plot_sweep_nfa_decomposition(
    pi_sweep_results;
    sweep_title="AHP-calibrated U.S. NFA decomposition: π sweep, Tmax=105",
    filename="sweep_pi_nfa_12_panels.png",
    unavailable=pi_sweep_unavailable,
)
gamma_sweep_nfa_figure = nb19_plot_sweep_nfa_decomposition(
    gamma_sweep_results;
    sweep_title="AHP-calibrated U.S. NFA decomposition: γ sweep, Tmax=105",
    filename="sweep_gamma_nfa_12_panels.png",
    unavailable=gamma_sweep_unavailable,
)

println("\nU.S. NFA sweep-accounting validation")
for (name, results) in (("pi", pi_sweep_results),
                        ("gamma", gamma_sweep_results))
    max_error = maximum(
        nb19_sweep_nfa_decomposition_error(case.accounting)
        for case in results
    )
    @printf("%-8s cases=%d  max normalized decomposition error=%.3e\n",
            name, length(results), max_error)
end

println("\nSweep certification summary")
@printf("%-12s %-17s %11s %11s %9s %12s %s\n",
        "sweep", "case", "max u res", "prefix gap", "prefix ok",
        "finite env", "bound status")
for case in vcat(pi_sweep_cases, gamma_sweep_cases)
    if case.status == :ok
        plotted_case = only(filter(
            c -> c.case_id == case.case_id && c.sweep_kind == case.sweep_kind,
            vcat(pi_sweep_results, gamma_sweep_results),
        ))
        s = plotted_case.bound.summary
        @printf("%-12s %-17s %11.3e %11.3e %9s %12s %s\n",
                case.sweep_kind, case.label, case.result.max_u_residual,
                s.prefix_product_log_gap, string(s.prefix_stable),
                string(s.finite_envelope_diagnostics_pass), s.bound_status)
    else
        @printf("%-12s %-17s %11s %11s %9s %12s %s\n",
                case.sweep_kind, case.label, "", "", "false", "false",
                "unavailable at T=$(case.failure_T)")
    end
end
println("\nInterpretation: lower bounds are not certified at T_max=105; see")
println("sweep_case_summary.csv for the HKT-entry and future-envelope qualifications.")

nothing
