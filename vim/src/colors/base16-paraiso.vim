" Vim color file
" Converted from Textmate theme Paraíso (dark) using Coloration v0.3.3 (http://github.com/sickill/coloration)

set background=dark
highlight clear

if exists("syntax_on")
  syntax reset
endif

let g:colors_name = "Paraíso (dark)"

hi Cursor ctermfg=16 ctermbg=247 cterm=NONE guifg=#2f1e2e guibg=#a39e9b gui=NONE
hi Visual ctermfg=NONE ctermbg=59 cterm=NONE guifg=NONE guibg=#4f424c gui=NONE
hi CursorLine ctermfg=NONE ctermbg=53 cterm=NONE guifg=NONE guibg=#3b2b39 gui=NONE
hi CursorColumn ctermfg=NONE ctermbg=53 cterm=NONE guifg=NONE guibg=#3b2b39 gui=NONE
hi ColorColumn ctermfg=NONE ctermbg=53 cterm=NONE guifg=NONE guibg=#3b2b39 gui=NONE
hi LineNr ctermfg=59 ctermbg=53 cterm=NONE guifg=#695e65 guibg=#3b2b39 gui=NONE
hi VertSplit ctermfg=59 ctermbg=59 cterm=NONE guifg=#51434e guibg=#51434e gui=NONE
hi MatchParen ctermfg=97 ctermbg=NONE cterm=underline guifg=#815ba4 guibg=NONE gui=underline
hi StatusLine ctermfg=247 ctermbg=59 cterm=bold guifg=#a39e9b guibg=#51434e gui=bold
hi StatusLineNC ctermfg=247 ctermbg=59 cterm=NONE guifg=#a39e9b guibg=#51434e gui=NONE
hi Pmenu ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi PmenuSel ctermfg=NONE ctermbg=59 cterm=NONE guifg=NONE guibg=#4f424c gui=NONE
hi IncSearch ctermfg=16 ctermbg=72 cterm=NONE guifg=#2f1e2e guibg=#48b685 gui=NONE
hi Search ctermfg=NONE ctermbg=NONE cterm=underline guifg=NONE guibg=NONE gui=underline
hi Directory ctermfg=72 ctermbg=NONE cterm=NONE guifg=#48b685 guibg=NONE gui=NONE
hi Folded ctermfg=95 ctermbg=16 cterm=NONE guifg=#776e71 guibg=#2f1e2e gui=NONE

hi Normal ctermfg=247 ctermbg=16 cterm=NONE guifg=#a39e9b guibg=#2f1e2e gui=NONE
hi Boolean ctermfg=208 ctermbg=NONE cterm=NONE guifg=#f99b15 guibg=NONE gui=NONE
hi Character ctermfg=208 ctermbg=NONE cterm=NONE guifg=#f99b15 guibg=NONE gui=NONE
hi Comment ctermfg=95 ctermbg=NONE cterm=NONE guifg=#776e71 guibg=NONE gui=NONE
hi Conditional ctermfg=97 ctermbg=NONE cterm=NONE guifg=#815ba4 guibg=NONE gui=NONE
hi Constant ctermfg=208 ctermbg=NONE cterm=NONE guifg=#f99b15 guibg=NONE gui=NONE
hi Define ctermfg=97 ctermbg=NONE cterm=NONE guifg=#815ba4 guibg=NONE gui=NONE
hi DiffAdd ctermfg=247 ctermbg=64 cterm=bold guifg=#a39e9b guibg=#48810e gui=bold
hi DiffDelete ctermfg=88 ctermbg=NONE cterm=NONE guifg=#8d0609 guibg=NONE gui=NONE
hi DiffChange ctermfg=247 ctermbg=23 cterm=NONE guifg=#a39e9b guibg=#28345b gui=NONE
hi DiffText ctermfg=247 ctermbg=24 cterm=bold guifg=#a39e9b guibg=#204a87 gui=bold
hi ErrorMsg ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi WarningMsg ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi Float ctermfg=208 ctermbg=NONE cterm=NONE guifg=#f99b15 guibg=NONE gui=NONE
hi Function ctermfg=39 ctermbg=NONE cterm=NONE guifg=#06b6ef guibg=NONE gui=NONE
hi Identifier ctermfg=97 ctermbg=NONE cterm=NONE guifg=#815ba4 guibg=NONE gui=NONE
hi Keyword ctermfg=97 ctermbg=NONE cterm=NONE guifg=#815ba4 guibg=NONE gui=NONE
hi Label ctermfg=72 ctermbg=NONE cterm=NONE guifg=#48b685 guibg=NONE gui=NONE
hi NonText ctermfg=95 ctermbg=53 cterm=NONE guifg=#776e71 guibg=#352433 gui=NONE
hi Number ctermfg=208 ctermbg=NONE cterm=NONE guifg=#f99b15 guibg=NONE gui=NONE
hi Operator ctermfg=247 ctermbg=NONE cterm=NONE guifg=#a39e9b guibg=NONE gui=NONE
hi PreProc ctermfg=97 ctermbg=NONE cterm=NONE guifg=#815ba4 guibg=NONE gui=NONE
hi Special ctermfg=247 ctermbg=NONE cterm=NONE guifg=#a39e9b guibg=NONE gui=NONE
hi SpecialKey ctermfg=95 ctermbg=53 cterm=NONE guifg=#776e71 guibg=#3b2b39 gui=NONE
hi Statement ctermfg=97 ctermbg=NONE cterm=NONE guifg=#815ba4 guibg=NONE gui=NONE
hi StorageClass ctermfg=97 ctermbg=NONE cterm=NONE guifg=#815ba4 guibg=NONE gui=NONE
hi String ctermfg=72 ctermbg=NONE cterm=NONE guifg=#48b685 guibg=NONE gui=NONE
hi Tag ctermfg=203 ctermbg=NONE cterm=NONE guifg=#ef6155 guibg=NONE gui=NONE
hi Title ctermfg=247 ctermbg=NONE cterm=bold guifg=#a39e9b guibg=NONE gui=bold
hi Todo ctermfg=95 ctermbg=NONE cterm=inverse,bold guifg=#776e71 guibg=NONE gui=inverse,bold
hi Type ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi Underlined ctermfg=NONE ctermbg=NONE cterm=underline guifg=NONE guibg=NONE gui=underline
hi rubyClass ctermfg=97 ctermbg=NONE cterm=NONE guifg=#815ba4 guibg=NONE gui=NONE
hi rubyFunction ctermfg=39 ctermbg=NONE cterm=NONE guifg=#06b6ef guibg=NONE gui=NONE
hi rubyInterpolationDelimiter ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi rubySymbol ctermfg=72 ctermbg=NONE cterm=NONE guifg=#48b685 guibg=NONE gui=NONE
hi rubyConstant ctermfg=220 ctermbg=NONE cterm=NONE guifg=#f6e60d guibg=NONE gui=NONE
hi rubyStringDelimiter ctermfg=72 ctermbg=NONE cterm=NONE guifg=#48b685 guibg=NONE gui=NONE
hi rubyBlockParameter ctermfg=203 ctermbg=NONE cterm=NONE guifg=#ef6155 guibg=NONE gui=NONE
hi rubyInstanceVariable ctermfg=203 ctermbg=NONE cterm=NONE guifg=#ef6155 guibg=NONE gui=NONE
hi rubyInclude ctermfg=39 ctermbg=NONE cterm=NONE guifg=#06b6ef guibg=NONE gui=NONE
hi rubyGlobalVariable ctermfg=203 ctermbg=NONE cterm=NONE guifg=#ef6155 guibg=NONE gui=NONE
hi rubyRegexp ctermfg=79 ctermbg=NONE cterm=NONE guifg=#5bc4bf guibg=NONE gui=NONE
hi rubyRegexpDelimiter ctermfg=79 ctermbg=NONE cterm=NONE guifg=#5bc4bf guibg=NONE gui=NONE
hi rubyEscape ctermfg=79 ctermbg=NONE cterm=NONE guifg=#5bc4bf guibg=NONE gui=NONE
hi rubyControl ctermfg=97 ctermbg=NONE cterm=NONE guifg=#815ba4 guibg=NONE gui=NONE
hi rubyClassVariable ctermfg=203 ctermbg=NONE cterm=NONE guifg=#ef6155 guibg=NONE gui=NONE
hi rubyOperator ctermfg=247 ctermbg=NONE cterm=NONE guifg=#a39e9b guibg=NONE gui=NONE
hi rubyException ctermfg=39 ctermbg=NONE cterm=NONE guifg=#06b6ef guibg=NONE gui=NONE
hi rubyPseudoVariable ctermfg=203 ctermbg=NONE cterm=NONE guifg=#ef6155 guibg=NONE gui=NONE
hi rubyRailsUserClass ctermfg=220 ctermbg=NONE cterm=NONE guifg=#f6e60d guibg=NONE gui=NONE
hi rubyRailsARAssociationMethod ctermfg=79 ctermbg=NONE cterm=NONE guifg=#5bc4bf guibg=NONE gui=NONE
hi rubyRailsARMethod ctermfg=79 ctermbg=NONE cterm=NONE guifg=#5bc4bf guibg=NONE gui=NONE
hi rubyRailsRenderMethod ctermfg=79 ctermbg=NONE cterm=NONE guifg=#5bc4bf guibg=NONE gui=NONE
hi rubyRailsMethod ctermfg=79 ctermbg=NONE cterm=NONE guifg=#5bc4bf guibg=NONE gui=NONE
hi erubyDelimiter ctermfg=149 ctermbg=NONE cterm=NONE guifg=#9ec931 guibg=NONE gui=NONE
hi erubyComment ctermfg=95 ctermbg=NONE cterm=NONE guifg=#776e71 guibg=NONE gui=NONE
hi erubyRailsMethod ctermfg=79 ctermbg=NONE cterm=NONE guifg=#5bc4bf guibg=NONE gui=NONE
hi htmlTag ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi htmlEndTag ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi htmlTagName ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi htmlArg ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi htmlSpecialChar ctermfg=208 ctermbg=NONE cterm=NONE guifg=#f99b15 guibg=NONE gui=NONE
hi javaScriptFunction ctermfg=97 ctermbg=NONE cterm=NONE guifg=#815ba4 guibg=NONE gui=NONE
hi javaScriptRailsFunction ctermfg=79 ctermbg=NONE cterm=NONE guifg=#5bc4bf guibg=NONE gui=NONE
hi javaScriptBraces ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi yamlKey ctermfg=203 ctermbg=NONE cterm=NONE guifg=#ef6155 guibg=NONE gui=NONE
hi yamlAnchor ctermfg=203 ctermbg=NONE cterm=NONE guifg=#ef6155 guibg=NONE gui=NONE
hi yamlAlias ctermfg=203 ctermbg=NONE cterm=NONE guifg=#ef6155 guibg=NONE gui=NONE
hi yamlDocumentHeader ctermfg=72 ctermbg=NONE cterm=NONE guifg=#48b685 guibg=NONE gui=NONE
hi cssURL ctermfg=203 ctermbg=NONE cterm=NONE guifg=#ef6155 guibg=NONE gui=NONE
hi cssFunctionName ctermfg=79 ctermbg=NONE cterm=NONE guifg=#5bc4bf guibg=NONE gui=NONE
hi cssColor ctermfg=79 ctermbg=NONE cterm=NONE guifg=#5bc4bf guibg=NONE gui=NONE
hi cssPseudoClassId ctermfg=208 ctermbg=NONE cterm=NONE guifg=#f99b15 guibg=NONE gui=NONE
hi cssClassName ctermfg=208 ctermbg=NONE cterm=NONE guifg=#f99b15 guibg=NONE gui=NONE
hi cssValueLength ctermfg=208 ctermbg=NONE cterm=NONE guifg=#f99b15 guibg=NONE gui=NONE
hi cssCommonAttr ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
hi cssBraces ctermfg=NONE ctermbg=NONE cterm=NONE guifg=NONE guibg=NONE gui=NONE
