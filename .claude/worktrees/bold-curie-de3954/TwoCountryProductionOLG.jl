#= ================================================================
   TwoCountryProductionOLG.jl  –  Shared types & helpers for the
   two-country PRODUCTION OLG bubble model (V9_production.tex)

   Extension of TwoCountryOLG.jl from endowment to production:
   - Two-country CES production with skilled/unskilled labor
   - Endogenous labor allocations φ_US, φ_W
   - Per-variety stock prices q_i and dividends d_i (HKT primitive)
   - Aggregate market caps Q_i = N_{i,t+1} q_i
   - 7-equation equilibrium system at each (state, date)
   ================================================================ =#

using NLsolve, ForwardDiff, Parameters, LinearAlgebra, Printf, Statistics

# ─────────────────────────────────────────────────────────────────
# 1. Parameters
# ─────────────────────────────────────────────────────────────────

@with_kw struct ProductionParams
    # ── Preferences ──
    β::Float64  = 0.50                 # saving propensity
    γ::Float64  = 0.50                 # CRRA curvature; γ < 1 favours bubbles

    # ── Portfolio frictions ──
    κ::Float64       = 0.10            # home-bias quadratic cost
    ω̄::Float64       = 0.80            # US target weight on US equity
    ω̄_star::Float64  = 0.20            # RoW target weight on US equity

    # ── US bond convenience yield (RoW preference) ──
    χ::Float64 = 0.005

    # ── Bond-issuance cost ──
    η::Float64 = 0.01                  # scaling of Υ

    # ── Regime switching ──
    π_persist::Float64 = 0.70          # P(z_{t+1}=u | z_t=u)

    # ── US production technology (CES) ──
    # ρ > 1 (substitutes); larger ρ accelerates φ_US^u decay (ψ_US = (ξ_u-ν_u)(ρ_US-1)).
    α_US::Float64  = 0.40              # CES weight on knowledge input
    ρ_US::Float64  = 2.00              # CES exponent (ρ > 1 needed for bubble theory)
    ϑ_US::Float64  = 0.66              # intermediate-firm elasticity (Dixit-Stiglitz)
    a_US::Float64  = 1.20              # R&D productivity
    H_US::Float64  = 1.0               # mass of skilled workers
    L_US::Float64  = 1.0               # mass of unskilled workers

    # ── RoW production technology (CES) ──
    α_W::Float64   = 0.30
    ρ_W::Float64   = 1.50
    ϑ_W::Float64   = 0.66
    a_W::Float64   = 1.00
    H_W::Float64   = 1.0
    L_W::Float64   = 1.0

    # ── Absorbing-regime productivity primitives (US) ──
    Abar_X_US::Float64 = 1.0
    Abar_L_US::Float64 = 1.0
    ν_b::Float64       = 0.30          # absorbing-regime productivity exponent

    # ── Unbalanced-regime productivity primitives (US) ──
    # ξ_u > ν_u > ν_b is the V9 ordering; gap ξ_u-ν_u drives the bubble exponent ψ_US.
    A_X_US_u::Float64 = 1.0
    A_L_US_u::Float64 = 1.0
    ξ_u::Float64      = 1.20           # ξ_u > ν_u > ν_b
    ν_u::Float64      = 0.50

    # ── RoW productivity primitives (common across regimes) ──
    Abar_X_W::Float64 = 1.0
    Abar_L_W::Float64 = 1.0
    ξ_W::Float64      = 0.30

    # ── Initial knowledge stocks ──
    N_US_0::Float64 = 1.0
    N_W_0::Float64  = 1.0

    # ── Common-world-growth flag (G_b == G_W) ──
    common_world_growth::Bool = false

    # ── Simulation horizon (number of OLG periods) ──
    T_max::Int = 60

    # ── Solver tolerances ──
    ftol::Float64    = 1e-9
    xtol::Float64    = 1e-10
    iterations::Int  = 4000
    branch_iters::Int = 30             # forward-backward sweeps for u-branch
    branch_tol::Float64 = 1e-7
    do_global_polish::Bool = false     # final 7T-equation joint polish (expensive)
end

function validate_params(p::ProductionParams)
    @assert 0 < p.β < 1                               "β must be in (0,1)"
    @assert p.γ > 0                                   "γ must be > 0"
    @assert p.κ > 0                                   "κ must be > 0"
    @assert 0.5 ≤ p.ω̄ ≤ 1.0                           "ω̄ must be in [1/2, 1]"
    @assert 0 < p.ω̄_star < 0.5                        "ω̄* must be in (0, 1/2)"
    @assert p.χ > 0                                   "χ must be > 0"
    @assert p.η > 0                                   "η must be > 0"
    @assert 0 < p.π_persist < 1                       "π must be in (0,1)"
    @assert 0 < p.α_US < 1 && 0 < p.α_W < 1           "α in (0,1) per country"
    @assert p.ρ_US > 0 && p.ρ_W > 0                   "ρ > 0 per country"
    @assert 0 < p.ϑ_US < 1 && 0 < p.ϑ_W < 1           "ϑ in (0,1) per country"
    @assert p.a_US > 0 && p.a_W > 0                   "research productivity > 0"
    @assert p.H_US > 0 && p.H_W > 0                   "skilled labour > 0"
    @assert p.L_US > 0 && p.L_W > 0                   "unskilled labour > 0"
    @assert p.ν_b ≥ 0 && p.ξ_W ≥ 0                    "exogenous BGP exponents ≥ 0"
    @assert p.ν_u > p.ν_b                             "V9 ass.: ν_u > ν_b"
    @assert p.ξ_u > p.ν_u                             "V9 ass.: ξ_u > ν_u"
    @assert p.ρ_US > 1                                "V9 ass.: ρ_US > 1 for bubble theorem"
    @assert p.N_US_0 > 0 && p.N_W_0 > 0               "Initial knowledge stocks > 0"
    nothing
end


# ─────────────────────────────────────────────────────────────────
# 2. Issuance-cost function Υ
# ─────────────────────────────────────────────────────────────────

abstract type IssuanceCost end
struct LogQuadraticCost <: IssuanceCost end

# Υ(θ) = -log(1-θ) + θ²/2  satisfies Ass. ass_issuance_costs (V9 §3)
upsilon(::LogQuadraticCost, θ)        = -log(1 - θ) + θ^2 / 2
upsilon_prime(::LogQuadraticCost, θ)  = 1 / (1 - θ) + θ
upsilon_pprime(::LogQuadraticCost, θ) = 1 / (1 - θ)^2 + 1

const DEFAULT_COST = LogQuadraticCost()


# ─────────────────────────────────────────────────────────────────
# 3. CES production
# ─────────────────────────────────────────────────────────────────

# F(X̃, L̃) = (α X̃^(1-ρ) + (1-α) L̃^(1-ρ))^{1/(1-ρ)}
function ces_F(α, ρ, X̃, L̃)
    bracket = α * X̃^(1 - ρ) + (1 - α) * L̃^(1 - ρ)
    return bracket^(1 / (1 - ρ))
end

function ces_FX(α, ρ, X̃, L̃)
    bracket = α * X̃^(1 - ρ) + (1 - α) * L̃^(1 - ρ)
    return α * bracket^(ρ / (1 - ρ)) * X̃^(-ρ)
end

function ces_FL(α, ρ, X̃, L̃)
    bracket = α * X̃^(1 - ρ) + (1 - α) * L̃^(1 - ρ)
    return (1 - α) * bracket^(ρ / (1 - ρ)) * L̃^(-ρ)
end


# ─────────────────────────────────────────────────────────────────
# 4. Country production block
# ─────────────────────────────────────────────────────────────────

# Returns (A_X, A_L) for US under a given regime.
function productivity_US(p::ProductionParams, regime::Symbol, N_US)
    if regime === :b
        return (p.Abar_X_US * N_US^p.ν_b, p.Abar_L_US * N_US^p.ν_b)
    elseif regime === :u
        return (p.A_X_US_u * N_US^p.ξ_u, p.A_L_US_u * N_US^p.ν_u)
    else
        error("Unknown regime: $regime (expected :u or :b)")
    end
end

function productivity_W(p::ProductionParams, N_W)
    return (p.Abar_X_W * N_W^p.ξ_W, p.Abar_L_W * N_W^p.ξ_W)
end

# Compute production, wages, per-variety prices, and labour income.
# Returns NamedTuple with all primitive country quantities.
function compute_production(α, ρ, ϑ, a, H, L, φ, N, A_X, A_L)
    X    = φ * H
    X̃    = A_X * X
    L̃    = A_L * L
    Y    = ces_F(α, ρ, X̃, L̃)
    F_X  = ces_FX(α, ρ, X̃, L̃)
    F_L  = ces_FL(α, ρ, X̃, L̃)
    w_H  = ϑ * F_X * A_X
    w_L  = F_L * A_L
    q    = w_H / (a * N)
    d    = (1 - ϑ) / ϑ * w_H * (X / N)
    e    = w_H * H + w_L * L
    return (Y=Y, X=X, w_H=w_H, w_L=w_L, q=q, d=d, e=e, A_X=A_X, A_L=A_L)
end

us_block(p::ProductionParams, regime::Symbol, φ_US, N_US) = let
    A_X, A_L = productivity_US(p, regime, N_US)
    compute_production(p.α_US, p.ρ_US, p.ϑ_US, p.a_US, p.H_US, p.L_US, φ_US, N_US, A_X, A_L)
end

row_block(p::ProductionParams, φ_W, N_W) = let
    A_X, A_L = productivity_W(p, N_W)
    compute_production(p.α_W, p.ρ_W, p.ϑ_W, p.a_W, p.H_W, p.L_W, φ_W, N_W, A_X, A_L)
end

# Knowledge growth factors
G_N_US(p::ProductionParams, φ_US) = 1 + p.a_US * (1 - φ_US) * p.H_US
G_N_W(p::ProductionParams, φ_W)   = 1 + p.a_W  * (1 - φ_W)  * p.H_W


# ─────────────────────────────────────────────────────────────────
# 5. Result structs
# ─────────────────────────────────────────────────────────────────

struct BGPResult
    # Policies
    φ_US::Float64; φ_W::Float64
    ω::Float64;    ω_star::Float64
    θ::Float64;    θ_US_star::Float64
    R_f::Float64;  R_f_W::Float64

    # State at evaluation point
    N_US::Float64; N_W::Float64

    # Production / aggregates
    Y_US::Float64; Y_W::Float64
    e_US::Float64; e_W::Float64
    q_US::Float64; q_W::Float64
    d_US::Float64; d_W::Float64
    Q_US::Float64; Q_W::Float64

    # Returns (deterministic)
    R_US::Float64; R_W::Float64
    R_p::Float64;  R_A::Float64
    R_p_star::Float64; R_A_star::Float64

    # Knowledge growth
    G_N_US::Float64; G_N_W::Float64

    # Diagnostics
    converged::Bool
    residual_norm::Float64
end

mutable struct UPeriodState
    t::Int
    N_US::Float64; N_W::Float64
    φ_US::Float64; φ_W::Float64
    ω::Float64;    ω_star::Float64
    θ::Float64;    θ_US_star::Float64
    R_f::Float64;  R_f_W::Float64
    Y_US::Float64; Y_W::Float64
    e_US::Float64; e_W::Float64
    q_US::Float64; q_W::Float64
    d_US::Float64; d_W::Float64
    Q_US::Float64; Q_W::Float64
    A::Float64;    A_star::Float64
    S::Float64;    S_star::Float64
    R_US_u::Float64; R_W_u::Float64; R_p_u::Float64; R_A_u::Float64
    R_p_star_u::Float64; R_A_star_u::Float64
    R_US_b::Float64; R_W_b::Float64; R_p_b::Float64; R_A_b::Float64
    R_p_star_b::Float64; R_A_star_b::Float64
    residual_norm::Float64
end

struct ProductionDiagnostics
    cond_1a::Vector{Float64}     # d_t^u / q_t^u
    cum_1a::Vector{Float64}
    cond_1b::Vector{Float64}     # (q_t^b + d_t^b)/q_t^u * (C_t^u/C_t^b)^γ
    cum_1b::Vector{Float64}
    a_t::Vector{Float64}         # leakage ratio
    cum_a_t::Vector{Float64}
    bubble_exists::Bool
    cond_1a_converges::Bool
    cond_1b_converges::Bool
end

struct ProductionSimulationResult
    params::ProductionParams
    bgp_seq::Vector{BGPResult}          # BGP at (N_US,t^u, N_W,t)
    u_path::Vector{UPeriodState}
    diagnostics::ProductionDiagnostics
end


# ─────────────────────────────────────────────────────────────────
# 6. BGP solver: 7 unknowns (φ_US, φ_W, ω, θ, ω*, R_f, R_f^W)
#    at a given state (N_US, N_W).
#    Constraints enforced via transformations:
#      φ_US = sigmoid(g1)         ∈ (0,1)
#      φ_W  = sigmoid(g2)         ∈ (0,1)
#      ω    = sigmoid(g3)         ∈ (0,1)
#      θ    = -exp(g4)            < 0
#      ω*   = sigmoid(g5)         ∈ (0,1)
#      R_f  = exp(g6)             > 0
#      R_f^W = exp(g7)            > 0
# ─────────────────────────────────────────────────────────────────

sigmoid(x)       = 1 / (1 + exp(-x))
inv_sigmoid(p)   = log(p / (1 - p))

function _bgp_unpack(x_c)
    g1, g2, g3, g4, g5, g6, g7 = x_c
    return (sigmoid(g1), sigmoid(g2), sigmoid(g3), -exp(g4), sigmoid(g5), exp(g6), exp(g7))
end

function _bgp_pack(φ_US, φ_W, ω, θ, ω_s, R_f, R_f_W)
    [inv_sigmoid(clamp(φ_US, 1e-6, 1 - 1e-6)),
     inv_sigmoid(clamp(φ_W,  1e-6, 1 - 1e-6)),
     inv_sigmoid(clamp(ω,    1e-6, 1 - 1e-6)),
     log(max(-θ, 1e-12)),
     inv_sigmoid(clamp(ω_s,  1e-6, 1 - 1e-6)),
     log(max(R_f, 1e-12)),
     log(max(R_f_W, 1e-12))]
end

function bgp_residual!(F, x_c, p::ProductionParams, N_US, N_W)
    φ_US, φ_W, ω, θ, ω_s, R_f, R_f_W = _bgp_unpack(x_c)

    us = us_block(p, :b, φ_US, N_US)
    rw = row_block(p, φ_W, N_W)

    A   = p.β * us.e
    As  = (p.β + p.χ) / (1 + p.χ) * rw.e
    θ_Us = -θ * A / As                          # bond clearing (θ_W^* = 0)
    S   = (1 - θ) * A
    Ss  = (1 - θ_Us) * As

    G_US = G_N_US(p, φ_US)
    G_W  = G_N_W(p, φ_W)

    Q_US = G_US * N_US * us.q                   # = N_US,t+1 * q_US,t
    Q_W  = G_W  * N_W  * rw.q

    # Deterministic absorbing-regime returns (Step 2 of prompt)
    R_US = G_US^(p.ν_b - 1) * (1 + us.d / us.q)
    R_W  = G_W ^(p.ξ_W - 1) * (1 + rw.d / rw.q)

    R_p   = ω   * R_US + (1 - ω)   * R_W
    R_A   = (1 - θ)    * R_p + θ * R_f
    R_ps  = ω_s * R_US + (1 - ω_s) * R_W
    R_As  = (1 - θ_Us) * R_ps + θ_Us * R_f

    if R_A ≤ 0 || R_As ≤ 0
        F .= 1e8
        return F
    end

    sav_scale = max(A + As, 1e-12)
    F[1] = (Q_US - ω * S - ω_s * Ss) / sav_scale
    F[2] = (Q_W  - (1 - ω) * S - (1 - ω_s) * Ss) / sav_scale
    F[3] = p.β * (1 - θ)    * (R_US - R_W) / R_A          - p.κ * (ω   - p.ω̄)
    F[4] = p.β * (R_f  - R_p)            / R_A            - p.η * upsilon_prime(DEFAULT_COST, θ)
    F[5] = p.β * (1 - θ_Us) * (R_US - R_W) / R_As         - p.κ * (ω_s - p.ω̄_star)
    F[6] = R_f_W - R_ps                                   # deterministic: R_f^W = R_p*
    F[7] = p.β * (R_f - R_ps) / R_As + p.χ / θ_Us
    return F
end

function _bgp_make_result(p::ProductionParams, N_US, N_W, x_c,
                          is_converged::Bool, residual_norm::Float64)
    φ_US, φ_W, ω, θ, ω_s, R_f, R_f_W = _bgp_unpack(x_c)
    us = us_block(p, :b, φ_US, N_US)
    rw = row_block(p, φ_W, N_W)
    A   = p.β * us.e
    As  = (p.β + p.χ) / (1 + p.χ) * rw.e
    θ_Us = -θ * A / As
    G_US = G_N_US(p, φ_US)
    G_W  = G_N_W(p, φ_W)
    Q_US = G_US * N_US * us.q
    Q_W  = G_W  * N_W  * rw.q
    R_US = G_US^(p.ν_b - 1) * (1 + us.d / us.q)
    R_W  = G_W ^(p.ξ_W - 1) * (1 + rw.d / rw.q)
    R_p  = ω   * R_US + (1 - ω)   * R_W
    R_A  = (1 - θ)    * R_p + θ * R_f
    R_ps = ω_s * R_US + (1 - ω_s) * R_W
    R_As = (1 - θ_Us) * R_ps + θ_Us * R_f

    BGPResult(φ_US, φ_W, ω, ω_s, θ, θ_Us, R_f, R_f_W,
              N_US, N_W, us.Y, rw.Y, us.e, rw.e,
              us.q, rw.q, us.d, rw.d, Q_US, Q_W,
              R_US, R_W, R_p, R_A, R_ps, R_As,
              G_US, G_W,
              is_converged, residual_norm)
end

"""
Solve the absorbing-regime stationary normalised system at (N_US, N_W).
"""
function solve_bgp_at(p::ProductionParams, N_US, N_W; x0_actual=nothing, verbose=false)
    if x0_actual === nothing
        x0_actual = (0.7, 0.7, p.ω̄, -0.05, p.ω̄_star, 1.5, 1.4)
    end

    candidate_starts = Tuple[]
    push!(candidate_starts, x0_actual)
    push!(candidate_starts, (0.5, 0.5, p.ω̄, -0.02, p.ω̄_star, 1.5, 1.5))
    push!(candidate_starts, (0.8, 0.8, p.ω̄, -0.10, p.ω̄_star, 2.0, 1.8))
    push!(candidate_starts, (0.3, 0.3, p.ω̄, -0.01, p.ω̄_star, 1.0, 1.0))
    push!(candidate_starts, (0.6, 0.7, p.ω̄, -0.03, p.ω̄_star, 1.2, 1.2))
    push!(candidate_starts, (0.4, 0.6, p.ω̄, -0.05, p.ω̄_star, 1.3, 1.3))
    push!(candidate_starts, (0.2, 0.5, p.ω̄, -0.005, p.ω̄_star, 1.05, 1.02))

    best_x = nothing
    best_norm = Inf
    best_conv = false

    for x0 in candidate_starts
        x0_c = _bgp_pack(x0...)
        for method in (:trust_region, :newton)
            try
                r = nlsolve((F, x) -> bgp_residual!(F, x, p, N_US, N_W),
                            x0_c; autodiff=:forward, method=method,
                            ftol=p.ftol, xtol=p.xtol, iterations=p.iterations)
                if r.residual_norm < best_norm
                    best_x = r.zero
                    best_norm = r.residual_norm
                    best_conv = converged(r)
                end
                if best_conv && best_norm < 1e-8; break; end
            catch err
                verbose && @info "Solver error at $(x0) [$(method)]: $(err)"
            end
        end
        if best_conv && best_norm < 1e-8; break; end
    end

    if best_x === nothing
        # Catastrophic failure
        x0_c = _bgp_pack(x0_actual...)
        F0 = zeros(7); bgp_residual!(F0, x0_c, p, N_US, N_W)
        verbose && @warn "BGP failed at (N_US, N_W)=($N_US, $N_W); returning initial guess"
        return _bgp_make_result(p, N_US, N_W, x0_c, false, norm(F0))
    end

    return _bgp_make_result(p, N_US, N_W, best_x, best_conv, best_norm)
end


# ─────────────────────────────────────────────────────────────────
# 7. Common-world-growth calibration (optional)
#    Adjusts ν_b such that G_N_US^ν_b == G_N_W^ξ_W  in BGP.
#    Iterative: solve BGP, check ν_b, adjust, repeat.
# ─────────────────────────────────────────────────────────────────

"""
Find ν_b (or other parameter) such that common-world-growth holds at the BGP
evaluated at (N_US, N_W).

Because φ_b and φ_W are themselves endogenous, this is a fixed-point problem:
    G_b = G_N_US(φ_b)^ν_b
    G_W = G_N_W(φ_W)^ξ_W
    impose G_b = G_W  → ν_b = ξ_W * log(G_N_W(φ_W)) / log(G_N_US(φ_b)).

Returns the calibrated ν_b and the corresponding BGPResult.
"""
function calibrate_common_growth(p::ProductionParams, N_US, N_W;
                                 max_iter::Int=80, tol::Float64=1e-8,
                                 damp::Float64=0.3, verbose::Bool=false)
    p_cur = p
    bgp = solve_bgp_at(p_cur, N_US, N_W)
    for it in 1:max_iter
        Gus = G_N_US(p_cur, bgp.φ_US)
        Gw  = G_N_W(p_cur, bgp.φ_W)
        if Gus ≤ 1.0 + 1e-12
            verbose && @warn "G_N_US too close to 1; stopping"
            break
        end
        ν_target = p_cur.ξ_W * log(Gw) / log(Gus)
        # Damped update to avoid oscillations
        ν_new = damp * ν_target + (1 - damp) * p_cur.ν_b
        Δ = abs(ν_new - p_cur.ν_b)
        p_cur = ProductionParams(p_cur; ν_b=ν_new)
        bgp = solve_bgp_at(p_cur, N_US, N_W;
                           x0_actual=(bgp.φ_US, bgp.φ_W, bgp.ω, bgp.θ, bgp.ω_star,
                                       bgp.R_f, bgp.R_f_W))
        verbose && @printf("  iter %2d: ν_b -> %.6f (Δ=%.2e), ‖F‖=%.2e\n",
                            it, ν_new, Δ, bgp.residual_norm)
        if Δ < tol && bgp.residual_norm < 1e-6
            break
        end
    end
    # Final check: G_b - G_W
    Gus = G_N_US(p_cur, bgp.φ_US); Gw = G_N_W(p_cur, bgp.φ_W)
    verbose && @printf("  Common-growth gap: G_b - G_W = %.2e\n",
                        Gus^p_cur.ν_b - Gw^p_cur.ξ_W)
    return (params=p_cur, bgp=bgp)
end


# ─────────────────────────────────────────────────────────────────
# 8. Knowledge-stock paths
# ─────────────────────────────────────────────────────────────────

"""
Forward-compute knowledge stocks along the u-history given a vector of φ_US,t.
Returns Vector{Float64} of length T+1: N_US^u at t = 0, 1, ..., T.
"""
function knowledge_path_US(p::ProductionParams, φ_US_path::Vector{<:Real})
    T = length(φ_US_path)
    N = Vector{Float64}(undef, T + 1)
    N[1] = p.N_US_0
    for t in 1:T
        N[t+1] = G_N_US(p, φ_US_path[t]) * N[t]
    end
    N
end

function knowledge_path_W(p::ProductionParams, φ_W_path::Vector{<:Real})
    T = length(φ_W_path)
    N = Vector{Float64}(undef, T + 1)
    N[1] = p.N_W_0
    for t in 1:T
        N[t+1] = G_N_W(p, φ_W_path[t]) * N[t]
    end
    N
end


# ─────────────────────────────────────────────────────────────────
# 9. Unbalanced-branch residual: 7 unknowns at each date t
#    (φ_US, φ_W, ω, θ, ω*, R_f, R_f^W)
#    BGPResult-at-t+1 is treated as a fixed input (for use within
#    forward-backward iteration).
# ─────────────────────────────────────────────────────────────────

# Same constrained transformation as BGP
_u_unpack(x_c) = _bgp_unpack(x_c)
_u_pack(φ_US, φ_W, ω, θ, ω_s, R_f, R_f_W) = _bgp_pack(φ_US, φ_W, ω, θ, ω_s, R_f, R_f_W)

"""
Residual for the date-t u-branch system.
Inputs:
  N_US_t, N_W_t          : current predetermined state
  next_u                 : NamedTuple (φ_US, φ_W, q_US, q_W, d_US, d_W, N_US, N_W)
                            for the u-successor at t+1
  next_b                 : BGPResult at the b-successor evaluated at (N_US_t+1^u, N_W_t+1)
"""
function u_residual!(F, x_c, p::ProductionParams,
                     N_US_t, N_W_t,
                     next_u, next_b::BGPResult)
    φ_US, φ_W, ω, θ, ω_s, R_f, R_f_W = _u_unpack(x_c)

    us_t = us_block(p, :u, φ_US, N_US_t)
    rw_t = row_block(p, φ_W, N_W_t)

    A    = p.β * us_t.e
    As   = (p.β + p.χ) / (1 + p.χ) * rw_t.e
    θ_Us = -θ * A / As
    S    = (1 - θ) * A
    Ss   = (1 - θ_Us) * As

    G_US = G_N_US(p, φ_US)
    G_W  = G_N_W(p, φ_W)
    N_US_tp1 = G_US * N_US_t
    N_W_tp1  = G_W  * N_W_t

    Q_US_t = N_US_tp1 * us_t.q
    Q_W_t  = N_W_tp1  * rw_t.q

    # Re-evaluate u-successor production at the implied N_US_tp1, N_W_tp1
    us_u_next = us_block(p, :u, next_u.φ_US, N_US_tp1)
    rw_next   = row_block(p,    next_u.φ_W,  N_W_tp1)

    # Re-evaluate b-successor production at the same state (by valuation parity,
    # the BGPResult's q,d scale to the same N_US_tp1; we recompute via :b regime
    # using next_b.φ_US (≈ φ̄_b) for consistency)
    us_b_next = us_block(p, :b, next_b.φ_US, N_US_tp1)
    # RoW under switch is the same production block (ξ_W invariant to z)
    # rw_next applies for both successors

    R_US_u = (us_u_next.q + us_u_next.d) / us_t.q
    R_W_u  = (rw_next.q   + rw_next.d)   / rw_t.q

    R_US_b = (us_b_next.q + us_b_next.d) / us_t.q
    R_W_b  = R_W_u   # RoW production block is regime-invariant

    R_p_u   = ω   * R_US_u + (1 - ω)   * R_W_u
    R_A_u   = (1 - θ)    * R_p_u + θ * R_f
    R_ps_u  = ω_s * R_US_u + (1 - ω_s) * R_W_u
    R_As_u  = (1 - θ_Us) * R_ps_u + θ_Us * R_f

    R_p_b   = ω   * R_US_b + (1 - ω)   * R_W_b
    R_A_b   = (1 - θ)    * R_p_b + θ * R_f
    R_ps_b  = ω_s * R_US_b + (1 - ω_s) * R_W_b
    R_As_b  = (1 - θ_Us) * R_ps_b + θ_Us * R_f

    if R_A_u ≤ 0 || R_A_b ≤ 0 || R_As_u ≤ 0 || R_As_b ≤ 0
        F .= 1e8
        return F
    end

    π_p = p.π_persist
    γ   = p.γ

    # Kernels
    E_RA_pow  = π_p * R_A_u^(1 - γ) + (1 - π_p) * R_A_b^(1 - γ)
    K_u = R_A_u^(-γ) / E_RA_pow
    K_b = R_A_b^(-γ) / E_RA_pow

    E_RAs_pow = π_p * R_As_u^(1 - γ) + (1 - π_p) * R_As_b^(1 - γ)
    M_u = R_As_u^(-γ) / E_RAs_pow
    M_b = R_As_b^(-γ) / E_RAs_pow

    # Expectations
    E_K_dR  = π_p * K_u * (R_US_u - R_W_u)  + (1 - π_p) * K_b * (R_US_b - R_W_b)
    E_K_dRf = π_p * K_u * (R_f    - R_p_u)  + (1 - π_p) * K_b * (R_f    - R_p_b)
    E_M_dR  = π_p * M_u * (R_US_u - R_W_u)  + (1 - π_p) * M_b * (R_US_b - R_W_b)
    E_M_dRf = π_p * M_u * (R_f    - R_ps_u) + (1 - π_p) * M_b * (R_f    - R_ps_b)
    E_M_dRfW= π_p * M_u * (R_f_W  - R_ps_u) + (1 - π_p) * M_b * (R_f_W  - R_ps_b)

    sav_scale = max(A + As, 1e-12)
    F[1] = (Q_US_t - ω * S - ω_s * Ss) / sav_scale
    F[2] = (Q_W_t  - (1 - ω) * S - (1 - ω_s) * Ss) / sav_scale
    F[3] = p.β * (1 - θ)   * E_K_dR  - p.κ * (ω   - p.ω̄)
    F[4] = p.β * E_K_dRf - p.η * upsilon_prime(DEFAULT_COST, θ)
    F[5] = p.β * (1 - θ_Us)* E_M_dR  - p.κ * (ω_s - p.ω̄_star)
    F[6] = p.β * E_M_dRfW
    F[7] = p.β * E_M_dRf + p.χ / θ_Us
    return F
end

# ─────────────────────────────────────────────────────────────────
# 10. Backward-induction over the u-branch
#     Outer loop: alternate between
#       (i)  fix {φ_US,t^u} → forward-compute {N_US,t^u},
#            solve BGP at each N_US,t+1^u,
#            backward-induct to update y_t^u,
#       (ii) extract new {φ_US,t^u} and check convergence.
# ─────────────────────────────────────────────────────────────────

function _build_u_period(p, t, N_US_t, N_W_t,
                        φ_US, φ_W, ω, ω_s, θ, R_f, R_f_W,
                        next_u, next_b::BGPResult, residual_norm)
    us_t = us_block(p, :u, φ_US, N_US_t)
    rw_t = row_block(p, φ_W, N_W_t)
    A    = p.β * us_t.e
    As   = (p.β + p.χ) / (1 + p.χ) * rw_t.e
    θ_Us = -θ * A / As
    S    = (1 - θ) * A
    Ss   = (1 - θ_Us) * As
    G_US = G_N_US(p, φ_US)
    G_W  = G_N_W(p, φ_W)
    N_US_tp1 = G_US * N_US_t
    N_W_tp1  = G_W  * N_W_t
    Q_US = N_US_tp1 * us_t.q
    Q_W  = N_W_tp1  * rw_t.q

    us_u_next = us_block(p, :u, next_u.φ_US, N_US_tp1)
    rw_next   = row_block(p,    next_u.φ_W,  N_W_tp1)
    us_b_next = us_block(p, :b, next_b.φ_US, N_US_tp1)

    R_US_u = (us_u_next.q + us_u_next.d) / us_t.q
    R_W_u  = (rw_next.q   + rw_next.d)   / rw_t.q
    R_US_b = (us_b_next.q + us_b_next.d) / us_t.q
    R_W_b  = R_W_u

    R_p_u  = ω * R_US_u + (1 - ω) * R_W_u
    R_A_u  = (1 - θ) * R_p_u + θ * R_f
    R_ps_u = ω_s * R_US_u + (1 - ω_s) * R_W_u
    R_As_u = (1 - θ_Us) * R_ps_u + θ_Us * R_f

    R_p_b  = ω * R_US_b + (1 - ω) * R_W_b
    R_A_b  = (1 - θ) * R_p_b + θ * R_f
    R_ps_b = ω_s * R_US_b + (1 - ω_s) * R_W_b
    R_As_b = (1 - θ_Us) * R_ps_b + θ_Us * R_f

    UPeriodState(t, N_US_t, N_W_t,
                 φ_US, φ_W, ω, ω_s, θ, θ_Us, R_f, R_f_W,
                 us_t.Y, rw_t.Y, us_t.e, rw_t.e,
                 us_t.q, rw_t.q, us_t.d, rw_t.d, Q_US, Q_W,
                 A, As, S, Ss,
                 R_US_u, R_W_u, R_p_u, R_A_u, R_ps_u, R_As_u,
                 R_US_b, R_W_b, R_p_b, R_A_b, R_ps_b, R_As_b,
                 residual_norm)
end

"""
Pack a (7, T+1) policy matrix into a constrained 7T-vector (terminal pol[:,T+1] held fixed).
"""
function _pack_policy(pol::Matrix{Float64}, T::Int)
    x = Vector{Float64}(undef, 7 * T)
    for t in 1:T
        xc = _u_pack(pol[1,t], pol[2,t], pol[3,t], pol[4,t],
                     pol[5,t], pol[6,t], pol[7,t])
        x[7*(t-1)+1:7*t] .= xc
    end
    x
end

"""
Unpack the 7T-vector back into actual values for policy[:, 1..T].
"""
function _unpack_policy_actual(x::AbstractVector, T::Int)
    pol = Matrix{Float64}(undef, 7, T)
    for t in 1:T
        a = _u_unpack(x[7*(t-1)+1:7*t])
        pol[:, t] .= [a[1], a[2], a[3], a[4], a[5], a[6], a[7]]
    end
    pol
end

"""
Global residual: assemble all 7T equations from the period-by-period u-residual,
with N_US, N_W trajectories computed forward from the current policy guess.
"""
function _u_branch_global_residual!(F, x, p::ProductionParams,
                                    bgp_seq::Vector{BGPResult},
                                    pol_terminal::Vector{Float64})
    T = length(bgp_seq) - 1   # bgp_seq has T+1 entries

    # Decode policy, compute knowledge paths
    pol = Matrix{eltype(x)}(undef, 7, T + 1)
    for t in 1:T
        a = _u_unpack(x[7*(t-1)+1:7*t])
        pol[:, t] .= [a[1], a[2], a[3], a[4], a[5], a[6], a[7]]
    end
    pol[:, T+1] .= pol_terminal

    # Forward N_US, N_W
    N_US = Vector{eltype(x)}(undef, T + 1)
    N_W  = Vector{eltype(x)}(undef, T + 1)
    N_US[1] = p.N_US_0
    N_W[1]  = p.N_W_0
    for t in 1:T
        N_US[t+1] = G_N_US(p, pol[1, t]) * N_US[t]
        N_W[t+1]  = G_N_W(p, pol[2, t]) * N_W[t]
    end

    # Build residuals at each t = 1..T
    Ft = zeros(eltype(x), 7)
    for t in 1:T
        next_u = (φ_US=pol[1, t+1], φ_W=pol[2, t+1])
        next_b = bgp_seq[t+1]
        x_t = x[7*(t-1)+1:7*t]
        u_residual!(Ft, x_t, p, N_US[t], N_W[t], next_u, next_b)
        F[7*(t-1)+1:7*t] .= Ft
    end
    return F
end

"""
Polish the u-branch by solving all 7T equations simultaneously.
Returns the polished policy matrix (7, T+1) or nothing on failure.
"""
function _polish_u_branch_global(p::ProductionParams,
                                  pol::Matrix{Float64},
                                  bgp_seq::Vector{BGPResult};
                                  verbose::Bool=false)
    T = size(pol, 2) - 1
    pol_terminal = copy(pol[:, T+1])
    x0 = _pack_policy(pol, T)

    try
        r = nlsolve((F, x) -> _u_branch_global_residual!(F, x, p, bgp_seq, pol_terminal),
                    x0; autodiff=:forward, method=:trust_region,
                    ftol=p.ftol, xtol=p.xtol, iterations=p.iterations)
        verbose && @printf("  polish ‖F‖=%.2e converged=%s\n", r.residual_norm, converged(r))
        if r.residual_norm < 1e-4
            new_pol_inner = _unpack_policy_actual(r.zero, T)
            out = Matrix{Float64}(undef, 7, T + 1)
            out[:, 1:T] .= new_pol_inner
            out[:, T+1] .= pol_terminal
            return out
        else
            return nothing
        end
    catch err
        verbose && @info "Polish solve error: $err"
        return nothing
    end
end

"""
Try to solve the date-t u-residual using multiple strategies.
Returns (best_x_c::Vector, best_norm::Float64, converged::Bool).
Stops early as soon as a converged solution with ‖F‖<1e-8 is found.
"""
function _solve_u_residual_at_t(p::ProductionParams,
                                N_US_t, N_W_t,
                                next_u, next_b::BGPResult,
                                start_guesses::Vector)
    best_x = nothing
    best_norm = Inf
    best_conv = false

    for x0 in start_guesses
        x0_c = _u_pack(x0...)
        try
            r = nlsolve((F, x) -> u_residual!(F, x, p, N_US_t, N_W_t, next_u, next_b),
                        x0_c; autodiff=:forward, method=:trust_region,
                        ftol=p.ftol, xtol=p.xtol, iterations=p.iterations)
            if r.residual_norm < best_norm
                best_x = r.zero
                best_norm = r.residual_norm
                best_conv = converged(r)
            end
            if best_conv && best_norm < 1e-8; break; end
        catch; end
    end
    # Newton fallback if no good solution
    if !best_conv || best_norm > 1e-6
        for x0 in start_guesses[1:min(2, length(start_guesses))]
            x0_c = _u_pack(x0...)
            try
                r = nlsolve((F, x) -> u_residual!(F, x, p, N_US_t, N_W_t, next_u, next_b),
                            x0_c; autodiff=:forward, method=:newton,
                            ftol=p.ftol, xtol=p.xtol, iterations=p.iterations)
                if r.residual_norm < best_norm
                    best_x = r.zero
                    best_norm = r.residual_norm
                    best_conv = converged(r)
                end
                if best_conv && best_norm < 1e-8; break; end
            catch; end
        end
    end
    return (best_x, best_norm, best_conv)
end

"""
Solve the unbalanced branch by forward-backward iteration.
- At iteration k, hold the trajectory {N_US,t^u} fixed (computed forward
  from a guess of φ_US^u).
- Solve BGP at each (N_US,t+1^u, N_W,t+1).
- Backward-induct y_t^u using the BGP and the next u-period guess.
- Update the trajectory {φ_US,t^u} and iterate.
"""
function solve_unbalanced_branch(p::ProductionParams,
                                 bgp_init::BGPResult;
                                 verbose::Bool=false)
    T = p.T_max

    # Initial guess: φ_US^u = bgp_init.φ_US for all t,  φ_W = bgp_init.φ_W for all t
    φ_US_path = fill(bgp_init.φ_US, T + 1)
    φ_W_path  = fill(bgp_init.φ_W,  T + 1)

    # Forward path of N's (will recompute each iteration)
    N_US_path = knowledge_path_US(p, φ_US_path[1:T])
    N_W_path  = knowledge_path_W(p, φ_W_path[1:T])

    # Solve BGP at each forward state (used as switch successor)
    bgp_seq = Vector{BGPResult}(undef, T + 1)
    bgp_seq[1] = bgp_init
    for t in 2:(T + 1)
        x0 = (bgp_seq[t-1].φ_US, bgp_seq[t-1].φ_W, bgp_seq[t-1].ω, bgp_seq[t-1].θ,
              bgp_seq[t-1].ω_star, bgp_seq[t-1].R_f, bgp_seq[t-1].R_f_W)
        bgp_seq[t] = solve_bgp_at(p, N_US_path[t], N_W_path[t]; x0_actual=x0)
    end

    # u-path policy storage
    pol = Matrix{Float64}(undef, 7, T + 1)
    # Initialise from BGP at each date
    for t in 1:(T + 1)
        pol[:, t] .= [bgp_seq[t].φ_US, bgp_seq[t].φ_W, bgp_seq[t].ω, bgp_seq[t].θ,
                      bgp_seq[t].ω_star, bgp_seq[t].R_f, bgp_seq[t].R_f_W]
    end

    converged_flag = false
    last_residual_norms = fill(NaN, T)

    for outer_it in 1:p.branch_iters
        # ---- Step 1: forward N_US_path from the current φ_US_path ----
        N_US_path = knowledge_path_US(p, pol[1, 1:T])
        N_W_path  = knowledge_path_W(p, pol[2, 1:T])

        # ---- Step 2: re-solve BGP at each forward state ----
        for t in 2:(T + 1)
            x0 = (bgp_seq[t-1].φ_US, bgp_seq[t-1].φ_W, bgp_seq[t-1].ω, bgp_seq[t-1].θ,
                  bgp_seq[t-1].ω_star, bgp_seq[t-1].R_f, bgp_seq[t-1].R_f_W)
            try
                bgp_seq[t] = solve_bgp_at(p, N_US_path[t], N_W_path[t]; x0_actual=x0)
            catch
                # keep previous
            end
        end

        # ---- Step 3: backward induction along u-branch ----
        # Terminal condition: y_{T+1}^u ≈ y_T^u (continuation approx)
        residual_norms = zeros(T + 1)
        n_failed = 0

        for t in T:-1:1
            N_US_t = N_US_path[t]
            N_W_t  = N_W_path[t]

            # Successor at t+1 (u): use current pol[:, t+1]
            φ_US_next, φ_W_next = pol[1, t+1], pol[2, t+1]
            next_u = (φ_US=φ_US_next, φ_W=φ_W_next)

            # Successor at t+1 (b): BGP at (N_US_path[t+1], N_W_path[t+1])
            next_b = bgp_seq[t+1]

            # Initial-guess pool: prev solution, BGP at this date, neighbour values
            bgp_t = bgp_seq[t]
            start_guesses = Tuple[]
            push!(start_guesses, (pol[1, t], pol[2, t], pol[3, t], pol[4, t],
                                  pol[5, t], pol[6, t], pol[7, t]))
            push!(start_guesses, (bgp_t.φ_US, bgp_t.φ_W, bgp_t.ω, bgp_t.θ,
                                  bgp_t.ω_star, bgp_t.R_f, bgp_t.R_f_W))
            if t < T
                push!(start_guesses, (pol[1, t+1], pol[2, t+1], pol[3, t+1], pol[4, t+1],
                                      pol[5, t+1], pol[6, t+1], pol[7, t+1]))
            end
            # Perturbed BGP guesses
            push!(start_guesses, (max(bgp_t.φ_US * 0.7, 0.05), bgp_t.φ_W,
                                  bgp_t.ω, bgp_t.θ, bgp_t.ω_star,
                                  bgp_t.R_f, bgp_t.R_f_W))
            push!(start_guesses, (min(bgp_t.φ_US * 1.3, 0.95), bgp_t.φ_W,
                                  bgp_t.ω, bgp_t.θ, bgp_t.ω_star,
                                  bgp_t.R_f, bgp_t.R_f_W))

            best_x, best_norm, best_conv = _solve_u_residual_at_t(
                p, N_US_t, N_W_t, next_u, next_b, start_guesses)

            spurious = false
            if best_x === nothing
                spurious = true
            else
                φ_US_t, φ_W_t, ω_t, θ_t, ω_s_t, R_f_t, R_f_W_t = _u_unpack(best_x)
                spurious = best_norm > 1e-3 ||
                           φ_US_t < 1e-3 || φ_US_t > 1 - 1e-3 ||
                           φ_W_t  < 1e-3 || φ_W_t  > 1 - 1e-3 ||
                           !isfinite(R_f_t) || !isfinite(R_f_W_t) ||
                           R_f_t < 0 || R_f_W_t < 0
            end

            if spurious
                n_failed += 1
                residual_norms[t] = best_x === nothing ? Inf : best_norm
                # Replace pol[:, t] by interpolation from neighbours so the
                # spurious value does not persist forever.
                if t < T
                    # Linear interp φ_US between t-1 (or BGP at t) and t+1
                    if t > 1
                        pol[:, t] .= 0.5 .* (pol[:, t-1] .+ pol[:, t+1])
                    else
                        pol[:, t] .= pol[:, t+1]
                    end
                end
                continue
            end

            φ_US_t, φ_W_t, ω_t, θ_t, ω_s_t, R_f_t, R_f_W_t = _u_unpack(best_x)
            pol[:, t] .= [φ_US_t, φ_W_t, ω_t, θ_t, ω_s_t, R_f_t, R_f_W_t]
            residual_norms[t] = best_norm
            best_conv || (n_failed += 1)
        end

        last_residual_norms = residual_norms[1:T]

        # ---- Step 4: convergence check on φ_US_path ----
        new_φ_US_path = pol[1, 1:T+1]
        Δ = maximum(abs.(new_φ_US_path .- φ_US_path))
        finite_norms = filter(isfinite, residual_norms)
        max_norm = isempty(finite_norms) ? Inf : maximum(finite_norms)

        verbose && @printf("  outer %2d: Δφ_US=%.2e, max ‖F‖=%.2e, fails=%d/%d\n",
                            outer_it, Δ, max_norm, n_failed, T)

        φ_US_path = new_φ_US_path
        φ_W_path  = pol[2, 1:T+1]

        if Δ < p.branch_tol && max_norm < 1e-5
            converged_flag = true
            verbose && println("  forward-backward converged at iter $outer_it")
            break
        end
    end

    # ---- Optional polish: solve all 7T equations simultaneously ----
    # Expensive (Jacobian is 7T × 7T). Off by default; enable only if iterative sweep stalls.
    if p.do_global_polish && (!converged_flag || any(>(1e-5), filter(isfinite, last_residual_norms)))
        verbose && println("  polishing via simultaneous 7T-equation solve...")
        polished = _polish_u_branch_global(p, pol, bgp_seq, verbose=verbose)
        if polished !== nothing
            pol = polished
            converged_flag = true
        end
    end

    if !converged_flag
        verbose && @warn "Forward-backward did not fully converge after $(p.branch_iters) iters."
    end

    # ---- Build u_path objects ----
    N_US_path = knowledge_path_US(p, pol[1, 1:T])
    N_W_path  = knowledge_path_W(p, pol[2, 1:T])
    for t in 2:(T + 1)
        x0 = (bgp_seq[t-1].φ_US, bgp_seq[t-1].φ_W, bgp_seq[t-1].ω, bgp_seq[t-1].θ,
              bgp_seq[t-1].ω_star, bgp_seq[t-1].R_f, bgp_seq[t-1].R_f_W)
        try
            bgp_seq[t] = solve_bgp_at(p, N_US_path[t], N_W_path[t]; x0_actual=x0)
        catch; end
    end

    u_path = Vector{UPeriodState}(undef, T)
    for t in 1:T
        N_US_t = N_US_path[t]; N_W_t = N_W_path[t]
        next_u = (φ_US=pol[1, t+1], φ_W=pol[2, t+1])
        next_b = bgp_seq[t+1]
        F = zeros(7); xc = _u_pack(pol[1,t], pol[2,t], pol[3,t], pol[4,t],
                                    pol[5,t], pol[6,t], pol[7,t])
        u_residual!(F, xc, p, N_US_t, N_W_t, next_u, next_b)
        u_path[t] = _build_u_period(p, t, N_US_t, N_W_t,
                                    pol[1,t], pol[2,t], pol[3,t], pol[5,t],
                                    pol[4,t], pol[6,t], pol[7,t],
                                    next_u, next_b, norm(F))
    end

    return (u_path=u_path, bgp_seq=bgp_seq, converged=converged_flag)
end


# ─────────────────────────────────────────────────────────────────
# 11. Bubble diagnostics (V9 Theorem 1 conditions)
# ─────────────────────────────────────────────────────────────────

function compute_diagnostics(p::ProductionParams,
                              u_path::Vector{UPeriodState},
                              bgp_seq::Vector{BGPResult})
    T = length(u_path)
    π_p = p.π_persist
    γ   = p.γ

    cond_1a = zeros(T)
    cond_1b = zeros(T)
    a_t     = zeros(T)

    for t in 1:T
        u_t = u_path[t]
        bgp_t = bgp_seq[t]

        # d^u/q^u at t
        cond_1a[t] = u_t.d_US / u_t.q_US

        # Branch values at t (for Theorem 1):
        # We use the previous-period u-state portfolio choices, which is what
        # the kernel is built on.  Here we follow the "branch-in-time" notation
        # of V9_production.tex: q_t^z, d_t^z built from N_US,t (predetermined).
        # u-branch at t: just u_path[t]
        q_u   = u_t.q_US
        d_u   = u_t.d_US
        # b-branch at t (same N_US,t, regime b productivity)
        bgp_t = bgp_seq[t]
        q_b   = bgp_t.q_US
        d_b   = bgp_t.d_US

        # C^z_t = β e^z_{t-1}  R^z_{A,t}.  Using portfolio chosen at t-1.
        if t == 1
            # Initial period: define ratios via current-period proxies
            cond_1b[t] = (q_b + d_b) / q_u * 1.0   # C ratio = 1 at t=0
            a_t[t] = cond_1a[t] + (1 - π_p)/π_p * (q_b + d_b) / q_u
        else
            u_prev = u_path[t-1]
            # R_A on u-branch: from t-1 to t (already stored)
            R_A_u = u_prev.R_A_u
            R_A_b = u_prev.R_A_b
            A_prev = u_prev.A
            C_u = A_prev * R_A_u
            C_b = A_prev * R_A_b
            ratio = C_u / C_b   # = (R_A_u/R_A_b) since A_prev common
            cond_1b[t] = (q_b + d_b) / q_u * (ratio)^γ
            a_t[t] = cond_1a[t] + (1 - π_p)/π_p * (ratio)^γ * (q_b + d_b) / q_u
        end
    end

    cum_1a = cumsum(cond_1a)
    cum_1b = cumsum(cond_1b)
    cum_at = cumsum(a_t)

    n_tail = max(1, T ÷ 10)
    tail_1a = cum_1a[end] - cum_1a[end - n_tail]
    tail_1b = cum_1b[end] - cum_1b[end - n_tail]
    conv_1a = tail_1a < 0.01 * max(cum_1a[end], 1e-15)
    conv_1b = tail_1b < 0.01 * max(cum_1b[end], 1e-15)

    bubble = conv_1a && conv_1b
    ProductionDiagnostics(cond_1a, cum_1a, cond_1b, cum_1b,
                          a_t, cum_at, bubble, conv_1a, conv_1b)
end


# ─────────────────────────────────────────────────────────────────
# 12. Top-level orchestrator
# ─────────────────────────────────────────────────────────────────

"""
End-to-end V9 production-economy simulation.

Steps:
1. Validate parameters.
2. (Optional) calibrate ν_b for common world growth.
3. Solve absorbing BGP at the initial state (N_US,0, N_W,0).
4. Solve unbalanced branch by forward-backward iteration.
5. Compute Theorem 1 bubble diagnostics.
"""
function run_production_simulation(p::ProductionParams=ProductionParams();
                                    verbose::Bool=true)
    validate_params(p)

    p_use = p
    bgp0 = BGPResult(0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,0.,
                     0.,0.,0.,0.,0.,0.,1.,1.,false,Inf)

    if p.common_world_growth
        verbose && println("Calibrating ν_b for common world growth...")
        cal = calibrate_common_growth(p, p.N_US_0, p.N_W_0; verbose=verbose)
        p_use = cal.params
        bgp0 = cal.bgp
        verbose && @printf("  Calibrated ν_b = %.6f (was %.6f)\n", p_use.ν_b, p.ν_b)
    else
        verbose && println("Solving absorbing BGP at initial state...")
        bgp0 = solve_bgp_at(p, p.N_US_0, p.N_W_0)
    end
    verbose && @printf("  BGP: φ_b=%.4f  φ_W=%.4f  ω=%.4f  θ=%+.4f  ω*=%.4f  R_f=%.4f  R_f^W=%.4f\n",
                       bgp0.φ_US, bgp0.φ_W, bgp0.ω, bgp0.θ,
                       bgp0.ω_star, bgp0.R_f, bgp0.R_f_W)
    verbose && @printf("  Residual norm: %.2e (converged: %s)\n",
                       bgp0.residual_norm, bgp0.converged)

    verbose && println("Solving unbalanced branch by forward-backward iteration...")
    branch = solve_unbalanced_branch(p_use, bgp0; verbose=verbose)

    verbose && println("Computing bubble diagnostics...")
    diag = compute_diagnostics(p_use, branch.u_path, branch.bgp_seq)

    if verbose
        println("\n══════ V9 PRODUCTION-ECONOMY DIAGNOSTICS ══════")
        @printf("  Condition (1a) converges: %s   (Σ d^u/q^u  = %.6f)\n",
                diag.cond_1a_converges, diag.cum_1a[end])
        @printf("  Condition (1b) converges: %s   (Σ branch   = %.6f)\n",
                diag.cond_1b_converges, diag.cum_1b[end])
        @printf("  BUBBLE EXISTS: %s\n", diag.bubble_exists)
        @printf("  Total leakage Σ a_t = %.6f\n", diag.cum_a_t[end])
    end

    ProductionSimulationResult(p_use, branch.bgp_seq, branch.u_path, diag)
end
