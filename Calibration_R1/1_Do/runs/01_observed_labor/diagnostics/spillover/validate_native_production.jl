# Evaluate the actual four production functions, without loading or solving GE.
const here = @__DIR__
const root = abspath(joinpath(here, "../../../.."))
const source = joinpath(root, "Codes/Two_country_proudction_zero_nu_b/TwoCountryProductionOLG.jl")
const wanted = Set([:ces_F, :ces_FX, :ces_FL, :compute_production])
const found = Dict{Symbol, Expr}()
function collect_functions(ex)
    ex isa Expr || return
    if ex.head == :function
        signature = ex.args[1]
        if signature isa Expr && signature.head == :call && signature.args[1] in wanted
            found[signature.args[1]] = ex
        end
    end
    for arg in ex.args
        collect_functions(arg)
    end
end
collect_functions(Meta.parseall(read(source, String)))
@assert Set(keys(found)) == wanted
for name in [:ces_F, :ces_FX, :ces_FL, :compute_production]
    Core.eval(Main, found[name])
end
mkpath(joinpath(here, "results"))
open(joinpath(here, "results/native_production_fixture.csv"), "w") do io
    println(io, "rho,year,H,L,Y,wH,wL,Q,N_true,X_true,theta,alpha,a,xi,nu,AX,AL")
    for rho in [2/3, 2.0]
        n=1.0
        for t in 0:23
            h=2+.02*t; l=3+.03*cos(t/3); phi=.55+.05*sin(t/4)
            alpha=.43; theta=.4; a=.07; xi=.8; nu=.25; ax=1.3; al=.9
            native=compute_production(alpha,rho,theta,a,h,l,phi,n,ax*n^xi,al*n^nu)
            g=1+a*(h-native.X)
            q=g*n*native.q
            @assert isapprox(native.Y,native.e+n*native.d-native.I;rtol=1e-12)
            # Independent finite differences of the native CES level function.
            step=1e-5
            xs=native.A_X*native.X; ls=native.A_L*l
            dX=(ces_F(alpha,rho,xs*(1+step),ls)-ces_F(alpha,rho,xs*(1-step),ls))/(2*step*xs)
            dL=(ces_F(alpha,rho,xs,ls*(1+step))-ces_F(alpha,rho,xs,ls*(1-step)))/(2*step*ls)
            @assert isapprox(native.w_H,theta*dX*native.A_X;rtol=1e-8)
            @assert isapprox(native.w_L,dL*native.A_L;rtol=1e-8)
            println(io,join([rho,2000+t,h,l,native.Y,native.w_H,native.w_L,q,n,native.X,
                            theta,alpha,a,xi,nu,ax,al],","))
            n*=g
        end
    end
end
println("PASS: native production/accounting and finite-difference wages; 48 fixture rows exported.")
