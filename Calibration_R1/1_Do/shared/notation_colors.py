"""Colour-code model notation in a generated Beamer deck.

Four classes, decided by symbol (not by slide):
  * raw data and externally fixed parameters -> default ink (unchanged)
  * series constructed from raw data      -> \\con  (violet); inherit raw-data quality
  * implied / inferred series             -> \\imp  (orange)
  * internally estimated parameters       -> \\est  (teal)

Implied series:  X, varphi, I (research payroll), A_X, A_L, N (incl. N^Q, N(a), N_t),
                 G^Q, G^a, a_t^imp, widehat Q, mathcal D.
Estimated:       a, xi_u, nu_u, bar A_{X,u}, bar A_{L,u}; vartheta only on the P3 slide,
                 where it is estimated rather than assigned.
Constructed:     w_H, w_L (wage bridge from e, H, L and the skill premium) and the P3
                 ratios x, y built from them. The ratio w_H/w_L itself is the raw premium.
Data (uncoloured): Y, e, Q, H, L, premium w_H/w_L, cash flow.

Usage: python notation_colors.py path/to/main.tex   (idempotent; rewrites in place)
"""
import re
import sys
from pathlib import Path

MARK = '% notation-colors: data = ink, implied series = imp, estimated parameters = est'
PREAMBLE = MARK + r'''
\definecolor{impcol}{HTML}{C25E00}
\definecolor{estcol}{HTML}{00838A}
\newcommand{\imp}[1]{{\color{impcol}#1}}
\newcommand{\est}[1]{{\color{estcol}#1}}
\definecolor{concol}{HTML}{6F3CC3}
\newcommand{\con}[1]{{\color{concol}#1}}
'''
KEY = (r'\node[anchor=north east,inner sep=0pt,outer sep=0pt,align=right,font=\sffamily\fontsize{10.5}{12.6}\selectfont] '
       r'at (30.8cm,-0.62cm) {\textcolor{gray}{Notation:}\enspace \textcolor{ink}{raw data / fixed parameter}'
       r'\enspace\textcolor{gray}{$\cdot$}\enspace \textcolor{concol}{constructed from data}'
       r'\enspace\textcolor{gray}{$\cdot$}\enspace \textcolor{impcol}{implied / inferred series}'
       r'\enspace\textcolor{gray}{$\cdot$}\enspace \textcolor{estcol}{estimated parameter}};' + '\n')

PROTECT = {r'\mathrm', r'\operatorname', r'\text', r'\textrm'}
IMP_CMDS = {r'\varphi', r'\I'}
EST_CMDS = {r'\xi', r'\nu'}


def tokens(s):
    """Split math into tokens: control words, escaped chars, braced groups, single chars."""
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == '\\':
            m = re.match(r'\\[A-Za-z]+|\\.', s[i:])
            out.append(m.group()); i += len(m.group())
        elif c == '{':
            depth, j = 0, i
            while True:
                depth += {'{': 1, '}': -1}.get(s[j], 0)
                if s[j] == '\\':
                    j += 1
                elif depth == 0:
                    break
                j += 1
            out.append(s[i:j + 1]); i = j + 1
        else:
            out.append(c); i += 1
    return out


def color_math(s, est_vartheta=False):
    s = s.replace(r'\mathcal D', r'\mathcal{D}')
    t, out, i = tokens(s), [], 0

    def scripts(k):
        """Index after any _x / ^{...} chain starting at k."""
        while k + 1 < len(t) and t[k] in '_^':
            k += 2
        return k

    while i < len(t):
        tok, nxt = t[i], (t[i + 1] if i + 1 < len(t) else '')
        prev = t[i - 1] if i else ''
        cls, end = None, i + 1
        if tok in PROTECT:
            out.append(tok + nxt); i += 2; continue
        if tok.startswith('{'):
            out.append('{' + color_math(tok[1:-1], est_vartheta) + '}'); i += 1; continue
        # A bare letter, unless it is the argument of an accent/font command.
        letter = len(tok) == 1 and tok.isalpha() and prev not in (
            r'\mathcal', r'\bar', r'\hat', r'\widehat', r'\tilde', r'\mathbf')
        if tok == r'\frac' and nxt.startswith('{w_') and i + 2 < len(t) and t[i + 2].startswith('{w_'):
            out.extend(t[i:i + 3]); i += 3; continue  # \frac{w_H}{w_L} = raw premium
        if letter and tok == 'w' and nxt == '_':
            k = scripts(i + 1)
            if t[k:k + 2] == ['/', 'w']:  # w_H/w_L = raw premium: leave uncoloured
                k2 = scripts(k + 2)
                out.extend(t[i:k2]); i = k2; continue
            cls, end = 'con', k
        elif tok == r'\widehat' and nxt == r'\Q':
            cls, end = 'imp', scripts(i + 2)
        elif tok == r'\mathcal' and nxt == '{D}':
            cls, end = 'imp', scripts(i + 2)
        elif tok in IMP_CMDS:
            cls, end = 'imp', scripts(i + 1)
        elif tok in EST_CMDS:
            cls, end = 'est', scripts(i + 1)
        elif tok == r'\vartheta' and est_vartheta:
            cls, end = 'est', scripts(i + 1)
        elif tok == r'\barAX' or tok == r'\barAL':
            cls, end = 'est', i + 1
        elif letter and tok == 'A' and nxt == '_' and i + 2 < len(t) and t[i + 2] in ('X', 'L'):
            cls, end = 'imp', i + 3
        elif letter and tok == 'N' and t[i + 1:i + 4] == ['(', 'a', ')']:
            cls, end = 'imp', i + 4
        elif letter and tok in ('X', 'N', 'G'):
            cls, end = 'imp', scripts(i + 1)
        elif letter and tok in ('x', 'y') and est_vartheta:
            cls, end = 'con', i + 1  # P3 regression ratios built from w_H, w_L
        elif letter and tok == 'a' and nxt == '_':
            cls, end = 'imp', scripts(i + 1)  # a_t^imp: datewise inversion
        elif letter and tok == 'a':
            cls, end = 'est', scripts(i + 1)
        if cls:
            # Outer braces keep the colour group a single argument (e.g. after \frac).
            out.append('{\\' + cls + '{' + ''.join(t[i:end]) + '}}'); i = end
        else:
            out.append(tok); i += 1
    return ''.join(out)


def color_line(line, est_vartheta=False):
    out, buf, in_math, i = [], [], False, 0
    while i < len(line):
        c = line[i]
        if c == '\\' and i + 1 < len(line):
            (buf if in_math else out).append(line[i:i + 2]); i += 2; continue
        if c == '$':
            if in_math:
                out.append('$' + color_math(''.join(buf), est_vartheta) + '$'); buf = []
            in_math = not in_math; i += 1; continue
        (buf if in_math else out).append(c); i += 1
    assert not in_math, line
    return ''.join(out)


def colorize(tex):
    if MARK in tex:
        return tex
    head, body = tex.split(r'\begin{document}', 1)
    head = head.replace(r'\newcommand{\Q}', PREAMBLE + r'\newcommand{\Q}', 1)
    lines, slide = [], 0
    for line in body.split('\n'):
        m = re.match(r'% =+ SLIDE (\d+):', line)
        if m:
            slide = int(m.group(1))
        if line.lstrip().startswith('%'):
            lines.append(line); continue
        # Equation callouts: render in ink so only the notation carries colour.
        line = line.replace('text width=9.3cm,text=blue,', 'text width=9.3cm,text=ink,')
        # Fitted Q (free-entry fit) is model-implied although it shares the symbol.
        line = line.replace(r'{Fitted $\Q$}', r'{Fitted $\widehat\Q$}')
        line = color_line(line, est_vartheta=(slide == 16))
        lines.append(line)
        if line.startswith(r'\begin{scope}[shift={(current page.north west)}]'):
            lines.append(KEY.rstrip('\n'))
    return head + r'\begin{document}' + '\n'.join(lines)


if __name__ == '__main__':
    p = Path(sys.argv[1])
    p.write_text(colorize(p.read_text()))
    print('colorized', p)
