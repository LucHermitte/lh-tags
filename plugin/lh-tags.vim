"=============================================================================
" $Id$
" File:		plugin/lh-tags.vim                                        {{{1
" Author:	Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"		<URL:http://code.google.com/p/lh-vim/>
" License:      GPLv3 with exceptions
"               <URL:http://code.google.com/p/lh-vim/wiki/License>
" Version:	1.0.0
let s:version = '1.0.0'
" Created:	04th Jan 2007
" Last Update:	$Date$
"------------------------------------------------------------------------
" Description:	
" 	Small plugin related to tags files. 
" 	It helps:
" 	- generate tag files
" 	- navigate (or more precisely: find the right tags)
" 
"------------------------------------------------------------------------
" Installation:	«install details»
" History:	
"       v3.0.0:
"       (*) GPLv3
" 	v0.2.0: 03rd Oct 2008
" 	(*) code moved to an autoload plugin
" 	v0.1.3: 30th Sep 2008
" 	(*) Langage hooks
" 	(*) ShowTags command
" 	(*) :LHTags command (that supports auto completion)
" 	v0.1.2: 11th Sep 2007
" 	(*) Fix a path problem on file save
" 	(*) Using a scratch buffer
" 	v0.1.1:
" 	(*) Using 'nomagic' when manually jumping to tags
" 	v0.1.0: 
" 	(*) Initial Version
" TODO:
" @todo use --abort-- in the scratch buffer
" @todo update tags history
" @todo inline help for sort
" @todo filter (like :g/:v)
" @todo toggle display signature
" @todo use keywords dependent on the ft
" @todo pluggable filters (that will check the number of parameters, their
" type, etc)
" }}}1
"=============================================================================


" ######################################################################
" Plugin pre-conditions {{{1
" Avoid global reinclusion {{{2
let s:cpo_save=&cpo
set cpo&vim
if exists("g:loaded_lh_tags") && !exists('g:force_reload_lh_tags')
  let &cpo=s:cpo_save
  finish 
endif
"------------------------------------------------------------------------
" Needs ctags executable {{{2
let s:tags_executable = lh#option#get('tags_executable', 'ctags', 'bg')
let s:script = expand('<sfile>:p')

if !executable(s:tags_executable)
  let g:loaded_lh_tags = s:script.' not loaded as ``'.s:tags_executable."'' is not available in $PATH"
  finish
endif

" ######################################################################
" Tag generation {{{1
" ======================================================================
" Mappings {{{2
" inoremap <expr> ; lh#tags#run('UpdateTags_for_ModifiedFile',';')

nnoremap <silent> <Plug>CTagsUpdateCurrent :call lh#tags#update_current()<cr>
if !hasmapto('<Plug>CTagsUpdateCurrent', 'n')
  nmap <silent> <c-x>tc  <Plug>CTagsUpdateCurrent
endif

nnoremap <silent> <Plug>CTagsUpdateAll     :call lh#tags#update_all()<cr>
if !hasmapto('<Plug>CTagsUpdateAll', 'n')
  nmap <silent> <c-x>ta  <Plug>CTagsUpdateAll
endif


" ======================================================================
" Auto command for automatically tagging a file when saved {{{2
augroup LH_TAGS
  au!
  autocmd BufWritePost,FileWritePost * if ! lh#option#get('LHT_no_auto', 0) | call lh#tags#run('UpdateTags_for_SavedFile',0) | endif
aug END

" ######################################################################
" Tag browsing {{{1

nnoremap <silent> <Plug>CTagsSplitOpen     :call lh#tags#split_open()<cr>
if !hasmapto('<Plug>CTagsSplitOpen', 'n')
  nmap <silent> <c-w><m-down>  <Plug>CTagsSplitOpen
endif
vnoremap <silent> <Plug>CTagsSplitOpen     <C-\><C-n>:call lh#tags#split_open(lh#visual#selection())<cr>
if !hasmapto('<Plug>CTagsSplitOpen', 'v')
  vmap <silent> <c-w><m-down>  <Plug>CTagsSplitOpen
endif

" ######################################################################
" Tag command {{{1
" ======================================================================

command! -nargs=* -complete=custom,LHTComplete
      \		LHTags call lh#tags#command(<f-args>)

" todo: 
" * filter on +/- f\%[unction]
" * filter on +/- a\%[ttribute]
" * filter on +/#/- v\%[isibility] (pub/pro/pri)

" Command completion  {{{1
let s:commands = '^LHT\%[ags]'
function! LHTComplete(ArgLead, CmdLine, CursorPos)  
  let cmd = matchstr(a:CmdLine, s:commands)
  let cmdpat = '^'.cmd

  let tmp = substitute(a:CmdLine, '\s*\S\+', 'Z', 'g')
  let pos = strlen(tmp)
  let lCmdLine = strlen(a:CmdLine)
  let fromLast = strlen(a:ArgLead) + a:CursorPos - lCmdLine 
  " The argument to expand, but cut where the cursor is
  let ArgLead = strpart(a:ArgLead, 0, fromLast )
  let ArgsLead = strpart(a:CmdLine, 0, a:CursorPos )
  if 0
    call confirm( "a:AL = ". a:ArgLead."\nAl  = ".ArgLead
	  \ . "\nAsL = ".ArgsLead
	  \ . "\nx=" . fromLast
	  \ . "\ncut = ".strpart(a:CmdLine, a:CursorPos)
	  \ . "\nCL = ". a:CmdLine."\nCP = ".a:CursorPos
	  \ . "\ntmp = ".tmp."\npos = ".pos
	  \, '&Ok', 1)
  endif

  " Build the pattern for taglist() -> all arguements are joined with '.*'
  " let pattern = ArgsLead
  let pattern = a:CmdLine
  " ignore the command
  let pattern = substitute(pattern, '^\S\+\s\+', '', '')
  let pattern = substitute(pattern, '\s\+', '.*', 'g')
  let tags = taglist(pattern)
  if 0
    call confirm ("pattern".pattern."\n->".string(tags), '&Ok', 1)
  endif

  " Keep only tag names
  let lRes = []
  call lh#list#Transform(tags, lRes, 'v:val.name')

  " No need (yet) to descend into the hierarchy
  call map(lRes, 'matchstr(v:val, '.string(ArgLead).'.".\\{-}\\>")')
  let lRes = lh#list#unique_sort(lRes)
  let res = join(lRes, "\n")
  if 0
    call confirm (string(res), '&Ok', 1)
  endif
  return res
endfunction

" ======================================================================
let g:loaded_lh_tags = s:version
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
