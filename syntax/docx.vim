" Vim syntax file
" Language:     docx
" Maintainer:   Matt Loar <https://github.com/mloar/vim-docx>
" Filenames:    *.docx
" Last Change:  2026 Jan 23

if exists("b:current_syntax")
  finish
endif

if !exists('main_syntax')
  let main_syntax = 'docx'
endif

if has('folding')
  let s:foldmethod = &l:foldmethod
  let s:foldtext = &l:foldtext
endif
let s:iskeyword = &l:iskeyword

runtime! syntax/html.vim
unlet! b:current_syntax

if !exists('g:docx_fenced_languages')
  let g:docx_fenced_languages = []
endif
let s:done_include = {}
for s:type in map(copy(g:docx_fenced_languages),'matchstr(v:val,"[^=]*$")')
  if has_key(s:done_include, matchstr(s:type,'[^.]*'))
    continue
  endif
  if s:type =~ '\.'
    let b:{matchstr(s:type,'[^.]*')}_subtype = matchstr(s:type,'\.\zs.*')
  endif
  syn case match
  exe 'syn include @docxHighlight_'.tr(s:type,'.','_').' syntax/'.matchstr(s:type,'[^.]*').'.vim'
  unlet! b:current_syntax
  let s:done_include[matchstr(s:type,'[^.]*')] = 1
endfor
unlet! s:type
unlet! s:done_include

syn spell toplevel
if exists('s:foldmethod') && s:foldmethod !=# &l:foldmethod
  let &l:foldmethod = s:foldmethod
  unlet s:foldmethod
endif
if exists('s:foldtext') && s:foldtext !=# &l:foldtext
  let &l:foldtext = s:foldtext
  unlet s:foldtext
endif
if s:iskeyword !=# &l:iskeyword
  let &l:iskeyword = s:iskeyword
endif
unlet s:iskeyword

if !exists('g:docx_minlines')
  let g:docx_minlines = 50
endif
execute 'syn sync minlines=' . g:docx_minlines
syn sync linebreaks=1
syn case ignore

syn match docxValid '[<>]\c[a-z/$!]\@!' transparent contains=NONE
syn match docxValid '&\%(#\=\w*;\)\@!' transparent contains=NONE

syn match docxLineStart "^[<@]\@!" nextgroup=@docxBlock,htmlSpecialChar

syn cluster docxBlock contains=docxH1,docxH2,docxH3,docxH4,docxH5,docxH6,docxBlockquote,docxListMarker,docxOrderedListMarker,docxCodeBlock,docxRule,docxNamedStyle
syn cluster docxInline contains=docxLineBreak,docxLinkText,docxItalic,docxBold,docxCode,docxEscape,@htmlTop,docxValid

syn match docxH1 "^.\+\n=\+$" contained contains=@docxInline,docxHeadingRule,docxAutomaticLink
syn match docxH2 "^.\+\n-\+$" contained contains=@docxInline,docxHeadingRule,docxAutomaticLink

syn match docxHeadingRule "^[=-]\+$" contained

syn region docxH1 matchgroup=docxH1Delimiter start=" \{,3}#\s"      end="#*\s*$" keepend oneline contains=@docxInline,docxAutomaticLink contained
syn region docxH2 matchgroup=docxH2Delimiter start=" \{,3}##\s"     end="#*\s*$" keepend oneline contains=@docxInline,docxAutomaticLink contained
syn region docxH3 matchgroup=docxH3Delimiter start=" \{,3}###\s"    end="#*\s*$" keepend oneline contains=@docxInline,docxAutomaticLink contained
syn region docxH4 matchgroup=docxH4Delimiter start=" \{,3}####\s"   end="#*\s*$" keepend oneline contains=@docxInline,docxAutomaticLink contained
syn region docxH5 matchgroup=docxH5Delimiter start=" \{,3}#####\s"  end="#*\s*$" keepend oneline contains=@docxInline,docxAutomaticLink contained
syn region docxH6 matchgroup=docxH6Delimiter start=" \{,3}######\s" end="#*\s*$" keepend oneline contains=@docxInline,docxAutomaticLink contained
syn region docxNamedStyle matchgroup=docxH1Delimiter start=" \{,3}#(\i*)\s"  end="#*\s*$" keepend oneline contains=@docxInline,docxAutomaticLink contained

syn match docxBlockquote ">\%(\s\|$\)" contained nextgroup=@docxBlock

syn region docxCodeBlock start="^\n\( \{4,}\|\t\)" end="^\ze \{,3}\S.*$" keepend

" TODO: real nesting
syn match docxListMarker "\%(\t\| \{0,4\}\)[-*+]\%(\s\+\S\)\@=" contained
syn match docxOrderedListMarker "\%(\t\| \{0,4}\)\<\d\+\.\%(\s\+\S\)\@=" contained

syn match docxRule "\* *\* *\*[ *]*$" contained
syn match docxRule "- *- *-[ -]*$" contained

syn match docxLineBreak " \{2,\}$"

syn region docxIdDeclaration matchgroup=docxLinkDelimiter start="^ \{0,3\}!\=\[" end="\]:" oneline keepend nextgroup=docxUrl skipwhite
syn match docxUrl "\S\+" nextgroup=docxUrlTitle skipwhite contained
syn region docxUrl matchgroup=docxUrlDelimiter start="<" end=">" oneline keepend nextgroup=docxUrlTitle skipwhite contained
syn region docxUrlTitle matchgroup=docxUrlTitleDelimiter start=+"+ end=+"+ keepend contained
syn region docxUrlTitle matchgroup=docxUrlTitleDelimiter start=+'+ end=+'+ keepend contained
syn region docxUrlTitle matchgroup=docxUrlTitleDelimiter start=+(+ end=+)+ keepend contained

syn region docxLinkText matchgroup=docxLinkTextDelimiter start="!\=\[\%(\_[^][]*\%(\[\_[^][]*\]\_[^][]*\)*]\%( \=[[(]\)\)\@=" end="\]\%( \=[[(]\)\@=" nextgroup=docxLink,docxId skipwhite contains=@docxInline,docxLineStart
syn region docxLink matchgroup=docxLinkDelimiter start="(" end=")" contains=docxUrl keepend contained
syn region docxId matchgroup=docxIdDelimiter start="\[" end="\]" keepend contained
syn region docxAutomaticLink matchgroup=docxUrlDelimiter start="<\%(\w\+:\|[[:alnum:]_+-]\+@\)\@=" end=">" keepend oneline

let s:concealends = ''
if has('conceal') && get(g:, 'docx_syntax_conceal', 1) == 1
  let s:concealends = ' concealends'
endif
exe 'syn region docxItalic matchgroup=docxItalicDelimiter start="\*\S\@=" end="\S\@<=\*\|^$" skip="\\\*" contains=docxLineStart,@Spell' . s:concealends
exe 'syn region docxItalic matchgroup=docxItalicDelimiter start="\w\@<!_\S\@=" end="\S\@<=_\w\@!\|^$" skip="\\_" contains=docxLineStart,@Spell' . s:concealends
exe 'syn region docxBold matchgroup=docxBoldDelimiter start="\*\*\S\@=" end="\S\@<=\*\*\|^$" skip="\\\*" contains=docxLineStart,docxItalic,@Spell' . s:concealends
exe 'syn region docxBold matchgroup=docxBoldDelimiter start="\w\@<!__\S\@=" end="\S\@<=__\w\@!\|^$" skip="\\_" contains=docxLineStart,docxItalic,@Spell' . s:concealends
exe 'syn region docxBoldItalic matchgroup=docxBoldItalicDelimiter start="\*\*\*\S\@=" end="\S\@<=\*\*\*\|^$" skip="\\\*" contains=docxLineStart,@Spell' . s:concealends
exe 'syn region docxBoldItalic matchgroup=docxBoldItalicDelimiter start="\w\@<!___\S\@=" end="\S\@<=___\w\@!\|^$" skip="\\_" contains=docxLineStart,@Spell' . s:concealends
exe 'syn region docxStrike matchgroup=docxStrikeDelimiter start="\~\~\S\@=" end="\S\@<=\~\~\|^$" contains=docxLineStart,@Spell' . s:concealends

syn region docxCode matchgroup=docxCodeDelimiter start="`" end="`" keepend contains=docxLineStart
syn region docxCode matchgroup=docxCodeDelimiter start="`` \=" end=" \=``" keepend contains=docxLineStart
syn region docxCodeBlock matchgroup=docxCodeDelimiter start="^\s*\z(`\{3,\}\).*$" end="^\s*\z1\ze\s*$" keepend
syn region docxCodeBlock matchgroup=docxCodeDelimiter start="^\s*\z(\~\{3,\}\).*$" end="^\s*\z1\ze\s*$" keepend

syn match docxFootnote "\[^[^\]]\+\]"
syn match docxFootnoteDefinition "^\[^[^\]]\+\]:"

let s:done_include = {}
for s:type in g:docx_fenced_languages
  if has_key(s:done_include, matchstr(s:type,'[^.]*'))
    continue
  endif
  exe 'syn region docxHighlight_'.substitute(matchstr(s:type,'[^=]*$'),'\..*','','').' matchgroup=docxCodeDelimiter start="^\s*\z(`\{3,\}\)\s*\%({.\{-}\.\)\='.matchstr(s:type,'[^=]*').'}\=\S\@!.*$" end="^\s*\z1\ze\s*$" keepend contains=@docxHighlight_'.tr(matchstr(s:type,'[^=]*$'),'.','_') . s:concealends
  exe 'syn region docxHighlight_'.substitute(matchstr(s:type,'[^=]*$'),'\..*','','').' matchgroup=docxCodeDelimiter start="^\s*\z(\~\{3,\}\)\s*\%({.\{-}\.\)\='.matchstr(s:type,'[^=]*').'}\=\S\@!.*$" end="^\s*\z1\ze\s*$" keepend contains=@docxHighlight_'.tr(matchstr(s:type,'[^=]*$'),'.','_') . s:concealends
  let s:done_include[matchstr(s:type,'[^.]*')] = 1
endfor
unlet! s:type
unlet! s:done_include

if get(b:, 'docx_yaml_head', get(g:, 'docx_yaml_head', main_syntax ==# 'docx'))
  syn include @docxYamlTop syntax/yaml.vim
  unlet! b:current_syntax
  syn region docxYamlHead start="\%^---$" end="^\%(---\|\.\.\.\)\s*$" keepend contains=@docxYamlTop,@Spell
endif

syn match docxEscape "\\[][\\`*_{}()<>#+.!-]"
"syn match docxError "\w\@<=_\w\@="

hi def link docxH1                    htmlH1
hi def link docxH2                    htmlH2
hi def link docxH3                    htmlH3
hi def link docxH4                    htmlH4
hi def link docxH5                    htmlH5
hi def link docxH6                    htmlH6
hi def link docxHeadingRule           docxRule
hi def link docxH1Delimiter           docxHeadingDelimiter
hi def link docxH2Delimiter           docxHeadingDelimiter
hi def link docxH3Delimiter           docxHeadingDelimiter
hi def link docxH4Delimiter           docxHeadingDelimiter
hi def link docxH5Delimiter           docxHeadingDelimiter
hi def link docxH6Delimiter           docxHeadingDelimiter
hi def link docxHeadingDelimiter      Delimiter
hi def link docxOrderedListMarker     docxListMarker
hi def link docxListMarker            htmlTagName
hi def link docxBlockquote            Comment
hi def link docxRule                  PreProc

hi def link docxFootnote              Typedef
hi def link docxFootnoteDefinition    Typedef

hi def link docxLinkText              htmlLink
hi def link docxIdDeclaration         Typedef
hi def link docxId                    Type
hi def link docxAutomaticLink         docxUrl
hi def link docxUrl                   Float
hi def link docxUrlTitle              String
hi def link docxIdDelimiter           docxLinkDelimiter
hi def link docxUrlDelimiter          htmlTag
hi def link docxUrlTitleDelimiter     Delimiter

hi def link docxItalic                htmlItalic
hi def link docxItalicDelimiter       docxItalic
hi def link docxBold                  htmlBold
hi def link docxBoldDelimiter         docxBold
hi def link docxBoldItalic            htmlBoldItalic
hi def link docxBoldItalicDelimiter   docxBoldItalic
hi def link docxStrike                htmlStrike
hi def link docxStrikeDelimiter       docxStrike
hi def link docxCodeDelimiter         Delimiter

hi def link docxEscape                Special
"hi def link docxError                 Error

let b:current_syntax = "docx"
if main_syntax ==# 'docx'
  unlet main_syntax
endif

" vim:set sw=2:
