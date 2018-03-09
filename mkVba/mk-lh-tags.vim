"=============================================================================
" File:         mkVba/mk-lh-tags.vim                              {{{1
" Author:       Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"               <URL:http://github.com/LucHermitte/lh-tags>
" License:      GPLv3 with exceptions
"               <URL:http://github.com/LucHermitte/lh-tags/tree/master/License.md>
" Version:      2.0.5
let s:version = '2.0.5'
" Created:      20th Mar 2012
" Last Update:  09th Mar 2018
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
ftplugin/cpp/cpp_lh-tags-hooks.vim
lh-tags-addon-info.txt
plugin/lh-tags.vim
VimFlavor
