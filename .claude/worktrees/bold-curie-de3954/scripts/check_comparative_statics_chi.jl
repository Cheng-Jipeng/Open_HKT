using Pkg

Pkg.activate(joinpath(@__DIR__, ".."))

include(joinpath(@__DIR__, "..", "TwoCountryOLG.jl"))

function run_and_summarize(p::ModelParams)
    try
        res = run_simulation(p; verbose=false)
        s0 = res.u_path[1]
        d = res.diagnostics

        return (
            converged = true,
            ω_0 = s0.ω,
            ω_star_0 = s0.ω_star,
            θ_0 = s0.θ,
            θ_Us_0 = s0.θ_US_star,
            ω_path = [s.ω for s in res.u_path],
            θ_path = [s.θ for s in res.u_path],
            θ_Us_path = [s.θ_US_star for s in res.u_path],
            ω_RoW_eq_path = [1.0 - s.ω_star for s in res.u_path],
            R_f_0 = s0.R_f,
            R_f_W_0 = s0.R_f_W,
            ep_0 = s0.R_f - s0.R_f_W,
            Q_US_0 = s0.Q_US,
            Q_W_0 = s0.Q_W,
            us_share = s0.Q_US / (s0.Q_US + s0.Q_W),
            sum_at = d.sum_a_t[end],
            sum_2a = d.sum_dividend_ratio[end],
            sum_2b = d.sum_cond_2b[end],
            bubble = d.bubble_exists,
            result = res,
        )
    catch err
        @warn "Simulation failed" p err
        return (
            converged = false,
            ω_0 = NaN,
            ω_star_0 = NaN,
            θ_0 = NaN,
            θ_Us_0 = NaN,
            ω_path = Float64[],
            θ_path = Float64[],
            θ_Us_path = Float64[],
            ω_RoW_eq_path = Float64[],
            R_f_0 = NaN,
            R_f_W_0 = NaN,
            ep_0 = NaN,
            Q_US_0 = NaN,
            Q_W_0 = NaN,
            us_share = NaN,
            sum_at = NaN,
            sum_2a = NaN,
            sum_2b = NaN,
            bubble = false,
            result = nothing,
        )
    end
end

θ_path_of(r) = hasproperty(r, :θ_path) ? r.θ_path : [s.θ for s in r.result.u_path]

function check_result(r, plot_periods)
    path_lengths = (
        ω = length(r.ω_path),
        θ = length(θ_path_of(r)),
        θ_Us = length(r.θ_Us_path),
        ω_RoW_eq = length(r.ω_RoW_eq_path),
    )

    minimum(values(path_lengths)) > 0 || error("One or more plotted paths are empty")

    for (name, len) in pairs(path_lengths)
        n_plot = min(plot_periods, len)
        n_plot > 0 || error("Plot horizon for $(name) is empty")
    end

    isfinite(r.R_f_0) || error("R_f_0 is not finite")
    isfinite(r.ep_0) || error("ep_0 is not finite")
    isfinite(r.sum_at) || error("sum_at is not finite")

    return path_lengths
end

function main()
    plot_periods = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 50
    chi_vals = [0.005, 0.01, 0.02, 0.03]

    println("Running χ comparative-statics validation with plot_periods=$(plot_periods)")
    chi_results = [run_and_summarize(ModelParams(χ=v)) for v in chi_vals]
    converged = Tuple{Float64, Any}[]
    failed = Float64[]

    for (v, r) in zip(chi_vals, chi_results)
        if !r.converged
            push!(failed, v)
            println("χ=$(v): converged=false")
            continue
        end

        lengths = check_result(r, plot_periods)
        push!(converged, (v, r))
        println(
            "χ=$(v): converged=$(r.converged), ",
            "R_f=$(round(r.R_f_0, digits=4)), ",
            "EP=$(round(r.ep_0, digits=4)), ",
            "θ0=$(round(r.θ_0, digits=6)), ",
            "path_lengths=$(lengths)",
        )
    end

    isempty(converged) && error("No χ runs converged; notebook path plots would be empty")

    if !isempty(failed)
        println("non-converged χ values: ", failed)
    end

    println("chi comparative-statics check passed")
end

main()
