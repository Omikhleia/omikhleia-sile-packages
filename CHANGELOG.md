# Changes

## version 1.0.0 - June 23, 2022

After months of raw hacking, these classes and packages, which started as some
sort of experiment, have reached a decent state.

Of course, there are several areas that still need some work:
- By nature, everything in `packages/experimental/` is obsviously not guaranteed to be
  stable and iron-proof.
- Everything in `hacks/` must be considered with caution. There are mere
  workarounds, often partial, for issues reported to the SILE team, a few
  back-ports of fixes that got into SILE 0.13 or for which a PR exists.
- The **styles** package remains highly experimental, despite not being in
  that folder.

Yet, a decent-looking 362-page book was produced and published. The milestone thus
reached has to be marked! Also, from now on, I'll try to respect semantic versioning,
rather than the wild development we had here before.

## version 1.1.0 - August 17, 2022

This release addresses a few fixes:
- Typos in documentation or in code and various small refactors.
- Less hazardous placement of the human readable interpretation in EAN-13 barcodes.
- Strut character size overlooked in caching (struts)
- Adjust strut and minimization in parboxing logic (ptable, parbox)
- Avoid page break just after a table header (ptable)

It also brings a few compatible improvements:
- Support for EAN-13 supplemental part (and other small goodies)
- Enhanced fake sub/super scripts (textsubsuper packages)
- More options for custom list styling (enumitem)
- Basic horiz. cell alignment in default hook (ptable)
- Experimental dot graph converter package
- Experimental syntax highlighting package
- Experimental custom Pandoc Lua writer to SILE converter

This will likely be the last 1.x release. I have started working on upgrading
to a more recent version of SILE than 0.12.5 - and whatever form it takes, this
will be the main focus for a 2.0 release.
