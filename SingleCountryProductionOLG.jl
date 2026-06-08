#= ================================================================
   SingleCountryProductionOLG.jl
   Faithful replication of the single-country PRODUCTION OLG bubble
   economy of Hirano, Kishi & Toda (2025),
   "Technological Innovation and Bursting Bubbles", arXiv:2501.08215,
   §3 (model of innovation and intangible capital) and §4.

   This is the ORIGINAL HKT one-country model — NOT a reduction of the
   two-country code. Key structural difference vs. TwoCountryProductionOLG.jl:
   there is a single asset (the per-variety stock), hence NO portfolio /
   asset-pricing fixed point. The real allocation φ_t is the static root of
   HKT eq. (3.21), depending on t only through n_t, so the whole path is a
   trivial forward recursion (solvable to any horizon).

   HKT numerical example (§4.2, verbatim):
     β=1/2, α=1/2, ρ=2, θ=1/2, A_XH=10, A_LL=1,
     ξu=0.7, λu=0.2, ξb=λb=0.1, aH=0.2, n0=1.
   Only the products (A_X·H, A_L·L, a·H) enter the equilibrium, so we
   parameterize those directly, exactly as HKT do.
   ================================================================ =#

using Parameters, Printf

@with_kw struct HKTParams
    β::Float64    = 0.5       # discount / saving rate (unit-EIS ⇒ save β·income)
    γ::Float64    = 0.5       # risk aversion. NOTE: HKT's price-dividend FIGURE is
                              # γ-free (unit EIS); γ enters ONLY bubble cond (2.15b).
                              # Not listed in HKT's numerical example; set to match
                              # our two-country model (γ<1, Hirano convention).
    α::Float64    = 0.5       # CES distribution weight (3.2)
    ρ::Float64    = 2.0       # CES exponent (= 1/EoS); ρ>1 ⇒ substitutes
    θ::Float64    = 0.5       # Dixit–Stiglitz elasticity param (ε = 1/(1-θ) = 2)
    A_XH::Float64 = 10.0      # product A_X · H
    A_LL::Float64 = 1.0       # product A_L · L
    ξu::Float64   = 0.7       # u-regime knowledge spillover to X-sector  (Assn 6)
    λu::Float64   = 0.2       # u-regime knowledge spillover to L-sector
    ξb::Float64   = 0.1       # b-regime (balanced): ξb = λb
    λb::Float64   = 0.1
    aH::Float64   = 0.2       # R&D productivity × H ; Gu = 1 + aH
    n0::Float64   = 1.0       # initial knowledge
    T::Int        = 100       # horizon (HKT figures run to t = 100)
end

# ── CES F(X,L) and partials (X, L are the *augmented* inputs A_X·X, A_L·L) ──
_ces_F(α,ρ,X,L)  = abs(ρ-1) < 1e-9 ? X^α*L^(1-α) :
                   (α*X^(1-ρ) + (1-α)*L^(1-ρ))^(1/(1-ρ))
_ces_FX(α,ρ,X,L) = abs(ρ-1) < 1e-9 ? α*(X^α*L^(1-α))/X :
                   α*(α*X^(1-ρ)+(1-α)*L^(1-ρ))^(ρ/(1-ρ))*X^(-ρ)
_ces_FL(α,ρ,X,L) = abs(ρ-1) < 1e-9 ? (1-α)*(X^α*L^(1-α))/L :
                   (1-α)*(α*X^(1-ρ)+(1-α)*L^(1-ρ))^(ρ/(1-ρ))*L^(-ρ)

_exps(p::HKTParams, z::Symbol) = z === :u ? (p.ξu, p.λu) : (p.ξb, p.λb)

# ── HKT eq. (3.21): labour share φ ∈ (0,1] in the intermediate-good sector ──
# Combining (3.18) knowledge law and (3.19) stock-market clearing, φ solves
#   1/(aH) = φ - 1 + β + (β(1-α)/(θα)) · B^{ρ-1} · φ^{ρ},   B := A_Xt·H / (A_Lt·L).
# The RHS is strictly increasing in φ; an interior root exists iff the innovation
# condition (3.20)  1/(aH) < β + (β(1-α)/(θα))·B^{ρ-1}  holds, else φ = 1.
function solve_phi(p::HKTParams, B::Float64)
    c = (p.β*(1-p.α))/(p.θ*p.α)
    f(φ) = φ - 1 + p.β + c*B^(p.ρ-1)*φ^p.ρ - 1/p.aH
    f(1.0) ≤ 0 && return 1.0                       # (3.20) fails ⇒ no innovation
    lo, hi = 1e-14, 1.0
    for _ in 1:200
        mid = 0.5*(lo+hi)
        f(mid) > 0 ? (hi = mid) : (lo = mid)
    end
    return 0.5*(lo+hi)
end

# Aggregate one-period block at knowledge n under regime z (all in HKT products).
# Returns (φ, e, D, PD_pv, PD_agg, G, mc_resid) where
#   e   = H·wH + L·wL                aggregate young labour income
#   D   = (1-θ)/θ · (H·wH) · φ       aggregate dividend  (= n·d_pv)
#   PD_pv  = q_pv/d_pv = θ/((1-θ)·φ·aH)      per-variety price–dividend ratio
#   PD_agg = (n_{t+1} q_pv)/(n d_pv) = G·PD_pv   aggregate market-cap / dividend
#   G   = 1 + aH(1-φ)               knowledge growth factor (3.18)
#   mc_resid = G·(H wH)/aH - β·e    stock-market-clearing residual (should be ~0)
function hkt_block(p::HKTParams, n::Float64, z::Symbol)
    ξ, λ = _exps(p, z)
    AXH = p.A_XH * n^ξ
    ALL = p.A_LL * n^λ
    B   = AXH / ALL
    φ   = solve_phi(p, B)
    X̃, L̃ = AXH*φ, ALL
    FX  = _ces_FX(p.α,p.ρ,X̃,L̃)
    FL  = _ces_FL(p.α,p.ρ,X̃,L̃)
    HwH = p.θ*FX*AXH            # H·wH = θ·F_X·A_X·H   (3.22b)
    LwL = FL*ALL               # L·wL = F_L·A_L·L     (3.22c)
    e   = HwH + LwL
    D   = (1-p.θ)/p.θ * HwH * φ
    PD_pv  = p.θ/((1-p.θ)*φ*p.aH)
    G   = 1 + p.aH*(1-φ)
    PD_agg = G*PD_pv
    mc_resid = G*HwH/p.aH - p.β*e
    return (φ=φ, e=e, D=D, PD_pv=PD_pv, PD_agg=PD_agg, G=G, mc_resid=mc_resid)
end

# Geometric-tail certification (same ratio test used in the two-country code):
# fit the summand's asymptotic decay ratio r by log-linear LS over the last k+1
# terms; r<1 ⇒ the infinite sum converges, with tail cond_T·r/(1-r).
function geom_tail(cond::AbstractVector{<:Real}; k::Int=10)
    T = length(cond); T < 3 && return (NaN, Inf, false)
    k = clamp(k, 2, T-1)
    xs = Float64[]; ys = Float64[]
    for t in (T-k):T
        cond[t] > 0 && (push!(xs, float(t)); push!(ys, log(cond[t])))
    end
    length(ys) < 2 && return (NaN, Inf, false)
    x̄, ȳ = sum(xs)/length(xs), sum(ys)/length(ys)
    Sxx = sum(abs2, xs .- x̄); Sxx ≤ 0 && return (NaN, Inf, false)
    r = exp(sum((xs .- x̄).*(ys .- ȳ))/Sxx)
    conv = isfinite(r) && 0 < r < 1
    Σ∞ = conv ? sum(cond) + cond[T]*r/(1-r) : Inf
    return (r, Σ∞, conv)
end

"""
    run_hkt(p; verbose=true)

Simulate the HKT single-country economy along the all-u history (z_t=u ∀t),
which is the relevant branch for the bubble-existence conditions (Theorem 1).
At each t we also evaluate the b-branch counterfactual at the same predetermined
n_t (a switch to balanced growth at t) to form condition (2.15b).
Returns a NamedTuple of paths and the geometric-tail certification.
"""
function run_hkt(p::HKTParams = HKTParams(); verbose::Bool=true)
    T = p.T
    n   = Vector{Float64}(undef, T+1); n[1] = p.n0
    φ   = zeros(T); eu = zeros(T); Du = zeros(T)
    PDpv = zeros(T); PDagg = zeros(T); G = zeros(T)
    eb  = zeros(T); Db = zeros(T)
    c215a = zeros(T); c215b = zeros(T)
    mc = zeros(T)
    for t in 1:T
        u = hkt_block(p, n[t], :u)
        b = hkt_block(p, n[t], :b)              # switch-to-b counterfactual at n_t
        φ[t], eu[t], Du[t] = u.φ, u.e, u.D
        PDpv[t], PDagg[t], G[t], mc[t] = u.PD_pv, u.PD_agg, u.G, u.mc_resid
        eb[t], Db[t] = b.e, b.D
        cu = p.β*eu[t] + Du[t]                  # c^u_t = β e^u + D^u   (old consumption)
        cb = p.β*eb[t] + Db[t]                  # c^b_t = β e^b + D^b
        c215a[t] = Du[t]/eu[t]                  # HKT (2.15a) summand
        c215b[t] = (cb/cu)^(1 - p.γ)            # HKT (2.15b) summand
        n[t+1] = G[t]*n[t]                       # u persists (all-u branch)
    end
    r_a, Σa, conv_a = geom_tail(c215a)
    r_b, Σb, conv_b = geom_tail(c215b)
    bubble = conv_a && conv_b

    if verbose
        @printf("HKT single-country (arXiv:2501.08215) — all-u path, T=%d\n", T)
        @printf("  φ_1=%.4f → φ_T=%.4f   (monotone → 0; Prop. 5)\n", φ[1], φ[T])
        @printf("  n_T=%.3e   G_t: %.4f → %.4f   (asymptote Gu=1+aH=%.3f)\n",
                n[T], G[1], G[T], 1+p.aH)
        @printf("  price-dividend ratio (per-variety): %.3f → %.3f\n", PDpv[1], PDpv[T])
        @printf("  max |stock-mkt-clearing residual|  : %.2e\n", maximum(abs, mc))
        @printf("  cond (2.15a) Σ D^u/e^u : geom ratio r=%.4f  converges=%s  Σ_∞=%.4f\n",
                r_a, conv_a, Σa)
        @printf("  cond (2.15b) Σ(c^b/c^u)^{1-γ}: geom ratio r=%.4f  converges=%s  Σ_∞=%.4f\n",
                r_b, conv_b, Σb)
        @printf("  BUBBLE EXISTS: %s\n", bubble)
        # Horizon needed for a fixed-window 1%-tail test to register (illustrative).
        T_need(r) = (0 < r < 1) ? ceil(Int, log(0.01)/log(r)) : -1
        @printf("  ⇒ fixed-window 1%%-tail test would need ≈T=%d (2.15a), ≈T=%d (2.15b)\n",
                T_need(r_a), T_need(r_b))
    end
    return (n=n, φ=φ, eu=eu, Du=Du, PDpv=PDpv, PDagg=PDagg, G=G,
            cond_2_15a=c215a, cond_2_15b=c215b,
            ratio_a=r_a, ratio_b=r_b, sum_inf_a=Σa, sum_inf_b=Σb,
            bubble_exists=bubble, mc_resid=mc, params=p)
end
