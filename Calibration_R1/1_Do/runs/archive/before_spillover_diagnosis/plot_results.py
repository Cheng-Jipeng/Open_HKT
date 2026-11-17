"""One figure of measured inputs, P1 implications and labelled conditional paths."""
import json
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator, PercentFormatter


def plot_results(out, config):
    dest=out/'figures'
    dest.mkdir(exist_ok=True)
    p=pd.read_csv(out/'baseline_allocation.csv')
    paths=pd.read_csv(out/'conditional_paths.csv')
    params=pd.read_csv(out/'conditional_parameters.csv')
    start,end=int(p.year.min()),int(p.year.max())
    mu,rho=config['baseline_markup'],config['baseline_rho']
    diag_mu=config['central_diagnostic_markup']
    run_id=f'mu{diag_mu:g}_rho{rho:g}_observed'
    d=paths[paths.run_id.eq(run_id)].copy()
    par=params[params.run_id.eq(run_id)]
    x=p.year.to_numpy()
    blue,red,green,purple,gray='#24628A','#AD3D3D','#2D7D68','#80639E','#66737C'
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,
                         'axes.spines.top':False,'axes.spines.right':False,
                         'axes.titleweight':'bold','axes.labelcolor':'#35434D',
                         'text.color':'#253642','axes.edgecolor':'#ABB5BD',
                         'savefig.facecolor':'white','svg.fonttype':'none','pdf.fonttype':42})
    fig,axes=plt.subplots(4,3,figsize=(16,15))
    axes=axes.ravel()
    def line(ax,values,label,color=blue,style='-',width=2):
        ax.plot(x,np.asarray(values,dtype=float),label=label,color=color,ls=style,lw=width)
    def setup(i,title,ylabel):
        ax=axes[i]
        ax.set_title(f'{chr(65+i)}  {title}',loc='left',fontsize=11,pad=10)
        ax.set_ylabel(ylabel)
        ax.set_xlim(start-.25,end+.25)
        ax.set_xticks(sorted(set([start]+list(range(start+3,end,3))+[end])))
        ax.tick_params(axis='both',labelsize=9)
        ax.yaxis.set_major_locator(MaxNLocator(nbins=5))
        ax.grid(axis='y',alpha=.2,lw=.7)
        ax.set_axisbelow(True)
        return ax
    ax=setup(0,'Output, compensation and cash flow','Trillion 2017 USD / year')
    line(ax,p.Y,'Output Y')
    line(ax,p.COMP,'Compensation',green)
    line(ax,p.D,'Cash flow (untargeted)',gray)
    ax=setup(1,'Operating enterprise value','Trillion 2017 USD (stock)')
    line(ax,p.Q,'Observed Q')
    if len(d):
        line(ax,d.Q_free_entry_fit,f'Entry fit, diagnostic mu={diag_mu:g}',purple,'--')
    ax=setup(2,'Labor endowments','Million persons')
    line(ax,p.H,'Skilled H')
    line(ax,p.L,'Unskilled L',green)
    ax=setup(3,'Annual compensation per worker','Thousand 2017 USD / worker-year')
    line(ax,1000*p.wH,'Skilled wH')
    line(ax,1000*p.wL,'Unskilled wL',green)
    ax=setup(4,'Skill premium','wH / wL')
    line(ax,p.premium,'Composition-adjusted premium')
    ax=setup(5,'Compensation shares','Share')
    line(ax,p.COMP/p.Y,'Compensation / output')
    line(ax,p.BH/p.COMP,'Skilled / total compensation',green)
    ax.yaxis.set_major_formatter(PercentFormatter(1))
    ax=setup(6,'Implied production share phi','X / H')
    ax.axhspan(0,1,color=green,alpha=.07)
    ax.axhline(1,color=gray,ls=':',lw=1.5,label='Zero-research boundary')
    line(ax,p.phi,f'Baseline mu={mu:g}',red)
    if len(d):
        line(ax,d.phi,f'Diagnostic mu={diag_mu:g}',purple,'--')
    ax.set_ylim(0,max(1.1,float(p.phi.max())*1.10))
    ax=setup(7,'Implied research labor','H - X, million persons')
    ax.axhline(0,color=gray,ls=':',lw=1.3)
    line(ax,p.H-p.X,f'Baseline mu={mu:g}',red)
    if len(d):
        line(ax,d.H-d.X,f'Diagnostic mu={diag_mu:g}',purple,'--')
    ax=setup(8,'Implied research payroll','I = wH (H - X), trillion 2017 USD')
    ax.axhline(0,color=gray,ls=':',lw=1.3)
    line(ax,p.I,f'Baseline mu={mu:g}',red)
    if len(d):
        line(ax,d.I,f'Diagnostic mu={diag_mu:g}',purple,'--')
    ax=setup(9,'Markup required for active research','Gross markup')
    line(ax,p.markup_floor,'Datewise zero-research bound',blue)
    ax.axhline(p.markup_floor.max(),color=gray,ls=':',lw=1.5,
               label=f'Common bound > {p.markup_floor.max():.3f}')
    ax.axhline(mu,color=red,ls='--',lw=1.7,label=f'Baseline = {mu:g}')
    ax=setup(10,f'Innovation productivity | diagnostic mu={diag_mu:g}','a, per million workers per year')
    if len(d):
        line(ax,d.a_implied,'Datewise free-entry inversion',purple)
        ax.axhline(par.a.iloc[0],color=green,ls='--',lw=1.8,label='Joint constant-a fit')
        ax.ticklabel_format(axis='y',style='sci',scilimits=(-2,2))
    ax=setup(11,f'Technology paths | diagnostic mu={diag_mu:g}',f'Index: {start} = 100')
    if len(d):
        for col,label,color in [('N','Knowledge N',purple),('AX_fit','Skilled augmentation',blue),
                                ('AL_fit','Unskilled augmentation',green)]:
            line(ax,100*d[col]/d[col].iloc[0],label,color)
    for ax in axes:
        handles,labels=ax.get_legend_handles_labels()
        if handles:
            ax.legend(fontsize=8,loc='best',frameon=True,facecolor='white',edgecolor='none',framealpha=.9)
    if not len(d):
        for ax in axes[-2:]:
            ax.text(.5,.5,'Diagnostic scenario infeasible',ha='center',transform=ax.transAxes)
    state=json.loads((out/'calibration_status.json').read_text())['status']
    fig.suptitle(f'US production calibration | {start}–{end}',fontsize=22,fontweight='bold',x=.065,ha='left',y=.979)
    fig.text(.065,.951,f'rho = {rho:g}  |  substitution elasticity = {1/rho:g}  |  baseline markup = {mu:g}  |  {len(p)} fitting years  |  {state}',fontsize=12)
    fig.text(.065,.929,'Solid red: baseline accounting implications. Dashed purple / panels K–L: separate higher-markup diagnostics.',fontsize=10,color=gray)
    fig.subplots_adjust(left=.065,right=.985,bottom=.072,top=.89,hspace=.43,wspace=.28)
    fig.text(.065,.030,'Sources: preserved September 2026 Fed/BEA and CPS mappings. All dates are used for fitting; no holdout remains.',fontsize=10)
    fig.text(.065,.014,'Negative baseline research is retained as a rejection diagnostic. Higher-markup fitted paths are not accepted calibration estimates.',fontsize=10,color=red)
    for ext in ['png','pdf','svg']:
        fig.savefig(dest/f'calibration_overview.{ext}',dpi=180)
    plt.close(fig)
    series=p.copy()
    if len(d):
        extra=d[['year','phi','I','a_implied','G_a','G_Q_diagnostic','N','AX_fit','AL_fit','Q_free_entry_fit']]
        extra=extra.rename(columns={c:'diagnostic_'+c for c in extra if c!='year'})
        series=series.merge(extra,on='year',validate='one_to_one')
    series.to_csv(out/'figure_series.csv',index=False)
