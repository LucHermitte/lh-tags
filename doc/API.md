# lh-tags API

Since V3, lh-tags introduces _indexers_. All indexers are meant to provide the
same services. We are in a
[OO/Duck-typed world](https://github.com/LucHermitte/lh-vim-lib/blob/master/doc/OO.md).

[_Indexers_](#indexers)' job is to... index, as transparently as possible for
the end-users.
ctags-indexer provides a few other services in order to fill tag files with
precise information on the code in the current buffer like local-variables,
lines where functions are defined, and so on.
Other indexers are yet to be written.

## Misc/entry points

### `lh#tags#func_kind(ft)`
Returns the list of _kind_ characters used in
[`taglist()`](http://vimhelp.appspot.com/eval.txt.html#taglist%28%29) to store
functions for a given filetype.

Shortcut to `get_kind_flags('function')` on the flavour of the current indexer.

### `lh#tags#_is_ft_indexed(ft)`
Tells whether the specified filetype is explicitly requested to be indexed
with `lh#tags#add_indexed_ft()`

### `lh#tags#add_indexed_ft(fts...)`
Registers the given filetypes to be indexed.

Indexers shall then ignore the files that don't belong to the registered
filetypes. By default, the indexers will try to index all the files they
understand.

### `lh#tags#set_lang_map(ft, exts)`
Indexers like `ctags` index files according to their extension. When we use non
standard extensions (like `.tpp` in C++), we need to tell `ctags` that all
`*.tpp` files are C++ files.

lh-tags provides a unique function to register new extensions to a (Vim-)filetype.

### `lh#tags#session#get(args)`
Returns a tag session.

The session object returned:
- possesses a reference to the indexer used
- possesses the list of tags found
- possesses an internal counter to factorize multiple calls to `ctags`
- can be `finalize()`d

Every time a session is requested, an internal counter is incremented. This
permits to request tags from multiple Vim functions executed together, several
times, and yet have the external `ctags` executable run only once.

It's imperative to always execute `session.finalize()` from a
[`:finally`](http://vimhelp.appspot.com/eval.txt.html#%3afinally) block.
Each call to `#get()` must be balanced with a call to `finalize()`

`args` can contain:
- `firstline`, and `lastline` to restrict the lines on which the analyse is
  performed
- `indexer`, a name, or
  [Funcref](http://vimhelp.appspot.com/eval.txt.html#Funcref), to an indexer
  building function.
- any parameter used by `indexer.cmd_line()` method -- BTW, the following are
  forcefully injected:
  - `forced_language` to `&ft`,
  - `extract_local_variables'` to 1,
  - `end` to 1,
  - `extract_prototypes` to 0.

## Indexers

### Specialized methods common to all indexers
#### `indexer.run_on_all_files(FinishedCallback, args)`
Runs the indexer on all files from a project.

#### `indexer.run_update_file(FinishedCallback, args)`
Runs the indexer to update the tags associated to a file.

#### `indexer.run_update_modified_file(FinishedCallback, args)`
Runs the indexer to update the tags associated to a buffer -- non necessarily
saved.

#### `indexer.has_kind(ft, kind)`
Method specific to `ctags`-like indexers that fill tag file that can accessed
through [`taglist()`](http://vimhelp.appspot.com/eval.txt.html#taglist%28%29).

Tells whether there is a ctags _kind_ associated to the specified pattern.
The `kind_pattern` is expected to be a
[`regular-expression`](http://vimhelp.appspot.com/pattern.txt.html#regular-expression).
The names/patterns officially supported follow current universal-ctags kinds.

#### `indexer.get_kind_flags(ft, kind_pattern)`
Method specific to `ctags`-like indexers that fill tag file that can accessed
through [`taglist()`](http://vimhelp.appspot.com/eval.txt.html#taglist%28%29).

Returns the _kind_ letter that stores some information. The information is
identified through the `kind_pattern` which is expected to be a
[`regular-expression`](http://vimhelp.appspot.com/pattern.txt.html#regular-expression).
The names/patterns officially supported follow current universal-ctags kinds.

#### `indexer.analyse_buffer(options)`
Returns tags associated to the current buffer. The tags extraction can be
restricted to lines between `options.firstline` and `options.lastline` if
specified.

This is internally used by `lh#tags#session#*()` functions.

### Internal methods common to all indexers
#### `indexer.set_db_file()`
Changes the (tag) database filename.

`ctags` indexer sets it by default to `indexer.src_dirname() .
indexer.db_filename()` in `update_tags_option()` method.

#### `indexer.db_file()`
Getter to DB filename property.

#### `indexer.src_dirname()`
Returns the root directory where the sources are.

See the option
[`(bpg):paths.tags.src_dir`](../README.md#dirname-to-source-code-bpgpathstagssrc_dir).

### `indexer._fix_cygwin_paths()`
Some paths need to be translated when running Cygwin programs from Windows
native flavour of Vim. This method takes care of that.

### Methods specific to ctags indexer
#### `lh#tags#indexer#ctags#make([args])`
This is the factory function that builds new `ctags` indexers.

#### `indexer.cmd_line()`
Builds the command line to execute according to the various options passed.

#### `indexer.update_tags_option()`
Sets the filename of the tag database to `indexer.src_dirname() .
indexer.db_filename()`, and updates the
[`'tags'`](http://vimhelp.appspot.com/options.txt.html#%27tags%27) options
accordingly.

#### `indexer.db_filename()`
Getter to the name of the tag file to use. Wraps access to
`(bpg):tags_filename` option.

#### `indexer.executable()`
Getter that wraps access to `(bpg):tags_executable` option.

#### `indexer.set_executable()`
Method to locally override the tag executable, if need be, in the restricted
context of the indexer.

#### `indexer.flavour()`

Internally the ctags indexer relies on another object to obtain precise
information of what the exact flavour of ctags
(exhuberant-ctags/universal-ctags) can support.
