"=============================================================================
" File:         autoload/lh/tags/system.vim                       {{{1
" Author:       Luc Hermitte <EMAIL:luc {dot} hermitte {at} gmail {dot} com>
"		<URL:http://github.com/LucHermitte/lh-tags>
" License:      GPLv3 with exceptions
"               <URL:http://github.com/LucHermitte/lh-tags/blob/master/License.md>
" Version:      3.0.0.
let s:k_version = '300'
" Created:      26th Jul 2018
" Last Update:  26th Jul 2018
"------------------------------------------------------------------------
" Description:
"       Functions for launching external processes
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
function! lh#tags#system#version()
  return s:k_version
endfunction

" # Debug   {{{2
let s:verbose = get(s:, 'verbose', 0)
function! lh#tags#system#verbose(...)
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

function! lh#tags#system#debug(expr) abort
  return eval(a:expr)
endfunction

" # SID     {{{2
function! s:getSID() abort
  return eval(matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_getSID$'))
endfunction
let s:k_script_name      = s:getSID()

" # Options {{{2
let s:has_jobs     = lh#has#jobs()
let s:has_partials = lh#partial#has()

" Function: s:RunInBackground() {{{3
if s:has_jobs
  function! s:RunInBackground() abort
    return get(g:tags_options, 'run_in_bg')
  endfunction
else
  function! s:RunInBackground() abort
    return 0
  endfunction
endif

"------------------------------------------------------------------------
" ## Exported functions {{{1

" # System object {{{2
" Function: lh#tags#system#get_runner(mode) {{{3
function! lh#tags#system#get_runner(mode) abort
  call lh#assert#value(s:runners).has_key(a:mode)

  return s:RunInBackground() ? s:runners[a:mode] : s:runners.sync
endfunction

" Function: s:make_sync_system() {{{3
function! s:make_sync_system() abort
  let res = lh#object#make_top_type({})
  call lh#object#inject(res, 'run', 'run_sync', s:k_script_name)
  return res
endfunction

" Function: s:make_async_system() {{{3
function! s:make_async_system() abort
  let res = lh#object#make_top_type({})
  call lh#object#inject(res, 'run', 'run_async', s:k_script_name)
  return res
endfunction

" Function: s:run_sync(cmd_line, txt, finished_cb [, before_start_cb]) {{{3
function! s:run_sync(cmd_line, txt, finished_cb, ...) abort
  if a:0 > 0
    call lh#partial#execute(a:1)
  endif
  call s:Verbose("%1 with %2", a:txt, a:cmd_line)
  let res = lh#os#system(a:cmd_line)
  if v:shell_error
    throw "Cannot execute system call (".a:cmd_line."): ".res
  endif
  call lh#partial#execute(a:finished_cb)
  return res
endfunction

" Function: s:run_async(cmd_line, txt, finished_cb [, before_start_cb]) {{{3
function! s:async_output_factory()
  let res = {'output': []}
  function! s:callback(channel, msg) dict abort
    let self.output += [ a:msg ]
  endfunction
  let res.callback = function('s:callback')
  return res
endfunction

function! s:run_async(cmd_line, txt, finished_cb, ...) abort
  call s:Verbose('Register: %1',a:cmd_line)
  let async_output = s:async_output_factory()
  let job =
        \ { 'txt': a:txt
        \ , 'cmd': a:cmd_line
        \ , 'close_cb': function(a:finished_cb, [async_output])
        \ , 'callback': function(async_output.callback)
        \}
  if a:0 > 0
    let job.before_start_cb = a:1
  endif
  call lh#async#queue(job)
  return 0
endfunction

"------------------------------------------------------------------------
" ## Internal functions {{{1
" Function: lh#tags#system#__init() {{{2
function! lh#tags#system#__init() abort
  let runners = {}
  let runners.sync = s:make_sync_system()
  let runners.async = s:has_jobs && s:has_partials
        \ ? s:make_async_system()
        \ : runners.sync
  let s:runners = runners
endfunction

"------------------------------------------------------------------------
" }}}1
"------------------------------------------------------------------------
call lh#tags#system#__init()
"------------------------------------------------------------------------
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
