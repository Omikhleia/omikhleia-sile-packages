# Examples

The examples in this folder illustrate some of the SILE packages and classes
defined here.

Please note that their license(s) may differ from that of the main directory.

When not specified or in case of doubt, the applicable license is CC-BY-NC-SA 2.0.

## Sample book chapters

They are used as "sample tests" for the **omibook** class and related packages.

- An article in French, "Le conte perdu de Mercure — Tuor et Idril élevés au rang d'astre",
  by Alain Lefèvre, reproduced here with the author's kind authorization, and previously
  published in _Tolkien, le façonnement d’un monde_, vol. 1, Le Dragon de Brume, 2011.
  (License: CC-BY-NC-SA 2.0 as a special arrangement)
- Conan Doyle's "A Scandal in Bohemia", just because SILE used it in its own
  showcase, so why not check out it could look here. (License: public domain)

## Decorated colophons

A demonstration of the **colophon** package, as we did not want to show all these
big examples in the main documentation. The text is somewhat nonsensical, with
bits of actual explanations mixed with random quotes. (License: MIT)

## Sample curriculum vitae

A fake _résumé_ of some Sherlock Holmes guy, used as a "sample test" for the **omicv**
class. Sherlockians, be warned, the information in it might not be very canonical,
but it serves its purpose here. (License: MIT)

## Table tests

A showcase for the **ptable** package. (License: MIT)

## Examples for the TEI dictionary class and package

A small XML (TEI) lexicon (Almaqerin-French) and the corresponding PDF, to
illustrate the **teibook** class and related packages. (License: CC-BY-NC-SA 2.0 as
a special arrangement)

The PDF was generated as follows:

```
sile -I preambles/dict-sd-fr-preamble.sil examples/dict-aq-fr.xml -o examples/dict-aq-fr.pdf
```

For a more complex project using the same tools, you may also check
the [sindict](https://omikhleia.github.io/sindict/) repository.
