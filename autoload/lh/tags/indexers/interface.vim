"=============================================================================
" File:         autoload/lh/tags/indexers/interface.vim           {{{1
" Author:       Luc Hermitte <EMAIL:luc {dot} hermitte {at} gmail {dot} com>
"		<URL:http://github.com/LucHermitte/lh-tags>
" License:      GPLv3 with exceptions
"               <URL:http://github.com/LucHermitte/lh-tags/blob/master/License.md>
" Version:      3.0.0.
let s:k_version = '300'
" Created:      26th Jul 2018
" Last Update:  30th Jul 2018
"------------------------------------------------------------------------
" Description:
"       Interface for indexer objects
"
" Services:
" - 3 main entry points:
"   - index_tree
"   - index_update_file
"   - get_file_tags
" - Parameters (to translate to the indexer used):
"   - Restrict the language of the file analysed in a tree
"   - kind of informations to index (functions, definitions, declaration,
"   variables...)
"   - possibility of low level overriding?
"   - destination file
"
" Usage:
" Parameters will be set at project level (tag filename...)
" When building the command line, other parameters can be injected
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
function! lh#tags#indexers#interface#version()
  return s:k_version
endfunction

" # Debug   {{{2
let s:verbose = get(s:, 'verbose', 0)
function! lh#tags#indexers#interface#verbose(...)
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

function! lh#tags#indexers#interface#debug(expr) abort
  return eval(a:expr)
endfunction

" # SID     {{{2
function! s:getSID() abort
  return eval(matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_getSID$'))
endfunction
let s:k_script_name      = s:getSID()

"------------------------------------------------------------------------
" ## Exported functions {{{1

" Function: lh#tags#indexers#interface#make() {{{2
function! lh#tags#indexers#interface#make() abort
  let res = lh#object#make_top_type({})
  call lh#object#inject_methods(res, s:k_script_name,
        \ 'run', 'set_output_file', 'db_file', 'db_dirname')

  " TODO: harmonize set_output_file & db_file
  return res
endfunction

function! s:set_output_file(filename) dict abort " {{{2
  if !filewritable(a:filename)
    throw "tags-error: ".a:filename." cannot be modified"
  endif
  let self._db_file = a:filename
endfunction

function! s:db_file() dict abort " {{{2
  return self._db_file
endfunction
function! s:db_dirname() dict abort " {{{2
  return s:DB_Dirname()
endfunction

function! s:run(args) dict abort " {{{2
endfunction

"------------------------------------------------------------------------
" ## Internal functions {{{1
" # db_dirname support functions {{{2
" TODO: be able to distinguish where the sources are from where the tags
" DB is stored.
let s:project_roots = get(s:, 'project_roots', [])
function! s:GetPlausibleRoot() abort " {{{3
  " Note: this is a simplified version of the one from lhvl#Project
  call s:Callstack("Request plausible root")
  let crt = expand('%:p:h')
  let compatible_paths = filter(copy(s:project_roots), 'lh#path#is_in(crt, v:val)')
  if len(compatible_paths) == 1
    return compatible_paths[0]
  endif
  if len(compatible_paths) > 1
    let dirname = lh#path#select_one(compatible_paths, "ctags needs to know the current project root directory")
    if !empty(dirname)
      return dirname
    endif
  endif
  let dirname = lh#ui#input("ctags needs to know the current project root directory.\n-> ", expand('%:p:h'))
  if !empty(dirname)
    call lh#path#munge(s:project_roots, dirname)
  endif
  return dirname
endfunction

function! s:FetchDBDirname() abort " {{{3
  " 0- Old deprecated value: tags_dirname
  " 1- from lhlv#project: paths.sources
  " 2- from mu-template: project_sources_dir -- to be deprecated
  " 3- from BTW
  let dirname = lh#project#_check_project_variables(
        \ ['tags_dirname', 'paths.sources', 'project_sources_dir', ['BTW_project_config', '_.paths.sources']])
  if lh#option#is_set(dirname)
    return dirname
  endif

  " VCS & co
  let vcs_dirname = lh#project#_check_VCS_roots()
  if lh#option#is_set(vcs_dirname)
    return vcs_dirname
  endif

  " Deduce from current path, previous project paths
  return s:GetPlausibleRoot()
endfunction

function! s:DB_Dirname(...) abort " {{{3
  " Will be searched in descending priority in:
  " - (bpg):paths.tags.db_dir
  " - (bpg):tags_dirname
  " - (bpg):paths.sources
  " - b:project_source_dir (mu-template)
  " - BTW_project_config._.paths.sources (BTW)
  " - Where .git/ is found is parent dirs
  " - Where .svn/ is found in parent dirs
  " - confirm box for %:p:h, and remember previous paths
  let db_dirname = lh#option#get('paths.tags.db_dir')
  if lh#option#is_unset(db_dirname)
    unlet db_dirname
    let db_dirname = s:FetchDBDirname()
    call lh#let#to('p:paths.tags.db_dir', db_dirname)
  endif

  let res = lh#path#to_dirname(db_dirname)

  return res
endfunction


"------------------------------------------------------------------------
" }}}1
"------------------------------------------------------------------------
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
