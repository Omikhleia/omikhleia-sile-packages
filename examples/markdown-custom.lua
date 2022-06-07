SILE.require("packages/framebox")
SILE.scratch.styles.alignments["framed"] = "customframe"

SILE.doTexlike([[%
\style:define[name=Poetry]{
  \font[style=italic, size=0.9em]
  \paragraph[skipbefore=smallskip, skipafter=smallskip, align=block]
}
\style:define[name=Warning]{
  \font[weight=700]
  \color[color=#b94051]
}
\style:define[name=EmphaticRight]{
  \font[style=italic]
  \paragraph[skipbefore=smallskip, skipafter=smallskip, align=right]
}
\define[command=customframe]{\center{\roughbox[bordercolor=#59b24c,
  fillcolor=220,padding=15pt, enlarge=true]{\parbox[width=90%lw, minimize=true]{\process}}}}
\style:define[name=FramedPara]{
  \paragraph[skipbefore=smallskip, skipafter=medskip, align=framed]
}
]])
