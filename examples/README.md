# Examples

The examples in this folder illustrates some of the SILE packages and classes
defined here.

Please note that their license may differ from that of the main directory (most should
be CC-BY-NC-SA).

## Sample book chapters

An article in French, "Le conte perdu de Mercure — Tuor et Idril élevés au rang d'astre",
by Alain Lefèvre, reproduced here with the author's kind authorization, and previously
published in _Tolkien, le façonnement d’un monde_, vol. 1, Le Dragon de Brume, 2011.

It is used as a "sample test" for the **omibook** class and related packages.

## Examples for the TEI dictionary class and package

A small XML (TEI) lexicon (Almaqerin-French) and the corresponding PDF, to
illustrate the **teibook** class and related packages.

For a more complex project using the same tools, you may also check
the [sindict](https://omikhleia.github.io/sindict/) repository.

The PDF was generated as follows:

```
sile -I preambles/dict-sd-fr-preamble.sil examples/dict-aq-fr.xml -o examples/dict-aq-fr.pdf
```
