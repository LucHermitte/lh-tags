"=============================================================================
" File:         plugin/lh-tags.vim                                        {{{1
" Author:       Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"               <URL:http://github.com/LucHermitte/lh-tags>
" License:      GPLv3 with exceptions
"               <URL:http://github.com/LucHermitte/lh-tags/tree/master/License.md>
" Version:      2.0.2
let s:k_version = '2.0.2'
" Created:      04th Jan 2007
" Last Update:  07th Sep 2016
"------------------------------------------------------------------------
" Description:
"       Small plugin related to tags files.
"       It helps:
"       - generate tag files (+ spellfile + highlights)
"       - navigate (or more precisely: find the right tags)
"
"------------------------------------------------------------------------
" History:
"       v2.0.2:
"       (*) Tags can be automatically highlighted
"       v2.0.1:
"       (*) Spellfiles can be updated on demand
"       v2.0.0:
"       (*) LHT_no_auto defaults to 1 now, and is renamed to
"       tags_options.no_auto
"       v1.3.0:
"       (*) Tags browsing enabled even without ctags installed
"       (*) Tags filtering
"       v1.0.0:
"       (*) GPLv3
"       v0.2.0: 03rd Oct 2008
"       (*) code moved to an autoload plugin
"       v0.1.3: 30th Sep 2008
"       (*) Langage hooks
"       (*) ShowTags command
"       (*) :LHTags command (that supports auto completion)
"       v0.1.2: 11th Sep 2007
"       (*) Fix a path problem on file save
"       (*) Using a scratch buffer
"       v0.1.1:
"       (*) Using 'nomagic' when manually jumping to tags
"       v0.1.0:
"       (*) Initial Version
" TODO:
" @todo use --abort-- in the scratch buffer
" @todo inline help for sort
" @todo filter (like :g/:v)
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

" ######################################################################
" Tag browsing {{{1

nnoremap <silent> <Plug>CTagsSplitOpen     :call lh#tags#split_open()<cr>
if !hasmapto('<Plug>CTagsSplitOpen', 'n')
  nmap <silent> <c-w><m-down>  <Plug>CTagsSplitOpen
endif
xnoremap <silent> <Plug>CTagsSplitOpen     <C-\><C-n>:call lh#tags#split_open(lh#visual#selection())<cr>
if !hasmapto('<Plug>CTagsSplitOpen', 'v')
  xmap <silent> <c-w><m-down>  <Plug>CTagsSplitOpen
endif

" ######################################################################
" Tag command {{{1
" ======================================================================

command! -nargs=* -complete=custom,LHTComplete
      \         LHTags call lh#tags#command(<f-args>)

" todo:
" * filter on +/- f\%[unction]
" * filter on +/- a\%[ttribute]
" * filter on +/#/- v\%[isibility] (pub/pro/pri)

" Command completion  {{{1
let s:commands = '^LHT\%[ags]'
function! LHTComplete(ArgLead, CmdLine, CursorPos) abort
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

" ######################################################################
" Tag generation {{{1
" ======================================================================
" Needs ctags executable {{{2
let s:tags_executable = lh#option#get('tags_executable', 'ctags', 'bg')
let s:script = expand('<sfile>:p')

if !executable(s:tags_executable)
  let g:loaded_lh_tags = s:script.' partially loaded as ``'.s:tags_executable."'' is not available in $PATH"
  let &cpo=s:cpo_save
  finish
endif

" ======================================================================
" Mappings {{{2
" inoremap <expr> ; lh#tags#run('UpdateTags_for_ModifiedFile',';')

nnoremap <silent> <Plug>CTagsUpdateCurrent :call lh#tags#update_current()<cr>
let s:map_UpdateCurrent = {'modes': 'n'}
if !hasmapto('<Plug>CTagsUpdateCurrent', 'n')
  nmap <silent> <c-x>tc  <Plug>CTagsUpdateCurrent
  let s:map_UpdateCurrent['binding'] = '<c-x>tc'
endif

nnoremap <silent> <Plug>CTagsUpdateAll     :call lh#tags#update_all()<cr>
let s:map_UpdateAll = {'modes': 'n'}
if !hasmapto('<Plug>CTagsUpdateAll', 'n')
  nmap <silent> <c-x>ta  <Plug>CTagsUpdateAll
  let s:map_UpdateAll['binding'] = '<c-x>ta'
endif

nnoremap <silent> <Plug>CTagsUpdateSpell   :call lh#tags#update_spellfile()<cr>
let s:map_UpdateSpell = {'modes': 'n'}
if !hasmapto('<Plug>CTagsUpdateSpell', 'n')
  nmap <silent> <c-x>ts  <Plug>CTagsUpdateSpell
  let s:map_UpdateSpell['binding'] = '<c-x>ts'
endif

nnoremap <silent> <Plug>CTagsUpdateHighlight   :call lh#tags#update_highlight()<cr>
let s:map_UpdateHighlight = {'modes': 'n'}
if !hasmapto('<Plug>CTagsUpdateHighlight', 'n')
  nmap <silent> <c-x>th  <Plug>CTagsUpdateHighlight
  let s:map_UpdateHighlight['binding'] = '<c-x>th'
endif

" Menu {{{2
if has('gui_running') && has ('menu')
  amenu          50.97     &Project.-----<sep>-----       Nop
endif
call lh#menu#make('anore', '50.97.100',
      \ '&Project.&Tags.Update &all',
      \ s:map_UpdateAll,
      \ ':call lh#tags#update_all()<cr>')
" TODO inhibit this menu when no_auto is true
call lh#menu#make('anore', '50.97.101',
      \ '&Project.&Tags.Update &current',
      \ s:map_UpdateCurrent,
      \ ':call lh#tags#update_current()<cr>')
call lh#menu#make('anore', '50.97.102',
      \ '&Project.&Tags.Update &Spell Ignore List',
      \ s:map_UpdateSpell,
      \ ':call lh#tags#update_spellfile()<cr>')
call lh#menu#make('anore', '50.97.103',
      \ '&Project.&Tags.Update Tags &Highlighted',
      \ s:map_UpdateHighlight,
      \ ':call lh#tags#update_highlight()<cr>')

amenu          50.97.200 &Project.&Tags.-----<sep>----- Nop
if lh#has#jobs()
  call lh#let#if_undef('g:tags_options.run_in_bg', 1)
  if has('gui_running') && has ('menu')
  endif
  call lh#menu#def_toggle_item(
        \ { 'variable': 'tags_options.run_in_bg'
        \ , 'values': [0, 1]
        \ , 'menu': { 'priority': '50.98.201', 'name': "&Project.&Tags.&Generate"}
        \ , 'texts': ['blocked', 'in background']
        \ })
endif

call lh#let#if_undef('g:tags_options.auto_spellfile_update', 1)
call lh#menu#def_toggle_item(
      \ { 'variable': 'tags_options.auto_spellfile_update'
      \ , 'values': [0, 1, 'all']
      \ , 'menu': { 'priority': '50.98.202', 'name': "&Project.&Tags.&Update Spell Ignore List"}
      \ , 'texts': ['never', 'always', 'never on file saved']
      \ })

call lh#let#if_undef('g:tags_options.auto_highlight', 0)
call lh#menu#def_toggle_item(
      \ { 'variable': 'tags_options.auto_highlight'
      \ , 'values': [0, 1]
      \ , 'menu': { 'priority': '50.98.203', 'name': "&Project.&Tags.Auto &Highlight Tags"}
      \ , 'texts': ['no', 'yes']
      \ , 'actions': [':silent! syn clear TagsGroup', function('lh#tags#update_highlight')]
      \ })

" ======================================================================
" Auto command for automatically tagging a file when saved {{{2
augroup LH_TAGS
  au!
  autocmd BufWritePost,FileWritePost * if ! lh#option#get('tags_options.no_auto', 1) | call lh#tags#run('UpdateTags_for_SavedFile',0) | endif
aug END

" }}}1
" ======================================================================
let g:loaded_lh_tags = s:k_version
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
