using Pkg

const PROBE_DIR = @__DIR__
const MODEL_DIR = dirname(PROBE_DIR)
const PROJECT_DIR = dirname(MODEL_DIR)

Pkg.activate(PROJECT_DIR)
include(joinpath(MODEL_DIR, "TwoCountryProductionOLG.jl"))

using Printf
using Serialization

function ahp_params(T::Int, branch_iters::Int)
    return ProductionParams(
        T_max=T,
        n_buffer=0,
        β=0.45,
        γ=0.25,
        π_persist=0.75,
        a_US=0.20,
        ϑ_US=0.85,
        a_W=0.06,
        H_W=3.0,
        L_W=3.0,
        A_X_US_u=15.0,
        A_L_US_u=1.5,
        ν_b=0.10,
        ν_u=1.75,
        ξ_u=2.25,
        ξ_W=1.00,
        ω̄=0.50,
        ω̄_star=0.25,
        κ=1.00,
        χ=0.0002,
        η=0.010,
        common_world_growth=true,
        branch_iters=branch_iters,
        do_global_polish=false,
    )
end

function solve_case(T::Int, branch_iters::Int; initial_u_path=nothing, verbose::Bool=true)
    p = ahp_params(T, branch_iters)
    started = time()
    result = run_production_simulation(
        p; verbose=verbose, initial_u_path=initial_u_path,
    )
    elapsed = time() - started
    residuals = Float64[s.residual_norm for s in result.u_path]
    max_residual, max_t = findmax(residuals)
    safe = result.branch_converged && max_residual <= 1e-5 &&
           result.max_bgp_residual <= 1e-5
    @printf(
        "PROBE_RESULT T=%d branch_iters=%d start=%s elapsed_sec=%.6f branch_converged=%s max_u_residual=%.9e max_u_residual_t=%d max_bgp_residual=%.9e phi_US_end=%.9e safe=%s\n",
        T,
        branch_iters,
        initial_u_path === nothing ? "cold" : "warm",
        elapsed,
        result.branch_converged,
        max_residual,
        max_t,
        result.max_bgp_residual,
        result.u_path[end].φ_US,
        safe,
    )
    flush(stdout)
    return result, safe
end

function parse_int_arg(index::Int, default::Int)
    length(ARGS) >= index || return default
    return parse(Int, ARGS[index])
end

function search_frontier(
    search_cap::Int, branch_iters::Int, seed_iters::Int;
    start_T::Int=70, step::Int=10, verbose::Bool=false,
)
    start_T >= 60 || error("frontier start must be at least T=60")
    step > 0 || error("frontier step must be positive")
    search_cap >= start_T || error("frontier cap must be at least the start")

    cache_file = get(ENV, "T70_FRONTIER_CACHE", "")
    resume = lowercase(get(ENV, "T70_FRONTIER_RESUME", "false")) in
             ("1", "true", "yes")
    seed_path = nothing
    last_safe_T = 0
    last_safe_result = nothing
    if resume && !isempty(cache_file) && isfile(cache_file)
        cached = deserialize(cache_file)
        cached.T < start_T || error("cached T must be below frontier start")
        seed_path = cached.u_path
        last_safe_T = cached.T
        println("Resuming frontier from exact T=", last_safe_T, " state")
    else
        for T in (30, 45, 60)
            result, safe = solve_case(
                T, seed_iters; initial_u_path=seed_path, verbose=verbose,
            )
            safe || return 2
            seed_path = result.u_path_extended
            last_safe_T = T
            last_safe_result = result
        end
    end

    targets = collect(start_T:step:search_cap)
    targets[end] == search_cap || push!(targets, search_cap)
    for T in targets
        result, safe = solve_case(
            T, branch_iters; initial_u_path=seed_path, verbose=verbose,
        )
        @printf(
            "FRONTIER_STEP T=%d previous_safe_T=%d safe=%s\n",
            T, last_safe_T, safe,
        )
        flush(stdout)
        if !safe
            @printf(
                "FRONTIER_RESULT last_safe_T=%d first_failed_T=%d right_censored=false\n",
                last_safe_T, T,
            )
            return 1
        end
        seed_path = result.u_path_extended
        last_safe_T = T
        last_safe_result = result
        if !isempty(cache_file)
            serialize(cache_file, (; T=last_safe_T, u_path=seed_path))
            println("Saved safe frontier state T=", last_safe_T, " to ", cache_file)
        end
    end

    @printf(
        "FRONTIER_RESULT last_safe_T=%d first_failed_T=missing right_censored=true\n",
        last_safe_T,
    )
    return 0
end

function diagnose_warm_bgp_tail(
    cache_file::AbstractString, target_T::Int; carry_local_exponent::Bool=false,
)
    isfile(cache_file) || error("missing exact warm-seed cache: $(cache_file)")
    cached = deserialize(cache_file)
    seed_path = hasproperty(cached, :u_path) ? cached.u_path : cached
    p_input = ahp_params(target_T, 1)
    initial_calibration = calibrate_common_growth(
        p_input, p_input.N_US_0, p_input.N_W_0; verbose=false,
    )
    p = initial_calibration.params
    bgp = initial_calibration.bgp

    pol = Matrix{Float64}(undef, 7, target_T + 1)
    _seed_policy_from_u_path!(pol, seed_path, target_T)
    N_US = knowledge_path_US(p, pol[1, 1:target_T])
    N_W = knowledge_path_W(p, pol[2, 1:target_T])

    println("BGP_TAIL_HEADER t elapsed_sec N_US N_W phi_seed_US phi_seed_W nu_b_eff phi_b phi_W R_A R_As residual converged common_log_gap")
    verbose_bgp = lowercase(get(ENV, "T70_BGPDIAG_VERBOSE", "false")) in
                  ("1", "true", "yes")
    verbose_start = parse(Int, get(ENV, "T70_BGPDIAG_VERBOSE_START", "63"))
    for t in 2:(target_T + 1)
        x0 = (
            bgp.φ_US, bgp.φ_W, bgp.ω, bgp.θ_US_star,
            bgp.ω_star, bgp.R_f, bgp.R_f_W,
        )
        p_seed = carry_local_exponent ?
            ProductionParams(p; ν_b=bgp.ν_b_eff) : p
        started = time()
        bgp = solve_selected_bgp_at(
            p_seed, N_US[t], N_W[t];
            x0_actual=x0, verbose=verbose_bgp && t >= verbose_start,
        )
        elapsed = time() - started
        common_gap = bgp.ν_b_eff * log(bgp.G_N_US) - p.ξ_W * log(bgp.G_N_W)
        if t >= 55
            @printf(
                "BGP_TAIL t=%d elapsed_sec=%.6f N_US=%.9e N_W=%.9e phi_seed_US=%.9e phi_seed_W=%.9e nu_b_eff=%.9e phi_b=%.9e phi_W=%.9e R_A=%.9e R_As=%.9e residual=%.9e converged=%s common_log_gap=%.9e\n",
                t, elapsed, N_US[t], N_W[t], pol[1, t], pol[2, t], bgp.ν_b_eff,
                bgp.φ_US, bgp.φ_W, bgp.R_A, bgp.R_A_star,
                bgp.residual_norm, bgp.converged, common_gap,
            )
            flush(stdout)
        end
        if !bgp.converged || !isfinite(bgp.residual_norm) ||
           !isfinite(common_gap) || abs(common_gap) > 1e-7
            @printf(
                "BGP_TAIL_FAILURE t=%d residual=%.9e common_log_gap=%.9e\n",
                t, bgp.residual_norm, common_gap,
            )
            return 1
        end
    end
    return 0
end

function main()
    mode = length(ARGS) >= 1 ? Symbol(ARGS[1]) : :cold
    target_T = parse_int_arg(2, 70)
    target_iters = parse_int_arg(3, 60)
    seed_iters = parse_int_arg(4, 60)
    verbose = get(ENV, "T70_PROBE_VERBOSE", "true") == "true"
    cache_file = get(ENV, "T70_PROBE_CACHE", "/tmp/ahp_t60_u_path.jls")

    if mode == :bgpdiag
        return diagnose_warm_bgp_tail(cache_file, target_T)
    elseif mode == :bgpdiag_carry
        return diagnose_warm_bgp_tail(
            cache_file, target_T; carry_local_exponent=true,
        )
    elseif mode == :compare
        isfile(cache_file) || error("missing exact warm-seed cache: $(cache_file)")
        seed_path = deserialize(cache_file)
        cold, cold_safe = solve_case(target_T, target_iters; verbose=verbose)
        warm, warm_safe = solve_case(
            target_T, target_iters; initial_u_path=seed_path, verbose=verbose,
        )
        max_log_phi_gap = maximum(abs(
            log(cold.u_path[t].φ_US) - log(warm.u_path[t].φ_US)
        ) for t in eachindex(cold.u_path))
        max_log_q_gap = maximum(abs(
            log(cold.u_path[t].q_US) - log(warm.u_path[t].q_US)
        ) for t in eachindex(cold.u_path))
        @printf(
            "PROBE_COMPARE T=%d cold_safe=%s warm_safe=%s max_log_phi_US_gap=%.9e max_log_q_US_gap=%.9e\n",
            target_T, cold_safe, warm_safe, max_log_phi_gap, max_log_q_gap,
        )
        return cold_safe && warm_safe && max_log_phi_gap <= 1e-5 &&
               max_log_q_gap <= 1e-5 ? 0 : 1
    elseif mode == :cold
        _, safe = solve_case(target_T, target_iters; verbose=verbose)
        return safe ? 0 : 1
    elseif mode == :resume
        frontier_cache = get(ENV, "T70_FRONTIER_CACHE", "")
        isfile(frontier_cache) || error("missing frontier cache: $(frontier_cache)")
        cached = deserialize(frontier_cache)
        cached.T < target_T || error("cached T must be below target T")
        println("Solving from exact cached T=", cached.T, " state")
        _, safe = solve_case(
            target_T, target_iters;
            initial_u_path=cached.u_path, verbose=verbose,
        )
        return safe ? 0 : 1
    elseif mode == :frontier
        start_T = parse(Int, get(ENV, "T70_FRONTIER_START", "70"))
        step = parse(Int, get(ENV, "T70_FRONTIER_STEP", "10"))
        return search_frontier(
            target_T, target_iters, seed_iters;
            start_T=start_T, step=step, verbose=verbose,
        )
    elseif mode == :chain
        seed_path = if isfile(cache_file)
            println("Loading exact T=60 warm seed from ", cache_file)
            deserialize(cache_file)
        else
            nothing
        end
        if seed_path === nothing
            for T in (30, 45, 60)
                T >= target_T && break
                result, safe = solve_case(
                    T, seed_iters; initial_u_path=seed_path, verbose=verbose,
                )
                safe || return 2
                seed_path = result.u_path_extended
                if T == 60
                    serialize(cache_file, seed_path)
                    println("Saved exact T=60 warm seed to ", cache_file)
                end
            end
        end
        _, safe = solve_case(
            target_T, target_iters; initial_u_path=seed_path, verbose=verbose,
        )
        return safe ? 0 : 1
    else
        error("mode must be `bgpdiag`, `bgpdiag_carry`, `compare`, `cold`, `resume`, `frontier`, or `chain`")
    end
end

exit(main())
