"=============================================================================
" File:         autoload/lh/tags/session.vim                      {{{1
" Author:       Luc Hermitte <EMAIL:luc {dot} hermitte {at} gmail {dot} com>
"		<URL:http://github.com/LucHermitte/lh-tags>
" License:      GPLv3 with exceptions
"               <URL:http://github.com/LucHermitte/lh-tags/blob/master/License.md>
" Version:      3.0.3.
let s:k_version = '303'
" Created:      31st Aug 2018
" Last Update:  04th Sep 2018
"------------------------------------------------------------------------
" Description:
"       «description»
"
"------------------------------------------------------------------------
" History:      «history»
" TODO:         «missing features»
" }}}1
"=============================================================================

let s:cpo_save=&cpo
set cpo&vim
"------------------------------------------------------------------------
" ## Misc Functions     {{{1
" # Version {{{2
function! lh#tags#session#version()
  return s:k_version
endfunction

" # Debug   {{{2
let s:verbose = get(s:, 'verbose', 0)
function! lh#tags#session#verbose(...)
  if a:0 > 0 | let s:verbose = a:1 | endif
  return s:verbose
endfunction

function! s:Log(expr, ...) abort
  call call('lh#log#this',[a:expr]+a:000)
endfunction

function! s:Verbose(expr, ...) abort
  if s:verbose
    call call('s:Log',[a:expr]+a:000)
  endif
endfunction

function! lh#tags#session#debug(expr) abort
  return eval(a:expr)
endfunction

" # SID      {{{2
" s:function(func_name) {{{3
function! s:function(func)
  if !exists("s:SNR")
    let s:SNR=matchstr(expand('<sfile>'), '<SNR>\d\+_\zefunction$')
  endif
  return function(s:SNR . a:func)
endfunction

"------------------------------------------------------------------------
" ## Exported functions {{{1

" Function: lh#tags#session#get(...) {{{3
" if !exists('s:crt_session')
  let s:crt_session = {
        \ 'tags': [],
        \ 'count': 0
        \ }
" endif

function! lh#tags#session#get(...) abort
  if s:crt_session.count == 0
    let s:crt_session = call('lh#tags#session#new', a:000)
  endif
  let s:crt_session.count += 1

  return s:crt_session
endfunction

" Function: lh#tags#session#new(...) {{{3
function! lh#tags#session#new(...) abort
  let session = lh#on#exit()
        \.register(s:function('release'))

  let args    = get(a:, 1, {})
  let indexer = get(args, 'indexer', 'ctags')
  " call extend(args, {'dont_update_tags_option': 1})
  let session.count   = 0
  let session.indexer = lh#tags#build_indexer(indexer, {'dont_update_tags_option': 1})
  let session.tags    = call(session.indexer.analyse_buffer, [args], session.indexer)

  return session
endfunction

function! s:release() abort
  let s:crt_session.count -= 1
  if s:crt_session.count == 0
    let s:crt_session.tags = []
  endif
endfunction

"------------------------------------------------------------------------
" ## Internal functions {{{1

"------------------------------------------------------------------------
" }}}1
"------------------------------------------------------------------------
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
