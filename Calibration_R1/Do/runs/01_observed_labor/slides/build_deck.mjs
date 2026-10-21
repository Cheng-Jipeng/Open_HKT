// Editable calibration evidence. Runtime paths may be overridden on another Mac.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {execFileSync} from 'node:child_process';
const HERE=path.dirname(fileURLToPath(import.meta.url));
const BUILD=path.join(HERE,'.build');
const OUT=path.join(HERE,'output');
const MODULES=process.env.CALIBRATION_NODE_MODULES || '/Users/jipengcheng/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
process.env.RUNTIME_NODE_MODULES=MODULES;
const PYTHON=process.env.CALIBRATION_PYTHON || '/Users/jipengcheng/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3';
const SKILL=process.env.CALIBRATION_PRESENTATION_SKILL || '/Users/jipengcheng/.codex/plugins/cache/openai-primary-runtime/presentations/26.1011.11113/skills/presentations';
const SOFFICE=process.env.CALIBRATION_SOFFICE || '/Users/jipengcheng/.cache/codex-runtimes/codex-primary-runtime/dependencies/bin/override/soffice';
const {Presentation,PresentationFile}=await import(pathToFileURL(path.join(MODULES,'@oai/artifact-tool/dist/artifact_tool.mjs')));
const {applyPresentationChartFont,finalizePresentation}=await import(pathToFileURL(path.join(SKILL,'container_tools/artifact_tool_utils.mjs')));
const D=JSON.parse(await fs.readFile(path.join(BUILD,'slide_data.json'),'utf8'));
const {series:p,base:b,joint:j,sequential:s,config:c,metrics:m,diagnosis:dg,growth:g}=D;
const F='Arial';
const C={ink:'#253642',blue:'#24628A',green:'#2D7D68',purple:'#80639E',red:'#AD3D3D',gray:'#66737C',grid:'#DFE5E9'};
const W=1600,H=900;
const deck=Presentation.create({slideSize:{width:W,height:H}});
const years=p.year, n=years.length, first=years[0],last=years.at(-1);
const f=(x,d=4)=>Number(x).toFixed(d);
const pct=(x,d=2)=>`${f(100*x,d)}%`;
const constant=(v,xx=years)=>xx.map(()=>v);
const mul=(a,v)=>a.map(x=>v*x);
const index=a=>a.map(x=>100*x/a[0]);
// Excel chart workbooks store at most 15 significant digits. Round only the
// presentation snapshot to 12 digits, preserving full precision in slide_data.json.
const excelNumber=x=>Number(Number(x).toPrecision(12));
const sources={
  data:'Preserved September 2026 Fed/BEA and CPS mappings',
  procedure:'Evaluate Calibration Strategy, 6ac158c6-38ac-83ec-b89d-5a50c4a990b6. Read 12 October 2026. Local reference_conversation.md preserves the equations. The embedded pseudocode object was unavailable. Equations were checked against Codes/Calibration_R1/Plan/V6_parameter_identifying_moments.tex and Do/calibration.py.',
  macro:'Empirical_Data/Variable_mappings/Empirical_Mapping_Annual/data_final/empirical_moments_us_annual.csv. IDs: Y_US_AHP_TOTAL_CORP_GVA, COMP_US_AHP_TOTAL_CORP, Q_US_AHP_ENTERPRISE_VALUE_TOTAL_CORP. Flows sum quarters, valuation uses Q4. GDPDEF annual mean deflates all monetary inputs. Exact source ledger in Do/results/mapping_provenance.csv.',
  labor:'CPS MORG private-for-profit BA+/non-BA headcounts. IDs H_US_COLLEGE_EQUIV, L_US_NONCOLLEGE, WHWL_US_CPS_COMPOSITION_ADJ_COLLEGE_NONCOLLEGE. Adjusted hourly premium holds 2007 within-group composition weights fixed. See labor_wages_methodology.md in the empirical package. Annual compensation is bridged, not directly observed by skill.',
  rho:'Oberfield and Raval (2021), Micro Data and Macro Technology, Econometrica 89(2), 703–732. https://doi.org/10.3982/ECTA12807 and https://ezraoberfield.github.io/CESAggregation.pdf. Abstract and pp. 703–705 report capital–labor elasticity 0.5–0.7 for US manufacturing. rho=2 uses sigma=0.5 as a maintained analogy to a different V6 input margin. Do/rho_selection.md records Gechert et al. (2022) as additional evidence.',
  markup:'The retained 1.61 benchmark follows the project source audit for De Loecker, Eeckhout and Unger (2020), 2016 US sales-weighted markup. https://doi.org/10.1093/qje/qjz041. The model has a homogeneous intermediate producer. Firm aggregation, marginal-cost definition and a constant 2009–2024 markup remain assumptions. See Do/reference_audit.md and the Plan production literature review. The 3.5 case is diagnostic and has no adopted external calibration status.',
  diagnosis:'Do/Spillover_Diagnosis/results/summary.json, mapping_sensitivity.csv and annual_mechanism.csv. Native Julia production recovery and independent wage derivative checks passed. These checks establish consistency of the production implementation, not empirical identification or a full GE solution.',
};
let page=0;
const chartOwners=[],tableOwners=[],slideManifest=[];

function text(slide,content,x,y,w,h,size=26,color=C.ink,bold=false,align='left'){
  const sh=slide.shapes.add({geometry:'textbox',position:{left:x,top:y,width:w,height:h},fill:'none',line:{fill:'none',width:0}});
  sh.text=content;
  sh.text.style={typeface:F,fontSize:size,color,bold,alignment:align,verticalAlignment:'top',autoFit:'none',wrap:'square',insets:0};
  return sh;
}
function slide(title,phase,context,takeaway,footnote,notes,warning=false){
  const sl=deck.slides.add(); page++;
  sl.background.fill='#FFFFFF';
  text(sl,phase.toUpperCase(),60,30,1450,28,19,C.blue,true);
  text(sl,title,60,71,1480,68,46,C.ink,true);
  text(sl,context,60,144,1480,42,23,C.gray);
  text(sl,takeaway,60,777,1480,64,27,warning?C.red:C.blue,true);
  text(sl,footnote,60,852,1400,28,17,C.gray);
  text(sl,String(page).padStart(2,'0'),1470,852,70,28,17,C.gray,false,'right');
  sl.speakerNotes.text=`${sources.procedure}\n\n${notes}\n\nRun: ${first}–${last}. All ${n} dates are fitting observations. One annual period is a conditional production convention. The full OLG generation mapping and GE calibration are outside this run.\n\nNotation: phi denotes skilled production allocation, not the portfolio wedge varphi. theta=1/mu. Technology scale units follow trillion 2017 USD and million workers.\n\nSource hashes: Slides/.build/slide_data.json, provenance.`;
  slideManifest.push({number:page,title,phase,context,takeaway});
  return sl;
}
function block(sl,label,body,y,{size=25,height=95,color=C.ink}={}){
  text(sl,label.toUpperCase(),60,y,455,25,18,C.gray,true);
  text(sl,body,60,y+32,455,height,size,color);
}
function equation(sl,body,y,height=110,size=27){text(sl,body,60,y,455,height,size,C.blue);}
function series(name,values,color,{dash=false,x=years,markers=false}={}){
  return {name,values:values.map(excelNumber),xValues:x.map(excelNumber),smooth:false,line:{style:dash?'dashed':'solid',fill:color,width:3},marker:{symbol:markers?'circle':'none',size:5,fill:color}};
}
function chart(sl,title,data,{x=550,y=220,w=475,h=500,unit='',xmin=first,xmax=last,xstep=3,ymin,ymax,ystep,format='0.0',xformat='0',point=false}={}){
  const obj=sl.charts.add('scatter',{
    position:{left:x,top:y,width:w,height:h},title,titlePlacement:'aboveChart',
    titleTextStyle:{fontSize:25,bold:true,fill:C.ink},
    scatterOptions:{style:point?'marker':'lineWithMarkers'},series:data,hasLegend:true,
    legend:{position:'bottom',overlay:false,textStyle:{fontSize:20,fill:C.ink}},
    chartFill:'#FFFFFF',plotAreaFill:'#FFFFFF',chartLine:{fill:'none',width:0},plotAreaLine:{fill:'none',width:0},
    xAxis:{min:xmin,max:xmax,majorUnit:xstep,numberFormatCode:xformat,position:'bottom',tickLabelPosition:'low',
      textStyle:{fontSize:18,fill:C.gray},line:{fill:'#AAB6BE',width:1},majorGridlines:null},
    yAxis:{...(ymin!==undefined?{min:ymin}:{}),...(ymax!==undefined?{max:ymax}:{}),...(ystep!==undefined?{majorUnit:ystep}:{}),
      numberFormatCode:format,position:'left',textStyle:{fontSize:18,fill:C.gray},
      ...(unit?{title:{text:unit,textStyle:{fontSize:19,fill:C.gray}}}:{}),
      line:{fill:'#AAB6BE',width:1},majorGridlines:{fill:C.grid,width:1}},
  });
  applyPresentationChartFont(obj,{fontFamily:F});
  if(!chartOwners.includes(page))chartOwners.push(page);
  return obj;
}
function table(sl,values,{x=550,y=225,w=990,h=480,widths,size=25}={}){
  const t=sl.tables.add({rows:values.length,columns:values[0].length,left:x,top:y,width:w,height:h,values,
    ...(widths?{columnWidths:widths}:{})});
  t.styleOptions={headerRow:false,bandedRows:false};
  t.borders.assign({fill:'#DFE5E9',width:.7,style:'solid'});
  t.cells.block({row:0,column:0,rowCount:values.length,columnCount:values[0].length}).assign({
    fill:'#FFFFFF',textStyle:{typeface:F,fontSize:size,color:C.ink},margins:{top:10,right:14,bottom:9,left:14},anchor:'center',
  });
  for(let r=0;r<values.length;r++)for(let col=0;col<values[0].length;col++){
    const cell=t.getCell(r,col);
    cell.text.style={typeface:F,fontSize:size,color:r===0?C.blue:C.ink,bold:r===0,verticalAlignment:'middle',insets:12};
    if(r===0)cell.fill='#EEF3F6';
  }
  if(!tableOwners.includes(page))tableOwners.push(page);
  return t;
}
const conditional=`${first}–${last}. Conditional diagnostic: μ = ${c.central_diagnostic_markup}, θ = ${f(j.theta,4)}, ρ = ${j.rho}`;
const auditFoot='Source: saved Calibration R1 outputs. Full source mappings and equations appear in the speaker notes.';
let sl;

// 01. Macro input phase.
sl=slide('Corporate output, compensation and valuation','Input phase 1',`${first}–${last}. ${n} complete annual observations from the preserved September 2026 package`,
  '2024 is the latest common year in this data package. Every displayed year enters the fit.',
  'Corporate accounts extend to 2025. Labor quantities and the skill premium end in 2024.',sources.macro);
block(sl,'Input series','Output Y, total compensation C\nOperating enterprise value Q',225);
block(sl,'External choices','Annual period\nCommon GDP deflator, 2017 = 100',364);
block(sl,'Internal calibration','None at this phase\nThe panel supplies later moments',503);
equation(sl,'Money: trillion 2017 USD\nY and C: annual flows\nQ: year-end stock',638,110,25);
chart(sl,'Corporate flows',[series('Output Y',p.Y,C.blue),series('Compensation C',p.COMP,C.green)],{unit:'Trillion 2017 USD / year',ymin:0,ymax:15,ystep:3});
chart(sl,'Operating enterprise value',[series('Observed Q',p.Q,C.blue)],{x:1065,unit:'Trillion 2017 USD',ymin:0,ymax:70,ystep:10});

// 02. Labor input and wage bridge.
sl=slide('Labor quantities and the wage bridge','Input phase 2',`${first}–${last}. BA+ skilled labor and non-BA unskilled labor in CPS private-for-profit employment`,
  'The bridge exactly allocates total compensation, but the skill-specific annual bills remain inferred.',
  'Observed annual H and L relax fixed-endowment GE. The hourly premium does not directly measure annual compensation.',sources.labor+'\n'+sources.macro);
block(sl,'Input series','H, L, adjusted premium r\nTotal compensation C',225);
block(sl,'External choices','Million persons\n2007 composition weights for r',360);
block(sl,'Inferred series','Annual wages wH and wL\nNo structural parameter estimated',495);
equation(sl,'wL = C / (rH + L)\nwH = r × wL',627,110,29);
chart(sl,'Labor endowments',[series('Skilled H',p.H,C.blue),series('Unskilled L',p.L,C.green)],{y:220,h:255,unit:'Million persons',ymin:0,ymax:80,ystep:20});
chart(sl,'Adjusted skill premium',[series('wH / wL',p.premium,C.purple)],{x:1065,y:220,h:255,ymin:1.75,ymax:2.25,ystep:.1,format:'0.00'});
chart(sl,'Annual compensation per worker',[series('Skilled wH',mul(p.wH,1000),C.blue),series('Unskilled wL',mul(p.wL,1000),C.green)],{x:550,y:490,w:990,h:260,unit:'Thousand 2017 USD',ymin:30,ymax:110,ystep:20});

// 03. Fixed parameters, assumptions and normalizations.
sl=slide('External parameters and normalizations','Specification phase',`${first}–${last}. The external benchmark and the higher-markup diagnostic have different roles`,
  'ρ = 2 respects complementarity. Its capital–labor literature basis is an analogy for the V6 input margin.',
  'Sources: Oberfield and Raval (2021). Markup benchmark follows the project audit of De Loecker et al. (2020).',sources.rho+'\n'+sources.markup);
block(sl,'Inputs','Literature and model primitives\nMeasurement and period choices',225);
block(sl,'Externally assigned','ρ = 2, substitution elasticity = 0.5\nBaseline μ = 1.61',375);
block(sl,'Normalized','α = 0.5\nN at the start of 2009 = 1',525);
equation(sl,'θ = 1 / μ\nDiagnostic μ = 3.5',659,80,28);
table(sl,[['Object','Value','Role'],['ρ / elasticity','2 / 0.5','Maintained complementarity'],['Baseline μ / θ','1.61 / 0.6211','External benchmark'],['Diagnostic μ / θ','3.50 / 0.2857','Conditional experiment'],['α','0.50','Technology-scale normalization'],['N₂₀₀₉','1','Knowledge-unit normalization'],['Period','1 year','Conditional production timing'],['H, L','Observed annually','Extension of fixed endowments'],['Regime','u throughout','Maintained sample assignment']],{h:500,widths:[210,245,535],size:24});

// 04. P1 allocation.
sl=slide('P1: production and research allocation','Step 1',`${first}–${last}. Baseline μ = 1.61 and diagnostic μ = 3.5 use the same measured panel`,
  'The baseline fails in all 16 years. Later steps proceed only in the explicitly labelled diagnostic case.',auditFoot,sources.macro+'\n'+sources.labor+'\nDo/results/baseline_allocation.csv and conditional_paths.csv.',true);
block(sl,'Input series','Y, wH, wL, H and L',225,{height:65});
block(sl,'External parameter','θ = 1 / μ\nρ does not enter P1',331);
block(sl,'Inferred quantities',`X, φ = X / H, research payroll I\nBaseline φ: ${f(Math.min(...b.phi),3)}–${f(Math.max(...b.phi),3)}`,467);
equation(sl,'X = θ(Y − wL L) / wH\nI = wH(H − X)\nRequired: 0 < X < H and Q > I',605,130,25);
chart(sl,'Production share φ',[series('Baseline μ = 1.61',b.phi,C.red),series('Diagnostic μ = 3.5',p.phi,C.purple,{dash:true}),series('Zero-research boundary',constant(1),C.gray,{dash:true})],{ymin:0,ymax:2,ystep:.5,format:'0.0'});
chart(sl,'Implied research payroll',[series('Baseline I',b.I,C.red),series('Diagnostic I',p.I,C.purple,{dash:true}),series('Zero payroll',constant(0),C.gray,{dash:true})],{x:1065,unit:'Trillion 2017 USD / year',ymin:-2.5,ymax:1.5,ystep:1});

// 05. P2 innovation productivity.
sl=slide('P2: a constant innovation productivity','Step 2',conditional,
  `The sequential estimate is a = ${f(s.a,6)}. Relative valuation RMSE is ${pct(s.free_entry_relative_rmse)}.`,auditFoot,
  'Do/calibration.py: sequential. Free-entry WLS minimizes mean[((Q-I-wH/a)/Q)^2]. It estimates b=1/a analytically. The datewise a series is a diagnostic, not a separate time-varying parameter.\n'+sources.macro);
block(sl,'Input and inherited series','Observed Q and wH\nResearch payroll I from P1',225);
block(sl,'External and fitting choices','Diagnostic μ = 3.5\nRelative-Q residual scaling',364);
block(sl,'Internally estimated',`a = ${f(s.a,9)}\nDatewise a dispersion: CV ${pct(s.a_implied_cv,1)}`,503);
equation(sl,'aₜ = wHₜ / (Qₜ − Iₜ)\nQ̂ₜ = Iₜ + wHₜ / a',637,110,28);
chart(sl,'Implied innovation productivity',[series('Datewise inversion',p.a_implied,C.purple),series('Constant a estimate',constant(s.a),C.green,{dash:true})],{unit:'Per million workers per year',ymin:.001,ymax:.0055,ystep:.001,format:'0.000'});
chart(sl,'Free-entry valuation fit',[series('Observed Q',p.Q,C.blue),series('Fitted Q',p.Q_sequential_fit,C.purple,{dash:true})],{x:1065,unit:'Trillion 2017 USD',ymin:0,ymax:70,ystep:10});

// 06. Knowledge growth and timing.
sl=slide('P2: knowledge growth and accumulation','Step 3',conditional,
  'The joint estimator uses the innovation-law path N(a). The valuation-implied path remains a diagnostic.',
  'Each growth rate dated t links Nₜ to Nₜ₊₁. The 2024 rate produces N₂₀₂₅ outside the plotted stock window.',
  'Do/calibration.py: log_knowledge and fitted_path. Q=N_(t+1)q is post-entry capitalization. Current N excludes current growth. Sequential N_Q uses G_Q. Final joint N uses G_a. These paths differ when constant a does not exactly fit free entry.');
block(sl,'Input and inherited series','Q, I, H − X and fitted a',225,{height:70});
block(sl,'Normalization','N₂₀₀₉ = 1\nOne annual production period',337);
block(sl,'Inferred paths',`N₂₀₂₄ from Q: ${f(p.N_Q.at(-1),4)}\nN₂₀₂₄ from fitted a: ${f(p.N.at(-1),4)}`,476);
equation(sl,'GQ = Q / (Q − I)\nGa = 1 + a(H − X)\nNₜ₊₁ = Nₜ Gₜ',611,130,28);
chart(sl,'Annual knowledge growth',[series('GQ − 1',p.growth_Q_percent,C.purple),series('Ga − 1',p.growth_a_percent,C.green,{dash:true})],{unit:'Percent per year',ymin:0,ymax:5,ystep:1});
chart(sl,'Normalized knowledge stock',[series('Valuation path NQ',p.N_Q,C.purple),series('Innovation path N(a)',p.N,C.green,{dash:true})],{x:1065,unit:'2009 = 1',ymin:1,ymax:1.5,ystep:.1,format:'0.00'});

// 07. P4 level inversions.
sl=slide('P4: effective CES coefficients','Step 4',conditional,
  'The two coefficients identify datewise augmentation only after fixing α. They reuse the wage and output data.',auditFoot,
  'Do/calibration.py: ces_coefficients and fitted_path. P4 gives effective coefficients, not separate identification of alpha and both augmentations. With rho=2, A_X=alpha/C_X and A_L=(1-alpha)/C_L. The chart levels depend on the declared money and labor units.');
block(sl,'Input and inherited series','Y, wH, wL, L\nProduction labor X from P1',225);
block(sl,'Fixed parameters','θ = 0.2857, ρ = 2\nα = 0.5 for augmentation levels',364);
block(sl,'Inferred series','CX, CL and datewise AX, AL\nNo constant scale fitted yet',503);
equation(sl,'CX = (wH / θ)(X / Y)²\nCL = wL(L / Y)²\nAX = α / CX,  AL = (1 − α) / CL',630,120,24);
chart(sl,'Effective coefficients',[series('CX',p.CX,C.blue),series('CL',p.CL,C.green)],{unit:'Coefficients in run units',ymin:0,ymax:3.5,ystep:.5});
chart(sl,'Datewise augmentation',[series('AX',p.AX_inverted,C.blue),series('AL',p.AL_inverted,C.green)],{x:1065,unit:'Levels in run units',ymin:.1,ymax:.45,ystep:.1,format:'0.00'});

// 08. P5 sequential differences.
sl=slide('P5: sequential spillover estimates','Step 5',`${conditional}. Fifteen transitions from 2009–2010 through 2023–2024`,
  `The sequential estimates already fail the ordering: ξ = ${f(s.xi,4)} and ν = ${f(s.nu,4)}.`,
  'The horizontal axis dates the start of each transition. Final joint estimates appear on slide 10.',
  'Do/calibration.py: sequential. Each equation regresses Δlog C on (1-rho)log G_Q without an intercept. Labor uses observed annual L_t in the conditional extension. These estimates seed diagnosis, not the final joint path. P5 differences contain the same information as P4 levels and must not be counted again.',true);
block(sl,'Input and inherited series','CX, CL from P4\nValuation-implied growth GQ',225);
block(sl,'Fixed parameter','ρ = 2\n(1 − ρ) = −1',364);
block(sl,'Internally estimated',`Sequential ξ = ${f(s.xi,6)}\nSequential ν = ${f(s.nu,6)}`,503);
equation(sl,'Δ log CX = (1 − ρ) ξ log G\nΔ log CL = (1 − ρ) ν log G',635,110,25);
chart(sl,'Skilled coefficient growth',[series('Observed Δ log CX',g.delta_log_CX,C.blue,{x:g.year}),series('Sequential fitted value',g.fit_CX,C.purple,{dash:true,x:g.year})],{unit:'Log change',xmax:2023,ymin:-.15,ymax:.15,ystep:.05,format:'0.00'});
chart(sl,'Unskilled coefficient growth',[series('Observed Δ log CL',g.delta_log_CL,C.green,{x:g.year}),series('Sequential fitted value',g.fit_CL,C.purple,{dash:true,x:g.year})],{x:1065,unit:'Log change',xmax:2023,ymin:-.2,ymax:.15,ystep:.05,format:'0.00'});

// 09. Sequential intercepts.
sl=slide('Productivity scales over the sequential path','Step 6',`${conditional}. Sequential NQ, ξ and ν enter this phase`,
  'Full-sample log intercepts use all dates. The initial-date inversions remain a useful comparison.',auditFoot,
  'Do/calibration.py: sequential. The scale is exp(mean(log A_inverted - exponent*log N_Q)). Initial scales use N_2009=1 and only the 2009 P4 inversion. Joint scales on slide 10 use the joint N(a), xi and nu and differ from these sequential scales.');
block(sl,'Input and inherited series','Datewise AX and AL\nSequential NQ, ξ and ν',225);
block(sl,'Normalizations','α = 0.5\nN₂₀₀₉ = 1',364);
block(sl,'Internally estimated',`Sequential ĀX = ${f(s.AX,5)}\nSequential ĀL = ${f(s.AL,5)}`,503);
equation(sl,'log ĀX = mean(log AX − ξ log N)\nlog ĀL = mean(log AL − ν log N)',635,110,24);
chart(sl,'Skilled scale diagnostic',[series('AX / NQ^ξ',p.AX_scale_sequential,C.blue),series('Fitted constant scale',constant(s.AX),C.purple,{dash:true}),series('Initial-date scale',constant(s.AX_initial),C.gray,{dash:true})],{unit:'Scale in run units',ymin:.28,ymax:.40,ystep:.04,format:'0.00'});
chart(sl,'Unskilled scale diagnostic',[series('AL / NQ^ν',p.AL_scale_sequential,C.green),series('Fitted constant scale',constant(s.AL),C.purple,{dash:true}),series('Initial-date scale',constant(s.AL_initial),C.gray,{dash:true})],{x:1065,unit:'Scale in run units',ymin:.12,ymax:.22,ystep:.02,format:'0.00'});

// 10. Final conditional joint estimator.
sl=slide('Joint production fit','Joint estimation phase',conditional,
  'The joint fit uses each structural restriction once. It profiles a and fits both technology regressions.',
  'The three objective blocks have equal weights. The free-entry residual is divided by Q before squaring.',
  'Do/calibration.py: joint_fit. Objective = mean[((Q-I-wH/a)/Q)^2] + mean[rX^2] + mean[rL^2], where rX = log CX-log alpha-(1-rho)(log AXbar+xi log N(a)), analogously for rL. Conditional on a, intercept and slope regressions solve exactly. The grid profiles log a and refines all interior local minima. Sequential differences are not additional moment blocks.');
block(sl,'Input and inherited series','Q, I, wH, H − X\nCX and CL',225);
block(sl,'Fixed parameters','θ = 0.2857, ρ = 2\nα = 0.5, N₂₀₀₉ = 1',355);
block(sl,'Joint estimates',`a = ${f(j.a,9)}\nξ = ${f(j.xi,6)}     ν = ${f(j.nu,6)}\nĀX = ${f(j.AX,6)}\nĀL = ${f(j.AL,6)}`,485,{height:145,size:27});
equation(sl,'log AX = log ĀX + ξ log N(a)\nlog AL = log ĀL + ν log N(a)',654,100,24);
chart(sl,'Skilled augmentation regression',[series('Inverted log AX',p.log_AX,C.blue,{x:p.log_N_joint,markers:true}),series('Joint fit',p.log_AX_joint,C.purple,{dash:true,x:p.log_N_joint})],{unit:'Log augmentation',xmin:0,xmax:.4,xstep:.1,xformat:'0.0',ymin:-1.2,ymax:-.9,ystep:.1,format:'0.00'});
chart(sl,'Unskilled augmentation regression',[series('Inverted log AL',p.log_AL,C.green,{x:p.log_N_joint,markers:true}),series('Joint fit',p.log_AL_joint,C.purple,{dash:true,x:p.log_N_joint})],{x:1065,unit:'Log augmentation',xmin:0,xmax:.4,xstep:.1,xformat:'0.0',ymin:-1.9,ymax:-.9,ystep:.2,format:'0.0'});
text(sl,'Horizontal axes: log N from the joint innovation path',620,730,900,28,19,C.gray);

// 11. Fit assessment.
sl=slide('Targeted fit and an untargeted cash-flow check','Fit assessment phase',conditional,
  'Good production fit coexists with large valuation and cash-flow errors. No holdout or GE validation is available.',
  'Cash flow is a separate mapping check. Its relative RMSE uses observed cash flow in the denominator.',
  'Do/results/fit_metrics.csv. Y and wage errors compare fitted CES production at the P1 allocation against input series. Q is already targeted. D is the preserved AHP-style net cash-flow mapping, compared to incumbent profits minus research payroll. The mapping remains qualified. No independent general-equilibrium validation is implied.',true);
block(sl,'Input and inherited series','Observed and fitted Y, wages, Q\nUntargeted net cash flow',225);
block(sl,'Parameters used','The five joint estimates\nSame θ, ρ and normalizations',364);
block(sl,'Relative RMSE',`Y: ${pct(m.Y_relative_rmse)}\nwH: ${pct(m.wH_relative_rmse)}   wL: ${pct(m.wL_relative_rmse)}\nQ: ${pct(m.Q_relative_rmse)}\nCash flow: ${pct(m.untargeted_FCF_relative_rmse,1)}`,503,{height:150,size:26});
chart(sl,'Output fit',[series('Observed Y',p.Y,C.blue),series('CES fit',p.Y_fit,C.purple,{dash:true})],{unit:'Trillion 2017 USD / year',ymin:8,ymax:15,ystep:2});
chart(sl,'Net cash flow check',[series('Observed net cash flow',p.D,C.gray),series('Model profits minus research',p.net_cashflow_fit,C.purple,{dash:true})],{x:1065,unit:'Trillion 2017 USD / year',ymin:0,ymax:10,ystep:2});

// 12. Primitive restriction diagnosis.
sl=slide('The relative-wage restriction reverses the ordering','Restriction diagnosis phase',conditional,
  `The relative-input term contributes ${f(100*dg.relative_input_fraction_of_gap,1)}% of the negative fitted gap. This is an algebraic decomposition.`,auditFoot,
  sources.diagnosis+'\nAt rho=2, xi-nu = -slope(log premium on log N) - 2 slope(log X/L on log N). Contributions are -0.0747888 and -1.7448188. The manuscript restriction is xi_u>nu_u>nu_b>=0. The weaker production-only screen xi>nu>=0 already fails. Nu itself is positive.',true);
block(sl,'Input and inherited series','Skill premium, X / L and N(a)',225,{height:70});
block(sl,'Fixed assumption','ρ = 2, so (1 − ρ) < 0',337,{height:65});
block(sl,'Restriction result',`ξ − ν = ${f(j.xi-j.nu,4)}\nNecessary screen: ξ > ν ≥ 0\nNu is positive. Xi and the ordering fail.`,443,{height:128,size:26,color:C.red});
equation(sl,'log(AX / AL) = constant\n− log(wH / wL) − 2 log(X / L)',623,110,26);
chart(sl,'Changes in the wage contrast',[series('Log premium change',p.log_premium_change,C.purple),series('2 × log(X/L) change',p.rho_log_XL_change,C.blue)],{unit:'Log difference from 2009',ymin:-.15,ymax:.75,ystep:.15,format:'0.00'});
chart(sl,'Relative skilled augmentation',[series('Log(AX/AL) change',p.log_relative_A_change,C.red)],{x:1065,unit:'Log difference from 2009',ymin:-1,ymax:.1,ystep:.2,format:'0.0'});

// 13. Mapping sensitivity evidence.
sl=slide('Mapping changes alter levels but preserve ξ < ν','Mapping sensitivity phase',conditional,
  'Fixing labor stocks makes ξ positive. None of the ten tested mappings or counterfactuals restores the ordering.',
  'The 2022 end-date case has 14 observations. All other cases use 2009–2024. Counterfactuals are labelled.',sources.diagnosis,true);
block(sl,'Input alternatives','Premium, hours, labor stocks\nSector, output concept and deflator',225);
block(sl,'Fixed parameters','μ = 3.5, ρ = 2\nα = 0.5, initial N = 1',364);
block(sl,'Re-estimated parameters','a, ξ, ν, ĀX and ĀL in every case',503,{height:80});
equation(sl,'Passing ordering cases\n0 / 10',631,105,32);
const labels={current_mapping:'Current mapping',through_2022:'End in 2022',fixed_HL_2007:'Fixed H,L at 2007',raw_hourly_premium:'Raw hourly premium',observed_hours_FTE:'Observed-hours FTE',raw_premium_FTE:'Raw premium + FTE',fixed_premium_2009:'Fixed 2009 premium',NFC_macro_same_labor:'Nonfinancial macro',net_factor_cost_output:'Net factor-cost output',quarterly_GVA_deflator:'Alternative deflator'};
table(sl,[['Mapping / counterfactual','ξ','ν','ξ − ν'],...D.mappings.map(v=>[labels[v.scenario],f(v.xi,3),f(v.nu,3),f(v.gap,3)])],{y:216,h:530,widths:[470,170,170,180],size:23});

// 14. Restrictions imposed as a diagnostic.
sl=slide('The restricted fit reaches equal spillovers','Constrained diagnostic phase',conditional,
  'The best closed-cone fit reaches ξ = ν. Equality still violates the strict unbalanced-growth primitive.',
  'The objective increase is conditional on the declared residual weights and is not a statistical rejection test.',sources.diagnosis+'\nConstrained fit imposes xi>=nu>=0, the closure of the strict restriction, profiles the same a range and analytically projects slopes for each a. This provides a lower-bound fit cost over the searched range for xi>nu. It is not adopted.',true);
block(sl,'Input and inherited series','Same Q, I, wH, research labor\nSame CX and CL',225);
block(sl,'Added restriction','ξ ≥ ν ≥ 0\nSame equal-weight objective',364);
block(sl,'Constrained estimates',`ξ = ν = ${f(dg.constrained.xi,6)}\na = ${f(dg.constrained.a,9)}\nĀX = ${f(dg.constrained.AX,6)}\nĀL = ${f(dg.constrained.AL,6)}\nObjective increase: ${pct(dg.constrained.objective_ratio-1)}`,503,{height:175,size:25});
chart(sl,'Skilled augmentation paths',[series('Datewise inversion',index(p.AX_inverted),C.gray),series('Unrestricted joint fit',index(p.AX_fit),C.blue),series('Constrained fit',index(p.constrained_AX_fit),C.red,{dash:true})],{unit:'2009 = 100',ymin:80,ymax:140,ystep:20});
chart(sl,'Unskilled augmentation paths',[series('Datewise inversion',index(p.AL_inverted),C.gray),series('Unrestricted joint fit',index(p.AL_fit),C.green),series('Constrained fit',index(p.constrained_AL_fit),C.red,{dash:true})],{x:1065,unit:'2009 = 100',ymin:80,ymax:220,ystep:40});

// 15. Alternative P3 route.
sl=slide('P3: an alternative joint markup route','Alternative identification phase',`${first}–${last}. This exercise frees θ and a and does not replace the external benchmark`,
  'The fitted positive slope implies a negative inverse markup. P3 also fails economic admissibility.',
  'With externally fixed θ, P3 reuses the same restriction as P2. It supplies no additional independent moment.',
  'Do/results/p3_diagnostic.json. Ratio OLS y=intercept+slope*x, theta=-slope, a=1/intercept. Relative-Q WLS separately gives theta=-10.8414 and a=-0.00178694. Both fail. This is the alternative P3 route in the identifying-moments document, rather than a required additional step in the external-markup calibration.',true);
block(sl,'Input series','Y, Q, wH, wL, H and L',225,{height:70});
block(sl,'Externally fixed','No external markup in this check\nSame sample and annual units',337);
block(sl,'Internally estimated',`θ = ${f(D.p3.ratio_OLS.theta,4)}\na = ${f(D.p3.ratio_OLS.a,7)}\nBoth are economically inadmissible`,476,{height:130,color:C.red});
equation(sl,'y = Q / wH − H\nx = (Y − wL L) / wH\ny = 1 / a − θx',637,120,27);
const order=p.P3_x.map((x,i)=>i).sort((a,b)=>p.P3_x[a]-p.P3_x[b]);
const x3=order.map(i=>p.P3_x[i]);
chart(sl,'P3 ratio regression',[{...series('Annual observations',p.P3_y,C.blue,{x:p.P3_x,markers:true}),line:{fill:'none',width:0}},series('Unrestricted OLS fit',order.map(i=>p.P3_fit[i]),C.red,{x:x3})],
  {w:990,unit:'y in annual model units',xmin:60,xmax:105,xstep:10,ymin:100,ymax:600,ystep:100,point:false,format:'0'});
text(sl,'Horizontal axis: x in annual model units',730,730,800,28,19,C.gray);

// 16. Final calibrated parameter ledger.
sl=slide('Parameter ledger and current calibration status','Run assessment phase',`${first}–${last}. US conditional production block. Full two-country equilibrium remains outside this run`,
  'No admissible baseline vector emerges. The next empirical step is matched factor quantities and compensation.',
  'The deck reports the completed calibration attempt, including failed restrictions and explicitly conditional estimates.',sources.diagnosis+'\n'+sources.markup+'\n'+sources.rho,true);
block(sl,'Input evidence','16 annual observations\nAll dates treated as regime u',225);
block(sl,'Baseline result','μ = 1.61 fails P1 in 16/16 years\nActive research needs μ > 2.8148',364,{color:C.red});
block(sl,'Conditional result','μ = 3.5 passes allocation checks\nξ < 0 and ξ < ν remain',503,{color:C.red});
equation(sl,'Priority measurement work\nAnnual skill-specific compensation\nComparable factor and sector coverage',637,120,25);
table(sl,[['Parameter','Value','Assignment'],['ρ',f(j.rho,2),'Externally assigned'],['μ',f(j.markup,2),'Diagnostic scenario'],['α',f(j.alpha,2),'Normalization'],['N₂₀₀₉',f(j.N0,0),'Normalization'],['a',f(j.a,9),'Joint conditional fit'],['ξ',f(j.xi,6),'Joint conditional fit'],['ν',f(j.nu,6),'Joint conditional fit'],['ĀX',f(j.AX,6),'Joint conditional fit'],['ĀL',f(j.AL,6),'Joint conditional fit']],{h:525,widths:[190,300,500],size:24});

await fs.mkdir(path.join(BUILD,'renders'),{recursive:true});
await fs.mkdir(OUT,{recursive:true});
await fs.writeFile(path.join(BUILD,'slide_manifest.json'),JSON.stringify({slides:slideManifest,chartOwners,tableOwners},null,2));
const draft=path.join(BUILD,'calibration_steps_draft.pptx');
await (await PresentationFile.exportPptx(deck)).save(draft);
execFileSync(PYTHON,[path.join(HERE,'set_chart_interpolation.py'),draft],{stdio:'inherit'});
console.log(`Authored ${deck.slides.items.length} slides. Draft: ${draft}`);
const previewOnly=process.argv.includes('--preview') || process.argv.includes('--render-all');
const previewIndexes=process.argv.includes('--finalize-only')?[]:
  process.argv.includes('--preview')?[0,2,7,9,12]:deck.slides.items.map((_,i)=>i);
for(const i of previewIndexes){
  const stem=`slide-${String(i+1).padStart(2,'0')}`;
  const blob=await deck.export({slide:deck.slides.items[i],format:'png',scale:1});
  await fs.writeFile(path.join(BUILD,'renders',stem+'.png'),new Uint8Array(await blob.arrayBuffer()));
  const layout=await deck.slides.items[i].export({format:'layout'});
  await fs.writeFile(path.join(BUILD,'renders',stem+'.layout.json'),await layout.text());
  console.log(`Rendered ${stem}`);
}
if(!previewOnly){
  const finalName=process.env.CALIBRATION_DECK_NAME || 'calibration_steps_2009_2024';
  const finalPath=path.join(OUT,finalName+'.pptx');
  const result=await finalizePresentation({workspaceDir:HERE,candidatePath:draft,finalPath,
    pythonExecutable:PYTHON,
    integrityValidatorPath:path.join(SKILL,'container_tools/inspect_presentation_package_integrity.py'),
    layoutValidatorPath:path.join(SKILL,'container_tools/inspect_presentation_layout_geometry.py'),
    layoutArgs:['--expected-slide-size-emu',`${W*9525},${H*9525}`,'--validate-heading-fit',
                ...tableOwners.flatMap(v=>['--require-native-table-slide',String(v)])],
    requiredNativeTableOwnerSlides:tableOwners,requiredNativeChartOwnerSlides:chartOwners,
    materializeLiteralChartWorkbooks:true,
    fontPolicy:{basis:'design',families:[F]},verifyArtifactToolImport:true,
    receiptPath:path.join(BUILD,finalName+'.validation.json')});
  console.log(JSON.stringify({finalPath,validated:true}));
  // Convert the exact finalized file with the bundled native presentation
  // renderer. This also preserves searchable text in the PDF.
  execFileSync(SOFFICE,['--headless','--convert-to','pdf','--outdir',OUT,finalPath],{stdio:'inherit'});
  console.log('Exported final PDF');
}
