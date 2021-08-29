# omikhleia-sile-packages
Packages and classes for the SILE typesetter

I wanted to give a try to the [SILE](https://github.com/sile-typesetter/sile) typesetting system. If I had to typeset a book, however, the current version of SILE (0.10.15 at the initial time of writing) lacks many supporting packages for the sort of things I usually write. Here is my attempt at providing packages or classes the would fit my needs.

Some of the things I may (or not) provide here:
- [X] epigraphs
- [ ] quotations - the default "quote" package in SILE doesn't do the job for me.
- [ ] proper page masters (a.k.a an extended book template for print)
- [ ] side notes (a.k.a margin notes)
- [ ] figures (with captions, etc.)
- [ ] layout for dictionaries (two colum, running headers, etc.)
- [ ] other minor styles and hacks (details to be provided as my knowledge of SILE improves)
  - [X] Temporary command redefinition (save and restore)

Progress status:
- **epigraph** package: inspired (loosely) from the LaTeX package by the same name, with minimal set of useful features
- **redefine** package: considered as a beta-version at best.
