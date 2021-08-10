"=============================================================================
" File:         autoload/lh/tags/indexers/interface.vim           {{{1
" Author:       Luc Hermitte <EMAIL:luc {dot} hermitte {at} gmail {dot} com>
"		<URL:http://github.com/LucHermitte/lh-tags>
" License:      GPLv3 with exceptions
"               <URL:http://github.com/LucHermitte/lh-tags/blob/master/License.md>
" Version:      3.0.6.
let s:k_version = '306'
" Created:      26th Jul 2018
" Last Update:  10th Aug 2021
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
" - that need to be defined (overridden) in child functions
"   - get_kind_flags
"   - has_kind
"   - run_on_all_files          -- update tags for all files/directory
"   - run_update_file           -- update tags for current file (saved)
"   - run_update_modified_file  -- update tags for current file (modified, not saved)
"   - taglist                   -- wraps |taglist()| on a "forced" tag file
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

function! s:Callstack(...)
  if s:verbose
    call call('lh#log#callstack',a:000)
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

" Function: lh#tags#indexers#interface#make([args]) {{{2
function! lh#tags#indexers#interface#make(...) abort
  let res = lh#object#make_top_type(get(a:, 1, {}))
  call lh#object#inject_methods(res, s:k_script_name,
        \ 'set_db_file', 'db_file', 'src_dirname',
        \ 'analyse_buffer',
        \ '_fix_cygwin_paths',
        \ '__lhvl_oo_type')

  return res
endfunction

function! s:set_db_file(filename) dict abort " {{{2
  if !lh#path#writable(a:filename)
    throw "tags-error: ".a:filename." cannot be modified"
  endif
  let self._db_file = a:filename
  call self._fix_cygwin_paths()
endfunction

function! s:_fix_cygwin_paths() dict abort " {{{2
  " When calling cygwin-ctags from windows-vim, we cannot pass a full
  " windows absolute path. We need either to translate it, or to work
  " with relative paths.
  if lh#os#prog_needs_cygpath_translation(self.executable())
    let self._system_db_file = lh#os#system('cygpath -u '.shellescape(self._db_file))
  endif
endfunction

function! s:db_file() dict abort " {{{2
  return self._db_file
endfunction
function! s:src_dirname() dict abort " {{{2
  return s:DB_Dirname()
endfunction

function! s:analyse_buffer(...) dict abort " {{{2
  if !exists('s:temp_tags')
    let s:temp_tags = tempname()
  endif

  " previously known as lh#dev#__BuildCrtBufferCtags()
  let full_src_name = expand('%:.')
  let args = get(a:, 1, {})
  if &modified || has_key(args, 'firstline')
    let firstline   = get(args, 'firstline', 1)
    let lastline    = get(args, 'lastline',  '$')
    let source_name = tempname()
    let source_dir  = fnamemodify(source_name, ':h')
    call writefile(getline(firstline, lastline), source_name, 'b')
  else
    let source_name = expand('%:t')
    let source_dir  = expand('%:h')
  endif
  " call s:Verbose("Args: %1, %2", args, a:000)

  let ctags_dirname = fnamemodify(s:temp_tags, ':h')
  if filereadable(s:temp_tags)
    call delete(s:temp_tags)
  endif
  call self.set_db_file(s:temp_tags)

  let options = extend(args, {'forced_language':&ft, 'extract_local_variables': 1, 'end': 1, 'extract_prototypes': 0, 'analyse_file': source_name}, 'force')
  let cmd_line
        \ = lh#os#sys_cd(source_dir) . ' && '
        \ . join(self.cmd_line(options), ' ')

  if filereadable(s:temp_tags)
    call delete(s:temp_tags)
  endif
  call s:Verbose(cmd_line)
  let exec = system(cmd_line)
  if v:shell_error != 0
    throw "Cannot execute `".cmd_line."`: ".exec
  endif

  let pattern = get(args, 'pattern', '.')
  let lTags = self.taglist(pattern)

  " Inject back the right filename
  " -> it's necesary when working on extract of the original file, or
  "  when mixing cygwin-tags with windows-gvim
  call map(lTags, 'extend(v:val, {"filename": full_src_name}, "force")')
  return lTags
endfunction

function! s:__lhvl_oo_type() dict abort " {{{2
  return s:k_oo_type
endfunction

"------------------------------------------------------------------------
" ## Internal functions {{{1
" # Misc {{{2
let s:k_oo_type = 'ctags-indexer'
" Function: lh#tags#indexers#interface#is_an_indexer(dict) {{{3
function! lh#tags#indexers#interface#is_an_indexer(dict) abort
  return type(a:dict) == type({})
        \ && lh#object#is_an_object(a:dict)
        \ && a:dict.__lhvl_oo_type() == s:k_oo_type
endfunction

" # src_dirname support functions {{{2
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
  " - (bpg):paths.tags.src_dir
  " - (bpg):tags_dirname
  " - (bpg):paths.sources
  " - b:project_source_dir (mu-template)
  " - BTW_project_config._.paths.sources (BTW)
  " - Where .git/ is found is parent dirs
  " - Where .svn/ is found in parent dirs
  " - confirm box for %:p:h, and remember previous paths
  let src_dirname = lh#option#get('paths.tags.src_dir')
  if lh#option#is_unset(src_dirname)
    unlet src_dirname
    let src_dirname = s:FetchDBDirname()
    call lh#let#to('p:paths.tags.src_dir', src_dirname)
  endif

  let res = lh#path#to_dirname(src_dirname)

  return res
endfunction

" # lh#tags#indexers#interface#_sort_lines(t1, t2) {{{2
function! lh#tags#indexers#interface#_sort_lines(t1, t2) abort
  let l1 = a:t1.line
  let l2 = a:t2.line
  return    l1 == l2 ? 0
        \ : l1 >  l2 ? 1
        \ :           -1
endfunction

"------------------------------------------------------------------------
" }}}1
"------------------------------------------------------------------------
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
