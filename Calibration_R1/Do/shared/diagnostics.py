"""Production-only diagnostics shared across run folders."""
import numpy as np
from calibration import ces_coefficients, log_knowledge, golden_minimize

def slope(y,k):
    return float(np.linalg.lstsq(np.c_[np.ones(len(k)),k],np.asarray(y),rcond=None)[0][1])


def cone_fit(p,theta,rho,unrestricted,alpha=0.5):
    """Profile the CLOSED cone xi>=nu>=0; strict ordering has no attained boundary fit."""
    cx,cl=ces_coefficients(p,theta,rho)
    yx=(cx-np.log(alpha))/(1-rho)
    yl=(cl-np.log(1-alpha))/(1-rho)
    def at(loga,details=False):
        a=np.exp(loga); k,_=log_knowledge(p,a); kc=k-k.mean()
        sx=slope(yx,k); sl=slope(yl,k)
        candidates=[(max(0.,sx),0.),(max(0.,(sx+sl)/2),)*2,(0.,0.)]
        if sx>=sl>=0: candidates.append((sx,sl))
        def technology_loss(pair):
            x,n=pair
            return (1-rho)**2*(np.mean((yx-yx.mean()-x*kc)**2)+np.mean((yl-yl.mean()-n*kc)**2))
        xi,nu=min(candidates,key=technology_loss)
        ix=yx.mean()-xi*k.mean(); il=yl.mean()-nu*k.mean()
        ra=(p.Q-p.I-p.wH/a)/p.Q
        rx=(1-rho)*(yx-ix-xi*k); rl=(1-rho)*(yl-il-nu*k)
        obj=float(np.mean(ra**2)+np.mean(rx**2)+np.mean(rl**2))
        if details:
            return dict(a=float(a),xi=float(xi),nu=float(nu),AX=float(np.exp(ix)),AL=float(np.exp(il)),
                        objective=obj,free_entry_relative_rmse=float(np.sqrt(np.mean(ra**2))),
                        log_CX_rmse=float(np.sqrt(np.mean(rx**2))),log_CL_rmse=float(np.sqrt(np.mean(rl**2))))
        return obj
    grid=np.linspace(np.log(unrestricted['a'])-8,np.log(unrestricted['a'])+8,257)
    values=np.array([at(v) for v in grid])
    candidates=[(grid[0],values[0]),(grid[-1],values[-1])]
    for i in range(1,len(grid)-1):
        if values[i]<=min(values[i-1],values[i+1]):
            x=golden_minimize(at,grid[i-1],grid[i+1]); candidates.append((x,at(x)))
    best=min(candidates,key=lambda x:x[1])[0]
    result=at(best,True)
    result.update(constraint='xi >= nu >= 0; closure of the strict restriction',
                  at_equal_spillover_boundary=bool(abs(result['xi']-result['nu'])<1e-9),
                  at_a_search_boundary=bool(abs(best-grid[0])<1e-6 or abs(best-grid[-1])<1e-6),
                  meaning='Lower-bound fit cost; equality is not an admissible unbalanced-growth calibration')
    return result

