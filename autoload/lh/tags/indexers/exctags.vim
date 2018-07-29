"=============================================================================
" File:         autoload/lh/tags/indexers/exctags.vim             {{{1
" Author:       Luc Hermitte <EMAIL:luc {dot} hermitte {at} gmail {dot} com>
"		<URL:http://github.com/LucHermitte/lh-tags>
" License:      GPLv3 with exceptions
"               <URL:http://github.com/LucHermitte/lh-tags/blob/master/License.md>
" Version:      3.0.0.
let s:k_version = '300'
" Created:      27th Jul 2018
" Last Update:  29th Jul 2018
"------------------------------------------------------------------------
" Description:
"       Specifications for exhuberant-ctags object
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
function! lh#tags#indexers#exctags#version()
  return s:k_version
endfunction

" # Debug   {{{2
let s:verbose = get(s:, 'verbose', 0)
function! lh#tags#indexers#exctags#verbose(...)
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

function! lh#tags#indexers#exctags#debug(expr) abort
  return eval(a:expr)
endfunction

" # SID     {{{2
function! s:getSID() abort
  return eval(matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_getSID$'))
endfunction
let s:k_script_name      = s:getSID()

"------------------------------------------------------------------------
" ## Exported functions {{{1
" # Language Map {{{2
" Associate ft to ctags supported languages
let s:all_lang_map = {
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

" # ctags capabilities analysis {{{2
" We ask ctags --help & cie what extras, fields, kinds, are supported by
" the current version
" Let's hope ex-ctags can work this way because uni-ctags cannot tell us
" its current version number to deduce anything

let s:ctags_flavours = {}

" Function: s:get_flavour(exe) abort {{{3
function! s:get_flavour(exe) abort
  let exe = exepath(a:exe)
  if ! has_key(s:ctags_flavours, exe)
    let s:ctags_flavours[exe] = s:analyse_flavour(exe)
  endif
  return s:ctags_flavours[exe]
endfunction

" Function: s:analyse_flavour(exepath) abort {{{3
function! s:analyse_flavour(exepath) abort
  let flavour = lh#object#make_top_type({'exepath': a:exepath})
  let raw_options = lh#os#system(lh#path#fix(a:exepath).' --help')

  " Recent versions of uctags use another flags to fill 'extra' option
  let flavour._extras_flag = match(raw_options, '--extras ') >= 0
        \ ? '--extras'
        \ : '--extra'

  " uctags is deprecating <LANG>-kind in favour of kind-<LANG>
  " => use this form if possible
  let flavour._kind_opt_format = match(raw_options, '--kinds-<LANG>') >= 0
        \ ? '--kinds-%s'
        \ : '--%s-kinds'

  " Detect parameters for --extra(s) and --fields options
  if match(raw_options, '--list-extras ') >= 0
    call lh#object#inject_methods(flavour, s:k_script_name, '_analyse_extras')
  else
    call lh#object#inject(flavour, '_analyse_extras', '_use_default_extras', s:k_script_name)
  endif
  if match(raw_options, '--list-fields ') >= 0
    call lh#object#inject_methods(flavour, s:k_script_name, '_analyse_fields')
  else
    call lh#object#inject(flavour, '_analyse_fields', '_use_default_fields', s:k_script_name)
  endif
  call lh#object#inject_methods(flavour, s:k_script_name,
        \ '_analyse_kinds', '_analyse_languages')

  call flavour._analyse_extras()
  call flavour._analyse_fields()
  call flavour._analyse_kinds()
  call flavour._analyse_languages()
  return flavour
endfunction

" Function: s:_analyse_extras() dict abort {{{3
function! s:_analyse_extras() dict abort
  let raw_extras = lh#os#system(lh#path#fix(self.exepath).' --list-extras')
  let self._extras = s:parse_matrix(raw_extras)
  return self
endfunction

function! s:_use_default_extras() dict abort
  " TODO: merge names with universal ctags choices
  let raw_extras = "#LETTER NAME LANGUAGE ENABLED DESCRIPTION"
        \ ."\nf  basefilename NONE    NO  Include  an  entry  for  the base file name of every source file,  which addresses the first line of the file"
        \ ."\nq  class        C++     NO  Include  an  extra  class-qualified  tag entry for each tag which is a member of a class"
        \ ."\nq  class        Eiffel  NO  Include  an  extra  class-qualified  tag entry for each tag which is a member of a class"
        \ ."\nq  class        Java    NO  Include  an  extra  class-qualified  tag entry for each tag which is a member of a class"
  let self._extras = s:parse_matrix(raw_extras)
  return self
endfunction

" Function: s:_analyse_fields() dict abort {{{3
function! s:_analyse_fields() dict abort
  let raw_fields = lh#os#system(lh#path#fix(self.exepath).' --list-fields')
  let self._fields = s:parse_matrix(raw_fields)
  return self
endfunction

function! s:_use_default_fields() dict abort
  " TODO: merge names with universal ctags choices
  let raw_fields = "#LETTER NAME LANGUAGE ENABLED DESCRIPTION"
        \ ."\n a   access         NONE  NO  Access (or export) of class members"
        \ ."\n f   filescope      NONE  YES File-restricted scoping"
        \ ."\n i   inheritance    NONE  NO  Inheritance information"
        \ ."\n k   kindname       NONE  YES Kind of tag as a single letter"
        \ ."\n K   kindfullname   NONE  NO  Kind of tag as full name"
        \ ."\n l   language       NONE  NO  Language of source file containing tag"
        \ ."\n m   implementation NONE  NO  Implementation information"
        \ ."\n n   linenumer      NONE  NO  Line number of tag definition"
        \ ."\n s   scope          NONE  NO  Scope of tag definition"
        \ ."\n S   signature      NONE  NO  Signature of routine (e.g. prototype or parameter list)"
        \ ."\n z   kind           NONE  NO  Include the 'kind:' key in kind field"
        \ ."\n t   typeref        NONE  YES Type  and name of a variable or typedef as 'typeref:' field"

  let self._fields = s:parse_matrix(raw_fields)
  return self
endfunction

" Function: s:_analyse_kinds() dict abort {{{3
function! s:line2dict(line) abort
  let tokens = split(a:line)
  return {tokens[0] : join(tokens[1:], ' ')}
endfunction
function! s:extract_kinds(kinds, pattern) abort
  let kinds = map(deepcopy(a:kinds), "filter(v:val, 'v'.':val =~? a:pattern')")
  call filter(kinds, '!empty(v:val)')
  call map(kinds, 'keys(v:val)[0]')
  return kinds
endfunction
function! s:_analyse_kinds() dict abort
  let raw_kinds = lh#os#system(lh#path#fix(self.exepath).' --list-kinds')
  " Format:
  "   Lang
  "        letter    then the description
  let lines = split(raw_kinds, "\n")
  let self._kinds = {}

  " Analyse all lines in one pass with a kind of state machine. The
  " state is the current language with is stored at the and of the
  " 'languages' list.
  " If the line starts at the first character, we have a language, we
  " update the state machine and extend the self._kinds dictionary with
  " the new language
  " Otherwise, we have a "kind" entry which we add in self._kinds[crt
  " lang]
  let languages = []
  call map(lines, 'v:val[0] != " " '
        \ . '? extend(self._kinds, {add(languages, v:val)[-1] : {}})'
        \ . ': extend(self._kinds[languages[-1]], s:line2dict(v:val))')


  " By default, tags for almost all kinds are generated except for
  " - function declarations
  " - local variables
  " Unfortunatelly, depending on the language, the exact option may
  " change => pre-analyse it.
  let self._kinds_local = s:extract_kinds(self._kinds, 'local')
  let self._kinds_proto = s:extract_kinds(self._kinds, '\vprototype|interface content|subroutine declaration')

  return self
endfunction

" Function: s:_analyse_languages() dict abort {{{3
function! s:_analyse_languages() dict abort
  let raw_languages = lh#os#system(lh#path#fix(self.exepath).' --list-languages')
  let languages = lh#list#unique_sort(split(raw_languages, "\n"))
  let self._ft_lang_map = filter(copy(s:all_lang_map), 'index(languages, v:val) >= 0')
endfunction

" Function: s:feature_id(data, l_id, n_id) abort {{{3
function! s:feature_id(data, l_id, n_id) abort
  " Sometimes, there are entries with no NAME, only LETTER
  " => ID ::= N:{name} or L:{letter}
  return a:data[a:n_id] == 'NONE' ? "L:".a:data[a:l_id] : "N:".a:data[a:n_id]
endfunction

" Function: s:parse_matrix(raw) abort {{{3
function! s:parse_matrix(raw) abort
  let lines = split(a:raw, "\n")
  let keys = split(lines[0])
  let tmp = map(lines[1:], 'split(v:val)')
  let features = map(tmp, 'v:val[:len(keys)-2] + [join(v:val[len(keys)-1:], " ")]')

  let letter_idx  = index(keys, '#LETTER')
  let name_idx    = index(keys, 'NAME')
  let lang_idx    = index(keys, 'LANGUAGE')
  let descr_idx   = index(keys, 'DESCRIPTION')
  let enabled_idx = index(keys, 'ENABLED')

  let res = {}
  " To not loose multiple entries under a same NAME, we proceed in two
  " passes
  call map(copy(features), 'extend(res, {s:feature_id(v:val, letter_idx, name_idx) : {}})')

  call map(copy(features), 'extend(res[s:feature_id(v:val, letter_idx, name_idx)], {v:val[lang_idx] : {"letter": v:val[letter_idx], "description": v:val[descr_idx], "enabled": v:val[enabled_idx]}})')

  return res
endfunction

" # exctags object {{{2
" Function: lh#tags#indexers#exctags#make() {{{3
function! lh#tags#indexers#exctags#make() abort
  let res = lh#tags#indexers#interface#make()
  call lh#object#inject_methods(res, s:k_script_name,
        \ 'update_tags_option', 'db_filename',
        \ 'executable', 'flavour',
        \ 'cmd_line')

  " TODO: not to be done in the case of `get_file_tags`
  call res.update_tags_option()
  return res
endfunction

function! s:update_tags_option() dict abort " {{{3
  let self._db_file = self.db_dirname() . self.db_filename()
  let fixed_path = lh#path#fix(self._db_file)
  if lh#project#is_in_a_project()
    call lh#let#to('p:&tags', '+='.fixed_path)
  else
    exe 'setlocal tags+='.fixed_path
  endif
endfunction

function! s:db_filename() dict abort " {{{3
  let ctags_filename = lh#option#get('tags_filename', 'tags', 'bpg')
  return ctags_filename
endfunction

function! s:executable() dict abort " {{{3
  " FIXME: check the tags executable may be different in two different
  " buffers while the exctags object could be the same => this makes no
  " sense and this may be source of odd behaviours
  let tags_executable = lh#option#get('tags_executable', 'ctags', 'bpg')
  return tags_executable
endfunction

function! s:flavour() dict abort " {{{3
  return s:get_flavour(self.executable())
endfunction

function! s:cmd_line(...) dict abort " {{{3
  let args = get(a:, 1, {})
  let cmd_line = [self.executable()]
  let flavour = self.flavour()

  let options = []
  let options += ['--tag-relative=yes']

  " Forced languages
  let fts = lh#option#get('tags_options.indexed_ft')
  if lh#option#is_set(fts)
    let langs = map(copy(fts), 'get(flavour._ft_lang_map, v:val, "")')
    " TODO: warn about filetypes unknown to ctags
    call filter(langs, '!empty(v:val)')
    let options += ['--languages='.join(langs, ',')]
  else
    let langs = values(flavour._ft_lang_map)
  endif

  " Given the languages of the current project, generate the "kinds"
  " option
  let kinds = {}
  call map(copy(langs), 'extend(kinds, {v:val : []})')
  " first: add the prototypes
  call lh#assert#true(lh#has#vkey())
  call map(kinds, 'has_key(flavour._kinds_proto, v:key) ? add(v:val, flavour._kinds_proto[v:key]) : v:val')
  " Then analyse some other requirements
  if get(args, 'extract_local_variables', 0)
    call map(kinds, 'has_key(flavour._kinds_local, v:key) ? add(v:val, flavour._kinds_local[v:key]) : v:val')
  endif
  " TODO: add generic way to support other kinds...
  call filter(kinds, '!empty(v:val)')
  call map(kinds, 'add(options, printf(flavour._kind_opt_format."=+%s", v:key, join(v:val, "")))')

  " Regarding --extra, it becomes extras with a latter version of uctags
  " -> always +q
  let options += [flavour._extras_flag.'=+q']

  " Regarding fields: most are global,
  " C, C++:
  "   - fields:+imaSft, c++=+{properties},
  "     a: OO lang with public/protected/...
  "     i: OO lang w/ inhritance
  "     t: type + name of var/typedef
  "   - extras:+q
  "
  " Java
  "   - fields:+imaSft
  " Vim
  "   - fields:+mS


  " TODO: Need to pick various options (kind, langmap, fields, extra...) in
  " various places (b:, p:, g:) and assemble back something
  " let options += [lh#option#get('tags_options.'.get(args, 'ft', &ft).'.flags', '')]
  let options += [lh#option#get('tags_options.flags', '', 'wbpg')]
  let options += [lh#option#get('tags_options.langmap', '', 'wbpg')]

  " Leave the join to system/job call
  return cmd_line + options
endfunction

"------------------------------------------------------------------------
" ## Internal functions {{{1

"------------------------------------------------------------------------
" }}}1
"------------------------------------------------------------------------
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
