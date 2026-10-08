"""Build the A/B/C calibration-strategy register without assigning values."""
from collections import Counter
from pathlib import Path
from datetime import datetime, timezone
import csv
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
OUT = HERE.parent
ROOT = OUT.parent.parent
ROWS = []

def add(mid, group, fields, symbol, name, status, definition, discipline, labels, refs):
    ROWS.append(dict(entry_id=mid, group=group, code_fields=fields, symbol=symbol,
        name=name, assignment_status=status, definition_and_reason=definition,
        proposed_discipline=discipline, v6_labels=labels, references=refs))

add('M02', 'A', ['γ'], r'$\gamma$', 'Risk aversion', 'External literature review',
    r'Curvature of the old-age consumption certainty equivalent in V6 Epstein--Zin preferences, with unit intertemporal elasticity. The risk-aversion concept has an established empirical literature; transfer still requires compatible risks and population.',
    r'Review \lit{EZ}{EZ89} and \lit{BJKS}{BJKS97}, then document a range and aggregation assumptions. V6 theory additionally needs $0<\gamma<1$; retain contrary evidence rather than choosing only estimates that deliver bubbles. The solver accepts $\gamma>0$, while the displayed utility excludes $\gamma=1$.',
    ['US_K_def'], ['EZ', 'BJKS', 'HKT'])
add('M08', 'A', ['H_US', 'L_US', 'H_W', 'L_W'], r'$H_i,\ L_i$', 'Labor endowments',
    'External data and scale conventions',
    r'Masses of skilled and unskilled young workers; production uses $\varphi_iH_i$ and research uses $(1-\varphi_i)H_i$. These are external inputs registered as parameters, with credible labor-data counterparts.',
    r'Use the existing CPS/Eurostat mappings after fixing skill, age/cohort, sector and headcount/FTE definitions. Preserve relative country and skill sizes when choosing units. This is the data-based part of A; a search for a conventional literature number is unnecessary.',
    ['country_knowledge_law', 'country_labor_income'], [])
add('M10', 'A', ['ϑ_US', 'ϑ_W'], r'$\vartheta_i$', 'Inverse markup',
    'External literature review',
    r'Intermediate firms charge $p_i=w_{H,i}/\vartheta_i$, so their price/marginal-cost markup is $\mu_i=1/\vartheta_i$. The demand elasticity across varieties is $1/(1-\vartheta_i)$, distinct from the final-sector CES elasticity.',
    r'Review markup evidence such as \lit{DLEU}{DLEU20}; map a compatible gross markup by $\vartheta_i=1/\mu_i$. Distinguish markups from profit shares, overhead and taxes. A US listed-firm aggregate need not represent V6 intermediates or the RoW; retain sector/aggregation alternatives.',
    ['country_factor_prices', 'country_dividend_formula'], ['DLEU'])
add('M12', 'A', ['ρ_US', 'ρ_W'], r'$\rho_i$', 'Final-sector CES curvature',
    'External literature review',
    r'For $F=[\alpha\widetilde X^{1-\rho}+(1-\alpha)\widetilde L^{1-\rho}]^{1/(1-\rho)}$, the substitution elasticity is $\sigma_i=1/\rho_i$. A clear transformation and substantial substitution literature make this a priority for external review.',
    r'Use \lit{KM}{KM92} and \lit{CC}{CC06} as related skill/technology evidence. Match the intermediate-input/unskilled-labor margin, markup and technology controls before transfer. The implemented restriction $\rho_{US}>1$ means $\sigma_{US}<1$ (complementarity), not substitutability.',
    ['country_final_good', 'psi_US_def'], ['KM', 'CC', 'HKT'])

add('M01', 'B', ['β'], r'$\beta$', 'OLG utility / saving weight',
    'External range after cohort mapping',
    r'V6 places weights $1-\beta$ and $\beta$ on young consumption and the old-age certainty equivalent, yielding $A_t=\beta e_{US,t}$. A conventional annual infinite-horizon discount factor is a different object.',
    r'Use compatible life-cycle/OLG saving and preference evidence; \lit{HKT}{HKT25} is the closest specification. If a two-date utility instead uses weights $1,\delta$, then $\beta=\delta/(1+\delta)$. This algebra alone supplies no annual-to-generation conversion. Do not fit $\beta$ to an incompatible aggregate wealth/income ratio.',
    ['US_saving_rule_bond_cost'], ['HKT', 'BJKS'])
add('M07', 'B', ['π_persist'], r'$\pi$', 'Unbalanced-regime persistence',
    'External scenario / credible range',
    r'$\pi=\Pr(z_{t+1}=u\mid z_t=u)$ with absorbing $b$. Its empirical interpretation needs an operational technology-regime definition and a model-period length. It also affects financial valuation, but is not a portfolio friction.',
    r'Use regime-duration or disaster literature (\lit{BARRO}{Barro06}) as an analogy, not a direct crash-probability estimate. Under a matched constant annual event probability $h$, $\pi=(1-h)^{\Delta}$ for a $\Delta$-year period. Without matched events, report scenarios and re-fit C across them; an all-$u$ sample alone is weak evidence.',
    ['ass_regime_switch'], ['BARRO', 'HKT'])
add('M09', 'B', ['a_US', 'a_W'], r'$a_i$', 'Innovation productivity',
    'External range from a joint mapping',
    r'$N_{i,t+1}/N_{i,t}-1=a_i(1-\varphi_{i,t})H_i$. R\&D productivity evidence is relevant, but V6 varieties and skilled research labor are not directly observed as a matched pair. The coefficient depends on labor units and period length.',
    r'Use \lit{BJRW}{BJRW20} and \lit{HKT}{HKT25} to organize evidence and specification alternatives. Discipline $a_iH_i$ jointly with knowledge growth and the research share; recover $a_i$ only after fixing $H_i$. A research-spending growth rate or a patent count does not by itself deliver $a_i$.',
    ['country_knowledge_law'], ['BJRW', 'HKT'])
add('M11', 'B', ['α_US', 'α_W'], r'$\alpha_i$', 'CES distribution weights',
    'Normalization plus external production discipline',
    r'Levels enter through $\alpha_iA_{X,i}^{1-\rho_i}$ and $(1-\alpha_i)A_{L,i}^{1-\rho_i}$. A labor share is informative conditional on technology, markup and inputs; it is not the CES weight itself.',
    r'Fix units and a production normalization, then use matched income shares and relative wages, following the logic of \lit{CC}{CC06}. Do not separately choose both augmentation scales and $\alpha_i$ as if all three were independently identified. AHP cost shares use a different production model.',
    ['country_final_good', 'country_factor_prices'], ['CC', 'AHP'])
add('M13', 'B', ['A_X_US_u', 'A_L_US_u'],
    r'$\bar A_{X,US,u},\ \bar A_{L,US,u}$', 'US productivity scales in u',
    'Conditional production fit',
    r'$A^u_{X,US}=\bar A_{X,US,u}N_{US}^{\xi_u}$ and $A^u_{L,US}=\bar A_{L,US,u}N_{US}^{\nu_u}$. Code fields \code{A\_X\_US\_u}, \code{A\_L\_US\_u} are scale coefficients, not observed TFP levels.',
    r'Use initial output, matched skill wages and labor quantities under a declared $N_0$ and $\alpha$ normalization (\lit{CC}{CC06}; \lit{HKT}{HKT25}). Construct joint ranges for relative productivity and scale; record any production moments used to assign them as targeted moments.',
    ['US_u_productivity_primitives'], ['CC', 'HKT'])
add('M14', 'B', ['Abar_X_US', 'Abar_L_US'],
    r'$\bar A_{X,US,b},\ \bar A_{L,US,b}$', 'US absorbing-regime scales',
    'Counterfactual range',
    r'These levels determine post-switch production and equity payoffs. With $\nu_b=0$ they are constant augmentations. A history observed entirely in $u$ does not directly reveal the $b$ technology.',
    r'Use defensible post-transition analogues, bounded productivity changes or explicit continuity restrictions, with \lit{HKT}{HKT25} as a model comparison. Do not silently equate them to the $u$ scales. Re-fit C across these scenarios because switch severity trades off with $\pi$ and $\gamma$ in asset prices.',
    ['bg_us_primitives'], ['HKT'])
add('M15', 'B', ['Abar_X_W', 'Abar_L_W'],
    r'$\bar A_{X,W},\ \bar A_{L,W}$', 'RoW productivity scales',
    'Conditional production fit',
    r'With $\xi_W=0$, these are constant RoW factor augmentations, not country-average TFP. They set relative income and funding capacity and interact with $\alpha_W$, labor units and the geographic definition of RoW.',
    r'Use matched output and skill-wage evidence for the declared country aggregate; \lit{CC}{CC06} guides interpretation and \lit{AHP}{AHP25} the corporate-account scope. Keep full RoW and covered-country proxies distinct; a common scale normalization cannot determine all relative productivity levels.',
    ['bg_w_primitives'], ['CC', 'AHP'])
add('M16', 'B', ['ξ_u', 'ν_u'], r'$\xi_u,\ \nu_u$', 'Knowledge-spillover elasticities',
    'External joint range / specification review',
    r'These are elasticities of factor augmentations with respect to the knowledge stock: $\partial\log A_X/\partial\log N=\xi_u$, $\partial\log A_L/\partial\log N=\nu_u$. Broad innovation/growth estimates are related, but do not identify this pair directly.',
    r'Combine \lit{HKT}{HKT25}, \lit{CC}{CC06} and \lit{BJRW}{BJRW20} with knowledge and wage-growth mappings. Report a joint range. The solver requires $\xi_u>\nu_u\ge0$; V6 theory additionally uses $\nu_u>\nu_b$. $\psi_{US}=(\xi_u-\nu_u)(\rho_{US}-1)$ is derived, not another free parameter.',
    ['US_u_productivity_primitives', 'psi_US_def'], ['HKT', 'CC', 'BJRW'])
add('M17', 'B', ['ν_b', 'ξ_W'], r'$\nu_b=0,\ \xi_W=0$', 'Fixed growth specialization',
    'Imposed, not free parameters',
    r'These technology coefficients are fixed at zero by this solver. B marks their model-specific family; the zeros are imposed restrictions, not estimates.',
    r'Retain and assess these restrictions. Positive-exponent scenarios, including related \lit{HKT}{HKT25} illustrations, require an alternative solver before any value search.',
    ['bg_us_primitives', 'bg_w_primitives'], ['HKT'])

add('M03', 'C', ['κ'], r'$\kappa$', 'Equity-allocation friction',
    'Internal joint calibration candidate',
    r'Curvature of $-\kappa(\omega-\bar\omega)^2/2$ and its RoW counterpart. It governs the response of portfolio shares to expected risk-adjusted relative equity returns. There is no portable standard home-bias cost for this utility normalization.',
    r'Use share/return variation and gross equity exposures, conditional on A/B. \lit{CR}{CR13} provides plausibility checks. A single observed share mainly restricts the combination $\kappa(\omega-\bar\omega)$; it does not separate $\kappa$ from the center. Consider a restricted C block if informative variation is insufficient.',
    ['US_omega_FOC_bond_cost', 'RoW_omega_FOC_mod'], ['CR', 'AHP'])
add('M04', 'C', ['ω̄', 'ω̄_star'], r'$\bar\omega,\ \bar\omega^*$', 'US-equity preference centers',
    'Internal joint calibration candidates',
    r'Both are preferred US-equity weights within an investor equity portfolio, for US and RoW investors respectively. They are distinct from actual $\omega,\omega^*$ and from foreign ownership of the US issuer sector.',
    r'Use AHP-style gross equity positions and conditional portfolio-weight mappings jointly with $\kappa$ (\lit{AHP}{AHP25}; \lit{CR}{CR13}). Neither $E_L/V_{US}$ nor one observed home-bias index directly measures either center. Full RoW wealth/value coverage remains a constraint for $\omega^*$.',
    ['US_omega_FOC_bond_cost', 'RoW_omega_FOC_mod'], ['AHP', 'CR'])
add('M05', 'C', ['χ'], r'$\chi$', 'Foreign demand for US safe claims',
    'Internal joint calibration candidate',
    r'Coefficient of RoW utility from US-bond holdings; it also changes RoW saving to $A^*=[(\beta+\chi)/(1+\chi)]e_W$. Its value depends on the utility normalization and wealth/claim definitions.',
    r'Combine foreign safe-claim holdings, matched wealth/saving evidence and suitable safe-asset spreads. \lit{KVJ}{KVJ12} supports the convenience-yield mechanism, not a V6 coefficient value. AHP net non-equity positions are useful accounting targets but are not automatically pure safe debt.',
    ['RoW_thetaUS_FOC_mod'], ['KVJ', 'AHP'])
add('M06', 'C', ['η'], r'$\eta$', 'US bond-share friction',
    'Internal joint calibration candidate',
    r'Scales the utility term $-\eta\Upsilon(\theta)$ with the code-imposed $\Upsilon(\theta)=-\log(1-\theta)+\theta^2/2$. It is not an observed bond underwriting fee or a resource cost.',
    r'Jointly use US net borrowing, its response to returns, and the safe-return wedge, conditional on $\chi$, $\beta$ and the chosen bond mapping. External financing-friction studies offer plausibility only. NFA, CA and valuation alone need not separately identify $\eta$ and $\chi$.',
    ['US_theta_FOC_bond_cost'], ['AHP', 'CR'])

SOURCES = [
    dict(id='EZ', label='EZ89', authors='Epstein, Larry G., and Stanley E. Zin', year=1989,
         title='Substitution, Risk Aversion, and the Temporal Behavior of Consumption and Asset Returns: A Theoretical Framework',
         venue='Econometrica 57(4), 937--969', url='https://doi.org/10.2307/1913778',
         checked_url='https://people.bu.edu/lepstein/files-research/EZ1989.pdf',
         use='Preference definitions and separation of risk aversion from intertemporal substitution; not a V6 parameter estimate.'),
    dict(id='BJKS', label='BJKS97', authors='Barsky, Robert B., F. Thomas Juster, Miles S. Kimball, and Matthew D. Shapiro', year=1997,
         title='Preference Parameters and Behavioral Heterogeneity: An Experimental Approach in the Health and Retirement Study',
         venue='Quarterly Journal of Economics 112(2), 537--579', url='https://doi.org/10.1162/003355397555280',
         checked_url='https://websites.umich.edu/~shapiro/papers/qje1997-jstor.pdf',
         use='Survey preference evidence; population, risk definition and aggregation require a transfer audit.'),
    dict(id='KM', label='KM92', authors='Katz, Lawrence F., and Kevin M. Murphy', year=1992,
         title='Changes in Relative Wages, 1963--1987: Supply and Demand Factors',
         venue='Quarterly Journal of Economics 107(1), 35--78', url='https://doi.org/10.2307/2118323',
         checked_url='https://academic.oup.com/qje/article-abstract/107/1/35/1925833',
         use='Skill demand/supply evidence; its labor margin is not automatically the V6 intermediate-input margin.'),
    dict(id='CC', label='CC06', authors='Caselli, Francesco, and Wilbur John Coleman II', year=2006,
         title='The World Technology Frontier', venue='American Economic Review 96(3), 499--522',
         url='https://doi.org/10.1257/aer.96.3.499',
         checked_url='https://pubs.aeaweb.org/doi/abs/10.1257/aer.96.3.499',
         use='Skill-specific efficiency and production comparisons; supports conditional mapping, not independent V6 scale identification.'),
    dict(id='DLEU', label='DLEU20', authors='De Loecker, Jan, Jan Eeckhout, and Gabriel Unger', year=2020,
         title='The Rise of Market Power and the Macroeconomic Implications',
         venue='Quarterly Journal of Economics 135(2), 561--644', url='https://doi.org/10.1093/qje/qjz041',
         checked_url='https://crei.cat/wp-content/uploads/2020/10/the-rise-1.pdf',
         use='Firm-markup evidence; requires marginal-cost, sector and aggregation alignment.'),
    dict(id='BJRW', label='BJRW20', authors='Bloom, Nicholas, Charles I. Jones, John Van Reenen, and Michael Webb', year=2020,
         title='Are Ideas Getting Harder to Find?', venue='American Economic Review 110(4), 1104--1144',
         url='https://doi.org/10.1257/aer.20180338',
         checked_url='https://www.aeaweb.org/articles?id=10.1257/aer.20180338',
         use='Research-effort/productivity evidence; neither an estimate of V6 varieties nor a direct spillover coefficient.'),
    dict(id='BARRO', label='Barro06', authors='Barro, Robert J.', year=2006,
         title='Rare Disasters and Asset Markets in the Twentieth Century',
         venue='Quarterly Journal of Economics 121(3), 823--866', url='https://doi.org/10.1162/qjec.121.3.823',
         checked_url='https://dash.harvard.edu/entities/publication/73120378-850d-6bd4-e053-0100007fdf3b',
         use='Disaster-probability discipline as an analogy; recurrent macro disasters differ from an absorbing technology switch.'),
    dict(id='CR', label='CR13', authors='Coeurdacier, Nicolas, and Hélène Rey', year=2013,
         title='Home Bias in Open Economy Financial Macroeconomics',
         venue='Journal of Economic Literature 51(1), 63--115', url='https://doi.org/10.1257/jel.51.1.63',
         checked_url='https://www.aeaweb.org/articles?id=10.1257/jel.51.1.63',
         use='Alternative portfolio mechanisms and useful evidence; no transferable V6 preference-center or utility-cost value.'),
    dict(id='KVJ', label='KVJ12', authors='Krishnamurthy, Arvind, and Annette Vissing-Jorgensen', year=2012,
         title='The Aggregate Demand for Treasury Debt', venue='Journal of Political Economy 120(2), 233--267',
         url='https://doi.org/10.1086/666526',
         checked_url='https://www.journals.uchicago.edu/doi/pdf/10.1086/666526',
         use='Safety/liquidity demand and yield spreads; a spread is not the V6 utility coefficient.'),
    dict(id='HKT', label='HKT25', authors='Hirano, Tomohiro, Keiichi Kishi, and Alexis Akira Toda', year=2025,
         title='Technological Innovation and Bursting Bubbles', venue='Working paper, arXiv:2501.08215v2',
         url='https://arxiv.org/abs/2501.08215v2', checked_url='https://arxiv.org/abs/2501.08215v2',
         use='Version underlying the local V6 comparison. Numerical illustrations are not empirical estimates; a later version exists.'),
    dict(id='AHP', label='AHP25', authors='Atkeson, Andrew, Jonathan Heathcote, and Fabrizio Perri', year=2025,
         title='The End of Privilege: A Reexamination of the Net Foreign Asset Position of the United States',
         venue='American Economic Review 115(7), 2151--2206', url='https://doi.org/10.1257/aer.20230732',
         checked_url='https://www.aeaweb.org/articles?id=10.1257/aer.20230732',
         use='Section III separates accounting construction from model inversion. Its parameter paths and identification do not transfer to V6.'),
]

PREAMBLE = r"""% !TEX program = pdflatex
% Generated by parameter_group_evidence/build_groups.py.
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
\fancyhead[L]{\small\sffamily\color{heading}Two-country HKT: parameter calibration strategy}
\fancyhead[R]{\small\sffamily 27 September 2026}
\fancyfoot[C]{\thepage}
\renewcommand{\headrulewidth}{0.3pt}
\setlength{\parindent}{0pt}\setlength{\parskip}{5pt}
\setlength{\tabcolsep}{5pt}\setlength{\LTpre}{5pt}\setlength{\LTpost}{7pt}
\renewcommand{\arraystretch}{1.12}\setlength{\emergencystretch}{3em}
\newcolumntype{P}[1]{>{\raggedright\arraybackslash}p{#1}}
\newcommand{\code}[1]{{\footnotesize\texttt{#1}}}
\newcommand{\lit}[2]{\hyperlink{ref:#1}{#2}}
\newenvironment{grouptable}{%
\fontsize{9.4}{10.8}\selectfont\setlength{\parskip}{1.5pt}
\begin{longtable}{@{}P{\dimexpr .18\textwidth-6.67pt\relax}P{\dimexpr .385\textwidth-6.67pt\relax}P{\dimexpr .435\textwidth-6.66pt\relax}@{}}
\toprule\rowcolor{tablehead}\textbf{Parameter / core ID} & \textbf{V6 definition and reason for grouping} & \textbf{Proposed discipline and identification qualification}\\\midrule
\endfirsthead
\toprule\rowcolor{tablehead}\textbf{Parameter / core ID} & \textbf{V6 definition and reason for grouping} & \textbf{Proposed discipline and identification qualification}\\\midrule
\endhead
\midrule\multicolumn{3}{r}{\footnotesize\itshape Continued on next page}\\\endfoot
\bottomrule\endlastfoot
}{\end{longtable}}
\hypersetup{pdftitle={V6 parameter groups for external and internal calibration},pdfauthor={}}
\begin{document}
{\LARGE\sffamily\bfseries\color{heading}Parameter groups for calibration}\par
{\large\sffamily External discipline, model-specific ranges, and the international-finance block}\par

This companion to the measurability audit classifies the \textbf{17 parameter families / 30 economic scalar fields} in M01--M17 of \code{V6\_calibration\_core.tex}, checked against V6 and the current zero-exponent solver. It is a proposed allocation of calibration effort: \textbf{external versus internal assignment does not establish identification}. No numerical values or empirical ranges are selected here. Paper abbreviations link to the references.

\begin{center}\small
\begin{tabular}{@{}P{.09\textwidth}P{.56\textwidth}P{.27\textwidth}@{}}
\toprule\rowcolor{tablehead}\textbf{Group} & \textbf{Assignment principle} & \textbf{Coverage}\\\midrule
\textbf{A} & Strong candidates for external discipline; prioritize comparable literature and direct inputs. & 4 families / 9 scalars; 4 scalars are labor-data inputs.\\[3pt]
\textbf{B} & Related evidence exists, but V6 needs ranges, normalizations or model-specific restrictions. & 9 families / 16 scalars; 2 scalars are imposed zeros.\\[3pt]
\textbf{C} & Reserve the international-finance coefficients for joint internal calibration; literature is a plausibility check. & 4 families / 5 scalars.\\
\bottomrule
\end{tabular}
\end{center}

\section{Group A: strong candidates for external discipline}
The three structural families below have recognizable preference/production interpretations. A strong candidate for review is not an endorsement of any existing point estimate. Labor endowments belong to A through external data, not parameter borrowing.
"""

BETWEEN_B = r"""
\clearpage
\section{Group B: external candidates with a model-specific mapping}
Seek joint ranges and explicit normalizations. \emph{External} means outside the principal international-finance target block; fitting V6 production moments is still an internal production calibration, and those moments are targeted. Numerical ranges remain to be reviewed.
"""
BETWEEN_C = r"""
\clearpage
\section{Group C: parameters for the international-finance mechanism}
The proposed free block is $p_C=(\kappa,\bar\omega,\bar\omega^*,\chi,\eta)$. Use the AHP-style accounting counterparts documented in the measurability audit, conditional on the externally disciplined block and the B restrictions. All five coefficients require joint assessment; the proposed assignment is not a claim that the available moments identify them.
"""
AFTER_C = r"""
\textbf{Why the C parameters must be considered jointly.}
At interior portfolios, the V6 conditions include
\[
\underbrace{\beta(1-\theta_t)E_t[M_{t,t+1}(R_{US,t+1}-R_{W,t+1})]}_{\text{risk-adjusted relative return}}
=\kappa(\omega_t-\bar\omega),\qquad
\beta E_t[M_{t,t+1}(R_{f,t}-R_{p,t+1})]=\eta\Upsilon'(\theta_t),
\]
\[
\beta E_t[\widetilde M^*_{t,t+1}(R_{f,t}-R^*_{p,t+1})]
+\frac{\chi}{\theta^*_{US,t}}=0.
\]
The expectation and pricing kernels are model objects; realized AHP valuation effects do not directly observe them. These equations explain which evidence is relevant, but are not independent empirical measurements of the coefficients.

\textbf{Moment selection and identification.}
Start with matched gross equity positions, net non-equity positions/flows, equity revaluation and payout moments, and appropriate spread/portfolio-response evidence. NFA, CA and valuation obey accounting identities, so they are not automatically independent identifying restrictions. Stock-to-flow ratios require a fixed OLG period and population bridge. Choose targeted and validation moments explicitly; an algebraic residual is not an untargeted test.
For each admissible A/B specification $p_E$, re-fit C and examine moment sensitivity, singular values of $\partial m(p_C;p_E)/\partial p_C^\top$, profile objectives and economically relevant conclusions. Local rank is only a diagnostic; weak and global identification remain separate questions. If the five-dimensional block cannot be distinguished, reduce it with a stated restriction.

\textbf{Comparison with AHP.}
\lit{AHP}{AHP25, Section III, pp.\ 2174--2176}, first constructs accounting data and then inverts its own model for time-varying parameters. V6 instead proposes a small, constant financial-friction block conditional on production and preference choices. AHP's exact fit therefore supplies neither a five-parameter identification proof nor a requirement that V6 fit every series exactly.
"""
END = r"""
\clearpage
\section{Scope, implementation checks and literature entry points}
\textbf{Scope.} All 30 economic parameter fields are assigned once. Of these, four labor endowments are external data inputs and two exponents are imposed restrictions; the other 24 are structural coefficients to discipline. M18 initial knowledge stocks are exogenous conditions outside this parameter table: preserve the chosen knowledge normalization. Numerical tolerances, horizons and the inert \code{common\_world\_growth} flag are not economic parameters.

\textbf{Implementation checks.} The CES formula, rather than an old solver comment, establishes $\sigma_i=1/\rho_i$; hence $\rho_{US}>1$ is the complementarity case. The code imposes $\xi_u>\nu_u\ge0$, $\nu_b=\xi_W=0$ and $\rho_{US}>1$; V6's sufficient bubble theorem additionally uses $0<\gamma<1$ and $\nu_u>\nu_b$. Restrictions defining the implemented/theorem case must be reported separately from what external evidence supports. Keep contradictory evidence in the literature review.

\textbf{Research handoff.} For A and the free part of B, collect the original parameter definition, estimation or calibration method, population, frequency, range, V6 transformation and reason for transferability. HKT's numerical illustration and the present solver defaults are examples, not estimated benchmarks. The references below are verified starting points and conceptual comparisons, not a completed numerical literature review. HKT is pinned to the 2025 v2 used locally; the newer arXiv version was not substituted.

\begin{multicols}{2}\raggedright\fontsize{9}{10.5}\selectfont
"""

def table(group):
    result = [r'\begin{grouptable}']
    for row in ROWS:
        if row['group'] != group:
            continue
        id_separator = r'\par ' if row['entry_id'] in {'M13', 'M14', 'M15'} else ' '
        result.extend([
            f"% ENTRY: {row['entry_id']}; GROUP: {group}; FIELDS: {', '.join(row['code_fields'])}",
            r'\textbf{' + row['entry_id'] + '}' + id_separator + row['symbol'] + r'\par '
            + r'\textit{' + row['name'] + r'}\par '
            + r'{\footnotesize ' + row['assignment_status'] + '} & '
            + row['definition_and_reason'] + ' & ' + row['proposed_discipline']
            + (r'\\[3pt]' if group == 'B' else r'\\[5pt]')
        ])
    result.append(r'\end{grouptable}')
    return '\n'.join(result)

def main():
    source = (ROOT/'Codes/Two_country_proudction_zero_nu_b/TwoCountryProductionOLG.jl').read_text()
    economic = source.split('@with_kw struct ProductionParams', 1)[1].split('# ── Initial knowledge stocks', 1)[0]
    expected = re.findall(r'^\s*([^\s:]+)::Float64', economic, re.M)
    fields = [f for r in ROWS for f in r['code_fields']]
    assert len(expected) == len(fields) == len(set(fields)) == 30
    assert set(fields) == set(expected), (set(expected)-set(fields), set(fields)-set(expected))
    assert sorted(r['entry_id'] for r in ROWS) == [f'M{i:02d}' for i in range(1,18)]
    assert Counter(r['group'] for r in ROWS) == {'A':4, 'B':9, 'C':4}
    assert Counter(r['group'] for r in ROWS for _ in r['code_fields']) == {'A':9, 'B':16, 'C':5}
    assert {s for r in ROWS for s in r['references']} <= {s['id'] for s in SOURCES}
    manuscript = (ROOT/'AI_drafting/V6_production.tex').read_text()
    for row in ROWS:
        for label in row['v6_labels']:
            assert r'\label{'+label+'}' in manuscript, (row['entry_id'], label)
    baseline_paths = [
        'AI_drafting/V6_production.tex',
        'Codes/Two_country_proudction_zero_nu_b/TwoCountryProductionOLG.jl',
        'Codes/Two_country_proudction_zero_nu_b/06_post2008_ahp_nfa_calibration_search_zero_nu_b.ipynb',
        'Codes/Calibration_R1/V6_calibration_core.tex',
        'Codes/Calibration_R1/V6_calibration_core.pdf',
        'Codes/Calibration_R1/V6_calibration_measurability.tex',
        'Codes/Calibration_R1/V6_calibration_measurability.pdf',
        'Codes/Calibration_R1/V6_calibration_measurability.csv',
        'Codes/Reference/Atkeson_2025_End_of_Privilege.tex',
        'Codes/Reference/Hirano_2025_Bursting_Bubbles_LaTeX/Hirano et al. - 2025 - Technological Innovation and Bursting Bubbles.tex',
    ]
    hashes = {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in baseline_paths}
    baseline = HERE/'baseline_hashes.json'
    if baseline.exists():
        assert json.loads(baseline.read_text()) == hashes, 'Reviewed baseline changed; refresh the review explicitly.'
    else:
        baseline.write_text(json.dumps(hashes, indent=2, ensure_ascii=False)+'\n')
    doc = [PREAMBLE, table('A'), BETWEEN_B, table('B'), BETWEEN_C, table('C'), AFTER_C, END]
    for s in SOURCES:
        doc.append(r'\noindent\begin{minipage}{\linewidth}\raggedright'
            + r'\hypertarget{ref:' + s['id'] + r'}{\textbf{' + s['label'] + '}} '
            + s['authors'] + f" ({s['year']}). "
            + r'\href{' + s['url'] + '}{' + s['title'] + '}'
            + (' ' if s['title'].endswith('?') else '. ')
            + r'\emph{' + s['venue'] + r'}.\par '
            + s['use'] + r'\end{minipage}\par\vspace{6pt}')
    doc.append(r'\end{multicols}')
    doc.append(r'\small\textbf{Provenance.} Definitions were checked in \code{V6\_production.tex}, \code{TwoCountryProductionOLG.jl} and the existing calibration core on 27 September 2026. Publisher/author sources were checked for the listed literature. The companion CSV and \code{parameter\_group\_evidence/} retain the code-field crosswalk, equation labels, source URLs and baseline hashes. This document makes no changes to the model or the measurability classification.')
    doc.append(r'\end{document}')
    tex = '\n'.join(doc)
    assert not re.search(r'[\x00-\x08\x0b-\x1f]', tex)
    (OUT/'V6_parameter_calibration_groups.tex').write_text(tex)
    (HERE/'rows.json').write_text(json.dumps(ROWS, ensure_ascii=False, indent=2)+'\n')
    (HERE/'sources.json').write_text(json.dumps(SOURCES, ensure_ascii=False, indent=2)+'\n')
    with (OUT/'V6_parameter_calibration_groups.csv').open('w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=list(ROWS[0]))
        writer.writeheader()
        for row in ROWS:
            writer.writerow({k:';'.join(v) if isinstance(v, list) else v for k,v in row.items()})
    report = dict(checked_at=datetime.now(timezone.utc).isoformat(),
        parameter_families=len(ROWS), scalar_fields=len(fields),
        families_by_group=dict(Counter(r['group'] for r in ROWS)),
        scalars_by_group=dict(Counter(r['group'] for r in ROWS for _ in r['code_fields'])),
        all_code_fields_covered_once=True, all_v6_labels_exist=True,
        reviewed_baselines_unchanged=True, selected_parameter_values=False,
        classification_basis='Proposed assignment strategy; not a structural identification result.')
    (HERE/'coverage.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report, indent=2))

if __name__ == '__main__':
    main()
