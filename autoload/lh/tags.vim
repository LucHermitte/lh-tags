"=============================================================================
" File:         autoload/lh/tags.vim                                    {{{1
" Author:       Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"               <URL:http://github.com/LucHermitte/lh-tags>
" License:      GPLv3 with exceptions
"               <URL:http://github.com/LucHermitte/lh-tags/tree/master/License.md>
" Version:      3.0.5
let s:k_version = '3.0.5'
" Created:      02nd Oct 2008
" Last Update:  15th Feb 2019
"------------------------------------------------------------------------
" Description:
"       Small plugin related to tags files.
"       (Deported functions)
"
"------------------------------------------------------------------------
" History:
"       v3.0.0:
"       (*) Major OO refactoring of the plugin
"       v2.0.6:
"       (*) Fix `-kind` field to the right language
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
"       (*) Find a way to update update &tags correctly when tags are searched
"       and not at another moment.
"
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

" # SID      {{{2
" s:function(func_name) {{{3
function! s:function(func)
  if !exists("s:SNR")
    let s:SNR=matchstr(expand('<sfile>'), '<SNR>\d\+_\zefunction$')
  endif
  return function(s:SNR . a:func)
endfunction

" # lh#tags#_System {{{2
function! lh#tags#_System(cmd_line) abort
  call s:Verbose(a:cmd_line)
  let res = lh#os#system(a:cmd_line)
  if v:shell_error
    throw "Cannot execute system call (".a:cmd_line."): ".res
  endif
  return res
endfunction

" ######################################################################
" ## Options {{{1
" ======================================================================
" # ctags executable {{{2
" Function: lh#tags#ctags_is_installed() {{{3
function! lh#tags#ctags_is_installed() abort
  return executable(s:indexer().executable())
endfunction

" Function: lh#tags#ctags_flavour() {{{3
" @since version 1.5.0
" @deprecated from Version 3.0.0
function! lh#tags#ctags_flavour() abort
  call lh#notify#deprecated('lh#tags#ctags_flavour', 'lh-tags API differently')

  " call assert_true(lh#tags#ctags_is_installed())
  try
    let ctags_executable = s:indexer().executable()
    if !lh#tags#ctags_is_installed()
      return 'echo "No '.ctags_executable.' binary found: "'
    endif
    let ctags_version = lh#tags#_System(ctags_executable. ' --version')
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
" Function: lh#tags#func_kind(ft) {{{3
function! lh#tags#func_kind(ft) abort
  let fl = s:indexer().flavour()
  let lang = fl.get_lang_for(a:ft)
  return get(fl.get_kind_flags('function'), lang, 'f')
endfunction

" Fields options {{{3
LetIfUndef g:tags_options {}
" -> g:tags_options.__extra
" -> g:tags_options.{ft}.flags

function! s:indexer() abort " {{{3
  let indexer_names = []
  if !empty(&ft)
    let indexer_names += ['tags_options.'.&ft.'.__indexer']
  endif
  let indexer_names += ['tags_options.__indexer']
  let indexer = lh#option#get(indexer_names)
  if lh#option#is_unset(indexer)
    let indexer = lh#tags#set_indexer(function('lh#tags#indexers#ctags#make'))
  endif
  return indexer
endfunction

" Function: lh#tags#build_indexer(Func) {{{3
" If {Func} is a string, execute lh#tags#indexers#{Func}#make()
" If it's a function, just call it, and assert it's of the right type
function! lh#tags#build_indexer(Func, ...) abort
  call lh#assert#type(a:Func).belongs_to('', function('has'))
  if type(a:Func) == type('')
    let indexer = call('lh#tags#indexers#'.a:Func.'#make', a:000)
  else
    let indexer = a:Func()
  endif
  call lh#assert#value(indexer).verifies('lh#tags#indexers#interface#is_an_indexer')
  return indexer
endfunction

" Function: lh#tags#set_indexer(Func [,scope]) {{{3
" If {Func} is a string, execute lh#tags#indexers#{Func}#make()
" If it's a function, just call it, and assert it's of the right type
function! lh#tags#set_indexer(Func, ...) abort
  let indexer = lh#tags#build_indexer(a:Func)
  call lh#assert#value(indexer).verifies('lh#tags#indexers#interface#is_an_indexer')
  let scope = get(a:, 1, 'p')
  call lh#let#to(scope.':tags_options.__indexer', indexer)
  return indexer
endfunction

function! lh#tags#_is_ft_indexed(ft) abort " {{{3
  " This option needs to be set in each project!
  let indexed_ft = lh#option#get('tags_options.indexed_ft', [])
  return index(indexed_ft, a:ft) >= 0
endfunction

" Function: lh#tags#add_indexed_ft([ft list]) {{{3
function! lh#tags#add_indexed_ft(...) abort
  return call('lh#let#_push_options', ['p:tags_options.indexed_ft'] + a:000)
endfunction

" Function: lh#tags#set_lang_map(lang, exts) {{{3
let s:k_unset = lh#option#unset()
function! lh#tags#set_lang_map(ft, exts) abort
  let indexer = s:indexer()
  let fl = s:indexer().flavour()
  if !has_key(fl, 'set_lang_map')
    throw "tags-error: The current indexer has no ft -> lang map"
  endif
  call fl.set_lang_map(a:ft, a:exts)
endfunction

let s:project_roots = get(s:, 'project_roots', [])
" Function: lh#tags#update_tagfiles() {{{3
function! lh#tags#update_tagfiles() abort
  call s:indexer().update_tags_option()
endfunction

function! lh#tags#cmd_line(ctags_pathname) abort " {{{3
  call lh#notify#deprecated('lh#tags#cmd_line', 'lh#tags#indexers#ctags#make().cmd_line')
  let indexer = s:indexer()
  call indexer.set_db_file(a:ctags_pathname)
  let cmd_line = indexer.cmd_line()
  return cmd_line
endfunction

function! s:TagsSelectPolicy() abort " {{{3
  let select_policy = lh#option#get('tags_select', "expand('<cword>')", 'bpg')
  return select_policy
endfunction

function! s:AreIgnoredWordAutomaticallyGenerated() abort " {{{3
  " Possible values are:
  " "0": no
  " "1": yes
  " "all": only on <Plug>CTagsUpdateAll
  return lh#option#get('tags_options.auto_spellfile_update', 0, 'g')
endfunction

" ######################################################################
function! s:ShallWeAutomaticallyHighlightTags() abort " {{{3
  return lh#option#get('tags_options.auto_highlight', 0, 'g')
endfunction

" ######################################################################
" ## Tags generation {{{1
" ======================================================================
" # Tags generating functions {{{2
" ======================================================================
" (private) Conclude tag generation {{{3
function! s:TagGenerated(ctags_pathname, trigger, msg, ...) abort
  redrawstatus
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
  else
    " Force a redraw right before output if we have less than 2 lines to display
    " messages, so that the common case of updating ctags during a write doesn't
    " cause a pause that requires the user to press enter.
    if &cmdheight < 2
      redraw
    endif
  endif

  echomsg a:ctags_pathname . ' updated'.a:msg.'.'
  let auto_spell = s:AreIgnoredWordAutomaticallyGenerated()
  if auto_spell == 1 || (auto_spell == 'all' && a:trigger == 'complete')
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
    if a:tag_function == 'run_update_file' && !lh#tags#_is_ft_indexed(&ft)
      call s:Verbose("Ignoring ctags generation on %1: `%2` is an unsupported filetype", a:tag_function, &ft)
      return 0
    endif
    call lh#assert#value(&ft).not().empty()
    call s:Verbose("Run ctags on %1 %2", a:tag_function, a:force ? "(forcing)": "")
    let indexer = s:indexer()
    " let g:indexer = indexer
    let src_dirname = indexer.src_dirname()
    if strlen(src_dirname)==1
      if a:force
        " todo: a:force || not_already_notified_for_this_buffer
        throw "tags-error: empty dirname"
      else
        return 0
      endif
    endif

    let l:Finished_cb = s:function('TagGenerated')
    let args = lh#option#get('tags_options._', {})
    " yeah, "ft" can be injected at project level... This is certainly nuts!
    let args = extend(args, lh#option#get('tags_options.'.get(args, 'ft', &ft).'_', {}), 'force')
    let msg = indexer[a:tag_function](l:Finished_cb, args)
  catch /tags-error:/
    call lh#common#error_msg(v:exception)
    return 0
  endtry
  return 1
endfunction

" ======================================================================
" Main function for updating all tags {{{3
function! lh#tags#update_all() abort
  let done = lh#tags#run('run_on_all_files', 1)
endfunction

" Main function for updating the tags from one file {{{3
" @note the file may be saved or "modified".
function! lh#tags#update_current() abort
  if &modified
    let done = lh#tags#run('run_update_modified_file', 1)
  else
    let done = lh#tags#run('run_update_file', 1)
  endif
endfunction

" ######################################################################
" # Highligthing tags functions {{{2
" Default hilight {{{3
highlight default link TagsGroup Special

function! s:ExtractPaths(...) " {{{3
  if a:0 == 0
    let indexer = s:indexer
    let src_dirname = indexer.src_dirname()
    if strlen(src_dirname)==1
      if a:force
        " todo: a:force || not_already_notified_for_this_buffer
        throw "tags-error: empty dirname"
      else
        return 0
      endif
    endif
    let ctags_pathname = indexer.db_file()
  else
    let ctags_pathname = a:1
    let src_dirname = fnamemodify(ctags_pathname, ':h').'/'
  endif
  return [ctags_pathname, src_dirname]
endfunction

" Function: lh#tags#update_highlight(...) {{{3
function! lh#tags#update_highlight(...) abort
  let [ctags_pathname, src_dirname] = call('s:ExtractPaths', a:000)

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
  let tags_dirname = s:indexer().src_dirname()
  call lh#assert#value(tags_dirname).is_set()
  let ext = '.'.&enc.'.add'

  " 0- If there was a spell file remove it
  let old_spellfilename = lh#option#get('tags_options.spellfile')
  if lh#option#is_set(old_spellfilename)
    exe 'setlocal spellfile-='.lh#path#fix(tags_dirname.old_spellfilename)
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
    exe 'setlocal spellfile+='.lh#path#fix(tags_dirname.'ignore'.ext)
  endif
  exe 'setlocal spellfile+='.lh#path#fix(tags_dirname.spellfilename)
endfunction

" Update the spellfile {{{3
function! lh#tags#update_spellfile(...) abort
  let spellfilename = lh#option#get('tags_options.spellfile')
  if lh#option#is_unset(spellfilename)
    return
  endif

  let [ctags_pathname, src_dirname] = call('s:ExtractPaths', a:000)
  " TODO: Support different directory for spellfiles
  let spellfile = src_dirname . spellfilename
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
" Feature moved to lh-vim-lib 4.6.0

" lh#tags#jump {{{3
function! lh#tags#jump(tagentry) abort
  call lh#notify#deprecated('lh#tags#jump()', 'lh#tags#stack#jump() from lh-vim-lib')
  call lh#tags#stack#jump(a:tagentry)
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
  call lh#tags#stack#jump(a:taginfo)
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
