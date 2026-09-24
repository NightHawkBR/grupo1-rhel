#!/usr/bin/env bash
# Gera docs/pesquisa.pdf a partir de docs/pesquisa.md (pandoc + XeLaTeX).
# Uso: cd docs && ./gerar-pdf.sh
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
pandoc pesquisa.md -t latex --template=modelo/capa.tex -o build/capa.tex
pandoc pesquisa.md -o pesquisa.pdf \
  --pdf-engine=xelatex \
  --lua-filter=modelo/abnt.lua \
  -H modelo/preambulo.tex \
  -B build/capa.tex \
  -V documentclass=article -V fontsize=12pt -V papersize=a4 \
  -V geometry:top=3cm -V geometry:left=3cm -V geometry:bottom=2cm -V geometry:right=2cm \
  -V mainfont="TeX Gyre Termes" -V monofont="DejaVu Sans Mono" -V monofontoptions=Scale=0.82 \
  -V fontfamily=fontspec -V linestretch=1.5 -V indent=true -V colorlinks=true -V linkcolor=black -V urlcolor=black \
  -V secnumdepth=3 --number-sections --highlight-style=monochrome \
  --resource-path=.:img
echo "OK: $(pwd)/pesquisa.pdf"
