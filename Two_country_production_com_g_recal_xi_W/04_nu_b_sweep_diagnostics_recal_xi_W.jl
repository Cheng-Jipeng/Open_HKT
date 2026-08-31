using Pkg

# Notebook 04 helper: all definitions and plotting functions live here so the
# executed notebook remains readable.  This file does not run the sweep on
# include; the notebook invokes each stage explicitly.

function nb04_find_model_dir(start_dir=pwd())
    dir = abspath(start_dir)
    while true
        candidates = (
            joinpath(dir, "Two_country_production_com_g_recal_xi_W"),
            joinpath(dir, "Codes", "Two_country_production_com_g_recal_xi_W"),
        )
        idx = findfirst(d -> isfile(joinpath(d, "TwoCountryProductionOLG.jl")), candidates)
        idx !== nothing && return candidates[idx]
        parent = dirname(dir)
        parent == dir && error("Could not locate the recalibrated-xi_W model from $(start_dir)")
        dir = parent
    end
end

const NB04_MODEL_DIR = nb04_find_model_dir()
const NB04_ENV_DIR = joinpath(NB04_MODEL_DIR, "julia_env")
Pkg.activate(NB04_ENV_DIR)

const NB04_MODEL_FILE = joinpath(NB04_MODEL_DIR, "TwoCountryProductionOLG.jl")
if @isdefined ProductionParams
    (:xi_W_eff in Symbol.(String.(fieldnames(BGPResult)))) ||
        (:ξ_W_eff in fieldnames(BGPResult)) ||
        error("A different TwoCountryProductionOLG solver is already loaded; restart the kernel")
else
    include(NB04_MODEL_FILE)
end

using LaTeXStrings
using Markdown
using Plots
using Printf
using Statistics
using Plots.PlotMeasures

gr()
default(
    framestyle=:box, grid=:y, legend=:best, fontfamily="Computer Modern",
    linewidth=2, titlefontsize=10, guidefontsize=9, tickfontsize=8,
    legendfontsize=7, left_margin=8mm, right_margin=5mm,
    top_margin=6mm, bottom_margin=7mm,
)

const NB04_NU_B_GRID = Float64[0.10, 0.50, 1.00, 1.30]
const NB04_TARGET_HORIZON = 80
const NB04_SWITCH_DATE = 5
const NB04_RESID_TOL = 1e-5
const NB04_COMMON_GROWTH_TOL = 1e-7
const NB04_ACCOUNTING_TOL = 1e-8
const NB04_EQUILIBRIUM_ID_TOL = 1e-6
const NB04_IDENTITY_TOL = 1e-7
const NB04_BRANCH_SCHEDULE = Int[60, 200]
const NB04_COARSE_HORIZONS = Int[5, 8, 10, 12, 15, 20, 25, 30, 45, 60, 70]

const NB04_OUTDIR = get(
    ENV, "NB04_RECAL_XI_W_OUTDIR",
    joinpath(NB04_MODEL_DIR, "outputs_recal_xi_W", "04_nu_b_sweep_diagnostics"),
)
mkpath(NB04_OUTDIR)

const NB04_CASES = [
    (nu_b=0.10, id="nu_b_0p1", label=L"\nu_b=0.1", color=:black),
    (nu_b=0.50, id="nu_b_0p5", label=L"\nu_b=0.5", color=:steelblue),
    (nu_b=1.00, id="nu_b_1p0", label=L"\nu_b=1.0", color=:darkorange2),
    (nu_b=1.30, id="nu_b_1p3", label=L"\nu_b=1.3", color=:firebrick3),
]

nb04_case(nu_b) = only(filter(c -> c.nu_b == nu_b, NB04_CASES))

function nb04_exact_params(nu_b::Real, T::Int, branch_iters::Int)
    ProductionParams(
        T_max=T, n_buffer=0, branch_iters=branch_iters,
        do_global_polish=false, common_world_growth=true,
        β=0.45, γ=0.25, π_persist=0.75,
        a_US=0.20, ϑ_US=0.85,
        a_W=0.06, H_W=3.0, L_W=3.0,
        A_X_US_u=15.0, A_L_US_u=1.5,
        ν_b=Float64(nu_b), ν_u=1.75, ξ_u=2.25, ξ_W=1.00,
        ω̄=0.50, ω̄_star=0.25,
        κ=1.00, χ=0.0002, η=0.010,
    )
end

function nb04_common_growth_summary(result)
    p = result.params
    bgps = result.bgp_seq
    nu_error = maximum(abs(b.ν_b_eff - p.ν_b) for b in bgps)
    xi_values = Float64[b.ξ_W_eff for b in bgps]
    gaps = Float64[
        p.ν_b * log(b.G_N_US) - b.ξ_W_eff * log(b.G_N_W) for b in bgps
    ]
    return (
        nu_error=nu_error,
        xi_min=minimum(xi_values),
        xi_max=maximum(xi_values),
        max_log_gap=maximum(abs.(gaps)),
        exact=nu_error <= 1e-12 && all(isfinite, xi_values) &&
              minimum(xi_values) >= 0 && maximum(abs.(gaps)) <= NB04_COMMON_GROWTH_TOL,
    )
end

function nb04_residual_safe(result)
    all_bgp_safe = !isempty(result.bgp_seq) && all(
        b -> b.converged && isfinite(b.residual_norm) && b.residual_norm <= NB04_RESID_TOL,
        result.bgp_seq,
    )
    return result.branch_converged &&
           isfinite(result.max_u_residual) && result.max_u_residual <= NB04_RESID_TOL &&
           isfinite(result.max_bgp_residual) && result.max_bgp_residual <= NB04_RESID_TOL &&
           all_bgp_safe && nb04_common_growth_summary(result).exact
end

nb04_csv_cell(x) = begin
    x === missing && return ""
    s = string(x)
    if occursin(',', s) || occursin('"', s) || occursin('\n', s)
        return "\"" * replace(s, "\"" => "\"\"") * "\""
    end
    s
end

function nb04_row_value(row, name::String)
    if row isa NamedTuple
        key = Symbol(name)
        return hasproperty(row, key) ? getproperty(row, key) : missing
    end
    return get(row, name, missing)
end

function nb04_write_csv(path, rows, columns)
    open(path, "w") do io
        println(io, join(columns, ','))
        for row in rows
            println(io, join((nb04_csv_cell(nb04_row_value(row, c)) for c in columns), ','))
        end
    end
    path
end

function nb04_markdown_table(headers, rows)
    lines = String[
        "| " * join(headers, " | ") * " |",
        "|" * join(fill("---", length(headers)), "|") * "|",
    ]
    append!(lines, ["| " * join(string.(row), " | ") * " |" for row in rows])
    Markdown.parse(join(lines, "\n"))
end

function nb04_attempt_solve!(attempt_rows, nu_b, T, seed, stage;
                             schedule=NB04_BRANCH_SCHEDULE)
    local_seed = seed
    for branch_iters in schedule
        started = time()
        try
            result = run_production_simulation(
                nb04_exact_params(nu_b, T, branch_iters);
                verbose=false,
                initial_u_path=local_seed === nothing ? nothing : local_seed.u_path_extended,
                initial_bgp_seq=local_seed === nothing ? nothing : local_seed.bgp_seq_extended,
            )
            safe = nb04_residual_safe(result)
            common = nb04_common_growth_summary(result)
            push!(attempt_rows, Dict{String,Any}(
                "nu_b"=>nu_b, "stage"=>stage, "T"=>T,
                "branch_iters"=>branch_iters,
                "warm_start_T"=>seed === nothing ? missing : length(seed.u_path),
                "status"=>safe ? "residual_safe" : "unsafe_residual",
                "elapsed_sec"=>time() - started,
                "branch_converged"=>result.branch_converged,
                "max_u_residual"=>result.max_u_residual,
                "max_bgp_residual"=>result.max_bgp_residual,
                "max_common_growth_log_gap"=>common.max_log_gap,
                "error"=>"",
            ))
            @printf("nu_b=%.2f stage=%s T=%d iters=%d: %s, max u/bgp %.3e / %.3e\n",
                    nu_b, stage, T, branch_iters,
                    safe ? "residual-safe" : "unsafe", result.max_u_residual,
                    result.max_bgp_residual)
            safe && return result
            local_seed = result
        catch err
            msg = sprint(showerror, err)
            push!(attempt_rows, Dict{String,Any}(
                "nu_b"=>nu_b, "stage"=>stage, "T"=>T,
                "branch_iters"=>branch_iters,
                "warm_start_T"=>seed === nothing ? missing : length(seed.u_path),
                "status"=>"error", "elapsed_sec"=>time() - started,
                "branch_converged"=>missing, "max_u_residual"=>missing,
                "max_bgp_residual"=>missing, "max_common_growth_log_gap"=>missing,
                "error"=>msg,
            ))
            @printf("nu_b=%.2f stage=%s T=%d iters=%d: unavailable (%s)\n",
                    nu_b, stage, T, branch_iters, msg)
        end
    end
    nothing
end

function nb04_solve_one_case!(attempt_rows, nu_b, direct_seed=nothing)
    # The reference note asks for a T=80 check before a shorter-horizon search.
    direct = nb04_attempt_solve!(attempt_rows, nu_b, NB04_TARGET_HORIZON,
                                 direct_seed, "direct_T80"; schedule=Int[60])
    if direct !== nothing
        # A same-horizon warm refinement lowers residuals without changing the
        # T=80 pass/fail classification.
        refined = nb04_attempt_solve!(attempt_rows, nu_b, NB04_TARGET_HORIZON,
                                      direct, "T80_refinement"; schedule=Int[200])
        return (
            result=refined === nothing ? direct : refined,
            T_max=NB04_TARGET_HORIZON, next_failed=missing,
            direct_T80="residual_safe",
        )
    end

    warm = nothing
    safe_T = 0
    first_failed = NB04_TARGET_HORIZON
    for T in NB04_COARSE_HORIZONS
        result = nb04_attempt_solve!(attempt_rows, nu_b, T, warm, "coarse_search")
        if result === nothing
            first_failed = T
            break
        end
        warm = result
        safe_T = T
    end

    if safe_T == last(NB04_COARSE_HORIZONS) && first_failed == NB04_TARGET_HORIZON
        warm_T80 = nb04_attempt_solve!(attempt_rows, nu_b, NB04_TARGET_HORIZON,
                                       warm, "warm_T80_recheck")
        if warm_T80 !== nothing
            return (
                result=warm_T80, T_max=NB04_TARGET_HORIZON, next_failed=missing,
                direct_T80="direct_unavailable_warm_safe",
            )
        end
    end

    safe_T == 0 && return (
        result=nothing, T_max=0, next_failed=first_failed,
        direct_T80="unavailable",
    )

    # Integer refinement identifies the connected numerical continuation
    # frontier and explicitly checks the immediately following horizon.
    for T in (safe_T + 1):(first_failed - 1)
        result = nb04_attempt_solve!(attempt_rows, nu_b, T, warm, "integer_refinement")
        if result === nothing
            first_failed = T
            break
        end
        warm = result
        safe_T = T
    end

    return (
        result=warm, T_max=safe_T, next_failed=first_failed,
        direct_T80="unavailable",
    )
end

function nb04_solve_grid()
    attempts = Dict{String,Any}[]
    solutions = Dict{Float64,Any}()
    solve_meta = Dict{Float64,Any}()

    direct_seed = nothing
    for nu_b in NB04_NU_B_GRID
        # Nearby-calibration state and policy paths are numerical initial
        # guesses only.  Every target case is re-solved under its own nu_b and
        # period-specific xi_W selection.
        meta = nb04_solve_one_case!(attempts, nu_b, direct_seed)
        solve_meta[nu_b] = meta
        if meta.result !== nothing
            solutions[nu_b] = meta.result
            direct_seed = meta.result
        end
    end

    summary = NamedTuple[]
    for nu_b in NB04_NU_B_GRID
        meta = solve_meta[nu_b]
        if meta.result === nothing
            push!(summary, (
                nu_b=nu_b, available=false, direct_T80=meta.direct_T80,
                T_max=0, plot_horizon=0, next_failed=meta.next_failed,
                max_u_residual=missing, max_bgp_residual=missing,
                xi_W_eff_min=missing, xi_W_eff_max=missing,
                max_common_growth_log_gap=missing, theta_US_star_min=missing,
                psi_min=missing, equity_weight_min=missing,
            ))
            continue
        end
        result = meta.result
        common = nb04_common_growth_summary(result)
        push!(summary, (
            nu_b=nu_b, available=true, direct_T80=meta.direct_T80,
            T_max=meta.T_max, plot_horizon=min(NB04_TARGET_HORIZON, meta.T_max),
            next_failed=meta.next_failed,
            max_u_residual=result.max_u_residual,
            max_bgp_residual=result.max_bgp_residual,
            xi_W_eff_min=common.xi_min, xi_W_eff_max=common.xi_max,
            max_common_growth_log_gap=common.max_log_gap,
            theta_US_star_min=minimum(s.θ_US_star for s in result.u_path),
            psi_min=result.diagnostics.psi_min,
            equity_weight_min=result.diagnostics.equity_weight_min,
        ))
    end

    attempt_columns = [
        "nu_b", "stage", "T", "branch_iters", "warm_start_T", "status",
        "elapsed_sec", "branch_converged", "max_u_residual", "max_bgp_residual",
        "max_common_growth_log_gap", "error",
    ]
    summary_columns = String.(propertynames(first(summary)))
    nb04_write_csv(joinpath(NB04_OUTDIR, "horizon_search_attempts.csv"), attempts, attempt_columns)
    nb04_write_csv(joinpath(NB04_OUTDIR, "horizon_summary.csv"), summary, summary_columns)
    return (solutions=solutions, meta=solve_meta, attempts=attempts, summary=summary)
end

function nb04_horizon_table(summary)
    rows = [
        [
            @sprintf("%.1f", r.nu_b), string(r.available), string(r.direct_T80),
            string(r.T_max), string(r.plot_horizon), string(r.next_failed),
            r.available ? @sprintf("%.2e", r.max_u_residual) : "",
            r.available ? @sprintf("%.2e", r.max_bgp_residual) : "",
            r.available ? @sprintf("[%.4f, %.4f]", r.xi_W_eff_min, r.xi_W_eff_max) : "",
            r.available ? @sprintf("%.2e", r.max_common_growth_log_gap) : "",
        ] for r in summary
    ]
    nb04_markdown_table(
        ["nu_b", "available", "direct T=80", "T_max", "min(80,T_max)",
         "next failed T", "max u resid.", "max BGP resid.", "xi_W_eff range",
         "max CG log gap"],
        rows,
    )
end

function nb04_plot_xi_W_paths(sweep)
    rows = NamedTuple[]
    panel = plot(
        title="Period-by-period post-switch common-growth calibration",
        xlabel="possible switch date t", ylabel=L"\xi_{W,t}^{eff}",
        legend=:outertopright, size=(1050, 520),
    )

    for case in NB04_CASES
        haskey(sweep.solutions, case.nu_b) || continue
        result = sweep.solutions[case.nu_b]
        T = min(NB04_TARGET_HORIZON, length(result.u_path))
        t = collect(1:T)
        xi_eff = Float64[result.bgp_seq[j].ξ_W_eff for j in t]
        gaps = Float64[
            result.params.ν_b * log(result.bgp_seq[j].G_N_US) -
            result.bgp_seq[j].ξ_W_eff * log(result.bgp_seq[j].G_N_W)
            for j in t
        ]
        nu_errors = Float64[
            abs(result.bgp_seq[j].ν_b_eff - result.params.ν_b) for j in t
        ]
        maximum(abs.(gaps)) <= NB04_COMMON_GROWTH_TOL ||
            error("Common-growth gap failed in xi_W path for nu_b=$(case.nu_b)")
        maximum(nu_errors) <= 1e-12 ||
            error("nu_b drifted in xi_W path for nu_b=$(case.nu_b)")

        plot!(panel, t, xi_eff; color=case.color, lw=2.5,
              label=string(case.label))
        for j in t
            b = result.bgp_seq[j]
            push!(rows, (
                nu_b=case.nu_b, t=j, model_switch_index=j - 1,
                xi_W_seed=result.params.ξ_W, xi_W_eff=xi_eff[j],
                G_N_US_b=b.G_N_US, G_N_W_b=b.G_N_W,
                common_growth_log_gap=gaps[j],
                fixed_nu_b_error=nu_errors[j],
                bgp_residual_norm=b.residual_norm,
            ))
        end
    end

    hline!(panel, [1.0]; color=:gray45, lw=1.3, ls=:dot,
           label=L"\xi_W=1\;\mathrm{(all\!-!u\ seed)}")
    isempty(rows) && error("No residual-safe xi_W paths were available to plot")
    nb04_write_csv(
        joinpath(NB04_OUTDIR, "00_recalibrated_xi_W_sweep_paths.csv"),
        rows, String.(propertynames(first(rows))),
    )
    savefig(panel, joinpath(NB04_OUTDIR, "00_recalibrated_xi_W_sweep_paths.png"))
    return (figure=panel, rows=rows)
end

function nb04_ahp_accounting(result)
    u = result.u_path
    T = length(u)
    q_US = Float64[s.q_US for s in u]
    q_W = Float64[s.q_W for s in u]
    Y_US = Float64[s.Y_US for s in u]
    n_W = Float64[(1 - s.ω) * (1 - s.θ) * s.A / s.q_W for s in u]
    n_US_star = Float64[
        s.ω_star * (1 - s.θ_US_star) * s.A_star / s.q_US for s in u
    ]
    bond = Float64[s.θ * s.A for s in u]
    asset_position = q_W .* n_W
    liability_position = q_US .* n_US_star
    NFA = asset_position .+ bond .- liability_position

    VA_asset = zeros(T); VA_liability = zeros(T)
    CA_asset = zeros(T); CA_liability = zeros(T); CA_bond = zeros(T)
    delta_NFA = zeros(T)
    for t in 2:T
        VA_asset[t] = n_W[t - 1] * (q_W[t] - q_W[t - 1])
        VA_liability[t] = -n_US_star[t - 1] * (q_US[t] - q_US[t - 1])
        CA_asset[t] = q_W[t] * (n_W[t] - n_W[t - 1])
        CA_liability[t] = -q_US[t] * (n_US_star[t] - n_US_star[t - 1])
        CA_bond[t] = bond[t] - bond[t - 1]
        delta_NFA[t] = NFA[t] - NFA[t - 1]
    end
    VA = VA_asset .+ VA_liability
    CA = CA_asset .+ CA_liability .+ CA_bond
    residual = delta_NFA .- VA .- CA
    equilibrium_NFA = Float64[s.A - s.Q_US for s in u]
    return (
        T=T, q_US=q_US, q_W=q_W, Y_US=Y_US, n_W=n_W,
        n_US_star=n_US_star, bond=bond,
        asset_position=asset_position, liability_position=liability_position,
        NFA=NFA, delta_NFA=delta_NFA,
        VA_asset=VA_asset, VA_liability=VA_liability, VA=VA,
        CA_asset=CA_asset, CA_liability=CA_liability, CA_bond=CA_bond, CA=CA,
        residual=residual,
        residual_max=T >= 2 ? maximum(abs.(residual[2:end])) : 0.0,
        nfa_identity_error=maximum(abs.(NFA .- equilibrium_NFA)),
    )
end

function nb04_case_diagnostic(case, result)
    p = result.params
    T = length(result.u_path)
    T >= NB04_SWITCH_DATE + 1 || error(
        "T=$(T) is too short to display a post-switch segment after tau=$(NB04_SWITCH_DATE)",
    )
    u = result.u_path
    switch_path = build_switch_path(result, NB04_SWITCH_DATE; T=T)
    length(switch_path) == T || error("Realized switch path has the wrong length")
    for t in 1:(NB04_SWITCH_DATE - 1)
        abs(switch_path[t].N_US - u[t].N_US) <= 1e-10 || error("Pre-switch US state mismatch")
        abs(switch_path[t].N_W - u[t].N_W) <= 1e-10 || error("Pre-switch RoW state mismatch")
    end
    abs(switch_path[NB04_SWITCH_DATE].N_US - u[NB04_SWITCH_DATE].N_US) <= 1e-8 ||
        error("Switch-date US state mismatch")
    abs(switch_path[NB04_SWITCH_DATE].N_W - u[NB04_SWITCH_DATE].N_W) <= 1e-8 ||
        error("Switch-date RoW state mismatch")

    s_W = (p.β + p.χ) / (1 + p.χ)
    A = Float64[s_W * s.e_W / (p.β * s.e_US) for s in u]
    B = Float64[s.Q_W / (p.β * s.e_US) for s in u]
    zeta = Float64[s.Q_US / (p.β * s.e_US) for s in u]
    m = Float64[s.e_W / s.e_US for s in u]
    mu = Float64[s.Q_W / s.e_W for s in u]
    zeta_AB = 1 .+ A .- B
    zeta_m_mu = 1 .+ (m ./ p.β) .* (s_W .- mu)
    funding = (
        s_W=s_W, A=A, B=B, zeta=zeta, m=m, mu=mu,
        zeta_AB=zeta_AB, zeta_m_mu=zeta_m_mu,
        identity_error=max(maximum(abs.(zeta .- zeta_AB)),
                           maximum(abs.(zeta .- zeta_m_mu))),
    )

    hkt = (
        e_W_over_e_US=Float64[s.e_W / s.e_US for s in u],
        Q_W_over_beta_e_US=Float64[s.Q_W / (p.β * s.e_US) for s in u],
        Q_W_over_beta_e_W=Float64[s.Q_W / (p.β * s.e_W) for s in u],
        Q_US_over_beta_e_W=Float64[s.Q_US / (p.β * s.e_W) for s in u],
        zeta=zeta,
        Lambda_u=Float64[s.R_A_u / s.R_US_u for s in u],
        Lambda_b=Float64[s.R_A_b / s.R_US_b for s in u],
        Lambda_ratio=Float64[
            (s.R_A_u / s.R_US_u) / (s.R_A_b / s.R_US_b) for s in u
        ],
    )

    accounting = nb04_ahp_accounting(result)

    dividend = Float64.(result.diagnostics.cond_1a)
    switch = (1 - p.π_persist) / p.π_persist .* Float64.(result.diagnostics.cond_1b)
    total = Float64.(result.diagnostics.a_t)
    state_price = fill(NaN, T)
    physical_payoff = fill(NaN, T)
    for j in 1:(T - 1)
        k = j + 1
        prev = u[j]
        u_next = u[k]
        b_next = result.bgp_seq[k]
        state_price[k] = (1 - p.π_persist) / p.π_persist *
                         (prev.R_A_u / prev.R_A_b)^p.γ
        physical_payoff[k] = (b_next.q_US + b_next.d_US) / u_next.q_US
    end
    log_upper = zeros(T)
    for t in (T - 1):-1:1
        log_upper[t] = log_upper[t + 1] - log1p(total[t + 1])
    end
    leakage_error = maximum(abs.(total .- dividend .- switch))
    factor_error = maximum(abs.([
        switch[t] - state_price[t] * physical_payoff[t] for t in 2:T
    ]))
    leakage = (
        dividend=dividend, switch=switch, total=total,
        state_price=state_price, physical_payoff=physical_payoff,
        log_upper=log_upper, upper=exp.(log_upper),
        log10_upper=log_upper ./ log(10.0),
        decomposition_error=leakage_error, factor_error=factor_error,
    )

    return (
        case=case, result=result, p=p, T=T, t=collect(1:T), u=u,
        switch_path=switch_path, funding=funding, hkt=hkt,
        accounting=accounting, leakage=leakage,
        common=nb04_common_growth_summary(result),
    )
end

function nb04_build_diagnostics(sweep)
    diagnostics = Any[]
    for case in NB04_CASES
        haskey(sweep.solutions, case.nu_b) || continue
        push!(diagnostics, nb04_case_diagnostic(case, sweep.solutions[case.nu_b]))
    end
    diagnostics
end

nb04_u_series(d, field::Symbol) = Float64[getproperty(s, field) for s in d.u]
nb04_switch_series(d, field::Symbol) = Float64[getproperty(s, field) for s in d.switch_path]

function nb04_add_case_lines!(panel, diagnostics, getter;
                              switch_getter=nothing, legend=false)
    for d in diagnostics
        case = d.case
        y = getter(d)
        plot!(panel, d.t, y; color=case.color, lw=2.3, ls=:solid,
              label=legend ? "$(case.label), all-u" : false)
        if switch_getter !== nothing
            ys = switch_getter(d)
            plot!(panel, d.t, ys; color=case.color, lw=2.1, ls=:dash,
                  label=legend ? "$(case.label), switch tau=$(NB04_SWITCH_DATE)" : false)
        end
    end
    panel
end

function nb04_plot_growth_paths(diagnostics)
    specs = [
        (field=:φ_US, title="US production-labour share", ylabel=L"\varphi_{US}", log=false),
        (field=:φ_W, title="RoW production-labour share", ylabel=L"\varphi_W", log=false),
        (field=:e_US, title="US labour income", ylabel=L"e_{US}", log=true),
        (field=:e_W, title="RoW labour income", ylabel=L"e_W", log=true),
        (field=:Q_US, title="US aggregate equity value", ylabel=L"Q_{US}", log=true),
        (field=:Q_W, title="RoW aggregate equity value", ylabel=L"Q_W", log=true),
        (field=:q_US, title="US per-variety equity price", ylabel=L"q_{US}", log=true),
        (field=:q_W, title="RoW per-variety equity price", ylabel=L"q_W", log=true),
        (field=:N_US, title="US varieties", ylabel=L"N_{US}", log=true),
        (field=:N_W, title="RoW varieties", ylabel=L"N_W", log=true),
    ]
    panels = Plots.Plot[]
    for (j, spec) in enumerate(specs)
        panel = plot(
            title=spec.title, xlabel="period t", ylabel=spec.ylabel,
            yscale=spec.log ? :log10 : :identity,
            legend=j == 1 ? :outertopright : false,
        )
        nb04_add_case_lines!(
            panel, diagnostics,
            d -> nb04_u_series(d, spec.field);
            switch_getter=d -> nb04_switch_series(d, spec.field), legend=j == 1,
        )
        vline!(panel, [NB04_SWITCH_DATE]; color=:gray45, lw=1.3, ls=:dot,
               label=j == 1 ? "switch date tau=$(NB04_SWITCH_DATE)" : false)
        push!(panels, panel)
    end
    fig = plot(
        panels..., layout=(5, 2), size=(1550, 1900),
        plot_title="Section 1.1: all-u and realized switch paths",
    )
    savefig(fig, joinpath(NB04_OUTDIR, "section1_growth_all_u_and_switch_paths.png"))
    fig
end

function nb04_plot_funding(diagnostics)
    specs = [
        (key=:A, title="RoW funding capacity", ylabel=L"A_t"),
        (key=:B, title="RoW equity absorption", ylabel=L"B_t"),
        (key=:zeta, title="US stock-funding ratio", ylabel=L"\zeta_t"),
        (key=:m, title="Relative labour-income scale", ylabel=L"m_t"),
        (key=:mu, title="RoW capitalization/income", ylabel=L"\mu_t"),
    ]
    panels = Plots.Plot[]
    for (j, spec) in enumerate(specs)
        panel = plot(title=spec.title, xlabel="period t", ylabel=spec.ylabel,
                     legend=j == 1 ? :outertopright : false)
        nb04_add_case_lines!(panel, diagnostics,
                            d -> getproperty(d.funding, spec.key); legend=j == 1)
        push!(panels, panel)
    end
    identity = plot(title="Equivalent m-mu representation", xlabel="period t",
                    ylabel=L"\zeta_t", legend=false)
    for d in diagnostics
        plot!(identity, d.t, d.funding.zeta; color=d.case.color, lw=2.4,
              label=false)
        plot!(identity, d.t, d.funding.zeta_m_mu; color=d.case.color,
              lw=1.8, ls=:dash, label=false)
    end
    push!(panels, identity)
    fig = plot(panels..., layout=(2, 3), size=(1500, 900),
               plot_title="Section 1.2: US stock-funding identity")
    savefig(fig, joinpath(NB04_OUTDIR, "section1_stock_funding_identity.png"))
    fig
end

function nb04_plot_hkt(diagnostics)
    specs = [
        (key=:e_W_over_e_US, title="Relative labour income", ylabel=L"e_W/e_{US}"),
        (key=:Q_W_over_beta_e_US, title="RoW equity / US saving", ylabel=L"Q_W/(\beta e_{US})"),
        (key=:Q_W_over_beta_e_W, title="RoW equity / RoW saving", ylabel=L"Q_W/(\beta e_W)"),
        (key=:Q_US_over_beta_e_W, title="US equity / RoW saving", ylabel=L"Q_{US}/(\beta e_W)"),
        (key=:zeta, title="US stock-funding ratio", ylabel=L"\zeta_t"),
        (key=:Lambda_u, title="All-u return wedge", ylabel=L"\Lambda_t^u"),
        (key=:Lambda_b, title="Switch return wedge", ylabel=L"\Lambda_t^b"),
        (key=:Lambda_ratio, title="Relative return wedge", ylabel=L"\Lambda_t^u/\Lambda_t^b"),
    ]
    panels = Plots.Plot[]
    for (j, spec) in enumerate(specs)
        panel = plot(title=spec.title, xlabel="period t", ylabel=spec.ylabel,
                     legend=j == 1 ? :outertopright : false)
        nb04_add_case_lines!(panel, diagnostics,
                            d -> getproperty(d.hkt, spec.key); legend=j == 1)
        push!(panels, panel)
    end
    fig = plot(panels..., layout=(4, 2), size=(1450, 1500),
               plot_title="Section 2: finite-prefix HKT diagnostics")
    savefig(fig, joinpath(NB04_OUTDIR, "section2_hkt_finite_prefix.png"))
    fig
end

function nb04_plot_component_panels(diagnostics, specs; title, layout, size)
    panels = Plots.Plot[]
    for (j, spec) in enumerate(specs)
        yscale = get(spec, :yscale, :identity)
        panel = plot(title=spec.title, xlabel="period t", ylabel=spec.ylabel,
                     legend=j == 1 ? :outertopright : false,
                     yscale=yscale)
        for d in diagnostics
            y = spec.getter(d)
            plot!(panel, d.t, y; color=d.case.color, lw=2.2,
                  label=j == 1 ? string(d.case.label) : false)
        end
        yscale == :identity &&
            hline!(panel, [0.0]; color=:gray65, lw=0.8, label=false)
        push!(panels, panel)
    end
    fig = plot(panels..., layout=layout, size=size, plot_title=title)
    fig
end

function nb04_plot_nfa(diagnostics)
    flows = nb04_plot_component_panels(
        diagnostics,
        [
            (title="Change in NFA", ylabel=L"\Delta NFA_t/Y_{US,t}",
             getter=d -> d.accounting.delta_NFA ./ d.accounting.Y_US),
            (title="Valuation effect", ylabel=L"VA_t/Y_{US,t}",
             getter=d -> d.accounting.VA ./ d.accounting.Y_US),
            (title="Current-account quantity flow", ylabel=L"CA_t/Y_{US,t}",
             getter=d -> d.accounting.CA ./ d.accounting.Y_US),
            (title="Absolute adding-up residual", ylabel=L"|\Delta NFA-VA-CA|/Y_{US}",
             getter=d -> max.(abs.(d.accounting.residual ./ d.accounting.Y_US), 1e-18),
             yscale=:log10),
        ];
        title="Section 3.1: NFA = VA + CA accounting", layout=(2, 2), size=(1350, 900),
    )
    savefig(flows, joinpath(NB04_OUTDIR, "section3_nfa_va_ca.png"))

    va = nb04_plot_component_panels(
        diagnostics,
        [
            (title="US-held RoW equity valuation", ylabel=L"VA_t^{asset}/Y_{US,t}",
             getter=d -> d.accounting.VA_asset ./ d.accounting.Y_US),
            (title="Foreign-held US equity valuation", ylabel=L"VA_t^{liability}/Y_{US,t}",
             getter=d -> d.accounting.VA_liability ./ d.accounting.Y_US),
        ];
        title="Section 3.2: valuation components", layout=(1, 2), size=(1350, 480),
    )
    savefig(va, joinpath(NB04_OUTDIR, "section3_va_components.png"))

    ca = nb04_plot_component_panels(
        diagnostics,
        [
            (title="RoW-equity purchases", ylabel=L"CA_t^{asset}/Y_{US,t}",
             getter=d -> d.accounting.CA_asset ./ d.accounting.Y_US),
            (title="US-equity liability issuance", ylabel=L"CA_t^{liability}/Y_{US,t}",
             getter=d -> d.accounting.CA_liability ./ d.accounting.Y_US),
            (title="Net-bond-position change", ylabel=L"CA_t^{bond}/Y_{US,t}",
             getter=d -> d.accounting.CA_bond ./ d.accounting.Y_US),
        ];
        title="Section 3.3: current-account components", layout=(1, 3), size=(1550, 480),
    )
    savefig(ca, joinpath(NB04_OUTDIR, "section3_ca_components.png"))

    positions = nb04_plot_component_panels(
        diagnostics,
        [
            (title="US-held RoW equity quantity", ylabel=L"n_{W,t}",
             getter=d -> d.accounting.n_W),
            (title="Foreign-held US equity quantity", ylabel=L"n^*_{US,t}",
             getter=d -> d.accounting.n_US_star),
            (title="RoW equity-price index", ylabel=L"q_{W,t}/q_{W,1}",
             getter=d -> d.accounting.q_W ./ first(d.accounting.q_W)),
            (title="US equity-price index", ylabel=L"q_{US,t}/q_{US,1}",
             getter=d -> d.accounting.q_US ./ first(d.accounting.q_US)),
        ];
        title="Section 3.4: underlying quantities and prices", layout=(2, 2), size=(1350, 900),
    )
    savefig(positions, joinpath(NB04_OUTDIR, "section3_positions_and_prices.png"))
    return (flows=flows, va=va, ca=ca, positions=positions)
end

function nb04_plot_leakage(diagnostics)
    specs = [
        (key=:upper, title="Finite-horizon bubble-share upper bound",
         ylabel=L"\prod_{s=t+1}^{T_{max}}(1+a_s)^{-1}", log=true),
        (key=:total, title="Total leakage", ylabel=L"a_t", log=true),
        (key=:dividend, title="Dividend leakage", ylabel=L"d_t^u/q_t^u", log=true),
        (key=:switch, title="Switch leakage", ylabel="weighted switch term", log=true),
        (key=:state_price, title="State-price / SDF factor", ylabel="SDF factor", log=true),
        (key=:physical_payoff, title="Physical payoff-crash factor", ylabel="payoff factor", log=true),
    ]
    panels = Plots.Plot[]
    for (j, spec) in enumerate(specs)
        panel = plot(title=spec.title, xlabel="period t", ylabel=spec.ylabel,
                     yscale=spec.log ? :log10 : :identity,
                     legend=j == 1 ? :outertopright : false)
        for d in diagnostics
            values = getproperty(d.leakage, spec.key)
            idx = spec.key in (:total, :dividend, :switch, :state_price, :physical_payoff) ?
                  collect(2:d.T) : collect(1:d.T)
            y = Float64[values[t] for t in idx]
            keep = [isfinite(y[k]) && y[k] > 0 for k in eachindex(y)]
            plot!(panel, idx[keep], y[keep]; color=d.case.color, lw=2.2,
                  label=j == 1 ? string(d.case.label) : false)
        end
        push!(panels, panel)
    end
    fig = plot(panels..., layout=(2, 3), size=(1550, 900),
               plot_title="Section 4: finite-horizon bound and leakage decomposition")
    savefig(fig, joinpath(NB04_OUTDIR, "section4_bubble_bound_and_leakage.png"))
    fig
end

function nb04_export_diagnostics(diagnostics)
    path_rows = NamedTuple[]
    funding_rows = NamedTuple[]
    hkt_rows = NamedTuple[]
    nfa_rows = NamedTuple[]
    leakage_rows = NamedTuple[]
    verification_rows = NamedTuple[]

    for d in diagnostics
        for t in 1:d.T
            u = d.u[t]
            b = d.switch_path[t]
            push!(path_rows, (
                nu_b=d.case.nu_b, path="all_u", t=t, regime="u",
                phi_US=u.φ_US, phi_W=u.φ_W, e_US=u.e_US, e_W=u.e_W,
                Q_US=u.Q_US, Q_W=u.Q_W, q_US=u.q_US, q_W=u.q_W,
                N_US=u.N_US, N_W=u.N_W,
            ))
            push!(path_rows, (
                nu_b=d.case.nu_b, path="realized_switch_tau_$(NB04_SWITCH_DATE)",
                t=t, regime=string(b.regime),
                phi_US=b.φ_US, phi_W=b.φ_W, e_US=b.e_US, e_W=b.e_W,
                Q_US=b.Q_US, Q_W=b.Q_W, q_US=b.q_US, q_W=b.q_W,
                N_US=b.N_US, N_W=b.N_W,
            ))
            push!(funding_rows, (
                nu_b=d.case.nu_b, t=t, s_W=d.funding.s_W,
                A_t=d.funding.A[t], B_t=d.funding.B[t], zeta=d.funding.zeta[t],
                m_t=d.funding.m[t], mu_t=d.funding.mu[t],
                zeta_from_A_B=d.funding.zeta_AB[t],
                zeta_from_m_mu=d.funding.zeta_m_mu[t],
            ))
            push!(hkt_rows, (
                nu_b=d.case.nu_b, t=t,
                e_W_over_e_US=d.hkt.e_W_over_e_US[t],
                Q_W_over_beta_e_US=d.hkt.Q_W_over_beta_e_US[t],
                Q_W_over_beta_e_W=d.hkt.Q_W_over_beta_e_W[t],
                Q_US_over_beta_e_W=d.hkt.Q_US_over_beta_e_W[t],
                zeta=d.hkt.zeta[t], Lambda_u=d.hkt.Lambda_u[t],
                Lambda_b=d.hkt.Lambda_b[t], Lambda_u_over_Lambda_b=d.hkt.Lambda_ratio[t],
            ))
            a = d.accounting
            push!(nfa_rows, (
                nu_b=d.case.nu_b, t=t, Y_US=a.Y_US[t],
                delta_NFA=a.delta_NFA[t], VA=a.VA[t], CA=a.CA[t],
                VA_asset=a.VA_asset[t], VA_liability=a.VA_liability[t],
                CA_asset=a.CA_asset[t], CA_liability=a.CA_liability[t],
                CA_bond=a.CA_bond[t], adding_up_residual=a.residual[t],
                n_W=a.n_W[t], n_US_star=a.n_US_star[t], bond=a.bond[t],
                q_W=a.q_W[t], q_US=a.q_US[t], NFA=a.NFA[t],
            ))
            l = d.leakage
            push!(leakage_rows, (
                nu_b=d.case.nu_b, t=t,
                bubble_share_upper=l.upper[t], log10_bubble_share_upper=l.log10_upper[t],
                a_t=l.total[t], dividend_leakage=l.dividend[t],
                switch_leakage=l.switch[t], state_price_SDF_factor=l.state_price[t],
                physical_payoff_crash_factor=l.physical_payoff[t],
            ))
        end
        push!(verification_rows, (
            nu_b=d.case.nu_b, T=d.T,
            max_funding_identity_error=d.funding.identity_error,
            max_NFA_adding_up_residual=d.accounting.residual_max,
            max_NFA_equilibrium_identity_error=d.accounting.nfa_identity_error,
            max_leakage_decomposition_error=d.leakage.decomposition_error,
            max_switch_factorization_error=d.leakage.factor_error,
            fixed_nu_b_error=d.common.nu_error,
            max_common_growth_log_gap=d.common.max_log_gap,
            residual_safe=nb04_residual_safe(d.result),
        ))
    end

    exports = [
        ("section1_all_u_and_switch_paths.csv", path_rows),
        ("section1_stock_funding.csv", funding_rows),
        ("section2_hkt_finite_prefix.csv", hkt_rows),
        ("section3_nfa_decomposition.csv", nfa_rows),
        ("section4_bubble_bound_and_leakage.csv", leakage_rows),
        ("verification_summary.csv", verification_rows),
    ]
    for (name, rows) in exports
        isempty(rows) && continue
        nb04_write_csv(joinpath(NB04_OUTDIR, name), rows,
                       String.(propertynames(first(rows))))
    end
    return verification_rows
end

function nb04_verification_table(rows)
    table_rows = [
        [
            @sprintf("%.1f", r.nu_b), string(r.T),
            @sprintf("%.2e", r.max_funding_identity_error),
            @sprintf("%.2e", r.max_NFA_adding_up_residual),
            @sprintf("%.2e", r.max_NFA_equilibrium_identity_error),
            @sprintf("%.2e", r.max_leakage_decomposition_error),
            @sprintf("%.2e", r.max_switch_factorization_error),
            @sprintf("%.2e", r.fixed_nu_b_error),
            @sprintf("%.2e", r.max_common_growth_log_gap),
            string(r.residual_safe),
        ] for r in rows
    ]
    nb04_markdown_table(
        ["nu_b", "T", "funding id.", "NFA add-up", "NFA equilibrium id.",
         "leakage id.", "switch factor id.", "fixed nu_b err.", "CG log gap",
         "residual-safe"],
        table_rows,
    )
end

function nb04_assert_definition_of_done(sweep, diagnostics, verification_rows)
    Set(keys(sweep.meta)) == Set(NB04_NU_B_GRID) || error("A requested calibration is missing")
    length(sweep.summary) == length(NB04_NU_B_GRID) || error("Horizon summary is incomplete")
    for r in sweep.summary
        r.available || error("nu_b=$(r.nu_b) has no residual-safe horizon")
        r.plot_horizon == min(NB04_TARGET_HORIZON, r.T_max) ||
            error("Plot horizon is not min(80,T_max)")
    end
    length(diagnostics) == length(NB04_NU_B_GRID) || error("A diagnostic case is missing")
    for d in diagnostics
        d.funding.identity_error <= NB04_IDENTITY_TOL || error("Funding identity failed")
        d.accounting.residual_max <= NB04_ACCOUNTING_TOL || error("NFA adding-up failed")
        d.accounting.nfa_identity_error <= NB04_EQUILIBRIUM_ID_TOL ||
            error("NFA equilibrium identity failed")
        d.leakage.decomposition_error <= NB04_IDENTITY_TOL ||
            error("Leakage decomposition failed")
        d.leakage.factor_error <= NB04_IDENTITY_TOL || error("Switch factorization failed")
        d.common.exact || error("Fixed-nu_b common-growth selection failed")
        length(d.switch_path) == d.T || error("Switch path is incomplete")
    end
    all(r -> r.residual_safe, verification_rows) || error("An exported case is not residual-safe")
    println("NB04_DEFINITION_OF_DONE_OK")
    true
end

println("Notebook 04 helper loaded")
println("Model:       ", NB04_MODEL_FILE)
println("Output dir:  ", NB04_OUTDIR)
println("nu_b grid:   ", NB04_NU_B_GRID)
println("switch date: ", NB04_SWITCH_DATE)
