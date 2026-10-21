"""Offline decomposition of the P1 rejection. No model or calibration is retuned.

Run with the same NumPy/pandas/matplotlib environment as the original calibration.
Amounts are trillion 2017 USD unless a column is explicitly a share or multiplier.
All counterfactual mappings below are diagnostics, not accepted replacements.
"""
import hashlib
import json
from pathlib import Path
import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
DO = HERE.parent
ROOT = DO.parents[2]
EMP = ROOT / 'Empirical_Data/Variable_mappings/Empirical_Mapping_Annual'
OUT = HERE / 'results'
MU = 1.61


def main():
    OUT.mkdir(exist_ok=True)
    p = pd.read_csv(DO/'results/baseline_panel.csv')
    p = p[p.year.between(1994, 2022)].copy()
    source = pd.read_csv(EMP/'data_final/empirical_moments_us_annual.csv')
    mids = ['NOS_US_AHP_TOTAL_CORP', 'I_US_BERD_RD_COMP',
            'WHWL_US_CPS_RAW_MEAN_HOURLY_COLLEGE_NONCOLLEGE',
            'H_US_COLLEGE_EQUIV_FTE_OBSERVED_HOURS',
            'L_US_NONCOLLEGE_FTE_OBSERVED_HOURS']
    selected = source[source.mapping_id.isin(mids) & source.year.between(1994,2022)].copy()
    assert not selected.duplicated(['mapping_id','year']).any()
    selected.to_csv(OUT/'additional_input_observations.csv', index=False)
    for mid in mids:
        s = selected[selected.mapping_id.eq(mid)].set_index('year').value
        p[mid] = p.year.map(s)
    p['BH'] = p.wH*p.H
    p['BL'] = p.wL*p.L
    p['NOS'] = p.NOS_US_AHP_TOTAL_CORP/1e6/p.deflator
    p['CFC_plus_production_taxes'] = p.Y-p.COMP-p.NOS
    p['Y_net_factor_cost'] = p.COMP+p.NOS
    p['labor_share'] = p.COMP/p.Y
    p['skilled_comp_share'] = p.BH/p.COMP
    p['phi_gross'] = (p.Y-p.BL)/(MU*p.BH)
    p['phi_net_factor_cost'] = (p.Y_net_factor_cost-p.BL)/(MU*p.BH)
    p['phi_net_factor_mu1_84'] = (p.Y_net_factor_cost-p.BL)/(1.84*p.BH)
    p['phi_all_skilled_lower_bound'] = p.Y/(MU*p.COMP)
    p['skilled_share_required_boundary'] = (p.Y/p.COMP-1)/(MU-1)
    p['required_output_cost_boundary'] = p.Y-p.COMP-(MU-1)*p.BH
    p['required_output_cost_boundary_shareY'] = p.required_output_cost_boundary/p.Y
    p['cfc_tax_shareY'] = p.CFC_plus_production_taxes/p.Y
    p['remaining_cost_after_cfc_tax'] = p.NOS-(MU-1)*p.BH
    p['remaining_cost_after_cfc_tax_shareY'] = p.remaining_cost_after_cfc_tax/p.Y
    p['compensation_multiplier_boundary'] = p.Y/(p.COMP*(1+(MU-1)*p.skilled_comp_share))
    # Adjusted hourly premium is a counterfactual wage index, not an actual bill.
    # The raw/hour and FTE alternatives below remain proxies, not exact wage bills.
    for name, h, l, prem in [
        ('raw_premium_headcount',p.H,p.L,p.WHWL_US_CPS_RAW_MEAN_HOURLY_COLLEGE_NONCOLLEGE),
        ('raw_premium_observed_FTE',p.H_US_COLLEGE_EQUIV_FTE_OBSERVED_HOURS/1e6,
         p.L_US_NONCOLLEGE_FTE_OBSERVED_HOURS/1e6,p.WHWL_US_CPS_RAW_MEAN_HOURLY_COLLEGE_NONCOLLEGE)]:
        bh = p.COMP*prem*h/(prem*h+l)
        p['phi_'+name] = (p.Y-p.COMP+bh)/(MU*bh)
    # Ird is a mapped R&D employee-compensation proxy, not literal founder IPO income.
    p['Ird_proxy'] = p.I_US_BERD_RD_COMP/1000/p.deflator
    p['phi_rd_payroll_proxy'] = 1-p.Ird_proxy/p.BH
    p['cost_required_with_rd_gross_shareY'] = (p.Y-p.BL-MU*(p.BH-p.Ird_proxy))/p.Y
    p['cost_required_with_rd_net_shareY'] = (p.Y_net_factor_cost-p.BL-MU*(p.BH-p.Ird_proxy))/p.Y
    # Additional very restrictive timing bridge J_RD=Ird, not an accepted mapping.
    p['cost_required_with_rd_net_and_J_equals_I_shareY'] = (
        p.Y_net_factor_cost-p.Ird_proxy-p.BL-MU*(p.BH-p.Ird_proxy))/p.Y
    p['markup_implied_rd_gross'] = (p.Y-p.BL)/(p.BH-p.Ird_proxy)
    p['markup_implied_rd_net'] = (p.Y_net_factor_cost-p.BL)/(p.BH-p.Ird_proxy)
    p['I_implied_after_self_consistent_RD_capitalization'] = (
        p.BH-(p.Y-p.BL)/MU)/(1-1/MU)
    # Algebra checks: independent coordinates of the original rejection and bridge.
    np.testing.assert_allclose(p.phi_gross, (1+(p.Y/p.COMP-1)/p.skilled_comp_share)/MU)
    np.testing.assert_allclose(p.Y, p.COMP+p.NOS+p.CFC_plus_production_taxes)
    np.testing.assert_allclose(p.phi_gross-p.phi_net_factor_cost,
                               p.CFC_plus_production_taxes/(MU*p.BH))
    np.testing.assert_allclose(p.required_output_cost_boundary,
                               p.CFC_plus_production_taxes+p.remaining_cost_after_cfc_tax)
    assert (p.I_implied_after_self_consistent_RD_capitalization < 0).all()
    assert p.year.tolist() == list(range(1994,2023))
    p.to_csv(OUT/'annual_decomposition.csv',index=False)
    p[p.year.isin([1994,2007,2016,2022])].to_csv(OUT/'selected_years.csv',index=False)
    p[p.Ird_proxy.notna()].to_csv(OUT/'rd_payroll_diagnostic.csv',index=False)
    comparisons=[]
    for col, label in [('phi_gross','Original gross GVA, mu=1.61'),
                       ('phi_net_factor_cost','Remove CFC and production taxes, mu=1.61'),
                       ('phi_net_factor_mu1_84','Remove CFC and production taxes, mu=1.84'),
                       ('phi_raw_premium_headcount','Gross GVA, raw hourly premium, headcounts'),
                       ('phi_raw_premium_observed_FTE','Gross GVA, raw hourly premium, observed-hours FTE')]:
        s=p[col]
        comparisons.append(dict(scenario=label,column=col,phi_min=float(s.min()),phi_max=float(s.max()),
                                n_interior=int(((s>0)&(s<1)).sum()),n_years=len(p)))
    pd.DataFrame(comparisons).to_csv(OUT/'mapping_comparison.csv',index=False)
    conversion=[]
    for share in [0.,.3,.4,.45,.5]:
        mu_va=(1-share)/(1/MU-share)
        # Cost-minimizing CRS example: gross revenue=1, materials=share.
        primary_cost=1/MU-share
        np.testing.assert_allclose((1-share)/primary_cost,mu_va)
        conversion.append(dict(gross_output_markup=MU,materials_revenue_share=share,
                               effective_value_added_markup=mu_va,
                               status='illustration_only_not_a_measured_US_mapping'))
    pd.DataFrame(conversion).to_csv(OUT/'markup_basis_illustration.csv',index=False)
    summary=dict(
        source_vintage='preserved September 2026 snapshot; no revised numerical series downloaded',
        sample='1994-2022',markup=MU,rows=len(p),
        original_phi_range=[float(p.phi_gross.min()),float(p.phi_gross.max())],
        net_factor_cost_phi_range=[float(p.phi_net_factor_cost.min()),float(p.phi_net_factor_cost.max())],
        original_gap_shareY_mean=float(p.required_output_cost_boundary_shareY.mean()),
        cfc_plus_taxes_shareY_mean=float(p.cfc_tax_shareY.mean()),
        share_of_total_real_accounting_gap_covered_by_cfc_tax=float(p.CFC_plus_production_taxes.sum()/p.required_output_cost_boundary.sum()),
        remaining_gap_shareY_mean=float(p.remaining_cost_after_cfc_tax_shareY.mean()),
        compensation_multiplier_range=[float(p.compensation_multiplier_boundary.min()),float(p.compensation_multiplier_boundary.max())],
        years_infeasible_even_all_pay_to_skilled=int((p.phi_all_skilled_lower_bound>=1).sum()),
        RD_proxy_years=int(p.Ird_proxy.notna().sum()),
        RD_proxy_phi_range=[float(p.phi_rd_payroll_proxy.min()),float(p.phi_rd_payroll_proxy.max())],
        note='Accounting diagnosis only. CFC+tax removal and material-markup conversion are not accepted model recalibrations.')
    (OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    manifest=[]
    for f in [DO/'results/baseline_panel.csv',EMP/'data_final/empirical_moments_us_annual.csv',
              ROOT/'AI_drafting/V6_production.tex',Path(__file__).resolve()]:
        manifest.append(dict(path=str(f.relative_to(ROOT)),sha256=hashlib.sha256(f.read_bytes()).hexdigest(),bytes=f.stat().st_size))
    pd.DataFrame(manifest).to_csv(OUT/'input_manifest.csv',index=False)
    make_figure(p)
    print(json.dumps(summary,indent=2))
    print(pd.DataFrame(comparisons).to_string(index=False))


def make_figure(p):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    plt.rcParams.update({'font.size':10,'axes.spines.top':False,'axes.spines.right':False})
    fig,ax=plt.subplots(1,2,figsize=(12,4.8))
    x=p.year.to_numpy()
    ax[0].plot(x,p.phi_gross.to_numpy(),color='#b04b43',lw=2,label='Corporate gross value added')
    ax[0].plot(x,p.phi_net_factor_cost.to_numpy(),color='#2f6486',lw=2,label='Net value added at factor cost')
    ax[0].axhline(1,color='black',ls='--',lw=1,label='Zero-research boundary')
    ax[0].set(title='Removing depreciation and production taxes helps',ylabel='Implied skilled production share',xlabel='Year')
    ax[0].legend(loc='upper right',fontsize=8)
    ax[1].stackplot(x,100*p.cfc_tax_shareY.to_numpy(),100*p.remaining_cost_after_cfc_tax_shareY.to_numpy(),
                    labels=['CFC + production taxes less subsidies','Remaining gap after those deductions'],
                    colors=['#6c9caf','#dc9d64'],alpha=.85)
    ax[1].set(title='Decomposition of the cost gap at zero research',ylabel='Percent of original gross value added',xlabel='Year',ylim=(0,34))
    ax[1].legend(loc='lower center',fontsize=8)
    fig.suptitle('P1 diagnosis at markup 1.61: a mismatch of economic objects',fontweight='bold',fontsize=13)
    fig.text(.06,.027,'US 1994–2022 | Fixed September 2026 Fed/BEA + CPS snapshot | Diagnostic accounting changes; no recalibrated parameters',fontsize=8)
    fig.tight_layout(rect=(0,.07,1,.94))
    for ext in ['png','svg']:
        fig.savefig(OUT/('p1_decomposition.'+ext),dpi=160)
    plt.close(fig)


if __name__=='__main__':
    main()
