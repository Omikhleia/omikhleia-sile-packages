local lpeg = require('lpeg')
-- Copyright 2006-2020 Brian "Sir Alaran" Schott. See License.txt.
-- JSON LPeg lexer.
-- Based off of lexer code by Mitchell.

local lexer = require('syntaxhighlight.textadept.lexer')
local token, word_match = lexer.token, lexer.word_match
local P, R, S = lpeg.P, lpeg.R, lpeg.S

local lex = lexer.new('json')

-- Whitespace.
lex:add_rule('whitespace', token(lexer.WHITESPACE, lexer.space^1))

-- Strings.
local sq_str = lexer.range("'", true)
local dq_str = lexer.range('"', true)
lex:add_rule('string', token(lexer.STRING, sq_str + dq_str))

-- Keywords.
lex:add_rule('keyword', token(lexer.KEYWORD, word_match[[true false null]]))

-- Comments.
local line_comment = lexer.to_eol('//', true)
local block_comment = lexer.range('/*', '*/')
lex:add_rule('comment', token(lexer.COMMENT, line_comment + block_comment))

-- Numbers.
local integer = S('+-')^-1 * lexer.digit^1 * S('Ll')^-1
lex:add_rule('number', token(lexer.NUMBER, lexer.float + integer))

-- Operators.
lex:add_rule('operator', token(lexer.OPERATOR, S('[]{}:,')))

-- Fold points.
lex:add_fold_point(lexer.OPERATOR, '[', ']')
lex:add_fold_point(lexer.OPERATOR, '{', '}')
lex:add_fold_point(lexer.COMMENT, '/*', '*/')
lex:add_fold_point(lexer.COMMENT, '//', lexer.fold_line_comments('//'))

return lex
