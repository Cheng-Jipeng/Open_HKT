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

add(1, r'$\beta$', 'Parameter', 'L', 'Structural identification',
    r'No accurate direct mapping. BEA personal saving/disposable income is aggregate net saving; $\beta=A/e_{US}$ concerns cohort asset acquisition/labor income, including purchases from the old. SCF wealth/income is not that flow either. Identify jointly after choosing the OLG period and the asset/income boundary.',
    ['S1'], r'BEA NIPA saving; SCF assets, income and saving questions. Metadata verified; contextual evidence only.')
add(2, r'$\gamma$', 'Parameter', 'L', 'Structural identification',
    r'Risk aversion in the specified continuation utility has no data column. Risk-attitude answers and realized returns can discipline a structural preference estimate, but neither equals this curvature. External estimates require a compatible utility specification and population.',
    ['S1','F2'], r'SCF questionnaire; CRSP returns via WRDS. Survey metadata and live return sample.')
add(3, r'$\kappa$', 'Parameter', 'L', 'Structural identification',
    r'Portfolio data discipline a return-wedge/target-deviation combination, not this preference curvature alone. A single equity share cannot separate $\kappa$ from $\bar\omega$, risk preferences and expectations. Requires allocation responses or explicitly imposed restrictions.',
    ['F2','F3'], r'CRSP returns; resident equity holdings. Neither source directly measures utility costs.')
add(4, r'$\bar\omega,\ \bar\omega^*$', 'Parameter', 'L', 'Structural identification',
    r'These are preference centers, not realized home bias. Observed US-equity portfolio weights identify the actual allocation only. Setting the centers equal to observed weights is an additional restriction on risk-adjusted return wedges, not direct measurement.',
    ['F3'], r'Fed international equity positions; domestic equity accounts needed for denominators. TIC/IMF PIP supplementary.')
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
add(10, r'$\vartheta_i$', 'Parameter', 'L', 'Structural identification',
    r'The inverse monopoly markup is not an accounting gross margin or dividend share. An inversion using $w_H\varphi H$ and model profit $\mathcal D$ requires the same production sector and treatment of physical capital, fixed costs, taxes and retention. Firm accounts supply ingredients, not the markup itself.',
    ['F1','P4','P1'], r'Compustat expenses/sales; corporate accounts; wages. WRDS access confirmed; no direct markup field.')
add(11, r'$\alpha_i$', 'Parameter', 'L', 'Normalization and identification',
    r'Not an observed labor-income share. CES levels depend on $\alpha_i A_{X,i}^{1-\rho_i}$ and $(1-\alpha_i)A_{L,i}^{1-\rho_i}$. Separating distribution weights from augmentation scales requires normalization and structural restrictions; downloading factor shares does not resolve this.',
    ['P1','P4'], r'Employment, wages and corporate accounts are joint calibration evidence.')
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
add(22, r'$\omega_t,\ \omega_t^*$', 'Endogenous', 'I', 'Portfolio-universe bridge',
    r'Construct actual US-equity weights from residence-consistent domestic and foreign equity holdings; both denominators include all equity in the same portfolio. External positions alone are insufficient. A foreign ownership share of US capitalization is not $\omega^*$. Match equity/FDI/fund coverage and consolidate intermediaries.',
    ['F3','F7'], r'Fed cross-border equity plus domestic equity-supply accounts. Feasible accounting recovery is given on page~\pageref{sec:bridges}.')
add(23, r'$\theta_{US,t}^*$; recovered $\theta_t,\theta_{W,t}^*$', 'Endogenous', 'I', 'Safe claim and wealth gap',
    r'Foreign US-safe-claim holdings need the corresponding investable-wealth denominator. Treasury holdings span maturities and private/official institutions. Neither debt/GDP nor all non-equity IIP is this share. $\theta_W^*=0$ and $\theta=-\theta_{US}^*A^*/A$ are equilibrium reconstructions, not empirical observations.',
    ['F6','F4','M1'], r'Treasury TIC; \code{ROWTSEQ027S}; model saving/clearing relations.')
add(24, r'$R_{f,t},\ R_{f,t}^W$', 'Endogenous', 'I', 'Period/numeraire bridge',
    r'A named nominal bill yield is D, but TB3MS is a monthly average of annualized discount-basis quotes. Match the holding period and payoff convention. Ex-post inflation adjustment does not create an ex-ante safe real payoff. The zero-supply RoW bond has no uniquely observed world issuer/currency; its yield is model implied.',
    ['F6','M1'], r'Fed H.15 \code{TB3MS}: live through Aug2026. RoW model shadow yield has no exact series.')

add(25, r'$A_{X,i,t},\ A_{L,i,t}$', 'Endogenous', 'I', 'Conditional model inversion',
    r'Can be inferred only conditional on CES parameters and matched production inputs/prices. That inversion is model implied and cannot independently validate the same parameters. Sector labor productivity, R\&D GFCF and knowledge-cost deflators are not factor augmentations.',
    ['P1','P4','P5'], r'Labor and accounts supply inversion inputs. Live R\&D-investment observations establish expenditure, not augmentation.')
add(26, r'$Y_{i,t}$', 'Endogenous', 'D', 'Conditional: output definition',
    r'Corporate GVA or a declared output aggregate is directly measured statistically. Choose its sector, real-price basis and country coverage; GDP and corporate GVA are not interchangeable. Reconcile national-accounts capitalization of R\&D with model $Y=e+\mathcal D-\mathcal I$ before adopting GVA as model output.',
    ['P4','P5'], r'US IMA corporate GVA; OECD $B1G[S11]+B1G[S12]$. Existing mapped panel and verified official definitions.')
add(27, r'$w_{H,i,t},\ w_{L,i,t}$', 'Endogenous', 'D', 'Conditional; RoW levels gap',
    r'US mean earnings per compatible labor unit and skill group are direct candidates. Earnings exclude benefits; median weekly wages are not mean hourly compensation. Corporate-compensation scaling is I. Current RoW relative-earnings panels do not supply matched wage levels, so that component remains I/gap.',
    ['P1','P4'], r'US CPS ORG micro wages; BLS wage sensitivities. OECD EAG ratios and Eurostat labor quantities: local mappings.')
add(28, r'$e_{i,t}$', 'Endogenous', 'I', 'Income/coverage bridge',
    r'Construct $w_HH+w_LL$ using matched workers, wages and time units. Aggregate corporate compensation is a candidate accounting bridge, not automatically young-cohort opportunity income. Forcing micro wages to reproduce compensation is an identity by construction, not independent validation. RoW wage ratios alone do not recover income levels.',
    ['P1','P4'], r'US corporate compensation \code{FU106025005}+\code{FU796025005}; micro wage-bill alternative.')
add(29, r'$q_{i,t},d_{i,t}$; reconstructed $R_{i,t+1}$', 'Endogenous', 'I', 'Variety-unit / price bridge',
    r'Per-variety levels need $q_t=\mathcal Q_t/N_{t+1}$ and $d_t=\mathcal D_t/N_t$, hence the knowledge mapping. Named traded-security price/total returns are D candidates for growth moments only. Splits, issuance and changing composition prevent raw share prices or capitalization growth from directly measuring $q$.',
    ['F2','P3','F5'], r'CRSP \code{prc,ret,retx}; live 2024 sample. Earlier AHP revaluation-implied price chain requires coverage reconciliation.')
add(30, r'$\mathcal Q_{i,t},\ \mathcal D_{i,t}$', 'Endogenous', 'I', 'Claim/cash-flow bridge',
    r'Equity capitalization and consolidated distributions can be D for a specified universe. Current AHP enterprise-value/FCF candidates are I for V6: enterprise value is not shareholder equity, and FCF is not paid dividends or the model profit flow. Retention, repurchases, taxes, debt and intercorporate payouts require reconciliation.',
    ['F7','F1','P4'], r'Fed EV and dividend alternatives; OECD F51 liabilities; Compustat accounts. Keep each mapping ID separate.')

add(31, r'$q_{W,t}n_{W,t}$, $q_{US,t}n_{US,t}^*$', 'Endogenous', 'D', 'Conditional: equity universe',
    r'Residence-based market-value external equity positions are direct counterparts. Specify FDI, fund shares and international-organization equity; current asset/liability source universes differ in fund coverage. Match timing and currency. The underlying model claim counts $n$ remain I after choosing a price normalization.',
    ['F3'], r'\code{ROWEISQ027S}, \code{ROWEINQ027S}; live exact series through2026Q2; Fed analyzer definitions checked.')
add(32, r'$b_t=\theta_tA_t$', 'Endogenous', 'I', 'Safe-bond aggregation gap',
    r'$NFA-E_A+E_L$ is a measurable non-equity residual, not automatically one safe bond. It includes loans, deposits, securities, derivatives and reserves in broad accounts. Foreign Treasury holdings are gross liabilities, whereas $b$ is a consolidated net present-value position. Specify the claim and netting rule.',
    ['F3','F4','F6'], r'International total/equity accounts; TIC Treasury holdings. Broad residual is descriptive, not a direct safe-bond measure.')
add(33, r'$NFA_t$', 'Endogenous', 'D', 'Conditional: instrument scope',
    r'Whole-economy NFA is directly measured by external assets minus liabilities; transparent subtraction does not make it latent. To match V6, choose a consistent instrument universe or reconcile omitted assets/claims in an explicit accounting bridge. Do not infer observed cohort wealth merely by imposing $A=NFA+\mathcal Q_{US}$.',
    ['F4'], r'\code{ROWTLEQ027S}-\code{ROWTASQ027S}=$-$\code{ROWNETQ027S}. Exact identity in all10 sampled quarters.')
add(34, r'$VA_t^{asset},\ VA_t^{liability}$; $VA_t$', 'Endogenous', 'I', 'Price/valuation bridge',
    r'Published revaluations are direct statistical inputs, but model $n_{t-1}\Delta q_t$ requires matched holdings and pure price changes. Separate FX/other changes and preserve the negative US-liability sign. The legacy liability price chain pairs a broad stock with a narrower revaluation series; resolve that difference first.',
    ['F5','F3'], r'Asset \code{FR263181105}; liability \code{FR263081005} versus \code{FR263081115}. Live coverage/value discrepancy verified.')
add(35, r'$CA_t,\ \Delta NFA_t$', 'Endogenous', 'I', 'Transactions/closure bridge',
    r'Observed $\Delta NFA$ and reported CA are D statistical quantities. The current model mapping remains I because it assigns all $\Delta b$ to transactions. Empirical bond valuation, capital-account/statistical discrepancies and other changes must remain separate; do not force $\Delta NFA=CA+VA$ by deleting residuals.',
    ['F4','F5'], r'Quarterly US CA candidate $-$\code{RWLBACQ027S}/4; NFA levels and separate FU/FR accounts. Annualization verified.')

SOURCES = [
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
      description=r'US NFA=ROWTLEQ027S-ROWTASQ027S=-ROWNETQ027S, million USD. US CA candidate=-RWLBACQ027S/4: the source is ROW net lending/borrowing (B9) at an annual rate. Capital-account/statistical items must be reconciled before identifying this candidate with CA. RWNEOWQ027S is ROW net-worth revaluation (US total VA is its negative); equity FU components are transactions. Do not conflate SAAR and period flows.',
      links=[('ROW net worth','https://fred.stlouisfed.org/series/ROWNETQ027S'),('ROW net lending','https://fred.stlouisfed.org/series/RWLBACQ027S')]),
 dict(id='F5', title='Equity revaluation and price/FX separation', status='Live scope discrepancy; current bridge unresolved',
      description=r'BOGZ1FR263181105Q, BOGZ1FR263081005Q and BOGZ1FR263081115Q are quarterly revaluations in million USD, not annualized transaction flows. BEA Concepts and Methods separates transactions, price/FX revaluation and other changes. Matching FR/FU/stock universes is required.',
      links=[('Broad liability FR','https://fred.stlouisfed.org/series/BOGZ1FR263081005Q'),('Legacy liability FR','https://fred.stlouisfed.org/series/BOGZ1FR263081115Q'),('BEA2026 methods,chs.8/24','https://www.bea.gov/sites/default/files/2026-06/BEA-International-Economic-Accounts-Concepts-and-Methods.pdf')]),
 dict(id='F6', title='Safe yields and Treasury holdings', status='Live series; Treasury coverage notes checked',
      description=r'TB3MS: monthly average3-month bill rate, percent at an annual discount-basis quote; saved through Aug2026. ROWTSEQ027S: quarterly foreign Treasury holdings. TIC Table5 includes multiple maturities and custody-based country attribution; it is not a model wealth denominator.',
      links=[('TB3MS','https://fred.stlouisfed.org/series/TB3MS'),('TIC Table5','https://ticdata.treasury.gov/Publish/slt_table5.html')]),
 dict(id='F7', title='Capitalization, operating-asset value and distributions', status='Live Fed alternatives; local AHP construction retained',
      description=r'AHP operating-asset values: LM102010405Q+LM792010405Q. Gross-dividend alternatives: FU106121001A+FU796121001A, sampled through2025. FCF uses operating surplus minus taxes/investment. These distinct claim/cash-flow concepts are not interchangeable; gross dividends also need intercorporate consolidation.',
      links=[('Operating-asset value','https://fred.stlouisfed.org/series/BOGZ1LM102010405Q'),('NFC dividends','https://fred.stlouisfed.org/series/BOGZ1FU106121001A')]),
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
\fancyhead[R]{\small\sffamily Evidence checked 22 September 2026}
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
\toprule\rowcolor{tablehead}\textbf{Core entry} & \textbf{Class / readiness} & \textbf{Proposed mapping and accuracy judgment} & \textbf{Data source / verification}\\\midrule
\endfirsthead
\toprule\rowcolor{tablehead}\textbf{Core entry} & \textbf{Class / readiness} & \textbf{Proposed mapping and accuracy judgment} & \textbf{Data source / verification}\\\midrule
\endhead\midrule\multicolumn{4}{r}{\footnotesize\itshape Continued on next page}\\\endfoot
\bottomrule\endlastfoot
}{\end{longtable}}
\hypersetup{pdftitle={Measurability of the 35 HKT calibration entries},pdfauthor={}}
\begin{document}
{\LARGE\sffamily\bfseries\color{heading}Measurability of the calibration entries}\par
{\large\sffamily Direct statistical counterparts, indirect constructions, and latent model quantities}\par

This document assesses \textbf{every one of the35 grouped entries} in \code{V6\_calibration\_core.tex}, in the same order. It uses the V6 equations, the zero-exponent solver, the earlier \code{Codes/Empirical\_Data} mappings, the FinAI measurement workflow, and fresh WRDS/OpenEcon/official-API checks. The classification concerns an \emph{accurate model-to-data mapping}, not simply whether a similarly named series exists.

\section*{Read the classification together with mapping readiness}
\begin{longtable}{@{}P{.17\textwidth}P{.79\textwidth}@{}}
\toprule\rowcolor{tablehead}\textbf{Class} & \textbf{Meaning}\\\midrule
\textbf{D: directly measured} & A specified statistical counterpart is reported or constructed by transparent aggregation, ratios or unit conversion, without imposing model behavioral equations. Sampling error and ordinary national-accounts estimation do not disqualify D. \textbf{D$^\dagger$ means the model correspondence is conditional}: the population, sector, instrument or timing convention still needs to be adopted and reconciled.\\[5pt]
\textbf{I: indirect / model implied} & A missing model coordinate requires a substantive bridge, a proxy, a normalization or a model inversion. The table distinguishes these cases. I does \emph{not} certify that a weak proxy is accurate, and a model-generated value is not independent empirical evidence.\\[5pt]
\textbf{L: structurally latent} & No verified observation rule measures the preference, technology or regime construct. It requires joint structural identification, a compatible external estimate, or an explicitly imposed restriction. L does not mean dispensable or inherently unidentifiable.\\
\bottomrule
\end{longtable}

\textbf{Assessment.} Five entry families have direct statistical candidates, all conditional;13 require an indirect/model-implied construction;17 are structurally latent, including the imposed zero exponents and the unmapped regime. Country/component qualifications remain visible: for example, US wage observations do not supply missing RoW wage levels. \textbf{No conditional D entry is being declared calibration-ready.} Under a strict requirement of an already completed model correspondence, those conditional D entries remain unresolved bridges too.

The most promising direct anchors are explicitly defined employment/earnings, output accounts, gross external equity positions and NFA. The principal unresolved mappings are research labor within skilled labor, knowledge varieties, factor augmentation, complete resident equity portfolios, the single safe bond, and the relation of enterprise value/FCF to model equity/profits.

\textbf{Verification is separate from identification.} Live WRDS samples,19 exact FRED series and two exact Eurostat samples establish access to specified observations. They do not establish a full historical panel or an identified calibration. Both OpenEcon checks returned a different concept from the one requested; their substitutions were rejected. The source column links to the evidence ledger and distinguishes live observations, current metadata and previously saved panels.
'''

BRIDGES = r'''
\clearpage
\section{Useful measurement constructions and their limits}\label{sec:bridges}
\textbf{Actual equity weights can be constructed without treating preference centers as data.}
Let $E_A=q_Wn_W$ and $E_L=q_{US}n_{US}^*$ be measured external equity positions. If domestic equity supplies $\mathcal Q_{US},\mathcal Q_W$ use the same equity/FDI/fund universe, residence rule and consolidation, then
\[
\omega=\frac{\mathcal Q_{US}-E_L}{\mathcal Q_{US}-E_L+E_A},\qquad
\omega^*=\frac{E_L}{\mathcal Q_W-E_A+E_L}.
\]
These are feasible accounting constructions for M22, not observations of $\bar\omega,\bar\omega^*$. Operating-asset enterprise value cannot silently replace equity supply; covered OECD countries cannot silently replace the entire RoW. National end-date holdings may be the chosen aggregate counterpart of model investors without literal age filtering, but that does not equate national net saving with young-cohort asset acquisition.

\textbf{Knowledge and augmentation require separate, explicit bridges.}
The identities $q_{i,t}=\mathcal Q_{i,t}/N_{i,t+1}$ and $d_{i,t}=\mathcal D_{i,t}/N_{i,t}$ preserve V6 timing. For $X_i=\varphi_iH_i$ and $\rho_i\ne1$, a conditional CES inversion is
\[
A_{X,i}=\left[\frac{\vartheta_i\alpha_iY_i^{\rho_i}}{w_{H,i}X_i^{\rho_i}}\right]^{1/(\rho_i-1)},\qquad
A_{L,i}=\left[\frac{(1-\alpha_i)Y_i^{\rho_i}}{w_{L,i}L_i^{\rho_i}}\right]^{1/(\rho_i-1)}.
\]
This requires the production accounting check $w_HX/\vartheta+w_LL=Y$, compatible input/wage units and all the indicated parameters. It is undefined at $\rho=1$ and sensitive nearby. Computing it does not independently identify or validate those parameters. Do not rescale inconsistent empirical factor payments merely to enforce the equality.

\textbf{The current external-account bridges need a coverage reconciliation.}
The earlier liability price chain combines \code{ROWEINQ027S}/FL263081005 with FR263081115. Current Fed component definitions link the broad stock to FR263081005, while FR263081115 excludes mutual/money-market fund shares. In 2026Q2 the live values are 3,921,264 and 3,718,464 million USD: a \textbf{202,800 million USD difference}. This establishes a scope difference, not a license to replace one series automatically. Reconcile levels, transactions, revaluations and other changes together. See \hyperlink{src-F3}{F3} and \hyperlink{src-F5}{F5}.

For M35, keep empirical CA, net financial transactions, equity VA, FX/bond VA, other changes and statistical discrepancies distinct. The model's assignment of all $\Delta b$ to CA is not valid for arbitrary long-maturity market-value debt. Notebook06's window statistics divide cumulative flows and the change in the NFA \emph{level} by end-window output; they are not sums of flow/output ratios or a change in NFA/output. Select the sectoral output denominator and model-period frequency before constructing calibration moments.
'''

LIVE = r'''
\clearpage
\section{What the live checks established}
\begin{longtable}{@{}P{.22\textwidth}P{.72\textwidth}@{}}
\toprule\rowcolor{tablehead}\textbf{Route / sample} & \textbf{Verified result and interpretation}\\\midrule
WRDS: Compustat NA & \code{comp.funda}, gvkey001690/fyear2024 returned2 formats. Exactly1 row is C/INDL/STD; the other is SUMM\_STD. R\&D, employee, payout and cash-flow fields exist in the standard row. This confirms a firm-level route, not national research/skill quantities. Duplicate-format summation would be wrong.\\[6pt]
WRDS: Compustat Global & \code{comp.g\_funda}, fyear2024 returned an intentionally capped3-row pilot;42,376 matching rows were advertised. \textbf{The pilot is incomplete and not representative.} No complete Global panel, growth trend or aggregate moment was inferred.\\[6pt]
WRDS: CRSP & \code{crsp.msf}, PERMNO14593 returned all12 unique months of2024 with price, distribution-inclusive/exclusive return and adjustment fields. The provider count reported3 despite12 returned records. Calendar/identifier validation established the bounded sample; the inconsistent metadata were preserved. This does not certify coverage of all securities or a current national index.\\[6pt]
Exact FRED / Fed data & 19 exact series:16 quarterly through2026Q2, TB3MS through Aug2026 and2 annual dividend series through2025. The request window began in2024. Dates are unique/sorted; the NFA identity holds exactly in all10 sampled quarters. These are saved-sample dates, not a claim about full source histories.\\[6pt]
Exact Eurostat: labor & \code{lfsa\_egaed}, DE, age25--64, both sexes, ED5-8, THS\_PER: 12,543.1; 12,708.1; 13,052.0 thousand employed persons in2021--23. The2021 break flag is preserved. This directly measures tertiary employment, not corporate skill efficiency or research labor.\\[6pt]
Exact Eurostat: R\&D & \code{nama\_10\_a64\_p5}, DE, TOTAL, N1171G, P51G, CP\_MNAC: 105,966; 110,894; 124,513 million national currency in2021--23. The2022--23 provisional flags are preserved. This is an investment flow, not knowledge varieties, innovation success or $A_X$.\\[6pt]
OpenEcon: two checks & Requested exact ROWEISQ027S, received FL263164100Q: the2026Q2 values differ by11,305,117 million USD. Requested MSTI business researchers B\_RS/FTE, received G+T\_RS URLs and generic units. Both responses contained numbers; both were rejected for these mappings. Direct exact-source probes supplied the usable evidence.\\[6pt]
Failed routes retained & The exact OECD MSTI direct request returned HTTP 403; earlier saved OECD data remain separately labeled. Initial network/time-out routes and unsuccessful candidate endpoints are logged. Failure of a route is not evidence that the economic series does not exist.\\
\bottomrule
\end{longtable}

\textbf{Reproducible package.} \code{measurability\_evidence/} contains immutable-for-this-audit raw samples, request/response receipts, source IDs/URLs, flags, validation summaries and the classification CSV/JSON. WRDS metadata are in \code{wrds/tool\_receipts.json}; official probes and rerun scripts are under \code{production/} and \code{external/}. The PDF is rebuilt by \code{build\_tables.py} plus LaTeX. A rerun can receive revised source data; retain this dated snapshot when changing vintages. No model solve, parameter estimation, bulk historical refresh or change to the earlier mappings was performed.
'''

assert [r['core_entry'] for r in ROWS] == list(range(1,36))
assert Counter(r['measurement_class'] for r in ROWS)=={'D':5,'I':13,'L':17}
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
print('Built35 entry rows,14 source groups; classes:',dict(Counter(r['measurement_class'] for r in ROWS)))
