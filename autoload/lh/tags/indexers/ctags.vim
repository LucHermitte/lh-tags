"=============================================================================
" File:         autoload/lh/tags/indexers/ctags.vim             {{{1
" Author:       Luc Hermitte <EMAIL:luc {dot} hermitte {at} gmail {dot} com>
"		<URL:http://github.com/LucHermitte/lh-tags>
" License:      GPLv3 with exceptions
"               <URL:http://github.com/LucHermitte/lh-tags/blob/master/License.md>
" Version:      3.0.0.
let s:k_version = '300'
" Created:      27th Jul 2018
" Last Update:  06th Aug 2018
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
  call lh#object#inject_methods(flavour, s:k_script_name,
        \ '_analyse_kinds', '_analyse_languages', '_recursive_or_all')

  call flavour._analyse_extras()
  call flavour._analyse_fields()
  call flavour._analyse_kinds()
  call flavour._analyse_languages()
  return flavour
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
function! s:extract_kinds(kinds, pattern) abort
  let kinds = map(deepcopy(a:kinds), "filter(v:val, 'v'.':val =~? a:pattern')")
  call filter(kinds, '!empty(v:val)')
  call map(kinds, 'keys(v:val)[0]')
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
  let self._kinds_local    = s:extract_kinds(self._kinds, 'local')
  let self._kinds_proto    = s:extract_kinds(self._kinds, '\vprototype|interface content|subroutine declaration')
  let self._kinds_variable = s:extract_kinds(self._kinds, '\v(local |forward )@<!variable')

  return self
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

  call map(copy(features), 'extend(res[s:feature_id(v:val, letter_idx, name_idx)], {v:val[lang_idx] : {"letter": v:val[letter_idx], "description": v:val[descr_idx], "enabled": (v:val[enabled_idx]=~?"on\\|TRUE")}})')

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
      \ }
" Function: lh#tags#indexers#ctags#make() {{{3
function! lh#tags#indexers#ctags#make() abort
  let res = lh#tags#indexers#interface#make()
  call lh#object#inject_methods(res, s:k_script_name,
        \ 'update_tags_option', 'db_filename',
        \ 'executable', 'set_executable', 'flavour',
        \ 'cmd_line')

  " By default the executable is set w/ "bpg:tags_executable", but it can be
  " overwritten for the current indexer instance.
  let res._executable = lh#ref#bind('bpg:tags_executable')

  " TODO: not to be done in the case of `get_file_tags`
  call res.update_tags_option()
  return res
endfunction

function! s:update_tags_option() dict abort " {{{3
  call self.set_output_file(self.db_dirname() . self.db_filename())
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
endfunction

function! s:flavour() dict abort " {{{3
  return s:get_flavour(self.executable())
endfunction

function! s:fts_2_langs(flavour, args, options) abort " {{{3
  let fts = get(a:args, 'fts', s:k_unset)
  if lh#option#is_unset(fts)
    let fts = lh#option#get('tags_options.indexed_ft')
  endif
  if lh#option#is_set(fts)
    let langs = map(copy(fts), 'get(a:flavour._ft_lang_map, v:val, "")')
    " TODO: warn about filetypes unknown to ctags
    call filter(langs, '!empty(v:val)')
    call add(a:options, '--languages='.join(langs, ','))
  else
    let langs = values(a:flavour._ft_lang_map)
  endif
  return langs
endfunction

function! s:kinds_2_options(flavour, langs, args, options) abort " {{{3
  let kinds = {}
  call map(copy(a:langs), 'extend(kinds, {v:val : []})')
  " first: add the prototypes
  call lh#assert#true(lh#has#vkey())
  call map(kinds, 'has_key(a:flavour._kinds_proto, v:key) ? add(v:val, a:flavour._kinds_proto[v:key]) : v:val')
  " Then analyse some other requirements
  if get(a:args, 'extract_local_variables', 0)
    call map(kinds, 'has_key(a:flavour._kinds_local, v:key) ? add(v:val, a:flavour._kinds_local[v:key]) : v:val')
  endif
  if get(a:args, 'extract_variables', 1)
    " TODO: no need to include the kind if it's not off by default
    call map(kinds, 'has_key(a:flavour._kinds_variable, v:key) ? add(v:val, a:flavour._kinds_variable[v:key]) : v:val')
  endif
  " TODO: add generic way to support other kinds...
  " -> match a pattern ?
  call filter(kinds, '!empty(v:val)')
  call map(kinds, 'add(a:options, printf(a:flavour._kind_opt_format."=+%s", v:key, join(v:val, "")))')
endfunction

function! s:add_matching_fields(flavour, field_names, state) abort " {{{3
  let fields = []
  let field_specs = a:flavour._fields
  " TODO: Add option to not request/inhibit fields when it matches their default ENABLED state.
  call map(a:field_names,
        \   '   has_key(field_specs, "N:".v:val) && (field_specs["N:".v:val].NONE.enabled != a:state) ? add(fields, field_specs["N:".v:val].NONE.letter)'
        \ . ' : has_key(field_specs, "L:".v:val) && (field_specs["L:".v:val].NONE.enabled != a:state) ? add(fields, field_specs["L:".v:val].NONE.letter)'
        \ . ' : v:val')
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
  let pos_fields = s:add_matching_fields(a:flavour, keys(positive_options), 1)
  let neg_fields = s:add_matching_fields(a:flavour, keys(negative_options), 0)
  let fields = []
  if !empty(pos_fields)
    let fields += ['+'] + pos_fields
  endif
  if !empty(neg_fields)
    let fields += ['-'] + neg_fields
  endif
  if !empty(fields)
    call add(a:options, '--fields='.join(fields, ''))
  endif
endfunction

function! s:cmd_line(...) dict abort " {{{3
  " Options:
  " - fts: list
  " - extract_local_variables: bool
  " - field names: bool
  " - tag_file
  let args = get(a:, 1, {})

  " When no field in particular is required through `cmd_line()`
  " arguments, we still force some default values.
  call extend(args, s:k_default_fields, 'keep')

  let cmd_line = [self.executable()]
  let flavour = self.flavour() " ctags flavour: exctag/universal-ctags (many different versions)

  let options = []
  let options += ['--tag-relative=yes']

  " # Files to index...
  if     get(args, 'recursive_or_all', 0)
    let last_options = [flavour._recursive_or_all()]
  else
    let file2index = get(args, 'index_file', '')
    if !empty(file2index)
      let last_options = ['--append', file2index]
      let ft = getbufvar(file2index, '&ft')
      let langs = [get(s:all_lang_map, ft, '')]
    endif
  endif

  " # Forced languages
  if !exists('langs')
    let langs = s:fts_2_langs(flavour, args, options)
  endif

  " # Given the languages of the current project, generate the "kinds"
  " option
  call s:kinds_2_options(flavour, langs, args, options)

  " # Regarding --extra, it becomes extras with a latter version of uctags
  " -> always +q
  let options += [flavour._extras_flag.'=+q']

  " # Fields
  " TODO: support other fields like properties, templates...
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
  " TODO: Need to pick various options (kind, langmap, fields, extra...) in
  " various places (b:, p:, g:) and assemble back something
  let options += [lh#option#get('tags_options.'.get(args, 'ft', &ft).'.flags', '')]
  let options += [lh#option#get('tags_options.flags', '', 'wbpg')]

  " # Destination file
  let options += ['-f', self._db_file]
  " File/dir to index...
  let options += last_options

  " Remove empty options
  call filter(options, '!empty(v:val)')

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
