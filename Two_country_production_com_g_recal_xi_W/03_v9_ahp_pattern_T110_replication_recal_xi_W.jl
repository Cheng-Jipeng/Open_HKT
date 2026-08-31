using Pkg

# Replication of the common-growth Notebook 19 workflow with a different
# equilibrium-selection instrument. The US absorbing exponent ν_b is fixed at
# its AHP seed, while a state-specific post-switch ξ_W enforces G_b = G_W.
# All model code and newly written artifacts live in this sibling directory.

function nb19_find_project_dir(start_dir=pwd())
    dir = abspath(start_dir)
    while true
        for candidate in (dir, joinpath(dir, "Codes"))
            project = joinpath(candidate, "Project.toml")
            model = joinpath(candidate, "Two_country_production_com_g_recal_xi_W",
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
const NB19_ENV_DIR = joinpath(
    NB19_PROJECT_DIR, "Two_country_production_com_g_recal_xi_W", "julia_env",
)
Pkg.activate(NB19_ENV_DIR)
cd(NB19_PROJECT_DIR)

const NB19_MODEL_FILE = joinpath(
    NB19_PROJECT_DIR, "Two_country_production_com_g_recal_xi_W", "TwoCountryProductionOLG.jl",
)
if @isdefined ProductionParams
    (:ξ_W_eff in fieldnames(BGPResult)) || error(
        "A different TwoCountryProductionOLG solver is already loaded. " *
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
const T_solved = 110
const NB19_AHP_TARGET_END = 15
const NB19_N_BUFFER = 0
const NB19_BRANCH_ITER_SCHEDULE = [60, 200]
const NB19_CONTINUATION_HORIZONS = [30, 45, 60, 70, 80, 90, 100, 105, T_solved]

const NB19_RESID_TOL = 1e-5
const NB19_PSI_INTERIOR_TOL = 0.02
const NB19_EQUITY_INTERIOR_TOL = 0.01
const NB19_THETA_FEASIBILITY_LOWER = 0.0
const NB19_THETA_INTERIOR_TOL = 0.01
const NB19_ACCOUNTING_SCALED_TOL = 1e-7
const NB19_COMMON_GROWTH_TOL = 1e-7
const NB19_NU_ORDER_BUFFER = 1e-3
const NB19_FIRST_WINDOW_MATCH_TOL = 2e-5

const NB19_OUTDIR = get(
    ENV, "NB03_RECAL_XI_W_OUTDIR",
    joinpath(
        NB19_PROJECT_DIR, "Two_country_production_com_g_recal_xi_W", "outputs_recal_xi_W",
        "03_ahp_pattern_T110_replication",
    ),
)
mkpath(NB19_OUTDIR)

println("Project directory:             ", NB19_PROJECT_DIR)
println("Output directory:              ", NB19_OUTDIR)
println("Requested solved horizon:      ", T_solved)
println("Scratch buffer:                ", NB19_N_BUFFER)
println("Fixed nu_b / xi_W seed:        0.10 / 1.00")
println("Common-growth restriction:     active via local post-switch xi_W")
println("Warm-continuation horizons:    ", NB19_CONTINUATION_HORIZONS)
println("Branch-iteration schedule:     ", NB19_BRANCH_ITER_SCHEDULE)

# -----------------------------------------------------------------------------
# CSV helpers and Notebook 15 targets
# -----------------------------------------------------------------------------

function nb19_read_numeric_csv(path::AbstractString)
    isfile(path) || error("Required CSV not found: $(path)")
    data, header = readdlm(path, ',', Float64, '\n'; header=true)
    matrix = ndims(data) == 1 ? reshape(data, 1, :) : data
    names = String.(vec(header))
    size(matrix, 2) == length(names) || error("CSV header mismatch: $(path)")
    return Dict(names[j] => Float64.(matrix[:, j]) for j in eachindex(names))
end

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

# The source directory is intentionally not read during execution. Its iCloud
# files may be offloaded, and the requested counterfactual is fully pinned down
# by the explicit AHP parameter factory below. This also prevents accidental
# writes to the common-growth benchmark directory.

# -----------------------------------------------------------------------------
# Notebook 17's long-horizon numerical method
# -----------------------------------------------------------------------------

# This is Notebook 17's local log-linear artificial successor.  It is installed
# notebook-locally so the T=110 solve does not depend on whatever closure another
# notebook may have left in the Julia session.
nb19_phi_clamp(x) = clamp(Float64(x), 1e-12, 1 - 1e-12)

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
        T_max=T, n_buffer=NB19_N_BUFFER, common_world_growth=true,
        β=0.45, γ=0.25, π_persist=0.75,
        a_US=0.20, ϑ_US=0.85,
        a_W=0.06, H_W=3.0, L_W=3.0,
        A_X_US_u=15.0, A_L_US_u=1.5,
        ν_b=0.10, ν_u=1.75, ξ_u=2.25, ξ_W=1.00,
        ω̄=0.50, ω̄_star=0.25,
        κ=1.00, χ=0.0002, η=0.010,
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
length(best_result.u_path) == T_solved || error("Final reported path is not T=110")

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
    # direct equilibrium identity is the same object and is safe at T=110.
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

function nb19_common_growth_diagnostics(result)
    p = result.params
    rows = Dict{String,Any}[]
    for (j, b) in enumerate(result.bgp_seq_extended)
        G_b = b.G_N_US^p.ν_b
        G_W = b.G_N_W^b.ξ_W_eff
        push!(rows, Dict{String,Any}(
            "switch_index"=>j - 1,
            "G_N_US"=>b.G_N_US,
            "G_N_W"=>b.G_N_W,
            "nu_b_eff"=>b.ν_b_eff,
            "xi_W_seed"=>p.ξ_W,
            "xi_W_eff"=>b.ξ_W_eff,
            "bgp_converged"=>b.converged,
            "bgp_residual_norm"=>b.residual_norm,
            "G_b"=>G_b,
            "G_W"=>G_W,
            "level_gap"=>G_b - G_W,
            "log_gap"=>p.ν_b * log(b.G_N_US) - b.ξ_W_eff * log(b.G_N_W),
        ))
    end
    return rows
end

function nb19_common_growth_summary(result)
    rows = nb19_common_growth_diagnostics(result)
    nu_eff = Float64[r["nu_b_eff"] for r in rows]
    xi_eff = Float64[r["xi_W_eff"] for r in rows]
    return (
        max_level_gap=maximum(abs(Float64(r["level_gap"])) for r in rows),
        max_log_gap=maximum(abs(Float64(r["log_gap"])) for r in rows),
        nu_b_eff_min=minimum(nu_eff),
        nu_b_eff_max=maximum(nu_eff),
        xi_W_eff_min=minimum(xi_eff),
        xi_W_eff_max=maximum(xi_eff),
        all_extended_bgp_converged=all(Bool(r["bgp_converged"]) for r in rows),
        max_extended_bgp_residual=maximum(
            Float64(r["bgp_residual_norm"]) for r in rows
        ),
    )
end

function nb19_hard_validity(result, a, common)
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
    theta_feasible = all(
        x -> isfinite(x) && NB19_THETA_FEASIBILITY_LOWER < x < 0.9,
        theta_US_star,
    )
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
    exact_common = common.max_level_gap <= NB19_COMMON_GROWTH_TOL &&
                   common.max_log_gap <= NB19_COMMON_GROWTH_TOL
    extended_bgp_valid = common.all_extended_bgp_converged &&
                         common.max_extended_bgp_residual <= NB19_RESID_TOL
    exponent_ordering = common.nu_b_eff_min > 0 &&
                        common.nu_b_eff_max <= result.params.ν_u - NB19_NU_ORDER_BUFFER
    valid = model_residuals && psi_interior && equity_interior && theta_feasible &&
        positive_foreign_claims && positive_returns && accounting_exact &&
        finite_accounting && exact_common && extended_bgp_valid && exponent_ordering
    return (
        valid=valid,
        model_residuals=model_residuals,
        psi_interior=psi_interior,
        equity_interior=equity_interior,
        theta_feasible=theta_feasible,
        theta_interior=theta_interior,
        positive_foreign_claims=positive_foreign_claims,
        positive_returns=positive_returns,
        accounting_exact=accounting_exact,
        finite_accounting=finite_accounting,
        exact_common=exact_common,
        extended_bgp_valid=extended_bgp_valid,
        exponent_ordering=exponent_ordering,
        accounting_scale=accounting_scale,
    )
end

best_accounting = nb19_ahp_accounting(best_result)
best_metrics = nb19_metrics(best_accounting)
best_common_diagnostics = nb19_common_growth_diagnostics(best_result)
best_common_summary = nb19_common_growth_summary(best_result)
best_validity = nb19_hard_validity(best_result, best_accounting, best_common_summary)

best_validity.valid || error("The recalibrated-xi_W T=110 continuation failed a model hard gate")
isapprox(best_result.params.ν_b, 0.10; atol=0.0, rtol=0.0) ||
    error("The solver did not preserve fixed nu_b=0.10")
isapprox(best_result.params.ξ_W, 1.0; atol=0.0, rtol=0.0) ||
    error("The AHP all-u xi_W seed is not 1.0")
best_result.params.common_world_growth ||
    error("The post-switch common-growth restriction must remain active")

# -----------------------------------------------------------------------------
# First-window outputs and machine-readable exports
# -----------------------------------------------------------------------------

# This counterfactual changes the equilibrium-selection instrument, so exact
# equality with the source common-growth path is neither expected nor used as
# a validity gate. The first 15 periods remain the AHP evidence window.
nb19_first_window_errors = Dict{String,Float64}()
nb19_max_first_window_error = missing
nb19_first_window_matches_source = missing

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
    joinpath(NB19_OUTDIR, "best_recalibrated_xi_W_common_growth.csv"),
    best_common_diagnostics,
    [
        "switch_index", "G_N_US", "G_N_W", "nu_b_eff",
        "xi_W_seed", "xi_W_eff", "bgp_converged",
        "bgp_residual_norm", "G_b", "G_W", "level_gap", "log_gap",
    ],
)

nb19_validation_rows = Dict{String,Any}[
    Dict("metric"=>"T_solved", "value"=>T_solved),
    Dict("metric"=>"n_buffer", "value"=>NB19_N_BUFFER),
    Dict("metric"=>"hard_valid", "value"=>best_validity.valid),
    Dict("metric"=>"theta_strictly_feasible", "value"=>best_validity.theta_feasible),
    Dict("metric"=>"theta_one_percent_interior", "value"=>best_validity.theta_interior),
    Dict("metric"=>"theta_US_star_min", "value"=>minimum(nb19_path_vector(best_result, :θ_US_star))),
    Dict("metric"=>"fixed_nu_b", "value"=>best_result.params.ν_b),
    Dict("metric"=>"xi_W_seed", "value"=>best_result.params.ξ_W),
    Dict("metric"=>"xi_W_eff_min", "value"=>best_common_summary.xi_W_eff_min),
    Dict("metric"=>"xi_W_eff_max", "value"=>best_common_summary.xi_W_eff_max),
    Dict("metric"=>"common_world_growth", "value"=>best_result.params.common_world_growth),
    Dict("metric"=>"branch_converged", "value"=>best_result.branch_converged),
    Dict("metric"=>"max_u_residual", "value"=>best_result.max_u_residual),
    Dict("metric"=>"max_bgp_residual", "value"=>best_result.max_bgp_residual),
    Dict("metric"=>"accounting_residual_max", "value"=>a.residual_max),
    Dict("metric"=>"nfa_identity_error", "value"=>a.nfa_identity_error),
    Dict("metric"=>"max_common_growth_log_gap", "value"=>best_common_summary.max_log_gap),
    Dict("metric"=>"max_extended_bgp_residual", "value"=>best_common_summary.max_extended_bgp_residual),
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
# Notebook 15 figures, now evaluated on the full T=110 solution
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
    title="Fixed nu_b=0.10, recalibrated post-switch xi_W: t=1:$(e) evidence window",
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
    title="Recalibrated-xi_W model: NFA/current Y (full T=110 tail)", legend=:outerbottom,
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

switch_t = Float64[r["switch_index"] for r in best_common_diagnostics]
G_b = Float64[r["G_b"] for r in best_common_diagnostics]
G_W = Float64[r["G_W"] for r in best_common_diagnostics]
nu_eff = Float64[r["nu_b_eff"] for r in best_common_diagnostics]
xi_eff = Float64[r["xi_W_eff"] for r in best_common_diagnostics]
growth_gaps = Float64[r["level_gap"] for r in best_common_diagnostics]

p_growth = plot(
    switch_t, G_b; color=:navy, lw=2.6, label="G_b",
    xlabel="switch-state index", ylabel="growth factor",
    title="Post-switch common growth",
)
plot!(p_growth, switch_t, G_W, color=:red3, ls=:dash, lw=2.2, label="G_W")
p_xi = plot(
    switch_t, xi_eff; color=:purple, lw=2.6, label="recalibrated xi_W_eff",
    xlabel="switch-state index", ylabel="effective exponent",
    title="State-specific post-switch xi_W",
)
plot!(p_xi, switch_t, nu_eff; color=:darkorange, ls=:dash, lw=2.2,
      label="fixed nu_b")
hline!(p_xi, [best_result.params.ξ_W], color=:gray35, ls=:dot,
       label="all-u xi_W seed")
p_gap = plot(
    switch_t, growth_gaps; color=:black, lw=2.0, label="G_b - G_W",
    xlabel="switch-state index", ylabel="level gap",
    title="Common-growth numerical gap",
)
fig_common_growth = plot(p_growth, p_xi, p_gap, layout=(1, 3), size=(1550, 460))
savefig(
    fig_common_growth,
    joinpath(NB19_OUTDIR, "best_recalibrated_xi_W_common_growth.png"),
)

println("\n" * repeat("=", 88))
println("NOTEBOOK 03 — FIXED-NU_B / RECALIBRATED-XI_W AHP FIGURES AT T=110")
println(repeat("=", 88))
@printf("Final max u residual:             %.3e\n", best_result.max_u_residual)
@printf("Final max BGP residual:           %.3e\n", best_result.max_bgp_residual)
println("Source-path equality check:         not imposed (selection instrument changed)")
@printf("t=15 rebased NFA:                 %+.6f\n", best_metrics.target_rebased_nfa)
@printf("t=15 net VA / cumulative CA:      %+.6f / %+.6f\n",
        best_metrics.target_net_va, best_metrics.target_ca)
@printf("|VA| / |CA|:                      %.3f\n",
        abs(best_metrics.target_net_va) / max(abs(best_metrics.target_ca), 1e-12))
@printf("Fixed nu_b_eff range:             [%.6f, %.6f]\n",
        best_common_summary.nu_b_eff_min, best_common_summary.nu_b_eff_max)
@printf("Recalibrated xi_W_eff range:      [%.6f, %.6f]\n",
        best_common_summary.xi_W_eff_min, best_common_summary.xi_W_eff_max)
@printf("Maximum common-growth log gap:    %.3e\n",
        best_common_summary.max_log_gap)
println("Hard-valid T=110 solution:         ", best_validity.valid)
println("One-percent theta screen:          ", best_validity.theta_interior,
        " (diagnostic, not an existence gate)")
println("Artifacts written to:             ", NB19_OUTDIR)

nothing
