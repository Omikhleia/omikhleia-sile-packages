local lpeg = require('lpeg')
-- Copyright 2006-2020 Mitchell mitchell.att.foicica.com. See License.txt.
-- Markdown LPeg lexer.

local lexer = require('syntaxhighlight.textadept.lexer')
local token, word_match = lexer.token, lexer.word_match
local P, R, S = lpeg.P, lpeg.R, lpeg.S

local lex = lexer.new('markdown')

-- Block elements.
local function h(n)
  return token('h' .. n, lexer.to_eol(lexer.starts_line(string.rep('#', n))))
end
lex:add_rule('header', h(6) + h(5) + h(4) + h(3) + h(2) + h(1))
local function add_header_style(n)
  local font_size = lexer.property_int['fontsize'] > 0 and
    lexer.property_int['fontsize'] or 10
  lex:add_style('h' .. n, 'fore:$(color.red),size:' .. (font_size + (6 - n)))
end
for i = 1, 6 do add_header_style(i) end

lex:add_rule('blockquote', token(lexer.STRING,
  lpeg.Cmt(lexer.starts_line(S(' \t')^0 * '>'), function(input, index)
    local _, e = input:find('\n[ \t]*\r?\n', index)
    return (e or #input) + 1
  end)))

lex:add_rule('list', token('list',
  lexer.starts_line(S(' \t')^0 * (S('*+-') + R('09')^1 * '.')) * S(' \t')))
lex:add_style('list', lexer.STYLE_CONSTANT)

local code_line = lexer.to_eol(lexer.starts_line(P(' ')^4 + '\t') * -P('<')) *
  lexer.newline^-1
local code_block = lexer.range(lexer.starts_line('```'), '```')
local code_inline = lexer.range('``') + lexer.range('`', false, false)
lex:add_rule('block_code', token('code', code_line + code_block + code_inline))
lex:add_style('code', lexer.STYLE_EMBEDDED .. ',eolfilled')

lex:add_rule('hr', token('hr', lpeg.Cmt(
  lexer.starts_line(S(' \t')^0 * lpeg.C(S('*-_'))), function(input, index, c)
    local line = input:match('[^\r\n]*', index):gsub('[ \t]', '')
    if line:find('[^' .. c .. ']') or #line < 2 then return nil end
    return (select(2, input:find('\r?\n', index)) or #input) + 1
  end)))
lex:add_style('hr', 'back:$(color.black),eolfilled')

-- Whitespace.
local ws = token(lexer.WHITESPACE, S(' \t')^1 + S('\v\r\n')^1)
lex:add_rule('whitespace', ws)

-- Span elements.
lex:add_rule('escape', token(lexer.DEFAULT, P('\\') * 1))

local ref_link_label = token('link_label', lexer.range('[', ']', true) * ':')
local ref_link_url = token('link_url', (lexer.any - lexer.space)^1)
local ref_link_title = token(lexer.STRING, lexer.range('"', true, false) +
  lexer.range("'", true, false) + lexer.range('(', ')', true))
lex:add_rule('link_label', ref_link_label * ws * ref_link_url *
  (ws * ref_link_title)^-1)
lex:add_style('link_label', lexer.STYLE_LABEL)
lex:add_style('link_url', 'underlined')

local link_label = P('!')^-1 * lexer.range('[', ']', true)
local link_target = P('(') * (lexer.any - S(') \t'))^0 *
  (S(' \t')^1 * lexer.range('"', false, false))^-1 * ')'
local link_ref = S(' \t')^0 * lexer.range('[', ']', true)
local link_url = 'http' * P('s')^-1 * '://' * (lexer.any - lexer.space)^1
lex:add_rule('link', token('link', link_label * (link_target + link_ref) +
  link_url))
lex:add_style('link', 'underlined')

local punct_space = lexer.punct + lexer.space

-- Handles flanking delimiters as described in
-- https://github.github.com/gfm/#emphasis-and-strong-emphasis in the cases
-- where simple delimited ranges are not sufficient.
local function flanked_range(s, not_inword)
  local fl_char = lexer.any - s - lexer.space
  local left_fl = lpeg.B(punct_space - s) * s * #fl_char +
    s * #(fl_char - lexer.punct)
  local right_fl = lpeg.B(lexer.punct) * s * #(punct_space - s) +
    lpeg.B(fl_char) * s
  return left_fl * (lexer.any - (not_inword and s * #punct_space or s))^0 *
    right_fl
end

lex:add_rule('strong', token('strong', flanked_range('**') +
  (lpeg.B(punct_space) + #lexer.starts_line('_')) * flanked_range('__', true) *
  #(punct_space + -1)))
lex:add_style('strong', 'bold')

lex:add_rule('em', token('em', flanked_range('*') +
  (lpeg.B(punct_space) + #lexer.starts_line('_')) * flanked_range('_', true) *
  #(punct_space + -1)))
lex:add_style('em', 'italics')

-- Embedded HTML.
local html = lexer.load('html')
local start_rule = lexer.starts_line(S(' \t')^0) * #P('<') *
  html:get_rule('element')
local end_rule = token(lexer.DEFAULT, P('\n')) -- TODO: lexer.WHITESPACE errors
lex:embed(html, start_rule, end_rule)

return lex
