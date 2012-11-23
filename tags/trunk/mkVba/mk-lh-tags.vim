"=============================================================================
" $Id$
" File:         mkVba/mk-lh-tags.vim                              {{{1
" Author:       Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"		<URL:http://code.google.com/p/lh-vim/>
" License:      GPLv3 with exceptions
"               <URL:http://code.google.com/p/lh-vim/wiki/License>
" Version:      1.1.0
let s:version = '1.1.0'
" Created:      20th Mar 2012
" Last Update:  $Date$
" }}}1
"=============================================================================

let s:project = 'lh-tags'
cd <sfile>:p:h
try 
  let save_rtp = &rtp
  let &rtp = expand('<sfile>:p:h:h').','.&rtp
  exe '27,$MkVimball! '.s:project.'-'.s:version
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
