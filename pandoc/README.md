Experimental markdown conversion.

This is based on the Lua custom writer for pandoc, so one first has to convert a markdown file with pandoc to SILE using:

```
pandoc -t omimarkdown-experimental.lua mymarkdown.md > mymarkdown.sil
```

And then use SILE upon it:

```
sile mymarkdown.sil
```
