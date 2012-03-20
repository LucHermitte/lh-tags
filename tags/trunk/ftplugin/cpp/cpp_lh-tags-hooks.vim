"=============================================================================
" $Id$
" File:		ftplugin/cpp/cpp_lh-tags-hooks.vim                {{{1
" Author:	Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"		<URL:http://hermitte.free.fr/vim/>
" License:      GPLv3 with exceptions
"               <URL:http://code.google.com/p/lh-vim/wiki/License>
" Version:	1.0.0
let s:version = '1.0.0'
" Created:	29th Sep 2008
" Last Update:	$Date$
"------------------------------------------------------------------------
" Description:	«description»
" 
"------------------------------------------------------------------------
" Installation:	«install details»
" History:	«history»
" TODO:		«missing features»
" }}}1
"=============================================================================

" Buffer-local Definitions {{{1
" Avoid local reinclusion {{{2
if &cp || (exists("b:loaded_ftplug_cpp_lh_tags_hooks") && !exists('g:force_reload_ftplug_cpp_lh_tags_hooks'))
  finish
endif
let b:loaded_ftplug_cpp_lh_tags_hooks = s:version
let s:cpo_save=&cpo
set cpo&vim
" Avoid local reinclusion }}}2

"------------------------------------------------------------------------
" Local settings {{{2

let b:tags_select = 'LHCpp_Tag_select_id()'

" Local mappings {{{2

"------------------------------------------------------------------------
" Local commands {{{2

"=============================================================================
" Global Definitions {{{1
" Avoid global reinclusion {{{2
if &cp || (exists("g:loaded_ftplug_cpp_lh_tags_hooks") && !exists('g:force_reload_ftplug_cpp_lh_tags_hooks'))
  let &cpo=s:cpo_save
  finish
endif
let g:loaded_ftplug_cpp_lh_tags_hooks = s:version
" Avoid global reinclusion }}}2
"------------------------------------------------------------------------
" Functions {{{2
" Note: most filetype-global functions are best placed into
" autoload/«your-initials»/cpp/«cpp_lh_tags_hooks».vim
" Keep here only the functions are are required when the ftplugin is
" loaded, like functions that help building a vim-menu for this
" ftplugin.

let s:re_id      = '\<\I\i*\>'
let s:re_leading = '\%(\s*'.s:re_id.'\s*::\s*\)*'

function! s:Re_main(col)
  let re_main    = '\<\%'.a:col.'\I\i*\>\|\<\I\i*\%'.a:col.'\i*\>'
  return re_main
endfunction

function! LHCpp_Tag_select_id()
  let line = getline('.')
  let col = col('.').'c'
  let re_crt     = s:re_leading . '\('.s:Re_main(col).'\)'

  let match = matchstr(line, re_crt)
  let tag = substitute(match, '\s\+', '', 'g')
  return tag
endfunction

" Functions }}}2
"------------------------------------------------------------------------
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
