# Examples

The examples in this folder illustrates some of the SILE packages and classes
defined here.

Please note that their license may differ from that of the main directory (most should
be CC-BY-NC-SA).

## Examples for the TEI dictionary class and package

The folder contains a small XML (TEI) lexicon and the corresponding PDF.

For a more complex project using the same tools, you may also check
the [sindict](https://omikhleia.github.io/sindict/) repository.

The PDF was generated as follows:

```
sile -I preambles/dict-sd-fr-preamble.sil examples/dict-aq-fr.xml -o examples/dict-aq-fr.pdf
```
