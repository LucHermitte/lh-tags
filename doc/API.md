# lh-tags API

## Misc/entry points

### `lh#tags#func_kind(ft)`

Returns the list of _kind_ characters used in
[`taglist()`](http://vimhelp.appspot.com/eval.txt.html#taglist%28%29) to store
functions for a given filetype.

Shortcut to `get_kind_flags('function')` on the flavour of the current indexer.

### `lh#tags#_is_ft_indexed(ft)`

Tells whether the specified filetype is explcitely requested to be indexed.

### `lh#tags#add_indexed_ft(ft)`
Registers the given filetype to be indexed

### `lh#tags#set_lang_map(ft, exts)`

## Indexers

### `lh#tags#indexer#ctags#make([args])`

### `indexer.update_tags_option()`
### `indexer.set_db_file()`
### `indexer.db_file()`
### `indexer.db_filename()`
### `indexer.source_dirname()`
### `indexer.executable()`
### `indexer.set_executable()`
### `indexer.fts_2_langs()`
### `indexer.kinds_2_options()`
### `indexer.get_enabled()`
### `indexer.get_field_id()`
### `indexer.fields_2_options()`
### `indexer.cmd_line()`
### `indexer.run_on_all_files()`
### `indexer.run_update_file'()`
### `indexer.run_update_modified_file()`

## Ctags flavours

