"""Reproduce one fixed-mean run and its LaTeX report without changing Run 1."""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path


def main(run):
    run=Path(run).resolve();shared=Path(__file__).resolve().parent
    if run.name=='01_observed_labor':
        raise ValueError('Run 1 is a preserved historical result; choose a separate run directory')
    for script,extra in [('run_calibration.py',['--run',str(run)]),
                         ('test_calibration.py',['--output',str(run/'results/synthetic_tests.json')]),
                         ('build_report.py',['--run',str(run)]),
                         ('prepare_slide_data.py',['--run',str(run)]),
                         ('build_slides.py',['--run',str(run)])]:
        subprocess.run([sys.executable,'-B',str(shared/script),*extra],check=True)
    compiler=shutil.which('latexmk')
    if compiler is None and Path('/Library/TeX/texbin/latexmk').exists():
        compiler='/Library/TeX/texbin/latexmk'
    if compiler is None:
        raise RuntimeError('LaTeX source is ready; latexmk is unavailable for PDF export')
    latex=run/'slides/latex';latex.mkdir(parents=True,exist_ok=True)
    subprocess.run([compiler,'-norc','-pdf','-interaction=nonstopmode','-halt-on-error','-synctex=1',
                    '-outdir=../.build/latex','main.tex'],cwd=latex,check=True)
    output=run/'slides/output';output.mkdir(exist_ok=True)
    import json
    name=json.loads((run/'config.json').read_text()).get('slides_pdf_name','calibration_steps_2009_2024_fixed_mean_labor.pdf')
    dest=output/name
    shutil.copy2(run/'slides/.build/latex/main.pdf',dest)
    print('Rebuilt:',dest)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--run',required=True,type=Path)
    main(p.parse_args().run)
