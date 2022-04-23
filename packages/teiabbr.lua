--
-- Abbreviations and localized information used in TEI dictionaries
-- (EXPERIMENTAL, UNSTABLE)
-- 2021, The Sindarin Dictionary Project, Omikhleia, Didier Willis
-- License: MIT
--
-- Unfortunately TEI doesn't standardize values for parts of speech, tenses, moods, etc.
-- And there's no easy way to make it generic, so many schemes could be used...
--
-- THE CURRENT SOLUTION IS NOT GENERIC
-- Here, we just provide lists of "usual" terms, as were used in our
-- dictionaries.
--
SILE.scratch.teiabbr = {}

-- METHODS

local lowercase = SILE.require("packages/textcase").exports.lowercase

local translateAbbr = function (content, _)
  if type(content) ~= "table" or #content ~= 1 then SU.error("Unexpect abbreviation type") end

  local abbr = content[1]
  local lang = SILE.settings.get("document.language")

  local teitrans = SILE.scratch.teiabbr[lang]
  if teitrans == nil and lang ~= "en" then
    teitrans = SILE.scratch.teiabbr.en
    SU.warn("Translation table not found for '"..lang.."', trying 'en'")
  end

  local teiabbr = teitrans.abbr[abbr]
  if teiabbr == nil then
    SU.warn("Abbreviation '"..abbr.."' not found for lang '"..lang.."'")
    teitrans.abbr[abbr] = {} -- Just stop warning afterwards
    return abbr
  end
  teiabbr.used = true
  return teiabbr.translate or abbr
end

local orthPrefix = function (prefix)
  local lang = SILE.settings.get("document.language")

  local teitrans = SILE.scratch.teiabbr[lang]
  if teitrans == nil and lang ~= "en" then
    teitrans = SILE.scratch.teiabbr.en
    SU.warn("Translation table not found for '"..lang.."', trying 'en'")
  end

  local teiprefix = teitrans.symbols[prefix]
  if teiprefix == nil then
    return ""
  end
  teiprefix.used = true
  return teiprefix.symbol
end

local function compare(a,b)
  return lowercase(a.translate) < lowercase(b.translate)
end

local writeAbbr = function ()
  local lang = SILE.settings.get("document.language")

  local teitrans = SILE.scratch.teiabbr[lang]
  if teitrans == nil and lang ~= "en" then
    teitrans = SILE.scratch.teiabbr.en
    SU.warn("Translation table not found for '"..lang.."', trying 'en'")
  end

  local a = {}
  for k, v in pairs(teitrans.abbr) do
    if v.translate == nil then v.translate = k end
    if v.used and v.full ~= nil then
      table.insert(a, v)
    end
  end
  table.sort(a, compare)

  SILE.settings.temporarily(function ()
    SILE.settings.set("document.lskip", "2cm")
    SILE.settings.set("document.parindent", "-2cm")
    SILE.call("medskip")
    SILE.call("pdf:destination", { name = "tei_abbreviations" })
    SILE.call("pdf:bookmark", { title = teitrans.titles.abbreviations, dest = "tei_abbreviations", level = 1 })
    SILE.call("style:apply", { name = "tei:orth" }, { teitrans.titles.abbreviations })
    SILE.typesetter:leaveHmode()

    for _, v in pairs(teitrans.symbols) do
      if v.used then
        local h = SILE.call("hbox", {}, { v.symbol })
        h.width = SILE.length("0cm") -- Real weird but works.
        SILE.typesetter:typeset(v.full)
        SILE.typesetter:leaveHmode()
      end
    end
    for _, n in ipairs(a) do
      local h = SILE.call("hbox", {}, function ()
        SILE.call("style:apply", { name = "tei:pos" }, { n.translate })
      end)
      h.width = SILE.length("0cm") -- Real weird but works.
      SILE.typesetter:typeset(n.full)
      SILE.typesetter:leaveHmode()
    end
  end)
end

local writeBibl = function (bibliography)
  local lang = SILE.settings.get("document.language")

  local teitrans = SILE.scratch.teiabbr[lang]
  if teitrans == nil and lang ~= "en" then
    teitrans = SILE.scratch.teiabbr.en
    SU.warn("Translation table not found for '"..lang.."', trying 'en'")
  end

  SILE.settings.temporarily(function ()
    SILE.settings.set("document.lskip", "1cm")
    SILE.settings.set("document.parindent", "-1cm")
    SILE.call("medskip")
    SILE.call("pdf:destination", { name = "tei_bibliography" })
    SILE.call("pdf:bookmark", { title = teitrans.titles.references, dest = "tei_bibliography", level = 1 })
    SILE.call("style:apply", { name = "tei:orth" }, { teitrans.titles.references })
    SILE.typesetter:leaveHmode()

    -- Process bibliography
    local nBibl = 0
    for i = 1, #bibliography do
      if type(bibliography[i]) == "table" and bibliography[i].command == "bibl" then
        nBibl = nBibl + 1
        local h = SILE.call("hbox", {}, function ()
          SILE.call("style:apply", { name = "tei:bibl" }, {
            bibliography[i].options.n or "["..nBibl.."]"
          })
        end)
        if h.width < 0 then
          h.width = SILE.length("0cm") -- Real weird but works.
        else
          SILE.typesetter:typeset(" ")
        end
        SILE.process(bibliography[i])
        SILE.typesetter:leaveHmode()
      end
      -- Everyting else than bibl entries is ignored
    end
  end)
end

local writeImpressum = function ()
  local lang = SILE.settings.get("document.language")

  local teitrans = SILE.scratch.teiabbr[lang]
  if teitrans == nil and lang ~= "en" then
    teitrans = SILE.scratch.teiabbr.en
    SU.warn("Translation table not found for '"..lang.."', trying 'en'")
  end

  SILE.call("teibook:impressum", {}, { teitrans.titles.impressum })
end

-- TRANSLATION TABLES

SILE.scratch.teiabbr.en = {
  titles = {
    abbreviations = "Symbols & Abbreviations",
    references = "References",
    impressum = "This dictionary was composed with care & passion and the help of the SILE typesetting system."
  },
  symbols = {
    ["deduced"] = { symbol = "#", full = "deduced form" },
    ["normalized"] = { symbol = "^", full = "normalized or reconstructed form" },
    ["deleted"] = { symbol = "×", full = "deleted form" }, -- U+00D7 multiplication sign
    ["historic"] = { symbol = "†", full = "historical form" }, -- U+2020 dagger
    ["coined"] = { symbol = "‡", full = "coined or invented form" } -- U+2021 double Dagger
  },
  abbr = {
    -- xr stuff
    ["of"] = {},
    ["Cf."] = { full="See also" },
    -- usg gram
    ["as a noun"] = {},
    ["as a proper noun"] = {},
    ["as an adverb"] = {},
    ["as a coll. noun"] = {},
    ["esp. in the pl."] = {},
    -- usg ext
    ["by ext."] = { full="by extension" },
    ["by opp."] = { full="by opposition" },
    ["lit."] = { full="literally" },
    -- pos, tns, mood etc.
    ["abst."] = { full="abstract form", translate = "abst." },
    ["adj."] = { full="adjective", translate = "adj." },
    ["adj. num."] = { full="number, numerical adjective", translate = "adj. num." },
    ["adj. or adv."] = { translate = "adj. or adv." },
    ["adv."] = { full="adverb", translate = "adv." },
    ["art."] = { full="article", translate = "art." },
    ["art. and pron."] = { translate = "art. and pron." },
    ["augm."] = { full="augmentative", translate = "augm." },
    ["aux."] = { full="auxiliary", translate = "aux." },
    ["conj."] = { full="conjunction", translate = "conj." },
    ["coord."] = { full = "coordination",  translate  = "coord." },
    ["dem."] = { full="demonstrative", translate = "dem." },
    ["der."] = { full="derivative", translate = "der." },
    ["det."] = { full = "determiner",  translate  = "det." },
    ["dim."] = { full="diminutive", translate = "dim." },
    ["etym."] = { full="etymology", translate = "etym." },
    ["hypo."] = { full="hypocoristic", translate = "hypo." },
    ["interj."] = { full="interjective", translate = "interj." },
    ["interr."] = { full = "interrogative",  translate  = "interr." },
    ["n."] = { full="noun", translate = "n." },
    ["n. and adj."] = { translate = "n. and adj." },
    ["n. pr."] = { full="proper name", translate = "n. pr." },
    ["pref."] = { full="prefix", translate = "pref." },
    ["prep."] = { full="preposition", translate = "prep." },
    ["prep. and conj."] = { translate = "prep. and conj." },
    ["poss."] = { full="possessive", translate = "poss." },
    ["pron."] = { full="pronoun", translate = "pron." },
    ["rel."] = { full="relative", translate = "rel." },
    ["unkn."] = { full="unknown part of speech", translate = "unkn." },
    ["v."] = { full="verb", translate = "v." },
    ["v. impers."] = { full="impersonal verb", translate = "v. impers." },
    ["v. intrans."] = { full="intransitive verb", translate = "v. intrans." },
    -- ordinal, cardinal etc.
    ["ord."] = { full="ordinal (number)", translate = "ord." },
    ["card."] = { full="cardinal (number)", translate = "card." },
    ["quant."] = { full="quantitative (number)", translate = "quant." },
    -- number
    ["dual"] = { full="dual", translate = "dual" },
    ["invar."] = { full="invariable", translate = "invar." },
    ["pl."] = { full="plural", translate = "pl." },
    ["class pl."] = { full="class plural", translate = "class pl." },
    ["coll."] = { full="collective plural", translate = "coll." },
    ["dual pl."] = { full="dual", translate = "dual pl." },
    ["sing."] = { full="singulative", translate = "sing." },
    ["sg."] = { full = "singular",  translate  = "sg." },
    -- itype mut
    ["mut."] = { full="mutation", translate = "mut." },
    ["nasal assim."] = { full="nasal assimilation", translate = "nasal assim." },
    ["nasal mut."] = { full="nasal mutation", translate = "nasal mut." },
    ["soft mut."] = { full="soft mutation (lenition)", translate = "soft. mut." },
    -- per
    ["1st"] = { full="first person", translate = "1st" },
    ["2nd"] = { full="second person", translate = "2nd" },
    ["3rd"] = { full="third person", translate = "3rd" },
    ["excl."] = { full="exclusive", translate = "excl." },
    ["incl."] = { full="inclusive", translate = "incl." },
    -- gen
    ["m."] = { full="masculine", translate = "m." },
    ["f."] = { full="feminine", translate = "f." },
    ["gen."] = { full = "general",  translate  = "gen." },
    ["indet."] = { full = "undetermined",  translate  = "undet." },
    ["resp."] = { full = "respective",  translate  = "resp." },
    -- tns, mood
    ["aor."] = { full="aorist", translate = "aor." },
    ["fut."] = { full="future", translate = "fut." },
    ["ger."] = { full="gerund", translate = "ger." },
    ["inf."] = { full="infinitive", translate = "inf." },
    ["imp."] = { full="imperative", translate = "imp." },
    ["part."] = { full="participle", translate = "part." },
    ["perf."] = { full="perfective", translate = "perf." },
    ["pres."] = { full="present", translate = "pres." },
    ["pa. t."] = { full="past tense", translate = "pa. t." },
    ["irreg. pa. t."] = { full="irregular past tense", translate = "irreg pa. t." },
    ["pp."] = { full="past participle", translate = "pp." },
    -- usg dom
    ["Bot."] = { full="Botany", translate = "Bot." },
    ["Geol."] = { full="Geology", translate = "Geol." },
    ["Ling."] = { full="Linguistics", translate = "Ling." },
    ["Mil."] = { full="Military domain", translate = "Mil." },
    ["Orn."] = { full="Ornithology", translate = "Orn." },
    ["Theo."] = { full="Theology", translate = "Theo." },
    ["Zool."] = { full="Zoology", translate = "Zool." },
    ["Arch."] = { full="archaism", translate = "Arch." },
    ["Astron."] = { full="Astronomy", translate = "Astron." },
    ["Biol."] = { full="Biology", translate = "Biol." },
    ["Phil."] = { full="Philosopy", translate = "Phil." },
    ["Geog."] = { full="Geography", translate = "Geog." },
    ["Cal."] = { full="Calendar", translate = "Cal." },
    ["Pop."] = { full="People, name of a population", translate = "Pop." },
    ["Poet."] = { full="literary or poetic language", translate = "Poet." },
    ["Arch., Poet."] = { translate = "Arch., Poet." },
    -- usg reg
    ["fam."] = { full="familiar", translate = "fam." },
    ["Pej."] = { full="pejorative register", translate = "Pej." },
    ["pol."] = { full="polite", translate = "pol." },
    -- sindarin
    ["N."] = { full="Noldorin", translate = "N." },
    ["S."] = { full="Sindarin", translate = "S." },
    ["*S."] = { full="normalized (Neo-)Sindarin", translate = "*S." }
  }
}

SILE.scratch.teiabbr.fr = {
  titles = {
    abbreviations = "Symboles & Abréviations",
    references = "Références",
    impressum = "Ce dictionnaire est présenté avec soin & passion à l’aide du système de composition SILE."
  },
  symbols = {
    ["deduced"] = { symbol = "#", full = "form déduite" },
    ["normalized"] = { symbol = "^", full = "forme normalisée ou reconstruite" },
    ["deleted"] = { symbol = "×", full = "forme rayée" }, -- U+00D7 multiplication sign
    ["historic"] = { symbol = "†", full = "forme historique" }, -- U+2020 dagger
    ["coined"] = { symbol = "‡", full = "forme inventée" } -- U+2021 double Dagger
  },
  abbr = {
    -- xr stuff
    ["of"] = { translate = "de" },
    ["Cf."] = { full="Voir aussi", translate = "Cf." },
    -- usg gram
    ["as a noun"] = { translate = "comme nom" },
    ["as a proper noun"] = { translate = "comme n. propre" },
    ["as an adverb"] = { translate = "comme adv." },
    ["as a coll. noun"] = { translate = "comme n. collectif" },
    ["esp. in the pl."] = { translate = "sp. au pl." },
    -- usg ext
    ["by ext."] = { full="par extension", translate = "par ext." },
    ["by opp."] = { full="par opposition", translate = "par opp." },
    ["lit."] = { full="littéralement", translate = "lit." },
    -- pos, tns, mood etc.
    ["abst."] = { full="forme abstraite", translate = "abst." },
    ["adj."] = { full="adjectif", translate = "adj." },
    ["adj. num."] = { full="nombre, adjectif numéral", translate = "adj. num." },
    ["adj. or adv."] = { translate = "adj. ou adv." },
    ["adv."] = { full="adverbe", translate = "adv." },
    ["art."] = { full="article", translate = "art." },
    ["art. and pron."] = { translate = "art. et pron." },
    ["augm."] = { full="augmentatif", translate = "augm." },
    ["aux."] = { full="auxiliaire", translate = "aux." },
    ["conj."] = { full="conjonction", translate = "conj." },
    ["coord."] = { full = "coordination",  translate  = "coord." },
    ["dem."] = { full="démonstratif", translate = "dém." },
    ["der."] = { full="dérivatif", translate = "dér." },
    ["det."] = { full = "déterminant",  translate  = "dét." },
    ["dim."] = { full="diminutif", translate = "dim." },
    ["etym."] = { full="étymologie", translate = "étym." },
    ["hypo."] = { full="hypocoristique", translate = "hypo." },
    ["interr."] = { full = "interrogatif",  translate  = "interr." },
    ["interj."] = { full="interjectif", translate = "interj." },
    ["n."] = { full="nom", translate = "n." },
    ["n. and adj."] = { translate = "n. et adj." },
    ["n. pr."] = { full="nom propre", translate = "n. pr." },
    ["pref."] = { full="préfixe", translate = "préf." },
    ["prep."] = { full="préposition", translate = "prép." },
    ["prep. and conj."] = { translate = "prép. et conj." },
    ["poss."] = { full="possessif", translate = "poss." },
    ["pron."] = { full="pronom", translate = "pron." },
    ["rel."] = { full="(pronom) relatif", translate = "rel." },
    ["unkn."] = { full="partie du discours inconnue", translate = "inc." },
    ["v."] = { full="verbe", translate = "v." },
    ["v. impers."] = { full="verbe impersonnel", translate = "v. impers." },
    ["v. intrans."] = { full="verbe intransitif", translate = "v. intrans." },
    -- ordinal, cardinal etc.
    ["ord."] = { full="(nombre) ordinal", translate = "ord." },
    ["card."] = { full="(nombre) cardinal", translate = "card." },
    ["quant."] = { full="(nombre) quantitatif", translate = "quant." },
    -- number
    ["dual"] = { full="duel", translate = "duel" },
    ["invar."] = { full="invariable", translate = "invar." },
    ["pl."] = { full="pluriel", translate = "pl." },
    ["class pl."] = { full="pluriel de classe", translate = "pl. de classe" },
    ["coll."] = { full="pluriel collectif", translate = "coll." },
    ["dual pl."] = { full="duel", translate = "pl. duel" },
    ["sing."] = { full="singulatif", translate = "sing." },
    ["sg."] = { full = "singulier",  translate  = "sg." },
    -- itype mut
    ["mut."] = { full="mutation", translate = "mut." },
    ["nasal assim."] = { full="assimilation nasale", translate = "assim. nasale" },
    ["nasal mut."] = { full="mutation nasale", translate = "mut. nasale" },
    ["soft mut."] = { full="mutation douce (lénition)", translate = "mut. douce" },
    -- per
    ["1st"] = { full="première personne", translate = "1e p." },
    ["2nd"] = { full="deuxième personne", translate = "2e p." },
    ["3rd"] = { full="troisième personne", translate = "3e p." },
    ["excl."] = { full="exclusif", translate = "excl." },
    ["incl."] = { full="inclusif", translate = "incl." },
    -- gen
    ["m."] = { full="masculin", translate = "m." },
    ["f."] = { full="féminin", translate = "f." },
    ["gen."] = { full = "général",  translate  = "gén." },
    ["indet."] = { full = "indéterminé",  translate  = "indét." },
    ["resp."] = { full = "respectif",  translate  = "resp." },
    -- tns, mood
    ["aor."] = { full="aoriste", translate = "aor." },
    ["fut."] = { full="futur", translate = "fut." },
    ["ger."] = { full="gérondif", translate = "gér." },
    ["inf."] = { full="infinitif", translate = "inf." },
    ["imp."] = { full="mode impératif", translate = "imp." },
    ["part."] = { full="participe", translate = "part." },
    ["perf."] = { full="perfectif", translate = "perf." },
    ["pres."] = { full="présent", translate = "prés." },
    ["pa. t."] = { full="passé", translate = "pas." },
    ["irreg. pa. t."] = { full="passé de forme irrégulière", translate = "pas. irrég." },
    ["pp."] = { full="participe passé", translate = "pp." },
    -- usg dom
    ["Bot."] = { full="Botanique", translate = "Bot." },
    ["Geol."] = { full="Géologie", translate = "Géol." },
    ["Ling."] = { full="Linguistique", translate = "Ling." },
    ["Mil."] = { full="domaine militaire", translate = "Mil." },
    ["Orn."] = { full="Ornithologie", translate = "Orn." },
    ["Theo."] = { full="Théologie", translate = "Théo." },
    ["Zool."] = { full="Zoologie", translate = "Zool." },
    ["Arch."] = { full="archaïsme", translate = "Arch." },
    ["Astron."] = { full="Astronomie", translate = "Astron." },
    ["Biol."] = { full="Biologie", translate = "Biol." },
    ["Phil."] = { full="Philosophie", translate = "Phil." },
    ["Geog."] = { full="Géographie", translate = "Géog." },
    ["Cal."] = { full="Calendrier", translate = "Cal." },
    ["Pop."] = { full="Population, nom de peuple", translate = "Pop." },
    ["Poet."] = { full="langage poétique ou littéraire", translate = "Poét." },
    ["Arch., Poet."] = { translate = "Arch., Poét." },
    -- usg reg
    ["fam."] = { full="familier", translate = "fam." },
    ["Pej."] = { full="registre péjoratif", translate = "Péj." },
    ["pol."] = { full="poli", translate = "pol." },
    -- sindarin
    ["N."] = { full="noldorin", translate = "N." },
    ["S."] = { full="sindarin", translate = "S." },
    ["*S."] = { full="(néo-)sindarin normalisé", translate = "*S." }
  }
}

return {
  exports = {
    translateAbbr = translateAbbr,
    writeAbbr = writeAbbr,
    writeBibl = writeBibl,
    writeImpressum = writeImpressum,
    orthPrefix = orthPrefix
  },
  documentation = [[\begin{document}
\script[src=packages/autodoc-extras]

This utility package is loaded by the \autodoc:package{teidict} package and
provides it with a few localized strings (currently for English
and French).

It also defines the routines for building and typesetting the
list of used abbreviations, the references and the default “impressum”
(colophon).

In the current state of art, it is at best experimental (hence
the reason for having these functions in a distinct package).
The only reason why one could want to look at it and modify it
would be to add new abbreviations (e.g. for grammatical categories)
or their translations.

\end{document}]]
}
-- ALL DONE
