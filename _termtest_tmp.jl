using Pkg; Pkg.activate(".")
include("TwoCountryProductionOLG.jl")
using Printf
function summarize(label, p)
    result = run_production_simulation(p; verbose=false)
    T = p.T_max
    rn = [s.residual_norm for s in result.u_path]
    ff = findfirst(>(1e-5), rn); ff = ff === nothing ? -1 : ff
    nbad = count(>(1e-5), rn); npen = count(>(1e7), rn)
    φmin = minimum(s.φ_US for s in result.u_path)
    @printf("%-34s conv=%-5s maxF=%.2e firstfail=%2d nbad=%2d/%2d npen=%2d φmin=%.2e\n",
            label, result.branch_converged, result.max_u_residual, ff, nbad, T, npen, φmin)
    flush(stdout)
end
println("=== HKT-matched default checks ===")
summarize("T=30 default buf=0",  ProductionParams(T_max=30, common_world_growth=true, branch_iters=30, n_buffer=0))
summarize("T=30 default buffer", ProductionParams(T_max=30, common_world_growth=true, branch_iters=30))
println("=== controls ===")
summarize("T=20 HKT regression", ProductionParams(T_max=20, common_world_growth=true, branch_iters=30))
summarize("T=20 fast-growth regression", fast_growth_params(T_max=20, common_world_growth=true))
println("ALLDONE")
