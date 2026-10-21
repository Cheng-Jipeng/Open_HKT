"""Figures are diagnostics; targeted inputs are never labelled validation."""
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt


def plot_results(out):
    dest=out/'figures'
    dest.mkdir(exist_ok=True)
    plt.rcParams.update({'font.size':10,'axes.spines.top':False,'axes.spines.right':False,'figure.dpi':150})
    p=pd.read_csv(out/'baseline_allocation.csv')
    p=p[p.year.between(1994,2022)]
    fig,axes=plt.subplots(1,2,figsize=(12,4.8))
    axes[0].plot(p.year.to_numpy(),p.phi.to_numpy(),lw=2,color='#a23b35',label='P1 implied skilled production share')
    axes[0].axhline(1,color='black',ls='--',label='All skilled workers in production')
    axes[0].set(title='Preferred markup 1.61: no feasible dates',ylabel='Skilled production / skilled endowment',xlabel='Year')
    axes[0].legend(loc='upper right',fontsize=8)
    axes[1].plot(p.year.to_numpy(),p.markup_floor.to_numpy(),lw=2,label='Datewise lower bound for active research')
    axes[1].axhline(p.markup_floor.max(),color='#a23b35',ls='--',label=f'Common-sample bound > {p.markup_floor.max():.3f}')
    axes[1].axhspan(1.1,1.84,color='#4b8672',alpha=.17,label='Supplied markup candidates: 1.10–1.84')
    axes[1].set(title='Required markups lie outside the candidate set',ylabel='Gross markup',xlabel='Year',ylim=(1,3.5))
    axes[1].legend(loc='lower center',fontsize=8)
    fig.suptitle('US annual production calibration fails the P1 allocation restriction',fontweight='bold',fontsize=13)
    fig.text(.06,.025,'1994–2022 | Fed/BEA total-corporate accounts + CPS BA/non-BA compensation bridge | September 2026 snapshot',fontsize=8)
    fig.tight_layout(rect=(0,.06,1,.94))
    for ext in ['png','svg']:
        fig.savefig(dest/('01_feasibility.'+ext))
    plt.close(fig)
    p=pd.read_csv(out/'conditional_paths.csv')
    p=p[p.run_id.eq('mu3.5_rho0.666667_observed')]
    fig,axes=plt.subplots(2,2,figsize=(11.5,7.5))
    for a in axes.ravel():
        a.axvspan(2022.5,2024.5,color='gray',alpha=.12)
        a.set_xlabel('Year')
    axes[0,0].plot(p.year.to_numpy(),p.a_implied.to_numpy(),label='Datewise entry inversion')
    fit_a=(p.wH/(p.Q_free_entry_fit-p.I)).iloc[0]
    axes[0,0].axhline(fit_a,color='#a23b35',ls='--',label='Joint constant a')
    axes[0,0].set(title='Innovation productivity is not constant in the data',ylabel='a per million workers')
    axes[0,0].legend(fontsize=8)
    axes[0,1].plot(p.year.to_numpy(),p.Q.to_numpy(),label='Observed enterprise value')
    axes[0,1].plot(p.year.to_numpy(),p.Q_free_entry_fit.to_numpy(),label='Conditional entry fit',ls='--')
    axes[0,1].set(title='Q is a targeted input',ylabel='Trillion 2017 USD')
    axes[0,1].legend(fontsize=8)
    axes[1,0].plot(p.year.to_numpy(),p.Y.to_numpy(),label='Observed real GVA')
    axes[1,0].plot(p.year.to_numpy(),p.Y_fit.to_numpy(),label='Conditional CES fit',ls='--')
    axes[1,0].set(title='Production evaluated at inferred allocations',ylabel='Trillion 2017 USD')
    axes[1,0].legend(fontsize=8)
    axes[1,1].plot(p.year.to_numpy(),100*(p.G_Q_diagnostic.to_numpy()-1),label='Q-based inversion')
    axes[1,1].plot(p.year.to_numpy(),100*(p.G_a.to_numpy()-1),label='Joint constant-a technology',ls='--')
    axes[1,1].set(title='Two knowledge-growth restrictions',ylabel='Annual knowledge growth (%)')
    axes[1,1].legend(fontsize=8)
    fig.suptitle('Illustrative markup 3.5, rho = 2/3: outside the supplied candidate set',fontweight='bold',fontsize=12)
    fig.text(.06,.025,'NOT AN ACCEPTED CALIBRATION | Shading: conditional 2023–2024 temporal check | Sources: Fed/BEA + CPS, September 2026',fontsize=8)
    fig.tight_layout(rect=(0,.06,1,.94))
    for ext in ['png','svg']:
        fig.savefig(dest/('02_conditional_diagnostic.'+ext))
    plt.close(fig)
