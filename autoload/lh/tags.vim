"=============================================================================
" $Id$
" File:		autoload/lh/tags.vim                                    {{{1
" Author:	Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"		<URL:http://hermitte.free.fr/vim/>
" Version:	0.2.0
" Created:	02nd Oct 2008
" Last Update:	$Date$
"------------------------------------------------------------------------
" Description:	«description»
" 
"------------------------------------------------------------------------
" Installation:	«install details»
" History:
" 	v0.2.0: 03rd Oct 2008
" 	(*) code moved to an autoload plugin
" TODO:		«missing features»
" }}}1
"=============================================================================

let s:cpo_save=&cpo
set cpo&vim
"------------------------------------------------------------------------

" ######################################################################
" ## Options {{{1
let g:tags_options_c   = '--c++-kinds=+p --fields=+imaS --extra=+q'
let g:tags_options_cpp = '--c++-kinds=+p --fields=+imaS --extra=+q'
" let g:tags_options_cpp = '--c++-kinds=+p --fields=+iaS --extra=+q --language-force=cpp'

function! s:CtagsExecutable()
  let tags_executable = lh#option#Get('tags_executable', 'ctags', 'bg')
  return tags_executable
endfunction

function! s:CtagsOptions()
  let ctags_options = lh#option#Get('tags_options_'.&ft, '')
  let ctags_options .= ' '.lh#option#Get('tags_options', '', 'wbg')
  return ctags_options
endfunction

function! s:CtagsDirname()
  let ctags_dirname = lh#option#Get('tags_dirname', '', 'b').'/'
  return ctags_dirname
endfunction

function! s:CtagsFilename()
  let ctags_filename = lh#option#Get('tags_filename', 'tags', 'bg')
  return ctags_filename
endfunction

function! s:CtagsCmdLine(ctags_pathname)
  let cmd_line = s:CtagsExecutable().' '.s:CtagsOptions().' -f '.a:ctags_pathname
  return cmd_line
endfunction

function! s:TagsSelectPolicy()
  let select_policy = lh#option#Get('tags_select', "expand('<cword>')", 'bg')
  return select_policy
endfunction

" ######################################################################
" ## Internal Functions {{{1
" # Debug {{{2
function! lh#tags#verbose(level)
  let s:verbose = a:level
endfunction

function! s:Verbose(expr)
  if exists(s:verbose) && s:verbose
    echomsg a:expr
  endif
endfunction

" ######################################################################
" ## Tags generation {{{1
" ======================================================================

" ======================================================================
" Tags generating functions {{{2
" ======================================================================
" generate tags on-the-fly {{{3
function! UpdateTags_for_ModifiedFile(ctags_pathname)
  let source_name    = expand('%')
  let temp_name      = tempname()
  let temp_tags      = tempname()

  " 1- purge old references to the source name
  if filereadable(a:ctags_pathname)
    " it exists => must be changed
    call system('grep -v "	'.source_name.'	" '.a:ctags_pathname.' > '.temp_tags.
	  \ ' && mv -f '.temp_tags.' '.a:ctags_pathname)
  endif

  " 2- save the unsaved contents of the current file
  call writefile(getline(1, '$'), temp_name, 'b')

  " 3- call ctags, and replace references to the temporary source file to the
  " real source file
  let cmd_line = s:CtagsCmdLine(a:ctags_pathname).' '.source_name.' --append'
  let cmd_line .= ' && sed "s#\t'.temp_name.'\t#\t'.source_name.'\t#" > '.temp_tags
  let cmd_line .= ' && mv -f '.temp_tags.' '.a:ctags_pathname
  call system(cmd_line)
  call delete(temp_name)
  
  return ';'
endfunction

" ======================================================================
" generate tags for all files {{{3
function! s:UpdateTags_for_All(ctags_pathname)
  call delete(a:ctags_pathname)
  let cmd_line  = 'cd '.s:CtagsDirname()
  " todo => use project directory
  "
  let cmd_line .= ' && '.s:CtagsCmdLine(a:ctags_pathname).' -R'
  echo cmd_line
  call system(cmd_line)
endfunction

" ======================================================================
" generate tags for the current saved file {{{3
function! s:UpdateTags_for_SavedFile(ctags_pathname)
  let source_name    = expand('%')
  let temp_tags      = tempname()

  if filereadable(a:ctags_pathname)
    " it exists => must be changed
    call system('grep -v "	'.source_name.'	" '.a:ctags_pathname.' > '.temp_tags.' && mv -f '.temp_tags.' '.a:ctags_pathname)
  endif
  let cmd_line = 'cd '.s:CtagsDirname()
  let cmd_line .= ' && ' . s:CtagsCmdLine(a:ctags_pathname).' --append '.source_name
  " echo cmd_line
  call system(cmd_line)
endfunction

" ======================================================================
" (public) Run a tag generating function {{{3
" See this function as a /template method/.
function! lh#tags#Run(tag_function)
  try
    let ctags_dirname  = s:CtagsDirname()
    if strlen(ctags_dirname)==1
      throw "tags-error: empty dirname"
    endif
    let ctags_filename = s:CtagsFilename()
    let ctags_pathname = ctags_dirname.ctags_filename
    if !filewritable(ctags_dirname) && !filewritable(ctags_pathname)
      throw "tags-error: ".ctags_pathname." cannot be modified"
    endif

    let Fn = function("s:".a:tag_function)
    call Fn(ctags_pathname)
  catch /tags-error:/
    " call lh#common#ErrorMsg(v:exception)
    return 0
  finally
  endtry

  echo ctags_pathname . ' updated.'
  return 1
endfunction

function! s:Irun(tag_function, res)
  call lh#tags#Run(a:tag_function)
  return a:res
endfunction

" ======================================================================
" Main function for updating all tags {{{3
function! lh#tags#UpdateAll()
  let done = lh#tags#Run('UpdateTags_for_All')
endfunction

" Main function for updating the tags from one file {{{3
" @note the file may be saved or "modified".
function! lh#tags#UpdateCurrent()
  if &modified
    let done = lh#tags#Run('UpdateTags_for_ModifiedFile')
  else
    let done = lh#tags#Run('UpdateTags_for_SavedFile')
  endif
  " if done
    " call lh#common#ErrorMsg("updated")
  " else
    " call lh#common#ErrorMsg("not updated")
  " endif
endfunction

" ######################################################################
" ## Tag browsing {{{1
function! s:LeftJustity(text, nb)
  let nbchars = strlen(a:text)
  let cpltWith = (nbchars >= a:nb) ? 0 : a:nb - nbchars
  return a:text.repeat(' ', cpltWith)
endfunction

function! s:RightJustity(text, nb)
  let nbchars = strlen(a:text)
  let cpltWith = (nbchars >= a:nb) ? 0 : a:nb - nbchars
  return repeat(' ', cpltWith).a:text
endfunction

function! s:GetKey(dict, keys_list)
  for key in a:keys_list
    if has_key(a:dict, key)
      return a:dict[key]
    endif
  endfor
  return ''
endfunction

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

" implementation
" inherits, signature
function! s:TagName(taginfo)
  " @todo: use keywords dependent on the ft
  let scope  = s:GetKey(a:taginfo,
	\ [ 'struct', 'class', 'namespace', 'enum', 'union' ])
  " if the id begins with the scope name, it means there is no need to care the
  " scope into account twice
  if (strlen(scope) != 0) && (a:taginfo.name !~ '^'.scope)
    let fullname =  scope . '::' . a:taginfo.name
  else
    let fullname = a:taginfo.name
  endif
  return fullname
endfunction

function! s:Fullname(taginfo, fullsignature)
  let fullname = a:taginfo.name 
  let fullname .= (a:fullsignature && has_key(a:taginfo, 'signature'))
	\ ? (a:taginfo.signature) 
	\ : ''
  return fullname
endfunction

function! s:TagEntry(taginfo, nameLen, fullsignature)
  let res = "  ".s:RightJustity(a:taginfo.nr,2).' '
	\ .s:LeftJustity(a:taginfo.pri, 3).' '
	\ .s:LeftJustity(a:taginfo.kind, 4).' '
	\ .s:LeftJustity(s:Fullname(a:taginfo, a:fullsignature), a:nameLen)
	\ .' '.a:taginfo.filename 
  return res
endfunction

function! s:PrepareTagEntry(tagrawinfo, nr)
  let kind = a:tagrawinfo.kind . ' ' . s:AccessSpecifier(a:tagrawinfo)
  let taginfo = {
	\ 'nr'              : a:nr,
	\ 'pri'             : '@@@',
	\ 'kind'            : kind,
	\ 'filename'        : a:tagrawinfo.filename,
	\ 'signature'       : s:GetKey(a:tagrawinfo, ['signature']),
	\ 'name'            : s:TagName(a:tagrawinfo)
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

function! s:BuildTagsMenu(tagsinfo, maxNameLen, fullsignature)
  let tags= []
  for taginfo in (a:tagsinfo)
    call add(tags, s:TagEntry(taginfo,a:maxNameLen, a:fullsignature))
  endfor
  return tags
endfunction

function! s:ComputeMaxNameLength(tagsinfo, fullsignature)
  let maxNameLen = 0
  for taginfo in a:tagsinfo
    let nameLen = strlen(s:Fullname(taginfo, a:fullsignature))
    if nameLen > maxNameLen | let maxNameLen = nameLen | endif
  endfor
  let maxNameLen += 1
  return maxNameLen
endfunction

function! s:ChooseTagEntry(tagrawinfos)
  if     len(a:tagrawinfos) <= 1 | return 0
    " < 0 => error
    " ==0 <=> empty => nothing to choose => abort
    " ==1 <=> 1 element => return its index
  else
    let fullsignature = 0
    " 1-  Prepare the tags
    let i=1
    let tagsinfo = [ s:tag_header ]
    for tagrawinfo in (a:tagrawinfos)
      let taginfo = s:PrepareTagEntry(tagrawinfo,i)
      call add(tagsinfo, taginfo)
      let i+= 1
    endfor
    let maxNameLen = s:ComputeMaxNameLength(tagsinfo, fullsignature)

    " 2- Prepare the lines to display

    let tags = s:BuildTagsMenu(tagsinfo, maxNameLen, fullsignature)

    " 3- Display
    let dialog = lh#buffer#dialog#new(
	  \ "tags-selector",
	  \ "lh-tags ".g:loaded_lh_tags_vim.": Select a tag to jump to",
	  \ '', 0,
	  \ 'LHTags_select', tags)
    let dialog.maxNameLen    = maxNameLen
    let dialog.fullsignature = fullsignature
    call s:Postinit(tagsinfo)
    return -1
  endif
endfunction

function! LH_Tabs_Sort(lhs, rhs)
  if     a:lhs.nr == '#' | return -1
  elseif a:rhs.nr == '#' | return 1
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

function! s:Sort(field)
  " let s:criteria = a:field
  let g:criteria = a:field
  call sort(b:tagsinfo, 'LH_Tabs_Sort')
  let tags = s:BuildTagsMenu(b:tagsinfo, b:dialog.maxNameLen, b:dialog.fullsignature)
  let b:dialog.choices = tags
  call lh#buffer#dialog#Update(b:dialog)
endfunction

function! s:ToggleSignature()
  let b:dialog.fullsignature = 1 - b:dialog.fullsignature
  let b:dialog.maxNameLen = s:ComputeMaxNameLength(b:tagsinfo, b:dialog.fullsignature)
  let tags = s:BuildTagsMenu(b:tagsinfo, b:dialog.maxNameLen, b:dialog.fullsignature)
  let b:dialog.choices = tags
  call lh#buffer#dialog#Update(b:dialog)
endfunction

function! s:Postinit(tagsinfo)
  let b:tagsinfo = a:tagsinfo

  nnoremap <silent> <buffer> K :call <sid>Sort('kind')<cr>
  nnoremap <silent> <buffer> N :call <sid>Sort('name')<cr>
  nnoremap <silent> <buffer> F :call <sid>Sort('filename')<cr>
  nnoremap <silent> <buffer> s :call <sid>ToggleSignature()<cr>
  exe "nnoremap <silent> <buffer> o :call lh#buffer#dialog#Select(line('.'), ".b:dialog.id.", 'sp')<cr>"

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

function! s:DisplaySignature()
endfunction

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
  call s:JumpToTag(cmd, info[selection-1])
endfunction

function! s:JumpToTag(cmd, taginfo)
  let filename = a:taginfo.filename
  call lh#buffer#Jump(filename, a:cmd)
  " Execute the search
  try
    let save_magic=&magic
    set nomagic
    exe a:taginfo.cmd
  finally
    let &magic=save_magic
  endtry
endfunction

function! s:Find(cmd, tagpattern)
  let info = taglist(a:tagpattern)
  if len(info) == 0
    call lh#common#ErrorMsg("lh-tags: no tags for `".a:tagpattern."'")
    return
  endif
  " call confirm( "taglist(".a:tagpattern.")=".len(info), '&Ok', 1)
  let which = s:ChooseTagEntry(info)
  if which >= 0 && which < len(info)
    call s:JumpToTag(a:cmd, info[which])
  else
    let b:info = info
    let b:cmd = a:cmd
  endif
endfunction

function! lh#tags#SplitOpen()
  let id = eval(s:TagsSelectPolicy())
  :call s:Find('e', id.'$')
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
function! lh#tags#Command(...)
  let id = join(a:000, '.*')
  :call s:Find('e', id)
endfunction


"------------------------------------------------------------------------
" }}}1
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
