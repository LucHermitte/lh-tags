"=============================================================================
" File:         mkVba/mk-lh-tags.vim                              {{{1
" Author:       Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"               <URL:http://github.com/LucHermitte/lh-tags>
" License:      GPLv3 with exceptions
"               <URL:http://github.com/LucHermitte/lh-tags/tree/master/License.md>
" Version:      3.0.4
let s:version = '3.0.4'
" Created:      20th Mar 2012
" Last Update:  31st Oct 2018
" }}}1
"=============================================================================

let s:project = 'lh-tags'
cd <sfile>:p:h
try
  let save_rtp = &rtp
  let &rtp = expand('<sfile>:p:h:h').','.&rtp
  exe '18,$MkVimball! '.s:project.'-'.s:version
  set modifiable
  set buftype=
finally
  let &rtp = save_rtp
endtry
finish
autoload/lh/tags.vim
autoload/lh/tags/indexers/ctags.vim
autoload/lh/tags/indexers/interface.vim
autoload/lh/tags/session.vim
autoload/lh/tags/system.vim
ftplugin/cpp/cpp_lh-tags-hooks.vim
addon-info.json
plugin/lh-tags.vim
VimFlavor
