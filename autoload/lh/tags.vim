"=============================================================================
" File:         autoload/lh/tags.vim                                    {{{1
" Author:       Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"               <URL:http://github.com/LucHermitte/lh-tags>
" License:      GPLv3 with exceptions
"               <URL:http://github.com/LucHermitte/lh-tags/tree/master/License.md>
" Version:      2.0.5
let s:k_version = '2.0.5'
" Created:      02nd Oct 2008
" Last Update:  09th Mar 2018
"------------------------------------------------------------------------
" Description:
"       Small plugin related to tags files.
"       (Deported functions)
"
" TODO:
"       Find a way to update update &tags correctly when tags are searched and
"       not at another moment.
"
"------------------------------------------------------------------------
" History:
"       v2.0.5:
"       (*) Change C++ property field for recent version of uctags
"       v2.0.4:
"       (*) Change --extra option to --extras for recent uctags
"       v2.0.3:
"       (*) Move to use lh-vim-lib v4 Project feature
"       (*) Normalize scratch buffer name
"       (*) Move cmdline completion function to autoload plugin
"       v2.0.2:
"       (*) Remove `v:shell_error` test after `job_start`
"       (*) Tags can be automatically highlighted
"       v2.0.1:
"       (*) Simplify and speeds-up spellfile feature
"       v2.0.0:
"       (*) s/lh#tags#options/tags_options/
"           because b:lh#tags#options isn't a valid variable name
"       (*) Add indexed filetype to specify which files will be indexed
"           TODO: Add also a blacklist option
"       (*) Use ctags `--language=` option
"       (*) Rename (wbg):tags_options to  (wbg):tags_options.flags
"       (*) Rename (wbg):tags_options_{ft} to  (wbg):tags_options.{ft}.flags
"       (*) Fix: UpdateTags_for_SavedFile
"       (*) Fix s:PurgeFileReferences
"       (*) Generate tags in the background
"       (*) lh#tags#ctags_flavor() renamed to lh#tags#ctags_flavour()
"       (*) Add lh#tags#set_lang_map() to set language mappings
"       (*) Remove ctags `--language-force=` option
"           Check it's okay w/
"           [ ] lh-dev/lh-refactor
"           [X] vif
"       v1.7.0:
"       (*) Auto detect project root directory
"       v1.6.3:
"       (*) Support ctags flavour w/o '--version' in lh#tags#ctags_flavour()
"           See lh-brackets issue#10
"       v1.6.2:
"       (*) Don't override g:tags_options with g:tags_options
"           TODO: merge these two into g:tags_options
"       v1.6.1:
"       (*) Bug fix for lh#tags#option_force_lang in C++
"       v1.6.0:
"       (*) New functions to get:
"           - ctags kinds associated to function/method definitions
"           - ctags language associated to vim filetype
"       v1.5.2:
"       (*) Universal ctags offers a --fields=+x{c++.properties} option
"       v1.5.1:
"       (*) Remove assert_true() call.
"       v1.5.0:
"       (*) New function lh#tags#ctags_flavour()
"       v1.4.2:
"       (*) Better flags for C++ analysis
"       v1.4.1:
"       (*) abort added to functions
"       v1.4.0:
"       (*) Dependency to system-tools removed
"       v1.3.0:
"       (*) filter tag browsing
"       v1.2.0:
"       (*) Injects &l:tags automatically in the new file opened
"       v1.1.0:
"       (*) new option: tags_to_spellfile that activates the automated
"           generation of spellfiles that contains all symbols from the
"           (re-)generated tagfile.
"       v1.0.0: GPLv3
"       v0.2.4: 26th Aug 2011
"       (*) tags jumping fixed to support the use of buffer-local &tags
"       v0.2.3: 23rd Dec 2010
"       (*) system() calls catch errors
"       v0.2.2: 26th May 2010
"       (*) s/s:tags/&_jump/g
"       (*) hook to run ctags with the default options, plus other ones
"       v0.2.1: 22nd Apr 2010
"       (*) Do not reuse a search buffer
"       (*) Jumps are pushed into the tagstack
"       v0.2.0: 03rd Oct 2008
"       (*) code moved to an autoload plugin
" TODO:
"       (*) Have behaviour similar to the one from the quickfix mode
"       (possibility to close and reopen the search window; prev&next moves)
"       (*) Show/hide declarations -- merge declaration and definitions
" }}}1
"=============================================================================

let s:cpo_save=&cpo
set cpo&vim
"------------------------------------------------------------------------
runtime plugin/let.vim

" ######################################################################
" ## Misc Functions     {{{1
" # Version {{{2
function! lh#tags#version()
  return s:k_version
endfunction

" # Debug   {{{2
let s:verbose = get(s:, 'verbose', 0)
function! lh#tags#verbose(...)
  if a:0 > 0 | let s:verbose = a:1 | endif
  return s:verbose
endfunction

function! s:Log(expr, ...)
  call call('lh#log#this',[a:expr]+a:000)
endfunction

function! s:Verbose(expr, ...)
  if s:verbose
    call call('s:Log',[a:expr]+a:000)
  endif
endfunction

function! s:Callstack(...)
  if s:verbose
    call call('lh#log#callstack',a:000)
  endif
endfunction

function! lh#tags#debug(expr) abort
  return eval(a:expr)
endfunction

" # s:System {{{2
function! s:System(cmd_line) abort
  call s:Verbose(a:cmd_line)
  let res = lh#os#system(a:cmd_line)
  if v:shell_error
    throw "Cannot execute system call (".a:cmd_line."): ".res
  endif
  return res
endfunction

" # s:AsyncSystem {{{2
function! s:async_output_factory()
  let res = {'output': []}
  function! s:callback(channel, msg) dict abort
    let self.output += [ a:msg ]
  endfunction
  let res.callback = function('s:callback')
  return res
endfunction

function! s:AsynchSystem(cmd_line, txt, FinishedCB, ...) abort
  if s:RunInBackground()
    call s:Verbose('Register: %1',a:cmd_line)
    let async_output = s:async_output_factory()
    let job =
          \ { 'txt': a:txt
          \ , 'cmd': a:cmd_line
          \ , 'close_cb': function(a:FinishedCB, [async_output])
          \ , 'callback': function(async_output.callback)
          \}
    if a:0 > 0
      let job.before_start_cb = a:1
    endif
    call lh#async#queue(job)
    let res = 0
  else
    if a:0 > 0
      let Cb = a:1
      call Cb()
    endif
    call s:Verbose(a:cmd_line)
    let res = lh#os#system(a:cmd_line)
    call a:FinishedCB()
    if v:shell_error " after a job_start, it cannot be used
      throw "Cannot execute system call (".a:cmd_line."): ".res
    endif
  endif
  return res
endfunction

" ######################################################################
" ## Options {{{1
" ======================================================================
" # ctags executable {{{2
" Function: s:CtagsExecutable() {{{3
function! s:CtagsExecutable() abort
  let tags_executable = lh#option#get('tags_executable', 'ctags', 'bg')
  return tags_executable
endfunction

" Function: lh#tags#ctags_is_installed() {{{3
function! lh#tags#ctags_is_installed() abort
  return executable(s:CtagsExecutable())
endfunction

" Function: lh#tags#ctags_flavour() {{{3
function! lh#tags#ctags_flavour() abort
  " @since version 1.5.0
  " call assert_true(lh#tags#ctags_is_installed())
  try
    let ctags_executable = s:CtagsExecutable()
    if !lh#tags#ctags_is_installed()
      return 'echo "No '.ctags_executable.' binary found: "'
    endif
    let ctags_version = s:System(s:CtagsExecutable(). ' --version')
    if ctags_version =~ 'Universal Ctags'
      " Here I'm interrested in knowing whether --extras has deprectaed
      " --extra, which was done in commit d76bc95
      if ctags_version =~ 'Compiled:.*201[56]'
        return 'utags-old'
      else
        return 'utags'
      endif
    elseif ctags_version =~ 'Exuberant Ctags'
      return 'etags'
    else
      return ctags_version
    endif
  catch /.*/
    return "bsd?"
  endtry
endfunction

" # The options {{{2
let s:has_jobs     = lh#has#jobs()
let s:has_partials = lh#has#partials()
"
" Forcing ft -> ctags languages {{{3
" list {{{4
let s:force_lang = {
      \ 'ada' : 'Ada',
      \ 'ant' : 'Ant',
      \ 'asm' : 'Asm',
      \ 'automake' : 'Automake',
      \ 'awk' : 'Awk',
      \ 'c' : 'C',
      \ 'cs' : 'C#',
      \ 'cpp' : 'C++',
      \ 'clojure' : 'Clojure',
      \ 'cobol' : 'Cobol',
      \ 'css' : 'CSS',
      \ 'tags' : 'ctags',
      \ 'd' : 'D',
      \ 'dosbatch' : 'DosBatch',
      \ 'dts' : 'DTS',
      \ 'eiffel' : 'Eiffel',
      \ 'erlang' : 'Erlang',
      \ 'falcon' : 'Falcon',
      \ 'lex' : 'Flex',
      \ 'fortran' : 'Fortran',
      \ 'go' : 'Go',
      \ 'html' : 'HTML',
      \ 'java' : 'Java',
      \ 'jproperties' : 'JavaProperties',
      \ 'javascript' : 'JavaScript',
      \ 'json' : 'JSON',
      \ 'lisp' : 'Lisp',
      \ 'lua' : 'Lua',
      \ 'make' : 'Make',
      \ 'matlab' : 'MatLab',
      \ 'objc' : 'ObjectiveC',
      \ 'ocaml' : 'OCaml',
      \ 'pascal' : 'Pascal',
      \ 'perl' : 'Perl',
      \ 'perl6' : 'Perl6',
      \ 'php' : 'PHP',
      \ 'python' : 'Python',
      \ 'r' : 'R',
      \ 'rrst' : 'reStructuredText',
      \ 'rexx' : 'REXX',
      \ 'ruby' : 'Ruby',
      \ 'rust' : 'Rust',
      \ 'scheme' : 'Scheme',
      \ 'sh' : 'Sh',
      \ 'slang' : 'SLang',
      \ 'sml' : 'SML',
      \ 'sql' : 'SQL',
      \ 'svg' : 'SVG',
      \ 'systemverilog' : 'SystemVerilog',
      \ 'tcl' : 'Tcl',
      \ 'tex' : 'Tex',
      \ 'vera' : 'Vera',
      \ 'verilog' : 'Verilog',
      \ 'vhdl' : 'VHDL',
      \ 'vim' : 'Vim',
      \ 'xslt' : 'XSLT',
      \ 'yacc' : 'YACC',
      \ }

function! s:BuildForceLangOption() abort " {{{4
  for [ft, lang] in items(s:force_lang)
    call lh#let#if_undef('g:tags_options.'.ft.'.force', lang)
  endfor
endfunction
call s:BuildForceLangOption()

" function kinds {{{3
" The ctags kind for function implementation may be f in C, C++, but m in Java,
" C#, ...
let s:func_kinds =
      \ { 'r': ['ada']
      \ , 'm': ['java', 'cs']
      \ , '[mf]' : ['javascript', 'objc', 'ocaml']
      \ , '[pf]' : ['pascal']
      \ , 's' : ['perl']
      \ , '[bsm]' : ['perl6']
      \ , '[fF]' : ['rust']
      \ , '[f]' : ['vim']
      \ }
function! s:BuildFuncKinds()
  for [pat, fts] in items(s:func_kinds)
    for ft in fts
      call lh#let#if_undef('g:tags_options.'.ft.'.func_kind', pat)
    endfor
  endfor
endfunction
call s:BuildFuncKinds()

" Function: lh#tags#option_force_lang(ft) {{{3
function! lh#tags#option_force_lang(ft) abort
  return lh#option#get('tags_options.'.a:ft.'.force')
endfunction

" Function: lh#tags#func_kind(ft) {{{3
function! lh#tags#func_kind(ft) abort
  return lh#option#get('tags_options.'.a:ft.'.func_kind', 'f')
endfunction

" Fields options {{{3
" They'll get overriden everytime this file is loaded
LetIfUndef g:tags_options {}
if lh#tags#ctags_is_installed()
  let s:flavour = lh#tags#ctags_flavour()
  if s:flavour == 'utags'
    LetTo g:tags_options.__extra = '--extras'
    LetIfUndef g:tags_options.cpp.flags  = '--c++-kinds=+pf --fields=+imaSft --fields-c++=+{properties} --extras=+q'
  elseif s:flavour == 'utags-old'
    LetTo g:tags_options.__extra = '--extra'
    LetIfUndef g:tags_options.cpp.flags  = '--c++-kinds=+pf --fields=+imaSft &x{c++.properties} --extras=+q'
  else " etags
    LetTo g:tags_options.__extra = '--extra'
    LetIfUndef g:tags_options.cpp.flags  = '--c++-kinds=+pf --fields=+imaSft --extra=+q'
  endif
  LetIfUndef g:tags_options.c.flags    = '--c++-kinds=+pf --fields=+imaS '.(g:tags_options.__extra).'=+q'
  " LetIfUndef g:tags_options.cpp.flags  = '--c++-kinds=+pf --fields=+imaSft '.(g:tags_options.__extra).'=+q --language-force=C++'
  " LetIfUndef g:tags_options.java.flags = '--c++-kinds=+acefgimp --fields=+imaSft '.(g:tags_options.__extra).'=+q --language-force=Java'
  LetIfUndef g:tags_options.java.flags = '--c++-kinds=+acefgimp --fields=+imaSft '.(g:tags_options.__extra).'=+q'
  LetIfUndef g:tags_options.vim.flags  = '--fields=+mS '.(g:tags_options.__extra).'=+q'
endif

function! s:CtagsOptions() abort " {{{3
  " TODO: Need to pick various options (kind, langmap, fields, extra...) in
  " various places (b:, p:, g:) and assemble back something
  let ctags_options = ' --tag-relative=yes'
  let ctags_options .= ' '.lh#option#get('tags_options.'.&ft.'.flags', '')
  let ctags_options .= ' '.lh#option#get('tags_options.flags', '', 'wbpg')
  let ctags_options .= ' '.lh#option#get('tags_options.langmap', '', 'wbpg')
  let fts = lh#option#get('tags_options.indexed_ft')
  if lh#option#is_set(fts)
    let langs = map(copy(fts), 'get(s:force_lang, v:val, "")')
    " TODO: warn about filetypes unknown to ctags
    call filter(langs, '!empty(v:val)')
    let ctags_options .= ' --languages='.join(langs, ',')
  endif
  return ctags_options
endfunction

function! s:is_ft_indexed(ft) abort " {{{3
  " This option needs to be set in each project!
  let indexed_ft = lh#option#get('tags_options.indexed_ft', [])
  return index(indexed_ft, a:ft) >= 0
endfunction

" Function: lh#tags#add_indexed_ft([ft list]) {{{3
function! lh#tags#add_indexed_ft(...) abort
  return call('lh#let#_push_options', ['p:tags_options.indexed_ft'] + a:000)
endfunction

" Function: lh#tags#set_lang_map(lang, exts) {{{3
function! lh#tags#set_lang_map(ft, exts) abort
  let lang = get(get(g:tags_options, a:ft, {}), 'force', lh#option#unset())
  if lh#option#is_unset(lang)
    throw "No language associated to " .a:ft." filetype for ctags!"
  endif
  " Be sure the option exists
  call lh#let#if_undef('p:tags_options.'.a:ft.'.langmap', '')
  " Override it
  if lh#tags#ctags_flavour() =~ 'utags'
    call lh#let#to('p:tags_options.'.a:ft.'.langmap', '--map-'.lang.'='.a:exts)
  else
    call lh#let#to('p:tags_options.'.a:ft.'.langmap', '--langmap='.lang.':'.a:exts)
  endif
endfunction

let s:project_roots = get(s:, 'project_roots', [])
function! s:GetPlausibleRoot() abort " {{{3
  call s:Callstack("Request plausible root")
  let crt = expand('%:p:h')
  let compatible_paths = filter(copy(s:project_roots), 'lh#path#is_in(crt, v:val)')
  if len(compatible_paths) == 1
    return compatible_paths[0]
  endif
  if len(compatible_paths) > 1
    let ctags_dirname = lh#path#select_one(compatible_paths, "ctags needs to know the current project root directory")
    if !empty(ctags_dirname)
      return ctags_dirname
    endif
  endif
  let ctags_dirname = lh#ui#input("ctags needs to know the current project root directory.\n-> ", expand('%:p:h'))
  if !empty(ctags_dirname)
    call lh#path#munge(s:project_roots, ctags_dirname)
  endif
  return ctags_dirname
endfunction

function! s:FetchCtagsDirname() abort " {{{3
  let sources_dir = lh#option#get('paths.sources')
  if lh#option#is_set(sources_dir)
    return sources_dir
  endif

  " call assert_true(!exists('b:tags_dirname'))
  let project_sources_dir = lh#option#get('project_sources_dir')
  if lh#option#is_set(project_sources_dir)
    return project_sources_dir
  endif
  let config = lh#option#get('BTW_project_config')
  if lh#option#is_set(config) && has_key(config, '_')
    let ctags_dirname = get(get(config._, 'paths', {}), 'sources', '')
    if !empty(ctags_dirname)
      return ctags_dirname
    else
      call lh#common#warning_msg('BTW_project_config is set, but `BTW_project_config._.paths.sources` is empty')
    endif
  endif
  let ctags_dirname = lh#vcs#get_git_root()
  if !empty(ctags_dirname)
    return matchstr(ctags_dirname, '.*\ze\.git$')
  endif
  let ctags_dirname = lh#vcs#get_svn_root()
  if !empty(ctags_dirname)
    return matchstr(ctags_dirname, '.*\ze\.svn$')
  endif

  return s:GetPlausibleRoot()
endfunction

function! s:CtagsDirname(...) abort " {{{3
  " Will be searched in descending priority in:
  " - (bpg):tags_dirname
  " - (bpg):paths.sources
  " - b:project_source_dir (mu-template)
  " - BTW_project_config._.paths.sources (BTW)
  " - Where .git/ is found is parent dirs
  " - Where .svn/ is found in parent dirs
  " - confirm box for %:p:h, and remember previous paths
  let tags_dirname = lh#option#get('tags_dirname')
  if lh#option#is_unset(tags_dirname)
    unlet tags_dirname
    let tags_dirname = s:FetchCtagsDirname()
    call lh#let#to('p:tags_dirname', tags_dirname)
  endif

  let res = lh#path#to_dirname(tags_dirname)
  " TODO: find another way to autodetect tags paths
  if get(a:, 1, 1)
    call lh#tags#update_tagfiles()
  endif
  return res
endfunction

" Function: lh#tags#update_tagfiles() {{{3
function! lh#tags#update_tagfiles() abort
  call s:CtagsDirname(0)
  let tags_dirname = lh#option#get('tags_dirname')
  let fixed_path = lh#path#fix(lh#path#to_dirname(tags_dirname).s:CtagsFilename())
  if lh#project#is_in_a_project()
    call lh#let#to('p:&tags', '+='.fixed_path)
  else
    exe 'setlocal tags+='.fixed_path
  endif
endfunction

function! s:CtagsFilename() abort " {{{3
  let ctags_filename = lh#option#get('tags_filename', 'tags', 'bpg')
  return ctags_filename
endfunction

function! lh#tags#cmd_line(ctags_pathname) abort " {{{3
  let cmd_line = s:CtagsExecutable().' '.s:CtagsOptions().' -f '.a:ctags_pathname
  return cmd_line
endfunction

function! s:TagsSelectPolicy() abort " {{{3
  let select_policy = lh#option#get('tags_select', "expand('<cword>')", 'bpg')
  return select_policy
endfunction

function! s:RecursiveFlagOrAll() abort " {{{3
  let recurse = lh#option#get('tags_must_go_recursive', 1)
  let res = recurse ? ' -R' : ' *'
  return res
endfunction

function! s:RunInBackground() abort " {{{3
  return lh#has#jobs() && g:tags_options.run_in_bg
endfunction

function! s:AreIgnoredWordAutomaticallyGenerated() abort " {{{3
  " Possible values are:
  " "0": no
  " "1": yes
  " "all": only on <Plug>CTagsUpdateAll
  return lh#option#get('tags_options.auto_spellfile_update', 0)
endfunction

" ######################################################################
function! s:ShallWeAutomaticallyHighlightTags() abort " {{{3
  return lh#option#get('tags_options.auto_highlight', 0)
endfunction

" ######################################################################
" ## Tags generation {{{1
" ======================================================================
" # Tags generating functions {{{2
" ======================================================================
" Purge all references to {source_name} in the tags file {{{3
function! s:PurgeFileReferences(ctags_pathname, source_name) abort
  call s:Verbose('Purge `%1` references from `%2`', a:source_name, a:ctags_pathname)
  if filereadable(a:ctags_pathname)
    let pattern = "\t".lh#path#to_regex(a:source_name)."\t"
    let tags = readfile(a:ctags_pathname)
    call filter(tags, 'v:val !~ pattern')
    call writefile(tags, a:ctags_pathname, "b")
  endif
endfunction

" ======================================================================
" generate tags on-the-fly {{{3
function! s:UpdateTags_for_ModifiedFile(ctags_pathname) abort
  let ctags_dirname  = s:CtagsDirname()
  let source_name    = lh#path#relative_to(expand('%:p'), ctags_dirname)
  let temp_name      = tempname()
  let temp_tags      = tempname()

  try
    " 1- purge old references to the source name
    call s:PurgeFileReferences(a:ctags_pathname, source_name)

    " 2- save the unsaved contents of the current file
    call writefile(getline(1, '$'), temp_name, 'b')

    " 3- call ctags, and replace references to the temporary source file to the
    " real source file
    let cmd_line = lh#tags#cmd_line(a:ctags_pathname).' '.source_name.' --append'
    " todo: test the redirection on windows
    let cmd_line .= ' && sed "s#\t'.temp_name.'\t#\t'.source_name.'\t#" > '.temp_tags
    let cmd_line .= ' && mv -f '.temp_tags.' '.a:ctags_pathname
    call s:System(cmd_line)
  finally
    call delete(temp_name)
    call delete(temp_tags)
  endtry

  return ';'
endfunction

" ======================================================================
" generate tags for all files {{{3
function! s:UpdateTags_for_All(ctags_pathname, ...) abort
  let ctags_dirname = s:CtagsDirname()

  runtime autoload/lh/os.vim
  if exists('*lh#os#sys_cd')
    let cmd_line  = lh#os#sys_cd(ctags_dirname)
  else
    let cmd_line  = 'cd '.ctags_dirname
  endif

  let cmd_line .= ' && '.lh#tags#cmd_line(s:CtagsFilename()).s:RecursiveFlagOrAll()
  let msg = 'ctags '.
        \ lh#option#get('BTW_project_config._.name', fnamemodify(ctags_dirname, ':p:h:t'))
  if s:has_partials
    let FinishedCB = a:1
    call s:AsynchSystem(
          \ cmd_line,
          \ msg,
          \ function(FinishedCB, ['']),
          \ function('delete', [a:ctags_pathname]))
  else
    call delete(a:ctags_pathname)
    call s:System(cmd_line)
    return msg
  endif
endfunction

" ======================================================================
" generate tags for the current saved file {{{3
function! s:UpdateTags_for_SavedFile(ctags_pathname, ...) abort
  " Work on the current file -> &ft, expand('%')
  if ! s:is_ft_indexed(&ft) " redundant check
    return
  endif
  let ctags_dirname  = s:CtagsDirname()
  let source_name    = lh#path#relative_to(ctags_dirname, expand('%:p'))
  " lh#path#relative_to() expects to work on dirname => it'll return a dirname
  let source_name    = substitute(source_name, '[/\\]$', '', '')

  let cmd_line = 'cd '.ctags_dirname
  let cmd_line .= ' && ' . lh#tags#cmd_line(a:ctags_pathname).' --append '.source_name
  if s:has_partials
    let FinishedCB = a:1
    call s:AsynchSystem(
          \ cmd_line,
          \ 'ctags '.expand('%:t'),
          \ function(FinishedCB, [ ' (triggered by '.source_name.' modification)']),
          \ function('s:PurgeFileReferences', [a:ctags_pathname, source_name]))
  else
    call s:PurgeFileReferences(a:ctags_pathname, source_name)
    call s:System(cmd_line)
    return ' (triggered by '.source_name.' modification)'
  endif
endfunction

" ======================================================================
" (private) Conclude tag generation {{{3
function! s:TagGenerated(ctags_pathname, msg, ...) abort
  if a:0 > 0
    let async_output = a:1
    let channel = a:2
    let job = a:3
    if job.exitval > 0
      redraw
      call lh#common#warning_msg([a:ctags_pathname . ' generation failed'.a:msg.'.']+async_output.output)
      call s:Verbose([a:ctags_pathname . ' generation failed'.a:msg.'.']+async_output.output)
      while ch_status(channel) == 'buffered'
        echomsg ch_read(channel)
      endwhile
      return
    endif
  endif
  echomsg a:ctags_pathname . ' updated'.a:msg.'.'
  let auto_spell = s:AreIgnoredWordAutomaticallyGenerated()
  if auto_spell == 1 || (auto_spell == 'all' && empty(a:msg))
    " TODO: Fix the crappy convention
    " - empty(msg) <=> GenerateAll
    " - !empty <=> UpdateCurrentFile
    call lh#tags#update_spellfile(a:ctags_pathname)
  endif
  if s:ShallWeAutomaticallyHighlightTags()
    call lh#tags#update_highlight(a:ctags_pathname)
  endif
endfunction

" (public) Run a tag generating function {{{3
" See this function as a /template method/.
function! lh#tags#run(tag_function, force) abort
  try
    if a:tag_function == 'UpdateTags_for_SavedFile' && !s:is_ft_indexed(&ft)
    call s:Verbose("Ignoring ctags generation on %1: `%2` is an unsupported filetype", a:tag_function, &ft)
      return 0
    endif
    call s:Verbose("Run ctags on %1 %2", a:tag_function, a:force ? "(forcing)": "")
    let ctags_dirname  = s:CtagsDirname()
    if strlen(ctags_dirname)==1
      if a:force
        " todo: a:force || not_already_notified_for_this_buffer
        throw "tags-error: empty dirname"
      else
        return 0
      endif
    endif
    let ctags_filename = s:CtagsFilename()
    let ctags_pathname = ctags_dirname.ctags_filename
    if !filewritable(ctags_dirname) && !filewritable(ctags_pathname)
      throw "tags-error: ".ctags_pathname." cannot be modified"
    endif

    let Fn = function("s:".a:tag_function)
    if s:has_partials
      call Fn(ctags_pathname, function('s:TagGenerated', [(ctags_pathname)]))
    else
      " w/o partials, we can't have jobs either
      let msg = Fn(ctags_pathname)
      call s:TagGenerated(ctags_pathname, msg)
    endif
  catch /tags-error:/
    call lh#common#error_msg(v:exception)
    return 0
  endtry

  " Force a redraw right before output if we have less than 2 lines to display
  " messages, so that the common case of updating ctags during a write doesn't
  " cause a pause that requires the user to press enter.
  if &cmdheight < 2
    redraw
  endif
  return 1
endfunction

function! s:Irun(tag_function, res) abort
  call lh#tags#run(a:tag_function)
  return a:res
endfunction

" ======================================================================
" Main function for updating all tags {{{3
function! lh#tags#update_all() abort
  let done = lh#tags#run('UpdateTags_for_All', 1)
endfunction

" Main function for updating the tags from one file {{{3
" @note the file may be saved or "modified".
function! lh#tags#update_current() abort
  if &modified
    let done = lh#tags#run('UpdateTags_for_ModifiedFile', 1)
  else
    let done = lh#tags#run('UpdateTags_for_SavedFile', 1)
  endif
  " if done
    " call lh#common#error_msg("updated")
  " else
    " call lh#common#error_msg("not updated")
  " endif
endfunction

" ######################################################################
" # Highligthing tags functions {{{2
" Default hilight {{{3
highlight default link TagsGroup Special

function! s:ExtractPaths(...) " {{{3
  if a:0 == 0
    let ctags_dirname  = s:CtagsDirname()
    if strlen(ctags_dirname)==1
      if a:force
        " todo: a:force || not_already_notified_for_this_buffer
        throw "tags-error: empty dirname"
      else
        return 0
      endif
    endif
    let ctags_filename = s:CtagsFilename()
    let ctags_pathname = ctags_dirname.ctags_filename
  else
    let ctags_pathname = a:1
    let ctags_dirname = fnamemodify(ctags_pathname, ':h').'/'
  endif
  return [ctags_pathname, ctags_dirname]
endfunction

" Function: lh#tags#update_highlight(...) {{{3
function! lh#tags#update_highlight(...) abort
  let [ctags_pathname, ctags_dirname] = call('s:ExtractPaths', a:000)

  " TODO: shall we use every tags, or only the current ones?
  let [lSymbols, t] = lh#time#bench('lh#tags#getnames', ctags_pathname)
  call s:Verbose('%1 symbols obtained in %2s', len(lSymbols), t)

  call filter(lSymbols, 'v:val =~ "\\v^\\k+$"')
  " TODO: register whether there are TagsGroup in order to avoid silent!
  silent! syn clear TagsGroup
  let [ma,t] = lh#time#bench(function('map'), copy(lSymbols), 'execute("syn keyword TagsGroup contained ".v:val)')
  call s:Verbose('%1 symbols registered in %2s', len(lSymbols), t)

  call s:Verbose('Highlight updated')
endfunction

" # Spellfile generating functions {{{2
" If the option generate spellfile contain a string, use that string to
" generate a spellfile that contains all the symbols from the tag file.
" This script is not (yet?) in charge of updating automatically the 'spellfile'
" option.
" ======================================================================
" Function: lh#tags#ignore_spelling([spellfilename]) {{{3
" Tells lh-tags to use a spell file
function! lh#tags#ignore_spelling(...) abort
  let tags_dirname = lh#option#get('tags_dirname')
  let spelldirname  = lh#path#to_dirname(tags_dirname)
  let ext = '.'.&enc.'.add'

  " 0- If there was a spell file remove it
  let old_spellfilename = lh#option#get('tags_options.spellfile')
  if lh#option#is_set(old_spellfilename)
    exe 'setlocal spellfile-='.lh#path#fix(spelldirname.old_spellfilename)
  endif

  " 1- Register the new spell file
  let spellfilename = a:0 > 0 ? a:1 : 'code-symbols-spell'.ext
  " 1.1- to lh-tags
  LetIfUndef p:tags_options {}
  call lh#let#to('p:tags_options.spellfile', spellfilename)
  " 1.1- to vim
  if empty(&spellfile)
    " Be sure there is a file to hold words to ignore manually registered by
    " the end user
    exe 'setlocal spellfile+='.lh#path#fix(spelldirname.'ignore'.ext)
  endif
  exe 'setlocal spellfile+='.lh#path#fix(spelldirname.spellfilename)
endfunction

" Update the spellfile {{{3
function! lh#tags#update_spellfile(...) abort
  let spellfilename = lh#option#get('tags_options.spellfile')
  if lh#option#is_unset(spellfilename)
    return
  endif

  let [ctags_pathname, ctags_dirname] = call('s:ExtractPaths', a:000)
  let spellfile = ctags_dirname . spellfilename
  call s:Verbose('Updating spellfile `%1`', spellfile)
  " This is slow as well
  let [lSymbols, t] = lh#time#bench('lh#tags#getnames', ctags_pathname)
  call s:Verbose('%1 symbols obtained in %2s', len(lSymbols), t)
  call writefile(lSymbols, spellfile)
  if exists('*execute')
    let [dummy, t] = lh#time#bench(function('execute'), 'mkspell! '.spellfile)
    call s:Verbose('spellfile built in %2s from `%1`', spellfile, t)
  else
    " This call is very slow
    exe  'mkspell! '.spellfile
  endif
  echomsg spellfile .' updated.'
endfunction

" ======================================================================
" ## Tag browsing {{{1
" ======================================================================
" # Tag push/pop {{{2
" internal tmp tags file {{{3
if !exists('s:tags_jump')
  let s:tags_jump = tempname()
  let &tags .= ','.s:tags_jump
  let s:lines = []
endif

let s:lines = []

" lh#tags#jump {{{3
let s:k_tag_name__ = '__jump_tag__'
let s:k_nb_digits  = 5 " works with ~1 million jumps. Should be enough
function! lh#tags#jump(tagentry) abort
  call s:Verbose('Jumping to tag %1', a:tagentry)
  let last = len(s:lines)+1
  " Assert s:tagentry.filename == expand('%:p')
  let filename = expand('%:p')

  let tag_name = s:k_tag_name__.repeat('0', s:k_nb_digits-strlen(last)).last
  let l = tag_name
        \ . "\t" . (filename)
        \ . "\t" . (a:tagentry.cmd)


  " test whether a new digit is used. In that case renumber every tags to have
  " a lexical order
  call add(s:lines, l)
  call writefile(s:lines, s:tags_jump)
  if exists('&l:tags')
    exe 'setlocal tags+='.s:tags_jump
  endif
  exe 'tag '.tag_name
endfunction

" # Tag dialog {{{2
" s:LeftJustify {{{3
function! s:LeftJustify(text, nb) abort
  let nbchars = strlen(a:text)
  let cpltWith = (nbchars >= a:nb) ? 0 : a:nb - nbchars
  return a:text.repeat(' ', cpltWith)
endfunction

" s:RightJustify {{{3
function! s:RightJustify(text, nb) abort
  let nbchars = strlen(a:text)
  let cpltWith = (nbchars >= a:nb) ? 0 : a:nb - nbchars
  return repeat(' ', cpltWith).a:text
endfunction

" s:GetKey {{{3
function! s:GetKey(dict, keys_list) abort
  for key in a:keys_list
    if has_key(a:dict, key)
      return a:dict[key]
    endif
  endfor
  return ''
endfunction

" s:AccessSpecifier {{{3
let s:access_table = {
      \ 'public'    : '+',
      \ 'protected' : '#',
      \ 'private'   : '-',
      \ 'friend'    : '*'
      \}

function! s:AccessSpecifier(taginfo) abort
  if has_key(a:taginfo, 'access')
    let access = a:taginfo.access
    if !has_key(s:access_table, access)
      echoerr "lh-tags: unsupported access specifier '".access."'"
      let access = ' '
    else
      let access = s:access_table[access]
    endif
  else
    let access = ' '
  endif
  return access
endfunction

" lh#tags#tag_name() {{{3
" implementation [c++]
" inherits, signature
function! lh#tags#tag_name(taginfo) abort
  " @todo: use keywords dependent on the ft
  let scope  = s:GetKey(a:taginfo,
        \ [ 'struct', 'class', 'namespace', 'enum', 'union' ])
  " if the id begins with the scope name, it means there is no need to care the
  " scope into account twice
  if (strlen(scope) != 0) && (a:taginfo.name !~ '^'.scope.'::')
    let fullname =  scope . '::' . a:taginfo.name
  else
    let fullname = a:taginfo.name
  endif
  return fullname
endfunction

" s:Fullname() {{{3
function! s:Fullname(taginfo, fullsignature) abort
  let fullname = a:taginfo.name
  let fullname .= (a:fullsignature && has_key(a:taginfo, 'signature'))
        \ ? (a:taginfo.signature)
        \ : ''
  return fullname
endfunction

" s:TagEntry() {{{3
let s:len_fields = { 'pri': 0, 'kind': 0}
function! s:TagEntry(taginfo, nameLen, fullsignature) abort
  let res = "  ".s:RightJustify(a:taginfo.nr,3).' '
        \ .s:LeftJustify(a:taginfo.pri, 3+s:len_fields.pri).' '
        \ .s:LeftJustify(a:taginfo.kind, 4+s:len_fields.kind).' '
        \ .s:LeftJustify(s:Fullname(a:taginfo, a:fullsignature), a:nameLen)
        \ .' '.lh#path#to_relative(a:taginfo.filename)
  return res
endfunction

" s:PrepareTagEntry0() {{{3
function! s:PrepareTagEntry0(tagrawinfo, nr) abort
  let kind = a:tagrawinfo.kind . ' ' . s:AccessSpecifier(a:tagrawinfo)
  let taginfo = {
        \ 'nr'              : a:nr,
        \ 'pri'             : '@@@',
        \ 'kind'            : kind,
        \ 'filename'        : a:tagrawinfo.filename,
        \ 'signature'       : get(a:tagrawinfo, 'signature', ''),
        \ 'name'            : lh#tags#tag_name(a:tagrawinfo)
        \ }
  return taginfo
endfunction

" s:PrepareTagEntry() {{{3
function! s:PrepareTagEntry(tagrawinfo) abort
  let kind = a:tagrawinfo.kind . ' ' . s:AccessSpecifier(a:tagrawinfo)
  let taginfo = {
        \ 'pri'             : '@@@',
        \ 'kind'            : kind,
        \ 'filename'        : a:tagrawinfo.filename,
        \ 'signature'       : get(a:tagrawinfo, 'signature', ''),
        \ 'name'            : lh#tags#tag_name(a:tagrawinfo)
        \ }
  return taginfo
endfunction

let s:tag_header = {
        \ 'nr'              : '#',
        \ 'pri'             : 'pri',
        \ 'kind'            : 'kind',
        \ 'filename'        : 'file',
        \ 'name'            : 'name'
        \ }

" s:BuildTagsMenu() {{{3
function! s:BuildTagsMenu(tagsinfo, maxNameLen, fullsignature) abort
  let tags = map(copy(a:tagsinfo), 's:TagEntry(v:val, a:maxNameLen, a:fullsignature)')
  return tags
endfunction

" s:ComputeMaxNameLength() {{{3
function! s:ComputeMaxNameLength(tagsinfo, fullsignature) abort
  let maxNameLen = 0
  for taginfo in a:tagsinfo
    let nameLen = strlen(s:Fullname(taginfo, a:fullsignature))
    if nameLen > maxNameLen | let maxNameLen = nameLen | endif
  endfor
  let maxNameLen += 1
  return maxNameLen
endfunction

" lh#tags#uniq_sort() {{{3
function! lh#tags#uniq_sort(tagrawinfos) abort
  let uniq_sort_tmp = {} " sometimes, taginfo entries are duplicated
  for tagrawinfo in (a:tagrawinfos)
    let taginfo = s:PrepareTagEntry(tagrawinfo)
    let stored_taginfo = taginfo
    let stored_taginfo['cmd'] = tagrawinfo.cmd
    let uniq_sort_tmp[string(taginfo)] = stored_taginfo
  endfor
  let g:criteria = 'name'
  let uniq_sorted = sort(values(uniq_sort_tmp), 'LH_Tabs_Sort')
  return uniq_sorted
endfunction

" s:ChooseTagEntry() {{{3
function! s:ChooseTagEntry(tagrawinfos, tagpattern) abort
  if     len(a:tagrawinfos) <= 1 | return 0
    " < 0 => error
    " ==0 <=> empty => nothing to choose => abort
    " ==1 <=> 1 element => return its index
  else
    let fullsignature = 0
    " 1-  Prepare the tags
    let uniq_sorted = lh#tags#uniq_sort(a:tagrawinfos)
    let tagsinfo = [ s:tag_header ]
    let nr=1
    for taginfo in (uniq_sorted)
      let taginfo['nr'] = nr
      call add(tagsinfo, taginfo)
      let nr+= 1
    endfor
    if len(tagsinfo) == 2 " [0] == header
      call s:JumpToTag(s:BuildTagsData('sp'), a:tagrawinfos[1])
      return -1
    endif
    let maxNameLen = s:ComputeMaxNameLength(tagsinfo, fullsignature)

    " 2- Prepare the lines to display
    let tags = s:BuildTagsMenu(tagsinfo, maxNameLen, fullsignature)

    " 3- Display
    let dialog = lh#buffer#dialog#new(
          \ "tags://selector(".a:tagpattern.")",
          \ "lh-tags ".g:loaded_lh_tags.": Select a tag to jump to",
          \ '', 0,
          \ 'lh#tags#_select', tags)
    let dialog.maxNameLen    = maxNameLen
    let dialog.fullsignature = fullsignature
    let dialog.filters       = {}
    call s:Postinit(tagsinfo)
    return -1
  endif
endfunction

" LH_Tabs_Sort() {{{3
function! LH_Tabs_Sort(lhs, rhs) abort
  if     has_key(a:lhs, 'nr') && a:lhs.nr == '#' | return -1
  elseif has_key(a:rhs, 'nr') && a:rhs.nr == '#' | return 1
  else
    let lhs = a:lhs[g:criteria]
    let rhs = a:rhs[g:criteria]
    let res
          \ = lhs < rhs ? -1
          \ : lhs == rhs ? 0
          \ : 1
    return res
  endif
endfunction

" s:Sort() {{{3
function! s:Sort(field) abort
  " let s:criteria = a:field
  let g:criteria = a:field
  call sort(b:tagsinfo, 'LH_Tabs_Sort')
  let tags = s:BuildTagsMenu(b:tagsinfo, b:dialog.maxNameLen, b:dialog.fullsignature)
  let b:dialog.choices = tags
  call lh#buffer#dialog#update(b:dialog)
endfunction

" s:FilterUI() {{{3
function! s:FilterUI() abort abort
  " 1- determine list of possible fields
  let fields = keys(b:alltagsinfo[1])
  let fields = filter(fields, 'v:val !~ "\\<\\(cmd\\|nr\\)\\>"')
  " 2- ask which field
  let field = lh#ui#which('lh#ui#combo', "Filter on:", join(map(copy(fields), '"&".v:val'), "\n"))
  " todo: manage exit
  " 3- ask the filter expression
  let filters = b:dialog.filters
  if field == 'kind'
    let kinds = lh#list#possible_values(b:alltagsinfo[1:], 'kind')
    call map(kinds, 'v:val[0]')
    let which = split(lh#ui#check('Which kinds to display? ', join(map(copy(kinds), '"&".v:val'), "\n")), '\zs\ze')
    let filter = match(which, '0')==-1 ? '' : '['.join(lh#list#mask(kinds, which), '').']'
  else
    let filter = get(filters, field, '')
    let filter = lh#ui#input('Which filter for '.field.'? ', filter)
  endif
  " Update tile to print the current filter, and do filter!
  let b:tagsinfo[0][field] = substitute(b:tagsinfo[0][field], '<.*', '', '')
  if !empty(filter)
    let filters[field] = filter
    let b:tagsinfo[0][field] .= ' <'.filter.'>'
  else
    silent! unlet filters[field]
  endif
  if match(keys(s:len_fields), field) >= 0
    let s:len_fields[field] = empty(filter) ? 0 : 3 + len(filter)
  endif
  " 4- Update!
  let b:tagsinfo = copy(b:alltagsinfo)
  " todo: remember the sort criteria
  " TODO: handle positive and negative filters
  for fd in fields
    if has_key(filters, fd)
      call filter(b:tagsinfo, 'v:val.nr=="#" || v:val[fd] =~ filters[fd]')
    endif
  endfor
  let tags = s:BuildTagsMenu(b:tagsinfo, b:dialog.maxNameLen, b:dialog.fullsignature)
  let b:dialog.choices = tags
  call lh#buffer#dialog#update(b:dialog)
endfunction

" s:ToggleSignature() {{{3
function! s:ToggleSignature() abort
  let b:dialog.fullsignature = 1 - b:dialog.fullsignature
  let b:dialog.maxNameLen = s:ComputeMaxNameLength(b:tagsinfo, b:dialog.fullsignature)
  let tags = s:BuildTagsMenu(b:tagsinfo, b:dialog.maxNameLen, b:dialog.fullsignature)
  let b:dialog.choices = tags
  call lh#buffer#dialog#update(b:dialog)
endfunction

" s:Postinit() {{{3
function! s:Postinit(tagsinfo) abort
  let b:alltagsinfo = a:tagsinfo " reference
  let b:tagsinfo = copy(b:alltagsinfo) " the one that'll get filtered, ...

  nnoremap <silent> <buffer> K :call <sid>Sort('kind')<cr>
  nnoremap <silent> <buffer> N :call <sid>Sort('name')<cr>
  nnoremap <silent> <buffer> F :call <sid>Sort('filename')<cr>
  nnoremap <silent> <buffer> s :call <sid>ToggleSignature()<cr>
  nnoremap <silent> <buffer> f :call <sid>FilterUI()<cr>
  exe "nnoremap <silent> <buffer> o :call lh#buffer#dialog#select(line('.'), ".b:dialog.id.", 'sp')<cr>"

  call lh#buffer#dialog#add_help(b:dialog, '@| o                       : Split (O)pen in a new buffer if not yet opened', 'long')
  call lh#buffer#dialog#add_help(b:dialog, '@| K, N, or F              : Sort by (K)ind, (N)ame, or (F)ilename', 'long')
  call lh#buffer#dialog#add_help(b:dialog, '@| s                       : Toggle full (s)signature display', 'long')
  call lh#buffer#dialog#add_help(b:dialog, '@| f                       : Filter results', 'long')

  if has("syntax")
    syn clear

    syntax match TagHeader  /^\s*\zs  #.*/
    syntax region TagLine  start='\d' end='$' contains=TagNumber,TagTagernative
    syntax region TagNbOcc  start='^--' end='$' contains=TagNumber,TagName
    syntax match TagNumber /\d\+/ contained
    syntax match TagName /<\S\+>/ contained
    syntax match TagFile /\S\+$/ contained

    syntax region TagExplain start='@' end='$' contains=TagStart
    syntax match TagStart /@/ contained
    syntax match Statement /--abort--/

    highlight link TagExplain Comment
    highlight link TagHeader Underlined
    highlight link TagStart Ignore
    highlight link TagLine Normal
    highlight link TagName Identifier
    highlight link TagFile Directory
    highlight link TagNumber Number
  endif
endfunction

" s:DisplaySignature() {{{3
function! s:DisplaySignature() abort
endfunction

" lh#tags#_select() {{{3
function! lh#tags#_select(results, ...) abort
  call s:Verbose('tags selected: %1', a:results.selection)
  if len(a:results.selection) > 1
    " this is an assert
    throw "lh-tags: We are not supposed to select several tags"
  endif
  " There is a header => we need to apply an offset!
  let selection = a:results.selection[0]-1
  if selection < 1
    call lh#common#warning_msg('Invalid selection')
    return
  endif
  if a:0 == 0
    let tags_data = b:tags_data
  else
    let tags_data = s:BuildTagsData(a:1[0])
  endif

  let choices = a:results.dialog.choices
  echomsg '-> '.choices[selection]
  " echomsg '-> '.info[selection-1].filename . ": ".info[selection-1].cmd
  if exists('s:quit') | :quit | endif
  " call s:JumpToTag(cmd, info[selection-1])
  call s:JumpToTag(tags_data, b:tagsinfo[selection])
endfunction

function! s:BuildTagsData(cmd) abort
  let tags_data = {
        \ 'cmd' : (a:cmd),
        \ 'previous_tags' : (&l:tags)
        \}
  return tags_data
endfunction

" s:JumpToTag() {{{3
function! s:JumpToTag(tags_data, taginfo) abort
  let filename = a:taginfo.filename
  call lh#buffer#jump(filename, a:tags_data.cmd)
  " Inject local tags in newly opened file 2/2
  let tags = split(a:tags_data.previous_tags, ',')
  for tag in tags
    if filereadable(tag)
      exe 'setlocal tags+='.tag
    endif
  endfor
  " Execute the search
  call lh#tags#jump(a:taginfo)
  return
  try
    let save_magic=&magic
    set nomagic
    exe a:taginfo.cmd
  finally
    let &magic=save_magic
  endtry
endfunction

" s:Find() {{{3
function! s:Find(cmd_edit, cmd_split, tagpattern) abort
  let info = taglist(a:tagpattern)
  if len(info) == 0
    call lh#common#error_msg("lh-tags: no tags for `".a:tagpattern."'")
    return
  endif
  " call confirm( "taglist(".a:tagpattern.")=".len(info), '&Ok', 1)
  if len(info) == 1
    call s:JumpToTag(s:BuildTagsData(a:cmd_split), info[0])
  else
    let tags_data = s:BuildTagsData(a:cmd_edit)
    let which = s:ChooseTagEntry(info, a:tagpattern)
    if which >= 0 && which < len(info)
      echoerr "Assert: unexpected path"
      call s:JumpToTag(tags_data, info[which])
    else
      let b:tags_data = tags_data
    endif
  endif
endfunction

" lh#tags#split_open() {{{3
function! lh#tags#split_open(...) abort
  let id = a:0 == 0 ? eval(s:TagsSelectPolicy()) : a:1
  :call s:Find('e', 'sp', id.'$')
endfunction

" ######################################################################
" ## Tag command {{{1
" ======================================================================
" Internal functions {{{2
" ======================================================================
" Command execution  {{{3
function! lh#tags#command(...) abort
  let id = join(a:000, '.*')
  :call s:Find('e', 'sp', id)
endfunction

" Command completion  {{{3
let s:commands = '^LHT\%[ags]'
function! lh#tags#_command_complete(ArgLead, CmdLine, CursorPos) abort
  let cmd = matchstr(a:CmdLine, s:commands)
  let cmdpat = '^'.cmd

  let tmp = substitute(a:CmdLine, '\s*\S\+', 'Z', 'g')
  let pos = strlen(tmp)
  let lCmdLine = strlen(a:CmdLine)
  let fromLast = strlen(a:ArgLead) + a:CursorPos - lCmdLine
  " The argument to expand, but cut where the cursor is
  let ArgLead = strpart(a:ArgLead, 0, fromLast )
  let ArgsLead = strpart(a:CmdLine, 0, a:CursorPos )
  " call s:Verbose( "a:AL = ". a:ArgLead."\nAl  = ".ArgLead
        " \ . "\nAsL = ".ArgsLead
        " \ . "\nx=" . fromLast
        " \ . "\ncut = ".strpart(a:CmdLine, a:CursorPos)
        " \ . "\nCL = ". a:CmdLine."\nCP = ".a:CursorPos
        " \ . "\ntmp = ".tmp."\npos = ".pos
        " )

  " Build the pattern for taglist() -> all arguments are joined with '.*'
  " let pattern = ArgsLead
  let pattern = a:CmdLine
  " ignore the command
  let pattern = substitute(pattern, '^\S\+\s\+', '', '')
  let pattern = substitute(pattern, '\s\+', '.*', 'g')
  let tags = taglist(pattern)
  if 0
    call confirm ("pattern".pattern."\n->".string(tags), '&Ok', 1)
  endif
  if empty(tags)
    echomsg "No matching tags found"
    return ''
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

" Function: lh#tags#getnames(tagfile) {{{3
function! s:getNames_Emulation(tagfile)
  let lines = readfile(a:tagfile)
  " match() solution is faster than filter()
  let first_tag = match(lines, '^[^!]')
  " let [names, t_keep_names] = lh#time#bench(function('map'), lines[ first_tag : ], "matchstr(v:val, '\\v^\\S+')")
  " stridx solution is twice as fast as matchstr one
  let [names, t_keep_names] = lh#time#bench(function('map'), lines[ first_tag : ], 'v:val[0 : stridx(v:val, "\t")-1]')
  call s:Verbose('%1 tag names filtered in %2s', len(names), t_keep_names)
  return names
endfunction

function! lh#tags#getnames(tagfile) abort
  if 1
    let [names, t_fetch] = lh#time#bench(function('s:getNames_Emulation'), a:tagfile)
  else
    " This is very slow as of Vim 7.4-2330
    try
      let cleanup = lh#on#exit()
            \.restore('&tags')
      let &l:tags = a:tagfile
      let [tags, t_f1]  = lh#time#bench(function('taglist'), '.*')
      call s:Verbose('taglist took: %1', t_f1)
      let [names, t_f2] = lh#time#bench(function('lh#list#get'), tags, 'name')
      call s:Verbose('filtering names took %1', t_f2)
      let t_fetch = t_f1 + t_f2
    finally
      call cleanup.finalize()
    endtry
  endif
  call s:Verbose('%1 names obtained in %2s', len(names), t_fetch)
  let [names, t_sort_names] = lh#time#bench(function('lh#list#unique_sort'), names)
  call s:Verbose('%1 tag names uniquelly sorted in %2s', len(names), t_sort_names)
  return names
endfunction
"------------------------------------------------------------------------
" }}}1
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
