#!/bin/bash

pandoc -t beamer virsh-slides.md \
    --template templates/beamer.template.tex \
    --slide-level 3 \
    --latex-engine=xelatex \
    -o virsh-slides.tex

pandoc -t beamer virsh-slides.md \
    --template templates/beamer.template.tex \
    --slide-level 3 \
    --latex-engine=xelatex \
    -o virsh-slides.pdf
