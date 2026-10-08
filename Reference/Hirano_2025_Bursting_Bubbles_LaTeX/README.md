# Technological Innovation and Bursting Bubbles — LaTeX source

Tomohiro Hirano, Keiichi Kishi, and Alexis Akira Toda. Paper dated August 19, 2025; arXiv:2501.08215v2.

Open `main.tex`. This is the authors' original TeX source, recovered from the exact arXiv version matching the supplied PDF. The paper's equations, prose, proofs, numbering, footnotes, and figures are retained. An explicit date replaces the implicit build date so that recompilation keeps the date printed in the supplied PDF.

## Build

Use pdfLaTeX and Biber with a recent TeX Live or MacTeX installation:

```sh
latexmk -pdf -interaction=nonstopmode -halt-on-error main.tex
```

Alternatively:

```sh
pdflatex main.tex
biber main
pdflatex main.tex
pdflatex main.tex
```

For Overleaf, upload the accompanying ZIP as a new project, select `main.tex` as the main document and pdfLaTeX as the compiler, and use a recent TeX Live version.

## Files and provenance

- `main.tex`: original article source, with its date fixed to August 19, 2025.
- `test.sty`: the authors' original mathematical macros and theorem definitions.
- `localbib.bib`: editable bibliography reconstructed from the 52 entries in the authors' original `.bbl`, because the arXiv source archive did not include the referenced `.bib` file. Author and editor roles are preserved separately.
- `fig_GH_phi.pdf`, `fig_GH_PD.pdf`, `fig_GH_Y.pdf`: the three original vector figures.
- `main.pdf`: the checked compiled result.
- `validation.json`: build verification and source/output checksums.

Source archive: https://arxiv.org/src/2501.08215v2

The original arXiv archive specifies the arXiv non-exclusive distribution license: https://arxiv.org/licenses/nonexclusive-distrib/1.0/. This package retains the original authorship; conversion does not confer new rights to the paper.

Validation compares the compiled article with the supplied 42-page PDF after normalizing whitespace and removing its arXiv margin stamp. The original PDF remains unchanged. The margin stamp, metadata, and any PDF annotations are not part of the article's TeX source.
