#= ================================================================
   run_v9_baseline.jl  –  V9 production-economy baseline simulation.

   Mirrors §10 of claude_code_prompt_v9_numerical_solver.md:
   1. Load baseline parameters
   2. Solve absorbing BGP (with optional common-world-growth calibration)
   3. Solve the unbalanced branch via forward-backward iteration
   4. Simulate one path with a specified switch date
   5. Save a CSV with simulated variables
   6. Save plots of price-dividend ratios, output, relative size, portfolio shares
   7. Print maximum absolute residuals for equilibrium conditions
   ================================================================ =#

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

include(joinpath(@__DIR__, "..", "TwoCountryProductionOLG.jl"))

using Plots, LaTeXStrings, Printf, Random
gr()

const OUTDIR = joinpath(@__DIR__, "..", "outputs_v9")
isdir(OUTDIR) || mkdir(OUTDIR)

# ── 1. Baseline parameters ──
p = ProductionParams(
    T_max = 30,
    common_world_growth = true,
    branch_iters = 20,
)
validate_params(p)

# ── 2-3. Solve BGP and unbalanced branch ──
result = run_production_simulation(p; verbose=true)
T = p.T_max

# ── 4. Simulate one switch path (deterministic switch τ = 12) ──
τ = 12
function build_switch_sim(p, u_path, bgp_seq, τ)
    T = length(u_path)
    rows = NamedTuple[]
    for t in 1:T
        if t < τ
            s = u_path[t]
            push!(rows, (t=t, regime=:u, φ_US=s.φ_US, φ_W=s.φ_W,
                         q_US=s.q_US, d_US=s.d_US, q_W=s.q_W, d_W=s.d_W,
                         Q_US=s.Q_US, Q_W=s.Q_W, e_US=s.e_US, e_W=s.e_W,
                         Y_US=s.Y_US, Y_W=s.Y_W, N_US=s.N_US, N_W=s.N_W,
                         ω=s.ω, ω_star=s.ω_star, θ=s.θ, θ_US_star=s.θ_US_star,
                         R_f=s.R_f, R_f_W=s.R_f_W))
        else
            b = bgp_seq[t]
            push!(rows, (t=t, regime=:b, φ_US=b.φ_US, φ_W=b.φ_W,
                         q_US=b.q_US, d_US=b.d_US, q_W=b.q_W, d_W=b.d_W,
                         Q_US=b.Q_US, Q_W=b.Q_W, e_US=b.e_US, e_W=b.e_W,
                         Y_US=b.Y_US, Y_W=b.Y_W, N_US=b.N_US, N_W=b.N_W,
                         ω=b.ω, ω_star=b.ω_star, θ=b.θ, θ_US_star=b.θ_US_star,
                         R_f=b.R_f, R_f_W=b.R_f_W))
        end
    end
    return rows
end

sim = build_switch_sim(p, result.u_path, result.bgp_seq, τ)

# ── 5. CSV output ──
open(joinpath(OUTDIR, "simulation_path.csv"), "w") do io
    write(io, "t,regime,phi_US,phi_W,q_US,d_US,q_W,d_W,Q_US,Q_W,e_US,e_W,Y_US,Y_W,N_US,N_W,omega,omega_star,theta,theta_US_star,R_f,R_f_W\n")
    for r in sim
        write(io, "$(r.t),$(r.regime),$(r.φ_US),$(r.φ_W),$(r.q_US),$(r.d_US),$(r.q_W),$(r.d_W),$(r.Q_US),$(r.Q_W),$(r.e_US),$(r.e_W),$(r.Y_US),$(r.Y_W),$(r.N_US),$(r.N_W),$(r.ω),$(r.ω_star),$(r.θ),$(r.θ_US_star),$(r.R_f),$(r.R_f_W)\n")
    end
end
println("✓ Saved: $(joinpath(OUTDIR, \"simulation_path.csv\"))")

# Also save BGP and u-branch
open(joinpath(OUTDIR, "bgp_solution.csv"), "w") do io
    write(io, "t,N_US,N_W,phi_US,phi_W,omega,omega_star,theta,theta_US_star,R_f,R_f_W,q_US,d_US,Q_US,Q_W,Y_US,Y_W,e_US,e_W,R_US,R_W,R_A,G_N_US,G_N_W,converged,resnorm\n")
    for (t, b) in enumerate(result.bgp_seq)
        write(io, "$(t-1),$(b.N_US),$(b.N_W),$(b.φ_US),$(b.φ_W),$(b.ω),$(b.ω_star),$(b.θ),$(b.θ_US_star),$(b.R_f),$(b.R_f_W),$(b.q_US),$(b.d_US),$(b.Q_US),$(b.Q_W),$(b.Y_US),$(b.Y_W),$(b.e_US),$(b.e_W),$(b.R_US),$(b.R_W),$(b.R_A),$(b.G_N_US),$(b.G_N_W),$(b.converged),$(b.residual_norm)\n")
    end
end
println("✓ Saved: $(joinpath(OUTDIR, \"bgp_solution.csv\"))")

open(joinpath(OUTDIR, "unbalanced_branch_solution.csv"), "w") do io
    write(io, "t,N_US,N_W,phi_US,phi_W,omega,omega_star,theta,theta_US_star,R_f,R_f_W,q_US,d_US,Q_US,Q_W,Y_US,Y_W,e_US,e_W,resnorm\n")
    for s in result.u_path
        write(io, "$(s.t),$(s.N_US),$(s.N_W),$(s.φ_US),$(s.φ_W),$(s.ω),$(s.ω_star),$(s.θ),$(s.θ_US_star),$(s.R_f),$(s.R_f_W),$(s.q_US),$(s.d_US),$(s.Q_US),$(s.Q_W),$(s.Y_US),$(s.Y_W),$(s.e_US),$(s.e_W),$(s.residual_norm)\n")
    end
end
println("✓ Saved: $(joinpath(OUTDIR, \"unbalanced_branch_solution.csv\"))")

# ── 6. Plots ──
tt = 1:T
qd_path  = [s.q_US/s.d_US for s in sim]
QD_agg   = [s.Q_US/(s.N_US*s.d_US) for s in sim]
Y_US_path = [s.Y_US for s in sim]
Y_W_path  = [s.Y_W  for s in sim]
ω_path = [s.ω for s in sim]; ωs_path = [s.ω_star for s in sim]
θ_path = [s.θ for s in sim]; θUs_path = [s.θ_US_star for s in sim]
switch_x = τ - 0.5

p1 = plot(tt, qd_path, lw=2, marker=:circle, label=L"q_{US}/d_{US}",
          xlabel="period t", ylabel="price-dividend ratio",
          title="Per-variety US price-dividend ratio")
plot!(p1, tt, QD_agg, lw=2, marker=:square, label=L"\mathcal{Q}_{US}/\mathcal{D}_{US}", ls=:dash)
vline!(p1, [switch_x], ls=:dash, color=:red, label="switch τ")
savefig(p1, joinpath(OUTDIR, "price_dividend_ratios.png"))

p2 = plot(tt, Y_US_path, lw=2, label=L"Y_{US}", yscale=:log10,
          xlabel="period t", ylabel="output (log)", title="Country output")
plot!(p2, tt, Y_W_path, lw=2, label=L"Y_W")
vline!(p2, [switch_x], ls=:dash, color=:red, label="")
savefig(p2, joinpath(OUTDIR, "output_paths.png"))

p3 = plot(tt, Y_W_path ./ Y_US_path, lw=2, marker=:circle, label=L"Y_W/Y_{US}",
          xlabel="period t", ylabel="ratio", title="Relative country size")
vline!(p3, [switch_x], ls=:dash, color=:red, label="")
savefig(p3, joinpath(OUTDIR, "relative_country_size.png"))

p4 = plot(tt, ω_path, lw=2, marker=:circle, label=L"\omega",
          xlabel="period t", ylabel="weight", title="Equity portfolio weights")
plot!(p4, tt, ωs_path, lw=2, marker=:square, label=L"\omega^*")
plot!(p4, tt, θ_path, lw=2, marker=:utriangle, label=L"\theta")
plot!(p4, tt, θUs_path, lw=2, marker=:dtriangle, label=L"\theta_{US}^*")
vline!(p4, [switch_x], ls=:dash, color=:red, label="")
savefig(p4, joinpath(OUTDIR, "portfolio_shares.png"))

println("✓ Saved plots in $OUTDIR")

# ── 7. Residual report ──
open(joinpath(OUTDIR, "residual_report.txt"), "w") do io
    write(io, "V9 PRODUCTION-ECONOMY RESIDUAL REPORT\n")
    write(io, "═══════════════════════════════════════════\n\n")
    @printf(io, "T_max = %d   common_world_growth = %s\n", p.T_max, p.common_world_growth)
    @printf(io, "Calibrated ν_b = %.6f\n\n", result.params.ν_b)
    write(io, "BGP residuals (per switch date):\n")
    for (t, b) in enumerate(result.bgp_seq)
        @printf(io, "  t=%2d  ‖F‖=%.2e  converged=%s\n", t-1, b.residual_norm, b.converged)
    end
    write(io, "\nu-path residuals:\n")
    for s in result.u_path
        @printf(io, "  t=%2d  ‖F‖=%.2e\n", s.t, s.residual_norm)
    end
    write(io, "\nMarket-clearing checks:\n")
    max_us = 0.0; max_w = 0.0; max_b = 0.0; max_id = 0.0
    for s in result.u_path
        us_err = abs(s.Q_US - s.ω*s.S - s.ω_star*s.S_star)
        w_err  = abs(s.Q_W - (1-s.ω)*s.S - (1-s.ω_star)*s.S_star)
        b_err  = abs(s.θ*s.A + s.θ_US_star*s.A_star)
        id_err = abs(s.Q_US + s.Q_W - (p.β*s.e_US + (p.β+p.χ)/(1+p.χ)*s.e_W))
        max_us = max(max_us, us_err); max_w = max(max_w, w_err)
        max_b  = max(max_b, b_err);   max_id = max(max_id, id_err)
    end
    @printf(io, "  US stock-clearing max:    %.2e\n", max_us)
    @printf(io, "  RoW stock-clearing max:   %.2e\n", max_w)
    @printf(io, "  Bond-clearing max:        %.2e\n", max_b)
    @printf(io, "  Aggregate-cap identity:   %.2e\n", max_id)
    write(io, "\nTheorem 1 diagnostics:\n")
    @printf(io, "  Σ d^u/q^u = %.6f (cond 1a converges: %s)\n",
            result.diagnostics.cum_1a[end], result.diagnostics.cond_1a_converges)
    @printf(io, "  Σ branch  = %.6f (cond 1b converges: %s)\n",
            result.diagnostics.cum_1b[end], result.diagnostics.cond_1b_converges)
    @printf(io, "  BUBBLE EXISTS:            %s\n", result.diagnostics.bubble_exists)
    @printf(io, "  Total leakage Σ a_t:      %.6f\n", result.diagnostics.cum_a_t[end])
end
println("✓ Saved: $(joinpath(OUTDIR, \"residual_report.txt\"))")

println("\n══════════════ DONE ══════════════")
