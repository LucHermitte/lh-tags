"=============================================================================
" File:         autoload/lh/tags/indexers/ctags.vim             {{{1
" Author:       Luc Hermitte <EMAIL:luc {dot} hermitte {at} gmail {dot} com>
"		<URL:http://github.com/LucHermitte/lh-tags>
" License:      GPLv3 with exceptions
"               <URL:http://github.com/LucHermitte/lh-tags/blob/master/License.md>
" Version:      3.0.0.
let s:k_version = '300'
" Created:      27th Jul 2018
" Last Update:  03rd Sep 2018
"------------------------------------------------------------------------
" Description:
"       Specifications for exhuberant-ctags and universal-ctags objects
"
"------------------------------------------------------------------------
" History:
"       V3.0 first version
" TODO:
"       (*) Add a way to test whether a feature is supported as kinds,
"       fields...
" }}}1
"=============================================================================

let s:cpo_save=&cpo
set cpo&vim
"------------------------------------------------------------------------
" ## Misc Functions     {{{1
" # Version {{{2
function! lh#tags#indexers#ctags#version()
  return s:k_version
endfunction

" # Debug   {{{2
let s:verbose = get(s:, 'verbose', 0)
function! lh#tags#indexers#ctags#verbose(...)
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

function! lh#tags#indexers#ctags#debug(expr) abort
  return eval(a:expr)
endfunction

" # SID     {{{2
function! s:getSID() abort
  return eval(matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_getSID$'))
endfunction
let s:k_script_name      = s:getSID()
" s:function(func_name) {{{3
function! s:function(func)
  if !exists("s:SNR")
    let s:SNR=matchstr(expand('<sfile>'), '<SNR>\d\+_\zefunction$')
  endif
  return function(s:SNR . a:func)
endfunction


"------------------------------------------------------------------------
" ## Exported functions {{{1
let s:k_unset = lh#option#unset()
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

" # ctags flavours -- ctags capabilities analysis {{{2
" We ask ctags --help & cie what extras, fields, kinds, are supported by
" the current version
" Let's hope ex-ctags can work this way because uni-ctags cannot tell us
" its current version number to deduce anything

let s:ctags_flavours = {}

" Function: s:get_flavour(exe) abort {{{3
function! s:get_flavour(exe) abort
  let exe = lh#path#exe(a:exe)
  if ! has_key(s:ctags_flavours, exe)
    let s:ctags_flavours[exe] = s:analyse_flavour(exe)
  endif
  return s:ctags_flavours[exe]
endfunction

" Function: s:check_pattern(raw_help, exepath, patterns, ...) abort {{{3
function! s:check_pattern(raw_help, exepath, patterns, ...) abort
  let values = get(a:, 1, a:patterns)
  for i in range(len(a:patterns))
    if match(a:raw_help, a:patterns[i]) >= 0
      return values[i]
    endif
  endfor
  throw "tags-error: ".a:exepath." isn't a valid ctags executable (no ".a:patterns[-1]." option)"
endfunction

" Function: s:analyse_flavour(exepath) abort {{{3
function! s:analyse_flavour(exepath) abort
  let flavour = lh#object#make_top_type({'exepath': lh#path#fix(a:exepath)})
  let raw_options = lh#os#system(flavour.exepath . ' --help')
  if v:shell_error != 0
    throw "tags-error: ".a:exepath." isn't a valid ctags executable (no --help option)"
  endif

  " Recent versions of uctags use another flags to fill 'extra' option
  let flavour._extras_flag = s:check_pattern(raw_options, a:exepath, ['--extras', '--extra'])

  " uctags is deprecating <LANG>-kind in favour of kind-<LANG>
  " => use this form if possible
  let flavour._kind_opt_format = s:check_pattern(raw_options, a:exepath, ['--kinds-<LANG>', '--<LANG>-kinds'], ['--kinds-%s', '--%s-kinds'])

  " uctags introduces --map-<LANG>
  let flavour._langmap_opt_format = s:check_pattern(raw_options, a:exepath, ['--map-<LANG>', '--langmap='], ['--map-%s=%s', '--langmap=%s:%s'])

  " Detect parameters for --extra(s) and --fields options
  if match(raw_options, '--list-extras') >= 0
    call lh#object#inject_methods(flavour, s:k_script_name, '_analyse_extras')
  else
    call lh#object#inject(flavour, '_analyse_extras', '_use_default_extras', s:k_script_name)
  endif
  if match(raw_options, '--list-fields') >= 0
    call lh#object#inject_methods(flavour, s:k_script_name, '_analyse_fields')
  else
    call lh#object#inject(flavour, '_analyse_fields', '_use_default_fields', s:k_script_name)
  endif
  call lh#object#inject_methods(flavour, s:k_script_name
        \ , '_analyse_kinds', '_analyse_languages', '_recursive_or_all'
        \ , 'set_lang_map', 'get_lang_for', 'get_kind_flags')

  call flavour._analyse_extras()
  call flavour._analyse_fields()
  call flavour._analyse_kinds()
  call flavour._analyse_languages()
  return flavour
endfunction

" Function: s:set_lang_map(ft, exts) dict abort {{{3
function! s:set_lang_map(ft, exts) dict abort
  let lang = self.get_lang_for(a:ft)
  call lh#let#to('p:tags_options.langmap.'.lang, a:exts)
endfunction

" Function: s:get_lang_for(ft) dict abort {{{3
function! s:get_lang_for(ft) dict abort
  let lang = get(self._ft_lang_map, a:ft, s:k_unset)
  if lh#option#is_unset(lang)
    throw "No language associated to " .a:ft." filetype for ctags!"
  endif
  return lang
endfunction

" Function: s:_recursive_or_all() dict abort {{{3
function! s:_recursive_or_all() dict abort
  let recurse = lh#option#get('tags_must_go_recursive', 1)
  let res = recurse ? '-R' : '*'
  return res
endfunction

" Function: s:_analyse_extras() dict abort {{{3
function! s:_analyse_extras() dict abort
  let raw_extras = lh#os#system(self.exepath.' --list-extras')
  let self._extras = s:parse_matrix(raw_extras)
  return self
endfunction

" Function: s:_use_default_extras() dict abort {{{3
function! s:_use_default_extras() dict abort
  " NB: universal-ctags aso has: {{{4
  " - F fileScope
  " - p pseudo
  " - r reference
  " - g guest
  " - s subparser
  " }}}4
  let raw_extras =
        \ "#LETTER NAME      LANGUAGE ENABLED DESCRIPTION"
        \ ."\nf    inputFile NONE     TRUE    Include  an  entry  for  the base file name of every source file,  which addresses the first line of the file"
        \ ."\nq    qualified C++      TRUE    Include  an  extra  class-qualified  tag entry for each tag which is a member of a class"
        \ ."\nq    qualified Eiffel   TRUE    Include  an  extra  class-qualified  tag entry for each tag which is a member of a class"
        \ ."\nq    qualified Java     TRUE    Include  an  extra  class-qualified  tag entry for each tag which is a member of a class"
  let self._extras = s:parse_matrix(raw_extras)
  return self
endfunction

" Function: s:_analyse_fields() dict abort {{{3
function! s:_analyse_fields() dict abort
  let raw_fields = lh#os#system(self.exepath.' --list-fields')
  let self._fields = s:parse_matrix(raw_fields)
  return self
endfunction

" Function: s:_use_default_fields() dict abort {{{3
function! s:_use_default_fields() dict abort
  " NB: universal-ctags also has: {{{4
  " - C compact
  " - r role
  " - R Ø             Marker representing whether tag is definition or reference
  " - Z scope         Include "scope:" key in scope field
  " - E extras        Extra tag type information
  " - x xpath
  " - p scopeKind
  " - e end           End lines of various items!
  " - Ø properties    (static, inline, mutable...) -> C, C++, CUDA
  " - Ø template      Template parameters -> C++
  " - Ø captures      Lambda capture list -> C++
  " - Ø name          Aliased names -> C++
  " - Ø decorators    -> Python
  " - Ø sectionMarker -> reStructuredText
  " - Ø version       -> Maven2
  " }}}4
  let raw_fields =
        \ "#LETTER NAME           LANGUAGE ENABLED DESCRIPTION"
        \ ."\n a   access         NONE     off     Access (or export) of class members"
        \ ."\n f   file           NONE     on      File-restricted scoping"
        \ ."\n i   inherits       NONE     off     Inheritance information"
        \ ."\n k   NONE           NONE     on      Kind of tag as a single letter"
        \ ."\n K   NONE           NONE     off     Kind of tag as full name"
        \ ."\n l   language       NONE     off     Language of source file containing tag"
        \ ."\n m   implementation NONE     off     Implementation information"
        \ ."\n n   line           NONE     off     Line number of tag definition"
        \ ."\n s   NONE           NONE     off     Scope of tag definition"
        \ ."\n S   signature      NONE     off     Signature of routine (e.g. prototype or parameter list)"
        \ ."\n z   kind           NONE     off     Include the 'kind:' key in kind field"
        \ ."\n t   typeref        NONE     on      Type  and name of a variable or typedef as 'typeref:' field"
  let self._fields = s:parse_matrix(raw_fields)
  return self
endfunction

" Function: s:_analyse_kinds() dict abort {{{3
function! s:line2dict(line) abort
  let tokens = split(a:line)
  return {tokens[0] : join(tokens[1:], ' ')}
endfunction
function! s:extract_kinds(kinds, pattern, ...) abort
  " a:1: exclude patterns
  let kinds = map(deepcopy(a:kinds), "filter(v:val, 'v'.':val =~? a:pattern')")
  if a:0 > 0
    call map(kinds, "filter(v:val, 'v'.':val !~? a:1')")
  endif
  call filter(kinds, '!empty(v:val)')
  call map(kinds, 'keys(v:val)')
  return kinds
endfunction
function! s:_analyse_kinds() dict abort
  let raw_kinds = lh#os#system(self.exepath.' --list-kinds')
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
  let self._kinds_functions       = s:extract_kinds(self._kinds, '\vsubprograms$|message|method|procedure|subroutine|function', '\vfunction (prototype|declaration|parameter|variable)')
  let self._kinds_local_variables = s:extract_kinds(self._kinds, 'local')
  let self._kinds_prototypess     = s:extract_kinds(self._kinds, '\vprototype|interface content|subroutine declaration')
  let self._kinds_variables       = s:extract_kinds(self._kinds, '\v(local |forward )@<!variable')

  return self
endfunction

" Function! s:get_kind_flags(kind) dict abort " {{{3
function! s:get_kind_flags(kind) dict abort
  if has_key(self, '_kinds_'.a:kind)
    return self['_kinds_'.a:kind]
  else
    return s:extract_kinds(self._kinds, a:kind)
  endif
endfunction

" Function: s:_analyse_languages() dict abort {{{3
function! s:_analyse_languages() dict abort
  let raw_languages = lh#os#system(self.exepath.' --list-languages')
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

  call map(copy(features), 'extend(res[s:feature_id(v:val, letter_idx, name_idx)], {v:val[lang_idx] : {"letter": v:val[letter_idx], "name": v:val[name_idx], "description": v:val[descr_idx], "enabled": (v:val[enabled_idx]=~?"on\\|TRUE")}})')

  return res
endfunction

" # ctags object {{{2
" Constants {{{3
let s:k_default_fields = {
      \ 'name'          : 1,
      \ 'input'         : 1,
      \ 'pattern'       : 1,
      \ 'file'          : 1,
      \ 'k'             : 1,
      \ 's'             : 1,
      \ 'typeref'       : 1,
      \ 'access'        : 1,
      \ 'implementation': 1,
      \ 'inherits'      : 1,
      \ 'signature'     : 1,
      \ 'line'          : 1
      \,'properties'    : 1
      \ }
" Function: lh#tags#indexers#ctags#make([args]){{{3
function! lh#tags#indexers#ctags#make(...) abort
  let res = call('lh#tags#indexers#interface#make', a:000)
  call lh#object#inject_methods(res, s:k_script_name,
        \ 'update_tags_option', 'db_filename',
        \ 'executable', 'set_executable', 'flavour',
        \ 'cmd_line', 'run_on_all_files', 'run_update_file', 'run_update_modified_file',
        \ 'taglist'
        \ )
  call lh#object#inject(res, 'get_kind_flags', '_idx_get_kind_flags', s:k_script_name)
  call lh#object#inject(res, 'has_kind',       '_idx_has_kind', s:k_script_name)


  " By default the executable is set w/ "bpg:tags_executable", but it can be
  " overwritten for the current indexer instance.
  if !has_key(res, '_executable')
    let res._executable = lh#ref#bind('bpg:tags_executable')
  endif

  if ! get(res, 'dont_update_tags_option', 0)
    " Useful in the case of `get_file_tags` (used from lh-dev)
    call res.update_tags_option()
  endif
  return res
endfunction

function! s:update_tags_option() dict abort " {{{3
  call self.set_db_file(self.src_dirname() . self.db_filename())
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
  let tags_executable = lh#ref#is_bound(self._executable) ? self._executable.resolve() : self._executable
  return lh#option#is_set(tags_executable) ? tags_executable : 'ctags'
endfunction

function! s:set_executable(exec) dict abort " {{{3
  if !executable(a:exec)
    throw "tags-error: ".a:exec." isn't a valid executable"
  endif
  " Check the flavour is compatible with ctags usual interface
  let fl = s:get_flavour(a:exec)
  let res._executable = a:exec

  call self._fix_cygwin_paths()
endfunction

function! s:flavour() dict abort " {{{3
  return s:get_flavour(self.executable())
endfunction

function! s:_idx_get_kind_flags(ft, ...) dict abort " {{{3
  " args:
  " - either <kind>
  " - or [<kind>, default...]
  let fl = self.flavour()
  let lang = fl.get_lang_for(a:ft)
  let res = map(copy(a:000), 'type(v:val) == type([]) ? get(fl.get_kind_flags(v:val[0]), lang, v:val[1:]) : get(fl.get_kind_flags(v:val), lang, "")')
  return res
endfunction

function! s:_idx_has_kind(ft, kind) dict abort " {{{3
  let fl = self.flavour()
  let lang = fl.get_lang_for(a:ft)
  return has_key(fl.get_kind_flags(a:kind), lang)
endfunction

function! s:fts_2_langs(flavour, args, options) abort " {{{3
  let fts = get(a:args, 'fts', s:k_unset)
  if lh#option#is_unset(fts)
    unlet fts
    let fts = lh#option#get('tags_options.indexed_ft')
  endif
  if lh#option#is_set(fts)
    let langs = map(copy(fts), 'get(a:flavour._ft_lang_map, v:val, "")')
    let unknown_fts = filter(copy(fts), '!has_key(a:flavour._ft_lang_map, v:val)')
    for ft in unknown_fts
      let exepath = a:flavour.exepath
      call lh#notify#once('lhtags_unknown_'.ft.'_'.exepath, "This flavour of ctags (".exepath.") doesn't know any language associated to ".ft." filetype")
    endfor
    call filter(langs, '!empty(v:val)')
    if !empty(langs)
      call add(a:options, '--languages='.join(langs, ','))
    endif
  else
    let langs = values(a:flavour._ft_lang_map)
  endif
  return langs
endfunction

function! s:kinds_2_options(flavour, langs, args, options) abort " {{{3
  let kinds = {} " {lang: [kind-list]}
  call map(copy(a:langs), 'extend(kinds, {v:val : []})')
  call lh#assert#true(lh#has#vkey())

  " first: add the prototypes, local variables, etc
  let default_opt = {'extract_prototypes': 1, 'extract_local_variables': 0, 'extract_variables': 1, 'extract_functions': 1}
  call extend(a:args, default_opt, 'keep')
  let kinds_to_extract = filter(copy(a:args), 'v:key =~ "extract_" && v:val == 1')
  for extracted_kind in keys(kinds_to_extract)
    let kind_name = matchstr(extracted_kind, 'extract_\zs.*')
    " v:key == lang, v:val == the list of kinds per lang
    call map(kinds, 'extend(v:val, get(a:flavour.get_kind_flags(kind_name), v:key, []))')
    call s:Verbose("Kind[%1] -> %2", extracted_kind, a:flavour.get_kind_flags(kind_name))
  endfor

  " No need to include the kind if it's not off by default
  if ! get(g:tags_options, 'explicit_cmdline', 0)
    for [lang, lg_kinds] in items(kinds)
      call filter(lg_kinds, 'a:flavour._kinds[lang][v:val] =~ "\\[off\\]"')
    endfor
  " TODO: else: explicitly list all unrejected implicit kinds?
  endif
  " Remove languages for which no specific "kinds" are to be extracted
  call filter(kinds, '!empty(v:val)')
  call map(kinds, 'add(a:options, printf(a:flavour._kind_opt_format."=+%s", v:key, join(v:val, "")))')

  call s:Verbose("Kinds: %1 => %2", a:args, kinds)
endfunction

function! s:get_enabled(field_spec, langs) abort " {{{3
  let res = has_key(a:field_spec, "NONE") ? a:field_spec.NONE.enabled
        \ : get(filter(map(copy(a:langs), 'has_key(a:field_spec, v:val) ? a:field_spec[v:val].enabled : ""'), '!empty(v:val)'), 0, 0)
  " call s:Verbose("%3abled: %1, %2", a:field_spec, a:langs, res?"en":"dis")
return res
  " return get(a:field_spec, "NONE", {'enabled': 0})['enabled']
endfunction

function! s:non_empty_field(dict, ...) abort
  let values = map(copy(a:000), 'get(a:dict, v:val, "")')
  return filter(values, 'v:val != "-"')[0]
endfunction

function! s:get_field_id(field_spec, langs) abort " {{{3
  if  has_key(a:field_spec, "NONE")
    let res = a:field_spec.NONE.letter
  else
    let res = get(filter(map(copy(a:langs), 'has_key(a:field_spec, v:val) ? [a:langs[v:key], s:non_empty_field(a:field_spec[v:val], "letter", "name")] : ["",[]]'), '!empty(v:val[1])'), 0, [])
  endif
  call s:Verbose("ID: %1%2 : %3", res, a:langs, a:field_spec)
  return res
endfunction

function! s:add_matching_fields(flavour, field_names, state, rejected_field_names, langs) abort " {{{3
  " TODO: There seems to be a confusion when handling the C++ field {name} with the generic N field.
  let fields = []
  let field_specs = a:flavour._fields
  call s:Verbose("Check matching %1 fields among %2", a:state ? "positive": "negative", keys(field_specs))
  if get(g:tags_options, 'explicit_cmdline', 0)
    " We loop on all the known fields
    call map(copy(field_specs),
          \   '   index(a:field_names, v:key[2:])>=0                                                          ? add(fields, s:get_field_id(v:val, a:langs))'
          \ . ' : (index(a:rejected_field_names, v:key[2:])< 0) && (s:get_enabled(v:val, a:langs) == a:state) ? add(fields, s:get_field_id(v:val, a:langs))'
          \ . ' : v:val'
          \ )
  else
    " We loop on the specific fields requested
    call map(a:field_names,
          \   '   has_key(field_specs, "N:".v:val) && (s:get_enabled(field_specs["N:".v:val], a:langs) != a:state) ? add(fields, s:get_field_id(field_specs["N:".v:val], a:langs))'
          \ . ' : has_key(field_specs, "L:".v:val) && (s:get_enabled(field_specs["L:".v:val], a:langs) != a:state) ? add(fields, s:get_field_id(field_specs["L:".v:val], a:langs))'
          \ . ' : v:val')
  endif
  call filter(fields, '!empty(v:val)')
  return fields
endfunction

function! s:fields_2_options(flavour, langs, args, options) abort " {{{3
  " # Regarding fields: most are global,
  " C, C++:
  "   - fields:+imaSft, c++=+{properties},
  "     a: OO lang with public/protected/...
  "     i: OO lang w/ inhritance
  "     t: type + name of var/typedef
  " Java
  "   - fields:+imaSft
  " Vim
  "   - fields:+mS
  let positive_options = filter(copy(a:args), 'type(v:val) == type(0) && v:val == 1')
  let negative_options = filter(copy(a:args), 'type(v:val) == type(0) && v:val == 0')

  call s:Verbose("arguments: %1", a:args)
  let pos_fields = s:add_matching_fields(a:flavour, keys(positive_options), 1, keys(negative_options), a:langs)
  let neg_fields = s:add_matching_fields(a:flavour, keys(negative_options), 0, keys(positive_options), a:langs)
  " let g:pos_fields = pos_fields
  " let g:neg_fields = neg_fields
  " let g:all_fields = a:flavour._fields
  let fields = []
  let lang_fields = []
  if !empty(pos_fields)
    let spe_fields = filter(copy(pos_fields), 'type(v:val) == type([])')
    " TODO: support old transformation syntax "&{<LANG>-<field-name>}"
    let lang_fields += map(spe_fields, 'printf("--fields-%s=+{%s}", v:val[0], v:val[1])')
    let fields += ['+'] + filter(pos_fields, 'type(v:val) == type("")')
  endif
  if !empty(neg_fields)
    let spe_fields = filter(copy(neg_fields), 'type(v:val) == type([])')
    let lang_fields += map(spe_fields, 'printf("--fields-%s=-{%s}", v:val[0], v:val[1])')
    let fields += ['-'] + filter(neg_fields, 'type(v:val) == type("")')
  endif
  if !empty(fields)
    call add(a:options, '--fields='.join(fields, ''))
    call extend(a:options, lang_fields)
  endif
endfunction

function! s:cmd_line(...) dict abort " {{{3
  " Options:
  " - fts: list
  " - extract_local_variables: bool
  " - field names: bool
  " - forced_language: string
  " - analyse_file: filename -- expected to be used & forced_language
  " - tag_file
  let args = get(a:, 1, {})

  " When no field in particular is required through `cmd_line()`
  " arguments, we still force some default values.
  call extend(args, s:k_default_fields, 'keep')

  let cmd_line = [self.executable()]
  let flavour = self.flavour() " ctags flavour: exctag/universal-ctags (many different versions)

  let options = []
  if get(args, 'relative', 1)
    let options += ['--tag-relative=yes']
  endif

  " # Forced languages
  if has_key(args, 'forced_language')
    let ft = args['forced_language']
    let langs = s:fts_2_langs(flavour, {'fts': [ft]}, options)
    let options += ['--language-force='.langs[0]]
  elseif !exists('langs')
    let langs = s:fts_2_langs(flavour, args, options)
  endif

  " # Files to index...
  let last_options = []
  if     get(args, 'recursive_or_all', 0)
    let last_options += [flavour._recursive_or_all()]
  else
    " TODO: Reject indexation of files with a language unsupported by ctags?

    let file2index = get(args, 'analyse_file', '')
    if !empty(file2index)
      " The file mays be a temporary file generated on the fly. The ft
      " is then the forced_language
      call lh#assert#value(args).has_key('forced_language', "When using lh-tags 'analyse_file' option, 'forced_language' is expected to be set")
      call lh#assert#value(l:).has_key('ft') " should be set in 'forced_language' case
      let args.fts = [ft]
      let last_options += [shellescape(file2index)]
    else
      let file2index = get(args, 'index_file', '')
      if !empty(file2index)
        " Expects the file to be an edited buffer
        if bufnr(file2index) >= 0
          let last_options += ['--append']
          let ft = getbufvar(file2index, '&ft')
          let args.fts = [ft]
        elseif has_key(args, 'fts')
          " filetypes already forced
          let last_options += ['--append']
        else
          call lh#assert#unexpected("lh-tags 'index_file' option is expected to be used on files loaded in a buffer")
          " this is probably a temporary file with ft = &ft
        endif
        let last_options += [shellescape(file2index)]
        " let langs = [get(flavour._ft_lang_map, ft, '')]
      endif
    endif

  endif

  " # Given the languages of the current project, generate the "kinds"
  " option
  call s:kinds_2_options(flavour, langs, args, options)

  " # Regarding --extra, it becomes extras with a latter version of uctags
  " -> always +q
  let options += [flavour._extras_flag.'=+q']

  " # Fields
  call s:fields_2_options(flavour, langs, args, options)

  " # --langmap/--map
  let langmaps = map(copy(langs), "[v:val, lh#option#get('tags_options.langmap.'.v:val, '', 'wbpg')]")
  call s:Verbose("langmaps: %1", langmaps)
  call filter(langmaps, '!empty(v:val[1])')
  let options += map(langmaps, 'printf(flavour._langmap_opt_format, v:val[0], v:val[1])')

  " # --exclude
  if empty(get(l:, 'file2index', ''))
    " If the file to index is explicitely specified => no need to
    " --exclude patterns
    " TODO: reject a file that matches any "--exclude" pattern
    let excludes = lh#option#get('tags_options.excludes', [], 'wbpg')
    let options += map(copy(excludes), '"--exclude=".v:val')
  endif

  " # Other options
  " TODO: Need to pick various options (kind, langmap, fields, extra...) in various places (b:, p:, g:) and assemble back something
  let options += [lh#option#get('tags_options.'.get(args, 'ft', &ft).'.flags', '')]
  let options += [lh#option#get('tags_options.flags', '', 'wbpg')]

  " # Destination file
  let options += ['-f', get(self, '_system_db_file', self._db_file)]
  " File/dir to index...
  let options += last_options

  " Remove empty options
  call filter(options, '!empty(v:val)')

  " Leave the join to system/job call
  return cmd_line + options
endfunction

function! s:run_on_all_files(FinishedCb, args) dict abort " {{{3
  let db_file     = self.db_file()
  let src_dirname = self.src_dirname()

  let args      = extend(a:args, {'recursive_or_all': 1}, 'force')
  let cmd_line  = lh#os#sys_cd(src_dirname)
  let cmd_line .= ' && '.join(self.cmd_line(args), ' ')
  " TODO: add function to request project name
  let msg = 'ctags '.
        \ lh#option#get('BTW_project_config._.name', fnamemodify(src_dirname, ':p:h:t'))
  return lh#tags#system#get_runner('async').run(
        \  cmd_line
        \, msg
        \, lh#partial#make(a:FinishedCb, [db_file, 'complete', ' (triggered by complete update request)'])
        \, lh#partial#make('delete', [db_file])
        \ )
endfunction

function! s:run_update_file(FinishedCb, args) dict abort " {{{3
  " Work on the current file -> &ft, expand('%')
  if ! lh#tags#_is_ft_indexed(&ft) " redundant check
    return
  endif
  let db_file        = self.db_file()
  let src_dirname    = self.src_dirname()
  let source_name    = lh#path#relative_to(src_dirname, expand('%:p'))
  " lh#path#relative_to() expects to work on dirname => it'll return a dirname
  let source_name    = substitute(source_name, '[/\\]$', '', '')

  let args      = extend(a:args, {'index_file': source_name}, 'force')
  let cmd_line  = lh#os#sys_cd(src_dirname)
  let cmd_line .= ' && ' . join(self.cmd_line(args), ' ')
  let msg = 'ctags '.expand('%:t')
  return lh#tags#system#get_runner('async').run(
          \ cmd_line,
          \ msg,
          \ lh#partial#make(a:FinishedCb, [db_file, 'save', ' (triggered by '.source_name.' modification)']),
          \ lh#partial#make(s:function('PurgeFileReferences'), [db_file, source_name])
          \ )
endfunction

"------------------------------------------------------------------------
function! s:run_update_modified_file(FinishedCb, args) dict abort " {{{3
  " Work on the current file -> &ft, expand('%')
  if ! lh#tags#_is_ft_indexed(&ft) " redundant check
    return
  endif
  let db_file     = self.db_file()
  let temp_tags   = tempname()

  " save the unsaved contents of the current file
  let src_dirname = self.src_dirname()
  let source_name = lh#path#relative_to(src_dirname, expand('%:p'))
  " lh#path#relative_to() expects to work on dirname => it'll return a dirname
  let source_name = substitute(source_name, '[/\\]$', '', '')
  let temp_name   = tempname()
  call writefile(getline(1, '$'), temp_name, 'b')

  let args      = extend(a:args, {'index_file': temp_name, 'fts': [&ft], 'forced_language': &ft}, 'force')
  let cmd_line  = lh#os#sys_cd(src_dirname)
  let cmd_line .= ' && ' . join(self.cmd_line(args), ' ')
  let msg = 'ctags '.expand('%:t')
  return lh#tags#system#get_runner('async').run(
          \ cmd_line,
          \ msg,
          \ lh#partial#make(s:function('remove_and_conclude'), [lh#partial#make(a:FinishedCb, [db_file, 'modified' , ' (triggered manually on modified '.source_name.')']), temp_name, source_name, temp_tags, db_file]),
          \ lh#partial#make(s:function('PurgeFileReferences'), [db_file, source_name])
          \ )

  " TODO: in case of failure, clean as well!
endfunction

function! s:taglist(pat) dict abort " {{{3
  let db_file = self.db_file()
  try
    " TODO: check local value & co
    let tags_save = &tags
    let &tags = db_file
    " This works only with ctags based DB...
    let lTags = taglist(a:pat)
  finally
    let &tags = tags_save
    if s:verbose < 2
      call delete(db_file)
    else
      let b = bufwinnr('%')
      call lh#buffer#jump(db_file, "sp")
      exe b.'wincmd w'
    endif
  endtry
  call s:EvalLines(lTags)
  call sort(lTags, function('lh#tags#indexers#interface#_sort_lines'))
  return lTags
endfunction

"------------------------------------------------------------------------
" ## Internal functions {{{1
" Purge all references to {source_name} in the tags file {{{2
function! s:PurgeFileReferences(ctags_pathname, source_name) abort
  call s:Verbose('Purge `%1` references from `%2`', a:source_name, a:ctags_pathname)
  if filereadable(a:ctags_pathname)
    let pattern = "\t".lh#path#to_regex(a:source_name)."\t"
    let tags = readfile(a:ctags_pathname)
    call filter(tags, 'v:val !~ pattern')
    call writefile(tags, a:ctags_pathname, "b")
  endif
endfunction

function! s:remove_and_conclude(FinishedCb, temp_name, source_name, temp_db, db_file,...) abort " {{{2
  let cmd_line = 'sed "s#\t'.a:temp_name.'\t#\t'.a:source_name.'\t#" '.shellescape(a:db_file).' >> '.shellescape(a:temp_db)
        \ . ' && mv -f '.shellescape(a:temp_db).' '.shellescape(a:db_file)
  call lh#tags#_System(cmd_line)
  call delete(a:temp_name)
  call delete(a:temp_db)
  return call('lh#partial#execute', [a:FinishedCb] + a:000)
endfunction

"------------------------------------------------------------------------
" s:EvalLines(list) {{{2
function! s:EvalLines(list) abort
  for t in a:list
    if !has_key(t, 'line') " sometimes, VimL declarations are badly understood
      let fields = split(t.cmd)
      for field in fields
        if field =~ '\v^\k+:'
          let [all, key, value; rest ] = matchlist(field, '\v^(\k+):(.*)')
          let t[key] = value
        elseif len(field) == 1
          let t.kind = field
        elseif field =~ '/.*/";'
          let t.cmd = field
        endif
      endfor
      let t.file = fields[0]
    endif
    " and do evaluate the line eventually
    let t.line = eval(t.line)
    unlet t.filename
  endfor
endfunction

" }}}1
"------------------------------------------------------------------------
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
