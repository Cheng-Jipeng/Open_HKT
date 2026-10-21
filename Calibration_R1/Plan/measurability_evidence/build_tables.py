#!/usr/bin/env python3
"""Build the standalone measurement audit from the reviewed 35-entry crosswalk.

No network requests. Raw MCP/API receipts are preserved in sibling folders.
Run from any directory with Python 3; then compile the .tex from Calibration_R1.
"""
from pathlib import Path
import csv
import json
import re
from collections import Counter

HERE = Path(__file__).resolve().parent
OUT = HERE.parent
ROWS = []

def add(n, symbol, kind, cls, readiness, judgment, sources, source_note):
    ROWS.append(dict(entry_id=f'M{n:02d}', core_entry=n, symbol=symbol,
        economic_category=kind, measurement_class=cls, mapping_readiness=readiness,
        mapping_and_judgment=judgment, source_ids=sources, source_note=source_note))

add(1, '$\\beta$', 'Parameter', 'L', 'Structural identification',
    'AHP calibrates its time-preference rate from an average dividend yield using its balanced-growth model. This is a structural restriction, not a measurement of V6 $\\beta$. National net saving/DPI differs from cohort asset acquisition/labor income $A/e_{US}$; select the OLG period and identify jointly.',
    ['AHP', 'S1'], 'AHP Sec. III, p. 2175; BEA saving and SCF data are supporting evidence, not a direct $\\beta$ series.')

add(2, r'$\gamma$', 'Parameter', 'L', 'Structural identification',
    r'Risk aversion in the specified continuation utility has no data column. Risk-attitude answers and realized returns can discipline a structural preference estimate, but neither equals this curvature. External estimates require a compatible utility specification and population.',
    ['S1','F2'], r'SCF questionnaire; CRSP returns via WRDS. Survey metadata and live return sample.')
add(3, r'$\kappa$', 'Parameter', 'L', 'Structural identification',
    r'Portfolio data discipline a return-wedge/target-deviation combination, not this preference curvature alone. A single equity share cannot separate $\kappa$ from $\bar\omega$, risk preferences and expectations. Requires allocation responses or explicitly imposed restrictions.',
    ['F2','F3'], r'CRSP returns; resident equity holdings. Neither source directly measures utility costs.')
add(4, '$\\bar\\omega,\\ \\bar\\omega^*$', 'Parameter', 'L', 'Preference centers',
    'AHP measures ownership fractions; V6 $\\bar\\omega,\\bar\\omega^*$ are preference centers. Measured actual portfolio weights (M22) help discipline these centers jointly with return wedges and curvature. Equating a preference center to observed home bias imposes an extra restriction.',
    ['AHP', 'F3'], 'AHP App. A4, pp. 2198--2199; source-backed ownership ratios cannot directly identify preference parameters.')

add(5, r'$\chi$', 'Parameter', 'L', 'Structural identification',
    r'A safe-asset spread or foreign Treasury share does not equal convenience utility. The model links $\chi$ jointly to holdings, marginal valuation and the safe-rate wedge; it also changes RoW saving. Currency, credit and duration differences in observed bonds must be separated from convenience.',
    ['F6','S1'], r'H.15/TB3MS and Treasury TIC holdings; household saving evidence. No exact $\chi$ series.')
add(6, r'$\eta$', 'Parameter', 'L', 'Structural identification',
    r'The coefficient scales a utility cost of the bond share, not observed underwriting fees or a resource cost. It needs joint identification from holdings and risk-adjusted return wedges. $\Upsilon(\theta)=-\log(1-\theta)+\theta^2/2$ is imposed by the code.',
    ['F2','F6','M1'], r'Equity returns, bond yields/positions; model first-order condition. Functional form is fixed.')
add(7, r'$\pi$', 'Parameter', 'L', 'Regime definition missing',
    r'Persistence becomes estimable only after an operational definition of $u/b$ and a period length. A recession indicator or a chosen 2008 date is not the model technology regime. An all-$u$ episode gives censored duration evidence, not a directly observed interior transition probability.',
    ['M1','P5'], r'No verified regime series. Productivity/investment histories are possible inputs to a future state rule.')

add(8, r'$H_i,\ L_i$', 'Parameter', 'D', 'Conditional: scope and units',
    r'Direct employment counts/hours exist for declared skill groups. Candidate: US CPS BA+ versus exhaustive non-BA; Eurostat tertiary versus non-tertiary, age 25--64. Adopt a common age, sector, headcount/FTE and country convention. Education as model skill is a maintained bridge; efficiency units remain I.',
    ['P1'], r'CPS ORG: local micro mapping. Eurostat \code{lfsa\_egaed}: live DE sample, annual thousand persons.')
add(9, r'$a_i$', 'Parameter', 'L', 'Structural identification',
    r'$a_i=(N_{i,t+1}/N_{i,t}-1)/[(1-\varphi_i)H_i]$ is conditional recovery, not direct measurement: neither knowledge varieties nor matched research labor is yet observed. Free-entry inversion uses the same valuation bridge. Separating $a_i$ from $a_iH_i$ needs the labor unit and model period.',
    ['P2','P3','P1'], r'MSTI/BERD research inputs; R\&D/patent stocks; labor quantities. Existing implied-$a$ series is a diagnostic.')
add(10, '$\\vartheta_i$', 'Parameter', 'L', 'Structural identification',
    'AHP infers its output wedge from valuations, capital and discounting; it does not directly observe V6 inverse markup $\\vartheta_i$. V6 recovery from profits and skilled production wages also needs $\\varphi_i$, sector alignment and treatment of taxes/capital. Profit shares are useful targets; the markup remains structurally identified.',
    ['AHP', 'F1', 'P4'], 'AHP Sec. III, pp. 2175--2176; IMA earnings/compensation and Compustat supply evidence.')

add(11, '$\\alpha_i$', 'Parameter', 'L', 'Normalization / identification',
    'AHP infers a Cobb--Douglas cost share conditional on its output wedge. V6 uses a different CES weight: levels depend jointly on $\\alpha_i A_{X,i}^{1-\\rho_i}$ and $(1-\\alpha_i)A_{L,i}^{1-\\rho_i}$. Observed labor shares do not separately identify that weight and augmentation scales.',
    ['AHP', 'P1', 'P4'], 'AHP Sec. III, p. 2176; measured labor shares are targets, not the V6 coefficient.')

add(12, r'$\rho_i$', 'Parameter', 'L', 'Structural identification',
    r'The elasticity is $1/\rho_i$. Identification needs relative-input/price variation and assumptions on markup and augmentation dynamics. A generic capital--labor elasticity is not automatically the intermediate-input/unskilled-labor elasticity used here. Both countries use CES in the solver.',
    ['P1','P4','M1'], r'Labor quantities/prices; production accounts; compatible external structural estimates.')
add(13, r'$\bar A_{X,US,u},\ \bar A_{L,US,u}$', 'Parameter', 'L', 'Structural identification',
    r'Factor-specific scale coefficients need a production inversion conditional on $\alpha,\rho,\vartheta$, knowledge normalization and output/input units. R\&D spending, sales per employee, and industry TFP do not measure these coefficients.',
    ['P1','P4','P5','F1'], r'Labor/production accounts and firm R\&D are ingredients. No verified direct augmentation series.')
add(14, r'$\bar A_{X,US,b},\ \bar A_{L,US,b}$', 'Parameter', 'L', 'Counterfactual restriction',
    r'Require measured absorbing-regime production with a justified state rule, or a counterfactual calibration restriction. An all-$u$ sample does not reveal absorbing productivity. Labeling a historical crash as $b$ does not establish the technology correspondence.',
    ['P4','M1'], r'Production histories plus an independently specified regime rule; currently no exact branch mapping.')
add(15, r'$\bar A_{X,W},\ \bar A_{L,W}$', 'Parameter', 'L', 'Structural identification',
    r'RoW augmentation scales need harmonized quantities, wages and output under the solver CES. A sector productivity ratio or a weighted country average is not either augmentation. Covered G4/OECD-ex-US panels are not the entire residual world.',
    ['P1','P4','P5'], r'Eurostat/OECD labor and institutional accounts. Matched RoW wage levels and scope remain gaps.')
add(16, r'$\xi_u,\ \nu_u$', 'Parameter', 'L', 'Structural identification',
    r'Elasticities of separately inferred augmentations with respect to a separately mapped knowledge stock. Relative wages alone cannot identify both. Defining $A_X=N^{\xi_u}$ and comparing that generated series to $N$ imposes the elasticity rather than measuring it.',
    ['P3','P1','P5'], r'Knowledge proxies and production evidence; no directly measured elasticity pair.')
add(17, r'$\nu_b=0,\ \xi_W=0$', 'Parameter', 'L', 'Imposed, not estimated',
    r'Known by construction in the chosen solver; not measurements of zero elasticities. Retain as maintained restrictions and test implications. Positive R\&D investment growth does not by itself reject zero factor augmentation. Reopening these coefficients changes the computational specification.',
    ['M1','P5'], r'\code{validate\_params} and zero-exponent restriction. R\&D investment is only contextual evidence.')

add(18, r'$N_{US,0},\ N_{W,0}$', 'Exogenous', 'I', 'Normalization / proxy',
    r'Setting initial knowledge to one is a normalization, not a measured level. A patent or R\&D-capital proxy requires office/residence, timing, depreciation and initial-stock conventions. Rebase only after these are fixed; normalized units do not remove the proxy gap.',
    ['P3'], r'Fed/BEA R\&D stocks; USPTO/OECD/WIPO patent alternatives in the local package.')
add(19, r'$z_t\in\{u,b\}$', 'Exogenous', 'L', 'Empirical state rule missing',
    r'Exogenous in the model does not mean observed in data. A switch date $\tau$ imposed in a simulation is a scenario. A documented empirical regime classifier would yield an inferred state (I); no accurate operational $u/b$ mapping is presently supplied.',
    ['M1'], r'Code path available; no verified empirical state series.')
add(20, r'$N_{i,t}$', 'Endogenous', 'I', 'Model state / proxy',
    r'The law of motion gives a model-implied path. R\&D-cost stocks and perpetual-inventory patent stocks are observable constructions but do not count model varieties. Their growth depends on valuation, depreciation, office coverage and initialization; preserve distinct proxy families.',
    ['P3'], r'Q4 R\&D stocks \code{FL105013465}, \code{FL795013465}; patent stock alternatives. Local evidence.')
add(21, r'$\varphi_{US,t},\ \varphi_{W,t}$', 'Endogenous', 'I', 'Research/skill bridge missing',
    r'Need $\varphi=1-R/H$ with research hours/persons a subset of the same skilled population. NRC$\cap H/H$ fixes the denominator but remains a task proxy: management/clinical work is not necessarily innovation. BERD/MSTI researcher or personnel FTE and headcount are different definitions.',
    ['P1','P2'], r'CPS/NRC and BERD/MSTI. Live OpenEcon researcher response rejected for wrong measure; OECD HTTP 403 retained.')
add(22, '$\\omega_t,\\ \\omega_t^*$', 'Endogenous', 'D/I', 'D: US weight; I: RoW scale gap',
    'Given an adopted operating-asset/equity perimeter, $\\omega=(V_{US}-E_L)/(V_{US}-E_L+E_A)$ is an accounting construction. $\\omega^*=E_L/(V_W-E_A+E_L)$ additionally needs the full RoW value. AHP observes $E_A$ without measuring $V_W$ directly. Its foreign ownership ratio $E_L/V_{US}$ is neither $\\omega^*$ nor $\\bar\\omega^*$.',
    ['AHP', 'F3', 'F7'], 'AHP App. A4, p. 2198; US EV and gross equity positions exist locally. Full-world denominator remains a gap.')

add(23, '$\\theta_{US,t}^*$; recovered $\\theta_t,\\theta_{W,t}^*$', 'Endogenous', 'I', 'Foreign wealth / safe-claim bridge',
    'AHP net non-equity accounts can anchor the numerator, but V6 foreign bond share needs matched RoW investable wealth. AHP App. A4 does not supply that denominator. Broad non-equity wealth is not automatically safe. Recovered US shares can be constructed after choosing that aggregation; $\\theta_W^*=0$ remains a model restriction.',
    ['AHP', 'F4', 'F6'], 'AHP Eq. (25) and Sec. III footnote 23; TIC holdings alone do not measure the portfolio denominator.')

add(24, '$R_{f,t},\\ R_{f,t}^W$', 'Endogenous', 'I', 'Real payoff / shadow yield',
    'AHP recovers its cost of capital through investment and current-account equations; this is model inference, not a directly observed V6 safe rate. A named bill yield is observable, but needs maturity, discount-quote and numeraire conversion. Ex-post deflation is not an ex-ante safe real payoff; the zero-supply RoW yield remains model implied.',
    ['AHP', 'F6'], 'AHP Sec. III, pp. 2175--2176; H.15/TB3MS observed through Aug 2026 in the saved probe.')

add(25, '$A_{X,i,t},\\ A_{L,i,t}$', 'Endogenous', 'I', 'Conditional production inversion',
    'AHP sets aggregate productivity growth to real corporate-output growth within its model. That rule does not measure V6 factor-specific $A_X,A_L$. Recover these only conditional on CES parameters and matched quantities/wages. Corporate GVA and labor shares can discipline the block without separately observing augmentations.',
    ['AHP', 'P1', 'P4'], 'AHP Sec. III, p. 2175; IMA/OECD output and compensation are usable inputs, not augmentation series.')

add(26, '$Y_{i,t}$', 'Endogenous', 'D', 'Measured output; scope condition',
    'Use the AHP residence-based corporate GVA aggregate: IMA S.5+S.6, with nonfinancial-only sensitivity; OECD S11+S12 for covered countries. GDP is a distinct denominator. Reconcile capitalized R\\&D with V6 $Y=e+\\mathcal D-\\mathcal I$. AHP estimates Canadian/Japanese corporate GVA through a share proxy; those country estimates remain I.',
    ['AHP', 'P4', 'P5'], 'AHP App. A2/A5, pp. 2194--2200. Saved US GVA construction reproduced for 36 annual observations.')

add(27, r'$w_{H,i,t},\ w_{L,i,t}$', 'Endogenous', 'D/I', 'D: US earnings; I: RoW levels gap',
    r'US mean earnings per compatible labor unit and skill group are direct candidates. Earnings exclude benefits; median weekly wages are not mean hourly compensation. Corporate-compensation scaling is I. Current RoW relative-earnings panels do not supply matched wage levels, so that component remains I/gap.',
    ['P1','P4'], r'US CPS ORG micro wages; BLS wage sensitivities. OECD EAG ratios and Eurostat labor quantities: local mappings.')
add(28, '$e_{i,t}$', 'Endogenous', 'D', 'Measured compensation; population condition',
    'AHP directly constructs corporate labor compensation. The same IMA/OECD employee-compensation aggregate is a usable counterpart to $e=w_HH+w_LL$ after adopting a common population and labor-income boundary. It need not be inferred from equilibrium or first reconstructed from skill wages. This does not separately measure skill wages or OLG saving propensity.',
    ['AHP', 'P4', 'P1'], 'IMA FU106025005+FU796025005; OECD D1, S11+S12. Saved US compensation reproduced for 36 years.')

add(29, '$q_{i,t},d_{i,t}$; reconstructed $R_{i,t+1}$', 'Endogenous', 'D/I', 'D: price/yield moments; I: levels',
    'AHP Eq. (3) gives observed revaluation returns $G_t/E_{t-1}$ and a chained price index. App. A4 constructs foreign cash-dividend yield from receipts divided by lagged holdings plus revaluation. These are direct accounting moments with scope/FX qualifications. Absolute per-variety $q,d$ still need $N$; total return needs matched payouts.',
    ['AHP', 'F3', 'F5', 'F8'], 'App. A4, pp. 2198--2199. New exact NIPA dividend probe supports 10 quarterly yield observations; see timing formulas.')

add(30, '$\\mathcal Q_{i,t},\\ \\mathcal D_{i,t}$', 'Endogenous', 'D/I', 'D: EV/FCF targets; I: payout bridge',
    'AHP enterprise value and FCF are directly constructed and legitimate targets under its fully equity-financed operating-asset convention. This can guide V6 $\\mathcal Q,\\mathcal D$. However, V6 pays incumbent profits while IPO proceeds fund new varieties. Reconcile net investment/issuance before equating AHP FCF to $\\mathcal D$; retain equity-capitalization and earnings alternatives.',
    ['AHP', 'F7', 'P4'], 'AHP Sec. I, Eq. (13), App. A2--A5. US EV/FCF replicated locally; RoW country panels have coverage/sign qualifications.')

add(31, '$q_{W,t}n_{W,t}$, $q_{US,t}n_{US,t}^*$', 'Endogenous', 'D', 'Measured external equity positions',
    'AHP observes US equity assets abroad $E_A$ and foreign equity in the US $E_L$ directly from IMA positions. V6 can use these aggregate values without observing claim counts or the full RoW equity market. Match residence, portfolio/FDI/fund scope, timing and currency. Claim counts remain inferred only if needed separately.',
    ['AHP', 'F3'], 'App. A1: historical S.9 lines 153/125. Exact FRED ROWEISQ027S / ROWEINQ027S already saved.')

add(32, '$b_t=\\theta_tA_t$', 'Endogenous', 'D/I', 'D: net non-equity; I: safe-bond interpretation',
    'AHP constructs $b^{NE}=NFA-E_A+E_L$ directly from positions. The CA-closing non-equity flow $F^{NE}=CA-(P_A-P_L)$ is also observable arithmetic. It need not equal $\\Delta b^{NE}$ because valuation/other changes intervene. Using either as V6 $b$ or $\\Delta b$ requires a stated single-bond aggregation; no latent parameter is needed for the empirical residual.',
    ['AHP', 'F3', 'F4'], 'App. A1 and Eq. (25); both residual constructions are available in AHP\\_NFA. Preserve stock-versus-flow distinction.')

add(33, '$NFA_t$', 'Endogenous', 'D', 'Measured NFA / changes',
    'US NFA is external assets minus liabilities, or negative ROW net worth. This is an observed accounting target and is used in Notebook 06. Sector/instrument omissions concern model fit and accounting correspondence, not whether NFA can be measured. Keep the chosen empirical perimeter and GVA denominator fixed.',
    ['AHP', 'F4'], 'App. A1; ROWTLEQ027S-ROWTASQ027S = -ROWNETQ027S. Saved observations and period targets independently rechecked.')

add(34, '$VA_t^{asset},\\ VA_t^{liability}$; $VA_t$', 'Endogenous', 'D', 'Measured equity revaluations',
    'AHP takes gross equity revaluations from IMA and sums them with the US-liability minus sign. V6 can target $VA^{asset},VA^{liability},VA^{eq}$ without separately identifying $n$ and $q$. FX, fund coverage and non-equity valuation belong in the mapping conditions; observed valuation is not an independently measured bubble component.',
    ['AHP', 'F5', 'F3'], 'App. A1: historical S.9 lines 100/84; FR263181105 and negative FR263081115 in the saved notebook. Broad-fund alternative retained.')

add(35, '$CA_t,\\ \\Delta NFA_t$', 'Endogenous', 'D', 'Measured CA and NFA change',
    'AHP defines $CA=-\\mathrm{RWLBACQ027S}/4$ and differences observed NFA. These are direct accounting targets, as in Notebook 06. Retain total/non-equity valuation and the residual in empirical closure. The model identity $\\Delta NFA=CA+VA^{eq}$ is a restriction to assess, not a reason to classify the data as indirectly measured.',
    ['AHP', 'F4', 'F5'], 'App. A1, p. 2193; exact saved 2008Q1--2023Q3 target reconstruction. Corporate-GVA normalization matches each notebook vintage.')


SOURCES = [
 dict(id='AHP', title='Atkeson, Heathcote and Perri (2025)', status='User-supplied published-paper transcription reviewed, 23 September 2026',
      description=r'\emph{The End of Privilege}, AER 115(7), 2151--2206. Sec. I and Eqs. (1)--(3): measured external accounts. Sec. III, pp. 2174--2176: data construction followed by model identification. App. A1--A5, pp. 2192--2200: exact measurement conventions. Local reference: \code{Codes/Reference/Atkeson\_2025\_End\_of\_Privilege.tex}. Journal page numbers, not recompiled pages, are used here. Separate Supplemental Appendix and author workbook were not obtained; present data retain their own vintages.',
      links=[('Published article','https://doi.org/10.1257/aer.20230732'),('Author data repository','https://doi.org/10.3886/E209797V1')]),
 dict(id='S1', title='Household saving and preferences', status='Official metadata checked; no new SCF microdata',
      description=r'BEA defines personal saving relative to disposable personal income; SCF collects family assets, debts, income and attitudes. These observations do not directly identify the model utility coefficients.',
      links=[('BEA saving definition','https://www.bea.gov/news/pio-release-additional-information'),('SCF public data','https://www.federalreserve.gov/econres/scfindex.htm'),('SCF questionnaire','https://www.federalreserve.gov/econres/files/scfoutline.2022.pdf')]),
 dict(id='P1', title='Skill labor and wages', status='Local CPS/EAG panels; live Eurostat sample and metadata',
      description=r'US CPS ORG local baseline: private-for-profit employees,1994--2024, BA+ versus exhaustive non-BA, headcount or matched-hours FTE. Eurostat \code{lfsa\_egaed}: annual thousand persons, sex T, age Y25-64, ED5-8/ED0-2/ED3\_4. Local RoW earnings ratios do not establish wage levels.',
      links=[('BLS definitions','https://www.bls.gov/cps/definitions.htm'),('LFS metadata','https://ec.europa.eu/eurostat/cache/metadata/en/lfsa_esms.htm'),('Exact DE API sample','https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/lfsa_egaed?lang=en&freq=A&unit=THS_PER&sex=T&age=Y25-64&isced11=ED5-8&geo=DE&sinceTimePeriod=2021&untilTimePeriod=2023')]),
 dict(id='P2', title='Research labor', status='Local official data/primary metadata; live OECD route403',
      description=r'OECD MSTI v1.3: business researchers B\_RS or total personnel B\_TT, FTE versus persons. NCSES BERD2023 Tables50/52 cover domestic business employment/research personnel; current local R\&D FTE panel is2015--2023. Survey scope and numerator membership in H must match.',
      links=[('OECD MSTI','https://www.oecd.org/en/data/datasets/main-science-and-technology-indicators.html'),('BERD Table52','https://ncses.nsf.gov/pubs/nsf25354/assets/data-tables/tables/nsf25354-tab052.pdf')]),
 dict(id='P3', title='Knowledge proxies', status='Existing frozen mappings; no exact-variety observation',
      description=r'Fed/BEA Q4 R\&D net stocks FL105013465+FL795013465; investment-price deflator Y006RG3Q086SBEA is a sensitivity, not an official stock-volume index. USPTO grants, OECD triadic and WIPO applicant-residence stocks have distinct coverage, initialization and depreciation.',
      links=[('NFC R&D stock','https://fred.stlouisfed.org/series/BOGZ1FL105013465Q'),('Financial R&D stock','https://fred.stlouisfed.org/series/BOGZ1FL795013465Q')]),
 dict(id='P4', title='Corporate output, labor income and equity', status='Existing2026-09 mapping vintage; producer definitions checked',
      description=r'US GVA: FU106902501Q+FU796902505Q; compensation: FU106025005Q+FU796025005Q. OECD institutional accounts: B1G and D1 for S11+S12; F51 liabilities are a distinct equity alternative. Native currencies, market FX/PPP and end-period/flow timing are separate choices.',
      links=[('US corporate GVA component','https://fred.stlouisfed.org/series/BOGZ1FU106902501Q'),('OECD accounts','https://www.oecd.org/en/publications/national-accounts-of-oecd-countries_2221433x.html')]),
 dict(id='P5', title='R&D investment and accounting', status='Live Eurostat data; BEA primary definitions',
      description=r'Eurostat \code{nama\_10\_a64\_p5}: N1171G asset, P51G transaction, TOTAL industry; CP\_MNAC is current-price million national currency. BEA capitalizes R\&D; expenditure and GDP contributions are not innovation success or factor augmentation.',
      links=[('Exact DE R&D API sample','https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/nama_10_a64_p5?geo=DE&freq=A&nace_r2=TOTAL&asset10=N1171G&na_item=P51G&unit=CP_MNAC&sinceTimePeriod=2021&untilTimePeriod=2023'),('BEA capitalization','https://www.bea.gov/help/faq/1028')]),
 dict(id='F1', title='WRDS / Compustat firm accounts', status='Live OPTIONS and data,2026-09-22',
      description=r'\code{comp.funda}: gvkey001690/fyear2024,2 raw format variants,1 C/INDL/STD row after local selection. \code{comp.g\_funda}: intentionally capped3-row2024 pilot, not a complete or representative sample. Employee/R\&D/accounting fields do not give research/skill hours or model markups. API types alone do not certify units.',
      links=[('NA API','https://wrds-api.wharton.upenn.edu/data/comp.funda/'),('Global API','https://wrds-api.wharton.upenn.edu/data/comp.g_funda/'),('Producer/access overview','https://wrds-www.wharton.upenn.edu/pages/grid-items/introduction-compustat-part-1/')]),
 dict(id='F2', title='WRDS / CRSP security prices and returns', status='Live12-month2024 sample; metadata discrepancy retained',
      description=r'\code{crsp.msf}, PERMNO14593: prc,ret,retx,shrout,cfacpr,cfacshr. All12 unique2024 months returned. Source count said3 despite12 records; completeness was checked against the requested calendar. Security returns are observable, but do not identify a model variety or a national investor portfolio.',
      links=[('Monthly stock API','https://wrds-api.wharton.upenn.edu/data/crsp.msf/'),('CRSP product description','https://www.crsp.org/research__trashed/crsp-us-stock-databases/')]),
 dict(id='F3', title='International equity positions', status='Live exact FRED samples and Fed component definitions',
      description=r'US external equity assets: ROWEISQ027S/FL263181105; US equity liabilities: ROWEINQ027S/FL263081005. Quarterly end-period million USD. Current fund/FDI/international-organization coverage must be read from the component trees, not inferred from an old shorthand label.',
      links=[('Asset component tree','https://www.federalreserve.gov/apps/fof/SeriesAnalyzer.aspx?s=FL263181105&t='),('Liability component tree','https://www.federalreserve.gov/apps/fof/SeriesAnalyzer.aspx?s=FL263081005&t=')]),
 dict(id='F4', title='NFA, transactions and current account', status='Live samples2024Q1--2026Q2',
      description=r'US NFA=ROWTLEQ027S-ROWTASQ027S=-ROWNETQ027S, million USD. AHP App. A1 defines CA as negative ROW net lending/borrowing: -RWLBACQ027S/4. Retain this declared accounting convention and distinguish a separately selected balance-of-payments CA series. RWNEOWQ027S is ROW net-worth revaluation (US total VA is its negative); equity FU components are transactions. AHP retains statistical discrepancies and other-volume changes.',
      links=[('ROW net worth','https://fred.stlouisfed.org/series/ROWNETQ027S'),('ROW net lending','https://fred.stlouisfed.org/series/RWLBACQ027S')]),
 dict(id='F5', title='Equity revaluation and price/FX separation', status='Live scope discrepancy; current bridge unresolved',
      description=r'BOGZ1FR263181105Q, BOGZ1FR263081005Q and BOGZ1FR263081115Q are quarterly revaluations in million USD, not annualized transaction flows. BEA Concepts and Methods separates transactions, price/FX revaluation and other changes. Matching FR/FU/stock universes is required.',
      links=[('Broad liability FR','https://fred.stlouisfed.org/series/BOGZ1FR263081005Q'),('Legacy liability FR','https://fred.stlouisfed.org/series/BOGZ1FR263081115Q'),('BEA2026 methods,chs.8/24','https://www.bea.gov/sites/default/files/2026-06/BEA-International-Economic-Accounts-Concepts-and-Methods.pdf')]),
 dict(id='F6', title='Safe yields and Treasury holdings', status='Live series; Treasury coverage notes checked',
      description=r'TB3MS: monthly average3-month bill rate, percent at an annual discount-basis quote; saved through Aug2026. ROWTSEQ027S: quarterly foreign Treasury holdings. TIC Table5 includes multiple maturities and custody-based country attribution; it is not a model wealth denominator.',
      links=[('TB3MS','https://fred.stlouisfed.org/series/TB3MS'),('TIC Table5','https://ticdata.treasury.gov/Publish/slt_table5.html')]),
 dict(id='F7', title='Capitalization, operating-asset value and distributions', status='Live Fed alternatives; local AHP construction retained',
      description=r'AHP operating-asset values: LM102010405Q+LM792010405Q. FCF: (FU106402101+FU796402101)-(FU106220001+FU796220001)-(FU105050985+FU795015085), with BOGZ1 prefix and Q suffix. These FU inputs are quarterly million-USD flows, not SAAR. Gross-dividend alternatives FU106121001A+FU796121001A need consolidation. AHP justifies EV/FCF using financing neutrality; V6 additionally needs an entry/issuance cash-flow bridge.',
      links=[('Operating-asset value','https://fred.stlouisfed.org/series/BOGZ1LM102010405Q'),('NFC dividends','https://fred.stlouisfed.org/series/BOGZ1FU106121001A')]),
 dict(id='F8', title='Dividends received on foreign equity', status='Exact official CSV probe, 23 September 2026 local time',
      description=r'BEA NIPA Table 4.1 line 11; account B3375C; FRED B3375C1Q027SBEA. Quarterly billions of USD at SAAR: multiply by 1000/4 for a quarterly million-USD payout. The sample, ROWEISQ027S and FR263181105 yield 10 observations, 2024Q1--2026Q2. Excludes separately reported reinvested earnings. AHP App. A4 uses the monetary-payout yield; tax-repatriation spikes and instrument/currency coverage need explicit treatment. OpenEcon timed out; exact-source CSV succeeded.',
      links=[('Exact dividend series','https://fred.stlouisfed.org/series/B3375C1Q027SBEA'),('NIPA Table 4.1','https://fred.stlouisfed.org/release/tables?eid=5405&rid=53'),('BEA dividend concepts','https://www.bea.gov/help/faq/200')]),
 dict(id='M1', title='Model, prior crosswalk and workflow', status='Local source review; no baseline changes or new estimation',
      description=r'\code{V6\_calibration\_core.tex}; V6 manuscript; \code{TwoCountryProductionOLG.jl}; annual empirical mapping registry and method notes; FinAI \code{AGENTS.md}, SMU\_RESEARCH and SMU\_PROVIDERS. Source authority, access success and economic mapping are separate assessments.',
      links=[]),
]

def clean_prose(value):
    value = re.sub(r'(?<=[a-z])(?=20[0-9]{2}\b)', ' ', value)
    value = re.sub(r'\b(All|all|Live|Table|Tables|route|average|said)(?=\d)', r'\1 ', value)
    value = re.sub(r',(?=20[0-9]{2}\b)', ', ', value)
    return (value.replace('2024,2', '2024, 2').replace('variants,1', 'variants, 1')
            .replace('employees,1994', 'employees, 1994').replace('BEA2026', 'BEA 2026')
            .replace('methods,chs.', 'methods, chs. '))

for item in ROWS:
    for key in ['mapping_and_judgment', 'source_note', 'mapping_readiness']:
        item[key] = clean_prose(item[key])
for item in SOURCES:
    for key in ['title', 'status', 'description']:
        item[key] = clean_prose(item[key])
    item['links'] = [(clean_prose(label), url) for label, url in item['links']]

def refs(keys):
    return ', '.join(r'\hyperlink{src-'+k+r'}{\textbf{'+k+'}}' for k in keys)

def table(start, end):
    buf=[r'\begin{measuretable}']
    for r in ROWS[start-1:end]:
        marker=r'\textbf{D}$^\dagger$' if r['measurement_class']=='D' else r'\textbf{'+r['measurement_class']+'}'
        buf.append('% ENTRY: '+r['entry_id'])
        buf.append(r'\textbf{'+r['entry_id']+r'}\par '+r['symbol']+' & '+marker+r'\par '+r['mapping_readiness']+' & '+r['mapping_and_judgment']+' & '+refs(r['source_ids'])+r'\par '+r['source_note']+r'\\[4pt]')
    buf.append(r'\end{measuretable}')
    return '\n'.join(buf)

PREAMBLE = r'''% !TEX program = pdflatex
% Generated by measurability_evidence/build_tables.py; editable row data are in that script.
% Scope: all 35 entries of V6_calibration_core.tex, same order and grouping.
\documentclass[10pt,a4paper,landscape]{article}
\usepackage[T1]{fontenc}
\usepackage[utf8]{inputenc}
\usepackage{lmodern,amsmath,amssymb}
\usepackage[margin=14mm,headheight=14pt,headsep=6mm,footskip=8mm]{geometry}
\usepackage{array,longtable,booktabs,ragged2e,multicol}
\usepackage[table]{xcolor}
\usepackage{microtype,fancyhdr}
\usepackage[hidelinks,bookmarksnumbered]{hyperref}
\definecolor{heading}{RGB}{28,53,73}
\definecolor{tablehead}{RGB}{231,238,243}
\pagestyle{fancy}\fancyhf{}
\fancyhead[L]{\small\sffamily\color{heading}Two-country HKT: measurability audit}
\fancyhead[R]{\small\sffamily AHP revision: 23 September 2026}
\fancyfoot[C]{\thepage}
\renewcommand{\headrulewidth}{0.3pt}
\setlength{\parindent}{0pt}\setlength{\parskip}{5pt}
\setlength{\tabcolsep}{5pt}\setlength{\LTpre}{5pt}\setlength{\LTpost}{8pt}
\renewcommand{\arraystretch}{1.12}\setlength{\emergencystretch}{3em}
\newcolumntype{P}[1]{>{\raggedright\arraybackslash}p{#1}}
\newcommand{\code}[1]{{\footnotesize\texttt{#1}}}
\newenvironment{measuretable}{%
\fontsize{9.4}{10.8}\selectfont\setlength{\parskip}{1pt}
\begin{longtable}{@{}P{\dimexpr .14\textwidth-4.2pt\relax}P{\dimexpr .135\textwidth-4.05pt\relax}P{\dimexpr .455\textwidth-13.65pt\relax}P{\dimexpr .27\textwidth-8.1pt\relax}@{}}
\toprule\rowcolor{tablehead}\textbf{Core entry} & \textbf{Class / qualifications} & \textbf{Mapping and calibration use} & \textbf{Data source / verification}\\\midrule
\endfirsthead
\toprule\rowcolor{tablehead}\textbf{Core entry} & \textbf{Class / qualifications} & \textbf{Mapping and calibration use} & \textbf{Data source / verification}\\\midrule
\endhead\midrule\multicolumn{4}{r}{\footnotesize\itshape Continued on next page}\\\endfoot
\bottomrule\endlastfoot
}{\end{longtable}}
\hypersetup{pdftitle={Measurability of the 35 HKT calibration entries},pdfauthor={}}
\begin{document}
{\LARGE\sffamily\bfseries\color{heading}Measurability of the calibration entries}\par
{\large\sffamily Direct statistical counterparts, indirect constructions, and latent model quantities}\par

This revision assesses \textbf{all 35 grouped entries} in \code{V6\_calibration\_core.tex}, retaining their order and IDs. It follows AHP's distinction between constructing data and using a structural model to explain those data. Sources are the supplied AHP paper, the V6 equations and zero-exponent solver, existing empirical mappings, the 22 September API audit and a new foreign-dividend probe. Paper references use \emph{journal page numbers}.

\section*{Separate measurement from assumptions used in calibration}
\begin{longtable}{@{}P{.17\textwidth}P{.79\textwidth}@{}}
\toprule\rowcolor{tablehead}\textbf{Class} & \textbf{Meaning}\\\midrule
\textbf{D: directly measured} & Reported statistics and transparent accounting constructions: sums, differences, ratios, unit conversions and revaluation-based indexes. No HKT equilibrium or latent parameter is needed to construct the specified empirical target. D does not mean error-free; the dagger flags population, instrument, timing or numeraire conditions for applying it to V6.\\[5pt]
\textbf{I: indirect / model implied} & A model coordinate needs an unobserved input, a substantive proxy, a normalization or a structural inversion. A country-coverage approximation remains explicit. Ordinary subtraction or aggregation alone is not grounds for I, and a model-generated value is not independent evidence.\\[5pt]
\textbf{L: structurally latent} & No verified observation rule measures the preference, technology or regime construct. It requires joint structural identification, a compatible external estimate, or an explicitly imposed restriction. L does not mean dispensable or inherently unidentifiable.\\
\textbf{D/I: component split} & A grouped entry contains both directly measured targets and unresolved model coordinates or country components. This is not a fourth degree of measurability: the row identifies which component is D and which remains I.\\[5pt]
\bottomrule
\end{longtable}

\textbf{Assessment.} Seven families are classified D, six I, seventeen L, and five D/I. In particular, \textbf{M34 equity valuation and M35 CA/NFA changes are D}; M28 compensation is also D under an explicit population convention. M22 portfolio weights, M27 skill wages, M29 prices/dividends, M30 corporate value/cash flow and M32 bonds are split by their observable and unresolved components. These family counts do not imply that every country component is already collected.

\textbf{What AHP adds.} Residence-based corporate GVA, labor compensation, enterprise value/FCF, external positions, revaluations, flows and foreign monetary-dividend yields provide concrete calibration targets. Corporate financing neutrality is a legitimate maintained interpretation, as in AHP. V6's new-variety issuance, skill composition and research technology require additional accounting or structural work; accurate measured aggregates do not identify those primitive parameters by themselves.

\textbf{Verification.} The earlier WRDS/FRED/Eurostat receipts are preserved. This revision reproduces the saved AHP external accounts, 36 annual observations each of US GVA, compensation, EV and FCF, and a 10-quarter AHP-style foreign cash-yield sample. It revises the measurement assessment without re-estimating the model. AHP's separate Supplemental Appendix and original author workbook were not available in the supplied reference.
'''

BRIDGES = r'''
\clearpage
\section{Borrowing AHP's corporate measurement}\label{sec:bridges}
AHP first constructs accounting quantities, then selects parameter paths to reproduce them (Sec. III, pp. 2174--2176). The second step does not turn the first-step observations into latent variables. Equally, the availability of those observations does not make the inferred preference or technology parameters directly measured.

\begin{longtable}{@{}P{.17\textwidth}P{.38\textwidth}P{.41\textwidth}@{}}
\toprule\rowcolor{tablehead}\textbf{V6 entry} & \textbf{AHP construction} & \textbf{How it can be used here}\\\midrule
M26: output & Corporate GVA: historical IMA S.5+S.6; OECD S11+S12. Residence, rather than multinational headquarters, defines the economy. & Direct output/denominator candidate. Keep NIPA corporate GVA and the broader IMA financial-business aggregate as distinct alternatives. R\&D capitalization must agree with the V6 production boundary.\\[6pt]
M28: labor income & Compensation paid by the same corporate sectors, including employer contributions. & Direct aggregate-income candidate. Skill-specific wages and labor endowments are additional measurements; aggregate compensation need not wait for that decomposition. Literal age/cohort coverage remains a maintained bridge.\\[6pt]
M30: corporate value & AHP $V$ is the market value of operating/nonfinancial assets: equity plus other financing claims, less financial assets, with FDI/residence adjustments. & A legitimate candidate for an all-equity operating sector, rather than an invalid proxy merely because real firms issue debt. Retain shareholder-capitalization alternatives and use consistent claims in portfolio denominators.\\[6pt]
M30: corporate cash flow & $FCF=NOS-TAX-NCF=GOS-TAX-GCF$; AHP interprets this as dividends of fully equity-financed firms with no financial assets. & Directly constructed net-cash-flow target. The exact V6 payout correspondence needs an investment/issuance decision, since incumbent dividends and new-variety finance are separate in V6.\\[6pt]
RoW counterparts & AHP App. A5 uses OECD country accounts, with market-exchange-rate aggregation and a PPP sensitivity. Canadian/Japanese GVA is estimated using a corporate share proxy. & Covered-country panels support output, compensation, EV/FCF ratios and robustness comparisons. They do not constitute a directly measured full-world equity denominator. Preserve the OECD net-financial-worth sign as reported; any sign reversal needs its own mapping ID and balance-sheet check.\\
\bottomrule
\end{longtable}

\textbf{The substantive V6 cash-flow qualification.} AHP's corporate financing neutrality makes EV a defensible valuation target (Sec. I, pp. 2162--2164; footnotes 16, 18). V6 also has no corporate debt, but its date-$t$ entry financing obeys
\[
\mathcal Q_t=N_{t+1}q_t,\quad \mathcal D_t=N_td_t,\quad
\mathcal I_t=(N_{t+1}-N_t)q_t,\quad Y_t=e_t+\mathcal D_t-\mathcal I_t.
\]
Under the \emph{illustrative} national-accounts bridge $GVA=Y+\mathcal I$, compensation $=e$, gross investment $=\mathcal I$, and no taxes or other investment, AHP-style FCF is $\mathcal D-\mathcal I$, not $\mathcal D$. Thus the corresponding V6 payout would be $FCF+\mathcal I$. This is a conditional accounting derivation, not an empirical identity already established. Do not add capitalized R\&D to observed GVA twice or mechanically add measured R\&D spending to FCF without the required expenditure/issuance bridge.

\textbf{What does not transfer as direct measurement.} AHP's output wedge, cost-of-capital and production-share identification uses its own equations. Its $Q$ is an investment-goods price; its $H$ is human wealth; its $\rho$ is a time-preference rate. These are not V6 $\mathcal Q$, skilled labor $H$, or CES curvature $\rho$. AHP supplies useful moments but no direct observations of V6 innovation productivity, variety stocks, factor augmentations, skill-specific research shares or preference centers.

\clearpage
\section{AHP ownership, prices and income yields}
\textbf{Observed ownership is different from an investor's portfolio weight.} Write $E_A$ for US external equity assets and $E_L$ for US external equity liabilities. AHP App. A4 measures issuer ownership $1-\lambda=E_L/V_{US}$. Under an adopted operating-asset/equity universe, V6 investor portfolio weights instead satisfy
\[
\omega=\frac{V_{US}-E_L}{V_{US}-E_L+E_A},\qquad
\omega^*=\frac{E_L}{V_W-E_A+E_L}.
\]
The US ratio can be constructed from measured aggregates under the same perimeter. The RoW ratio needs $V_W$. AHP explicitly does \emph{not} directly measure full RoW enterprise value in App. A4; it uses US foreign holdings and their payout yield. Accordingly, neither its ownership share nor an EU/G6 approximation automatically supplies V6 $\omega^*$, and neither identifies a preference center.

\textbf{AHP's foreign-yield route avoids the full-world denominator.} Let $G^A_t$ be positive-signed revaluation of US-held foreign equity and $C^A_t$ monetary dividend receipts on that same basket. AHP Eq. (3) and App. A4 motivate the observable constructions
\[
g^{q,A}_t=\frac{G^A_t}{E_{A,t-1}},\qquad
P^A_t=P^A_{t-1}(1+g^{q,A}_t),\qquad
y^{cash,A}_t=\frac{C^A_t}{E_{A,t-1}+G^A_t}.
\]
Under matched holdings, payouts and the V6 homogeneous-claim interpretation, the last ratio corresponds to $d_{W,t}/q_{W,t}$. A corresponding cash total-return construction is $1+(G^A_t+C^A_t)/E_{A,t-1}$, subject to within-period timing and instrument coverage. Absolute per-variety prices and dividends remain unobserved. Moreover, $\mathcal D_{i,t}/\mathcal Q_{i,t}=(N_{i,t}/N_{i,t+1})(d_{i,t}/q_{i,t})$: the per-variety yield is not the aggregate yield when new varieties enter.

\textbf{New source check.} NIPA Table 4.1 line 11 is FRED \code{B3375C1Q027SBEA}; quarterly monetary receipts in million USD equal the published billion-USD SAAR value times $1000/4$. The exact-source probe gives ten usable quarters, 2024Q1--2026Q2. The 2026Q2 AHP-style cash yield is 2.487\% at a simple annual rate (0.622\% for the quarter). This is a monetary-yield candidate, not a measure of reinvested earnings or a guarantee of matched V6 payouts. Tax-driven repatriation spikes and currency/instrument scope remain explicit.

\textbf{The external-account targets are measured.} App. A1 retains
\[
\Delta NFA=CA+VA^{eq}+VA^{non\text{-}eq}+RES.
\]
The saved 2008Q1--2023Q3 moments, divided by endpoint corporate GVA, reproduce Notebook 06:
\[
-1.023669=(-0.521721)+(-0.671568)+0.087168+0.082452.
\]
The terms are NFA change, CA, equity VA, non-equity VA and the residual, respectively. Residual closure is algebraic, not an independent model-fit test. The liability price-index construction still needs the documented fund-coverage reconciliation between the broad stock and narrower revaluation series; this affects the precise index choice, not the observability of the reported revaluation itself.
'''

LIVE = r'''
\clearpage
\section{Preserved API audit and revision evidence}
\begin{longtable}{@{}P{.22\textwidth}P{.72\textwidth}@{}}
\toprule\rowcolor{tablehead}\textbf{Route / sample} & \textbf{Verified result and interpretation}\\\midrule
WRDS: Compustat NA & \code{comp.funda}, gvkey001690/fyear2024 returned2 formats. Exactly1 row is C/INDL/STD; the other is SUMM\_STD. R\&D, employee, payout and cash-flow fields exist in the standard row. This confirms a firm-level route, not national research/skill quantities. Duplicate-format summation would be wrong.\\[6pt]
WRDS: Compustat Global & \code{comp.g\_funda}, fyear2024 returned an intentionally capped3-row pilot;42,376 matching rows were advertised. \textbf{The pilot is incomplete and not representative.} No complete Global panel, growth trend or aggregate moment was inferred.\\[6pt]
WRDS: CRSP & \code{crsp.msf}, PERMNO14593 returned all12 unique months of2024 with price, distribution-inclusive/exclusive return and adjustment fields. The provider count reported3 despite12 returned records. Calendar/identifier validation established the bounded sample; the inconsistent metadata were preserved. This does not certify coverage of all securities or a current national index.\\[6pt]
Exact FRED / Fed data & 19 exact series:16 quarterly through2026Q2, TB3MS through Aug2026 and2 annual dividend series through2025. The request window began in2024. Dates are unique/sorted; the NFA identity holds exactly in all10 sampled quarters. These are saved-sample dates, not a claim about full source histories.\\[6pt]
Exact Eurostat: labor & \code{lfsa\_egaed}, DE, age25--64, both sexes, ED5-8, THS\_PER: 12,543.1; 12,708.1; 13,052.0 thousand employed persons in2021--23. The2021 break flag is preserved. This directly measures tertiary employment, not corporate skill efficiency or research labor.\\[6pt]
Exact Eurostat: R\&D & \code{nama\_10\_a64\_p5}, DE, TOTAL, N1171G, P51G, CP\_MNAC: 105,966; 110,894; 124,513 million national currency in2021--23. The2022--23 provisional flags are preserved. This is an investment flow, not knowledge varieties, innovation success or $A_X$.\\[6pt]
OpenEcon: 22 September & Requested exact ROWEISQ027S, received FL263164100Q: the2026Q2 values differ by11,305,117 million USD. Requested MSTI business researchers B\_RS/FTE, received G+T\_RS URLs and generic units. Both responses contained numbers; both were rejected for these mappings. Direct exact-source probes supplied the usable evidence.\\[6pt]
Failed routes retained & The exact OECD MSTI direct request returned HTTP 403; earlier saved OECD data remain separately labeled. Initial network/time-out routes and unsuccessful candidate endpoints are logged. Failure of a route is not evidence that the economic series does not exist.\\
\bottomrule
\end{longtable}

\textbf{Reproducible package.} \code{measurability\_evidence/} contains immutable-for-this-audit raw samples, request/response receipts, source IDs/URLs, flags, validation summaries and the classification CSV/JSON. WRDS metadata are in \code{wrds/tool\_receipts.json}; official probes and rerun scripts are under \code{production/} and \code{external/}. The AHP revision adds three exact-source CSVs, a ten-quarter monetary-yield probe, and offline verification of saved corporate/external mappings under \code{ahp\_revision\_2026-09-23/}. Its OpenEcon request timed out; the receipt is retained. The PDF is rebuilt by \code{build\_tables.py} plus LaTeX. A rerun can receive revised source data; retain this dated snapshot when changing vintages. No model solve, parameter estimation, bulk historical refresh or change to the earlier mappings was performed.
'''

assert [r['core_entry'] for r in ROWS] == list(range(1,36))
assert Counter(r['measurement_class'] for r in ROWS)=={'D':7,'I':6,'L':17,'D/I':5}
assert set(k for r in ROWS for k in r['source_ids']) <= {s['id'] for s in SOURCES}

parts=[PREAMBLE,
    r'\clearpage\section{Parameters: saving, portfolios and regime risk}',table(1,7),
    r'\clearpage\section{Parameters: production and knowledge}',table(8,17),
    r'\clearpage\section{Exogenous inputs}',table(18,19),
    r'\section{Endogenous states and equilibrium choices}',table(20,24),
    r'\clearpage\section{Endogenous production and valuation}',table(25,30),
    r'\clearpage\section{External positions, valuation and flows}',table(31,35),
    BRIDGES,LIVE,
    r'\clearpage\section{Data-source and verification ledger}',
    r'\small Source keys used in the tables are defined below. Live sample dates identify the data actually retrieved; local panels retain their earlier vintage. URLs point to the producer or authenticated data endpoint. The accompanying source ledger records the full descriptions.',
    r'\begin{multicols}{2}\raggedright']
for s in SOURCES:
    parts.append(r'\noindent\begin{minipage}{\linewidth}\raggedright')
    parts.append(r'\hypertarget{src-'+s['id']+r'}{\textbf{'+s['id']+'. '+s['title'].replace('&',r'\&')+r'}}\par')
    parts.append(r'{\footnotesize\itshape '+s['status']+r'.}\par')
    parts.append(s['description'])
    if s['links']:
        parts.append(r'\par '+r'; '.join(r'\href{'+u+'}{'+t.replace('&',r'\&')+'}' for t,u in s['links'])+'.')
    parts.append(r'\end{minipage}\par\vspace{6pt}')
parts.extend([r'\end{multicols}',r'\end{document}'])

text='\n\n'.join(parts)
# Keep number-word spacing explicit in prose without altering identifiers/URLs.
for old,new in [('the35','the 35'),('all35','all 35'),('conditional;13','conditional; 13'),
                ('construction;17','construction; 17'),('samples,19','samples, 19'),
                ('all10','all 10'),('in2026','in 2026'),('are3,','are 3,'),('and3,','and 3,'),
                ('returned2','returned 2'),('Exactly1','Exactly 1'),('capped3-row','capped 3-row'),
                (';42,376','; 42,376'),('all12','all 12'),('of2024','of 2024'),
                ('reported3','reported 3'),('despite12','despite 12'),('series:16','series: 16'),
                ('through2026','through 2026'),('and2 annual','and 2 annual'),('through2025','through 2025'),
                ('in2024','in 2024'),('age25','age 25'),('in2021','in 2021'),
                ('The2021','The 2021'),('The2022','The 2022'),('the2026','the 2026'),
                ('by11,','by 11,'),('months of2024','months of 2024'),
                ('Notebook06','Notebook 06'), ('gvkey001690','gvkey 001690'), ('PERMNO14593','PERMNO 14593'), ('fyear2024','fyear 2024'), ('BERD2023','BERD 2023'), ('Tables50/52','Tables 50/52'), ('age25','age 25'), ('Aug2026','Aug 2026'), ('samples2024','samples 2024'), ('Live12-month2024','Live 12-month 2024'), ('returned12','returned 12'), ('million national currency in2021','million national currency in 2021')]:
    text=text.replace(old,new)
assert not any(ord(c)<32 and c not in '\n\r' for c in text), 'Unexpected control character in LaTeX'
(OUT/'V6_calibration_measurability.tex').write_text(text)
(HERE/'measurability_rows.json').write_text(json.dumps(ROWS,ensure_ascii=False,indent=2)+'\n')
(HERE/'source_ledger.json').write_text(json.dumps(SOURCES,ensure_ascii=False,indent=2)+'\n')
with (OUT/'V6_calibration_measurability.csv').open('w',newline='') as f:
    fields=list(ROWS[0])
    w=csv.DictWriter(f,fieldnames=fields);w.writeheader()
    for row in ROWS:w.writerow({**row,'source_ids':';'.join(row['source_ids'])})
print(f'Built {len(ROWS)} entry rows, {len(SOURCES)} source groups; classes:',dict(Counter(r['measurement_class'] for r in ROWS)))
