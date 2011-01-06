"=============================================================================
" $Id$
" File:		autoload/lh/tags.vim                                    {{{1
" Author:	Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"		<URL:http://code.google.com/p/lh-vim/>
" Version:	0.2.3
" Created:	02nd Oct 2008
" Last Update:	$Date$
"------------------------------------------------------------------------
" Description:	
" 	Small plugin related to tags files. 
" 	(Deported functions)
" 
"------------------------------------------------------------------------
" Installation:	«install details»
" History:
" 	v0.2.3: 23rd Dec 2010
" 	(*) system() calls catch errors
" 	v0.2.2: 26th May 2010
" 	(*) s/s:tags/&_jump/g
" 	(*) hook to run ctags with the default options, plus other ones
" 	v0.2.1: 22nd Apr 2010
" 	(*) Do not reuse a search buffer
" 	(*) Jumps are pushed into the tagstack
" 	v0.2.0: 03rd Oct 2008
" 	(*) code moved to an autoload plugin
" TODO:		
" 	(*) Have behaviour similars to the one from the quickfix mode
" 	(possibility to close and reopen the search window; prev&next moves)
" 	(*) Show/hide declarations -- merge declaration and definitions
" 	(*) exclude patterns
" }}}1
"=============================================================================

let s:cpo_save=&cpo
set cpo&vim
"------------------------------------------------------------------------

" ######################################################################
" ## Options {{{1
let g:tags_options_c   = '--c++-kinds=+p --fields=+imaS --extra=+q'
" let g:tags_options_cpp = '--c++-kinds=+p --fields=+imaS --extra=+q'
let g:tags_options_vim = '--fields=+mS --extra=+q'
let g:tags_options_cpp = '--c++-kinds=+p --fields=+imaS --extra=+q --language-force=C++'
" let g:tags_options_cpp = '--c++-kinds=+p --fields=+iaS --extra=+q --language-force=cpp'

function! s:CtagsExecutable()
  let tags_executable = lh#option#get('tags_executable', 'ctags', 'bg')
  return tags_executable
endfunction

function! lh#tags#ctags_is_installed()
  return executable(s:CtagsExecutable())
endfunction

function! s:CtagsOptions()
  let ctags_options = ' --tag-relative=yes'
  let ctags_options .= ' '.lh#option#get('tags_options_'.&ft, '')
  let ctags_options .= ' '.lh#option#get('tags_options', '', 'wbg')
  return ctags_options
endfunction

function! s:CtagsDirname()
  let ctags_dirname = lh#option#get('tags_dirname', '', 'b').'/'
  return ctags_dirname
endfunction

function! s:CtagsFilename()
  let ctags_filename = lh#option#get('tags_filename', 'tags', 'bg')
  return ctags_filename
endfunction

function! lh#tags#cmd_line(ctags_pathname)
  let cmd_line = s:CtagsExecutable().' '.s:CtagsOptions().' -f '.a:ctags_pathname
  return cmd_line
endfunction

function! s:TagsSelectPolicy()
  let select_policy = lh#option#get('tags_select', "expand('<cword>')", 'bg')
  return select_policy
endfunction

" ######################################################################
" ## Misc Functions     {{{1
" # Version {{{2
let s:k_version = 223
function! lh#tags#version()
  return s:k_version
endfunction

" # Debug {{{2
function! lh#tags#verbose(level)
  let s:verbose = a:level
endfunction

function! lh#tags#debug(expr)
  return eval(a:expr)
endfunction

function! s:Verbose(expr)
  if exists('s:verbose') && s:verbose
    echomsg a:expr
  endif
endfunction

" # s:System {{{2
function! s:System(cmd_line)
  call s:Verbose(a:cmd_line)
  let res = system(a:cmd_line)
  if v:shell_error
    throw "Cannot execute system call (".a:cmd_line."): ".res
  endif
  return res
endfunction

" ######################################################################
" ## Tags generation {{{1
" ======================================================================

" ======================================================================
" # Tags generating functions {{{2
" ======================================================================
" Purge all references to {source_name} in the tags file {{{3
function! s:PurgeFileReferences(ctags_pathname, source_name)
  if filereadable(a:ctags_pathname)
    let temp_tags      = tempname()
    " it exists => must be changed
    let cmd_line = 'grep -v '
	  \ .shellescape('	'.lh#path#to_regex(a:source_name).'	').' '.shellescape(a:ctags_pathname) 
	  " \.' > '.shellescape(temp_tags)
	  " The last redirection may cause troubles on windows
    let tags =  s:System(cmd_line)
    call writefile(split(tags,'\n'), a:ctags_pathname, "b")
    " using a single cmd_line with && causes troubles under windows ...
    " let cmd_line = 'mv -f '.shellescape(temp_tags).' '.shellescape(a:ctags_pathname)
    " call s:Verbose(cmd_line)
    " call system(cmd_line)
  endif
endfunction

" ======================================================================
" generate tags on-the-fly {{{3
function! s:UpdateTags_for_ModifiedFile(ctags_pathname)
  let ctags_dirname  = s:CtagsDirname()
  let source_name    = lh#path#relative_to(expand('%:p'), ctags_dirname)
  let temp_name      = tempname()
  let temp_tags      = tempname()

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
  call delete(temp_name)
  
  return ';'
endfunction

" ======================================================================
" generate tags for all files {{{3
function! s:UpdateTags_for_All(ctags_pathname)
  let ctags_dirname  = s:CtagsDirname()

  call delete(a:ctags_pathname)
  runtime autoload/lh/system.vim
  if exists('*lh#system#SysCD')
	let cmd_line  = lh#system#SysCD(ctags_dirname)
  else
	let cmd_line  = 'cd '.ctags_dirname
  endif
  " todo => use project directory
  "
  let cmd_line .= ' && '.lh#tags#cmd_line(s:CtagsFilename()).' -R'
  call s:System(cmd_line)
endfunction

" ======================================================================
" generate tags for the current saved file {{{3
function! s:UpdateTags_for_SavedFile(ctags_pathname)
  let ctags_dirname  = s:CtagsDirname()
  let source_name    = lh#path#relative_to(expand('%:p'), ctags_dirname)

  call s:PurgeFileReferences(a:ctags_pathname, source_name)
  return
  let cmd_line = 'cd '.ctags_dirname
  let cmd_line .= ' && ' . lh#tags#cmd_line(a:ctags_pathname).' --append '.source_name
  call s:System(cmd_line)
endfunction

" ======================================================================
" (public) Run a tag generating function {{{3
" See this function as a /template method/.
function! lh#tags#run(tag_function, force)
  try
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
    call Fn(ctags_pathname)
  catch /tags-error:/
    call lh#common#error_msg(v:exception)
    return 0
  finally
  endtry

  echo ctags_pathname . ' updated.'
  return 1
endfunction

function! s:Irun(tag_function, res)
  call lh#tags#run(a:tag_function)
  return a:res
endfunction

" ======================================================================
" Main function for updating all tags {{{3
function! lh#tags#update_all()
  let done = lh#tags#run('UpdateTags_for_All', 1)
endfunction

" Main function for updating the tags from one file {{{3
" @note the file may be saved or "modified".
function! lh#tags#update_current()
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
" ## Tag browsing {{{1
"
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
function! lh#tags#jump(tagentry)
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
  exe 'tag '.tag_name
endfunction

" # Tag dialog {{{2
" s:LeftJustify {{{3
function! s:LeftJustify(text, nb)
  let nbchars = strlen(a:text)
  let cpltWith = (nbchars >= a:nb) ? 0 : a:nb - nbchars
  return a:text.repeat(' ', cpltWith)
endfunction

" s:RightJustify {{{3
function! s:RightJustify(text, nb)
  let nbchars = strlen(a:text)
  let cpltWith = (nbchars >= a:nb) ? 0 : a:nb - nbchars
  return repeat(' ', cpltWith).a:text
endfunction

" s:GetKey {{{3
function! s:GetKey(dict, keys_list)
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
      \ 'private'   : '-'
      \}

function! s:AccessSpecifier(taginfo)
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
function! lh#tags#tag_name(taginfo)
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
function! s:Fullname(taginfo, fullsignature)
  let fullname = a:taginfo.name 
  let fullname .= (a:fullsignature && has_key(a:taginfo, 'signature'))
	\ ? (a:taginfo.signature) 
	\ : ''
  return fullname
endfunction

" s:TagEntry() {{{3
function! s:TagEntry(taginfo, nameLen, fullsignature)
  let res = "  ".s:RightJustify(a:taginfo.nr,2).' '
	\ .s:LeftJustify(a:taginfo.pri, 3).' '
	\ .s:LeftJustify(a:taginfo.kind, 4).' '
	\ .s:LeftJustify(s:Fullname(a:taginfo, a:fullsignature), a:nameLen)
	\ .' '.a:taginfo.filename 
  return res
endfunction

" s:PrepareTagEntry0() {{{3
function! s:PrepareTagEntry0(tagrawinfo, nr)
  let kind = a:tagrawinfo.kind . ' ' . s:AccessSpecifier(a:tagrawinfo)
  let taginfo = {
	\ 'nr'              : a:nr,
	\ 'pri'             : '@@@',
	\ 'kind'            : kind,
	\ 'filename'        : a:tagrawinfo.filename,
	\ 'signature'       : s:GetKey(a:tagrawinfo, ['signature']),
	\ 'name'            : lh#tags#tag_name(a:tagrawinfo)
	\ }
  return taginfo
endfunction

" s:PrepareTagEntry() {{{3
function! s:PrepareTagEntry(tagrawinfo)
  let kind = a:tagrawinfo.kind . ' ' . s:AccessSpecifier(a:tagrawinfo)
  let taginfo = {
	\ 'pri'             : '@@@',
	\ 'kind'            : kind,
	\ 'filename'        : a:tagrawinfo.filename,
	\ 'signature'       : s:GetKey(a:tagrawinfo, ['signature']),
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
function! s:BuildTagsMenu(tagsinfo, maxNameLen, fullsignature)
  let tags= []
  for taginfo in (a:tagsinfo)
    call add(tags, s:TagEntry(taginfo,a:maxNameLen, a:fullsignature))
  endfor
  return tags
endfunction

" s:ComputeMaxNameLength() {{{3
function! s:ComputeMaxNameLength(tagsinfo, fullsignature)
  let maxNameLen = 0
  for taginfo in a:tagsinfo
    let nameLen = strlen(s:Fullname(taginfo, a:fullsignature))
    if nameLen > maxNameLen | let maxNameLen = nameLen | endif
  endfor
  let maxNameLen += 1
  return maxNameLen
endfunction

" s:ChooseTagEntry() {{{3
function! s:ChooseTagEntry(tagrawinfos, tagpattern)
  if     len(a:tagrawinfos) <= 1 | return 0
    " < 0 => error
    " ==0 <=> empty => nothing to choose => abort
    " ==1 <=> 1 element => return its index
  else
    let fullsignature = 0
    " 1-  Prepare the tags
    let uniq_sort_tmp = {} " sometimes, taginfo entries are duplicated
    for tagrawinfo in (a:tagrawinfos)
      let taginfo = s:PrepareTagEntry(tagrawinfo)
      let stored_taginfo = taginfo
      let stored_taginfo['cmd'] = tagrawinfo.cmd
      let uniq_sort_tmp[string(taginfo)] = stored_taginfo
    endfor
    let g:criteria = 'name'
    let uniq_sorted = sort(values(uniq_sort_tmp), 'LH_Tabs_Sort')
    let tagsinfo = [ s:tag_header ]
    let nr=1
    for taginfo in (uniq_sorted)
      let taginfo['nr'] = nr
      call add(tagsinfo, taginfo)
      let nr+= 1
    endfor
    let maxNameLen = s:ComputeMaxNameLength(tagsinfo, fullsignature)

    " 2- Prepare the lines to display
    let tags = s:BuildTagsMenu(tagsinfo, maxNameLen, fullsignature)

    " 3- Display
    let dialog = lh#buffer#dialog#new(
	  \ "tags-selector(".a:tagpattern.")",
	  \ "lh-tags ".g:loaded_lh_tags.": Select a tag to jump to",
	  \ '', 0,
	  \ 'LHTags_select', tags)
    let dialog.maxNameLen    = maxNameLen
    let dialog.fullsignature = fullsignature
    call s:Postinit(tagsinfo)
    return -1
  endif
endfunction

" LH_Tabs_Sort() {{{3
function! LH_Tabs_Sort(lhs, rhs)
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
function! s:Sort(field)
  " let s:criteria = a:field
  let g:criteria = a:field
  call sort(b:tagsinfo, 'LH_Tabs_Sort')
  let tags = s:BuildTagsMenu(b:tagsinfo, b:dialog.maxNameLen, b:dialog.fullsignature)
  let b:dialog.choices = tags
  call lh#buffer#dialog#update(b:dialog)
endfunction

" s:ToggleSignature() {{{3
function! s:ToggleSignature()
  let b:dialog.fullsignature = 1 - b:dialog.fullsignature
  let b:dialog.maxNameLen = s:ComputeMaxNameLength(b:tagsinfo, b:dialog.fullsignature)
  let tags = s:BuildTagsMenu(b:tagsinfo, b:dialog.maxNameLen, b:dialog.fullsignature)
  let b:dialog.choices = tags
  call lh#buffer#dialog#update(b:dialog)
endfunction

" s:Postinit() {{{3
function! s:Postinit(tagsinfo)
  let b:tagsinfo = a:tagsinfo

  nnoremap <silent> <buffer> K :call <sid>Sort('kind')<cr>
  nnoremap <silent> <buffer> N :call <sid>Sort('name')<cr>
  nnoremap <silent> <buffer> F :call <sid>Sort('filename')<cr>
  nnoremap <silent> <buffer> s :call <sid>ToggleSignature()<cr>
  exe "nnoremap <silent> <buffer> o :call lh#buffer#dialog#select(line('.'), ".b:dialog.id.", 'sp')<cr>"

  call lh#buffer#dialog#add_help(b:dialog, '@| o                       : Split (O)pen in a new buffer if not yet opened', 'long')
  call lh#buffer#dialog#add_help(b:dialog, '@| K, N, or F              : Sort by (K)ind, (N)ame, or (F)ilename', 'long')
  call lh#buffer#dialog#add_help(b:dialog, '@| s                       : Toggle full (s)signature display', 'long')

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
function! s:DisplaySignature()
endfunction

" LHTags_select() {{{3
function! LHTags_select(results, ...)
  if len(a:results.selection) > 1
    " this is an assert
    throw "lh-tags: We are not supposed to select several tags"
  endif
  let selection = a:results.selection[0]
  let info = b:info
  if a:0 == 0
    let cmd = b:cmd
  else
    let cmd = a:1[0]
  endif

  let choices = a:results.dialog.choices
  echomsg '-> '.choices[selection]
  " echomsg '-> '.info[selection-1].filename . ": ".info[selection-1].cmd
  if exists('s:quit') | :quit | endif
  " call s:JumpToTag(cmd, info[selection-1])
  call s:JumpToTag(cmd, b:tagsinfo[selection])
endfunction

" s:JumpToTag() {{{3
function! s:JumpToTag(cmd, taginfo)
  let filename = a:taginfo.filename
  call lh#buffer#jump(filename, a:cmd)
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
function! s:Find(cmd_edit, cmd_split, tagpattern)
  let info = taglist(a:tagpattern)
  if len(info) == 0
    call lh#common#error_msg("lh-tags: no tags for `".a:tagpattern."'")
    return
  endif
  " call confirm( "taglist(".a:tagpattern.")=".len(info), '&Ok', 1)
  if len(info) == 1
    call s:JumpToTag(a:cmd_split, info[0])
  else
    let which = s:ChooseTagEntry(info, a:tagpattern)
    if which >= 0 && which < len(info)
      echoerr "Assert: not expected path"
      call s:JumpToTag(a:cmd_edit, info[which])
    else
      let b:info = info
      let b:cmd = a:cmd_edit
    endif
  endif
endfunction

" lh#tags#split_open() {{{3
function! lh#tags#split_open()
  let id = eval(s:TagsSelectPolicy())
  :call s:Find('e', 'sp', id.'$')
endfunction

" ######################################################################
" ## Tag command {{{1
" ======================================================================
" Internal functions {{{2
" ======================================================================
" todo: 
" * filter on +/- f\%[unction]
" * filter on +/- a\%[ttribute]
" * filter on +/#/- v\%[isibility] (pub/pro/pri)

" Command completion  {{{3
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

" Command execution  {{{3
function! lh#tags#command(...)
  let id = join(a:000, '.*')
  :call s:Find('e', 'sp', id)
endfunction


"------------------------------------------------------------------------
" }}}1
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
