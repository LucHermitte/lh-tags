"=============================================================================
" File:         plugin/lh-tags.vim                                        {{{1
" Author:       Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"               <URL:http://github.com/LucHermitte/lh-tags>
" License:      GPLv3 with exceptions
"               <URL:http://github.com/LucHermitte/lh-tags/tree/master/License.md>
" Version:      2.0.3
let s:k_version = '2.0.3'
" Created:      04th Jan 2007
" Last Update:  21st Feb 2017
"------------------------------------------------------------------------
" Description:
"       Small plugin related to tags files.
"       It helps:
"       - generate tag files (+ spellfile + highlights)
"       - navigate (or more precisely: find the right tags)
"
"------------------------------------------------------------------------
" History:
"       v2.0.3:
"       (*) Move cmdline completion function to autoload plugin
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

command! -nargs=* -complete=custom,lh#tags#_command_complete
      \         LHTags call lh#tags#command(<f-args>)

" todo:
" * filter on +/- f\%[unction]
" * filter on +/- a\%[ttribute]
" * filter on +/#/- v\%[isibility] (pub/pro/pri)

" ######################################################################
" Tag generation {{{1
" ======================================================================
" Needs ctags executable {{{2
let s:tags_executable = lh#option#get('tags_executable', 'ctags')
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
  call lh#project#menu#make('a', '97', '-----<sep>-----', '', 'Nop')
endif
call lh#project#menu#make('anore', '97.100',
      \ '&Tags.Update &all',
      \ s:map_UpdateAll,
      \ ':call lh#tags#update_all()<cr>')
" TODO inhibit this menu when no_auto is true
call lh#project#menu#make('anore', '97.101',
      \ '&Tags.Update &current',
      \ s:map_UpdateCurrent,
      \ ':call lh#tags#update_current()<cr>')
call lh#project#menu#make('anore', '97.102',
      \ '&Tags.Update &Spell Ignore List',
      \ s:map_UpdateSpell,
      \ ':call lh#tags#update_spellfile()<cr>')
call lh#project#menu#make('anore', '97.103',
      \ '&Tags.Update Tags &Highlighted',
      \ s:map_UpdateHighlight,
      \ ':call lh#tags#update_highlight()<cr>')

call lh#project#menu#make('a', '97.200', '&Tags.-----<sep>-----', '', 'Nop')
if lh#has#jobs()
  call lh#let#if_undef('g:tags_options.run_in_bg', 1)
  if has('gui_running') && has ('menu')
  endif
  call lh#project#menu#def_toggle_item(
        \ { 'variable': 'tags_options.run_in_bg'
        \ , 'values': [0, 1]
        \ , 'menu': { 'priority': '98.201', 'name': "&Tags.&Generate"}
        \ , 'texts': ['blocked', 'in background']
        \ })
endif

call lh#let#if_undef('g:tags_options.auto_spellfile_update', 1)
call lh#project#menu#def_toggle_item(
      \ { 'variable': 'tags_options.auto_spellfile_update'
      \ , 'values': [0, 1, 'all']
      \ , 'menu': { 'priority': '98.202', 'name': "&Tags.&Update Spell Ignore List"}
      \ , 'texts': ['never', 'always', 'never on file saved']
      \ })

call lh#let#if_undef('g:tags_options.auto_highlight', 0)
call lh#project#menu#def_toggle_item(
      \ { 'variable': 'tags_options.auto_highlight'
      \ , 'values': [0, 1]
      \ , 'menu': { 'priority': '98.203', 'name': "&Tags.Auto &Highlight Tags"}
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
