#!/usr/bin/env python3
"""Run an explicit, isolated calibration folder (see README.md)."""
from pathlib import Path
import runpy
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent/'shared'))
if __name__=='__main__':
    runpy.run_path(str(Path(__file__).resolve().parent/'shared/run_calibration.py'),run_name='__main__')
