# lh-tags v2.0.0: a ctags wrapper for Vim

## Introduction

lh-tags is a ctags wrapper plugin for Vim.

This plugin has two features:
 * The generation of `tags` files is simplified,
 * and tag selection is simplified (the support for overloads (when
   _overloading_ is supported) is more ergonomic than what `:tselect` permits)

## Features

### Tags generation
 * Is portable: the plugin is regularly used on nixes, windows (with or without
   cygwin, and with `'shellslash'` on).
 * Is incremental: when a file under the watch of lh-tags is modified, only
   this file is parsed -- its previous information is deleted from the current
   `tags` file.
 * Can be run on the whole project, when needed
 * Is, of course, [parametrisable](#options).
 * Can be run asynchronously (this is the default starting from Vim 7.4-1980).
   When this happens, [airline](https://github.com/vim-airline/vim-airline)
   will display information about the background jobs.
 * Can be done on a third-party project freshly cloned/checked out without a
   need to define any configuration file for 
   [local_vimrc](http://github.com/LucHermitte/local_vimrc).
 * Doesn't have external dependencies other than `ctags` and `cd`.
   BTW, I highly recommend [universal ctags](http://github.com/universal-ctags/ctags)
   over exhuberant ctags.
 * Is project friendly: i.e. multiple projects can be opened simultaneously in
   a vim session, and we can run `ctags` on each of them with different
   specialized options to produced dedicaded tag files.

### Tags selection
 * Presents all tags that match the selected text (`META-W-META-DOWN`), or the
   pattern used (`:LHTags`).
 * Can hide, or show, functions signatures (on `s`).
 * Permits to sort the results by `K`ind, `N`ame, or `F`ilename.
 * Can filter the results on any (ctags) field (_kind_, _name_, _filename_,
   _signature_, _namespace_, ...)
 * The selected tag can be jumped to in the current window (`CR`,
   _double-click_), or in a split window (`o`) -- the tags stack is updated
   along the way.

![LHTags and filter demo](doc/screencast-LHTags.gif ":LHTags and filter demo")

## Usage

In order to use lh-tags, I highly recommend to use a plugin like
[local_vimrc](http://github.com/LucHermitte/local_vimrc).

In the buffer local section, you'll have to:
 * adjust `(bg):tags_options.{ft}.flags` if the default values don't suit you
   -- I used to add exclusion lists in my projects.
 * to be sure where the root directory of the source files is:
   * either set `b:tags_dirname`, or `b:project_sources_dir`, or
     `b:BTW_project_config._.paths.sources` to the project root directory --
     when my projects are compiled with CMake+whatever I use the variables
     from CMake encapsulation of
     [BuildToolsWrapper](http://github.com/LucHermitte/vim-build-tools-wrapper)
     to set `b:tags_dirname`.
   * or be sure there is a `.git/` or a `.svn/` subdirectory in the root
     directory of the source code.

For instance, a typical `_vimrc_local.vim` file will contain:
```vim
" Local vimrc variable for source dir
let b:project_sources_dir = g:FooBarProject_config.paths.sources
" or
LetIfUndef b:BTW_project_config._ = g:FooBarProject_config
...
" ======================[ tags generation {{{2
" Be sure tags are automatically updated on the current file 
LetIfUndef b:tags_options.no_auto 0
" Declare the indexed filetypes
call lh#tags#add_indexed_ft('c', 'cpp')
" Update Vim &tags option w/ the tag file produced for the current project
call lh#tags#update_tagfiles() " uses b:project_sources_dir/BTW_project_config
" Register ITK/OTB extensions as C++ extensions (universal ctags!)
call lh#tags#set_lang_map('cpp', '+.txx')
```

Then, you'll have to generate the `tags` database once (`<C-X>ta`), then you
can enjoy lh-tag automagic update of the database, and improved tag selection.

## Options

 * `b:tags_dirname` defaults to an empty string for the current directory;
   you'll have to set this option to the root of your project.
   If you leave it unset, it will be set on first tags generation to (in
   order):

   * `b:project_sources_dir`, which is used by some of
     [mu-template](http://github.com/LucHermitte/mu-template) templates ;
   - or `(bg):BTW_project_config._.paths.sources`, which is used by
     [BuildToolsWrapper](http://github.com/LucHermitte/vim-build-tools-wrapper)
     to define project settings
   * or where `.git/` is found in parent directories ;
   * or where `.svn/` is found in parent directories ;
   * or asked to the end-user (previous values are recorded in case several
     files from a same project are opened).
 * `lh#tags#add_indexed_ft()`  
   Manages the filetypes whose files will be indexed. Other files are ignored.
   This sets the local option `b:tags_options.indexed_ft` -- prefer this
   function when using [local_vimrc](http://github.com/LucHermitte/local_vimrc)
   to configure project.
   It's also possible to set the global option `b:tags_options.indexed_ft`
   that'll be used instead. It's meant to be used when no project are defined.
   ```vim
   :call lh#tags#add_indexed_ft('c', 'cpp')
   ```

 * `lh#tags#set_lang_map()`  
   Manages the extensions associated to a filetype. You could directly set
   `b:tags_options.{ft}.flags` to `--langmap=C++:+.txx` or `--map-C++=+.txx`,
   the point is this tool function helps to set the option to the best
   possible value according to the current `ctags` flavour (etags or utags).
   ```vim
   :call lh#tags#set_lang_map('cpp', '+.txx')
   ```

 * `(bg):tags_options.flags` defaults to an empty string; It contains extra
   flags you could pass to `ctags` execution. You'll have to adjust
   these options to your needs.
 * `(bg):tags_options.{ft}.flags` defaults to:
    * c:    `'--c++-kinds=+p --fields=+imaS --extra=+q'`
    * cpp:  `'--c++-kinds=+pf --fields=+imaSft --extra=+q --language-force=C++'`
            `'x{c++.properties}` will also be added when using Universal ctags
    * java: `'--c++-kinds=+acefgimp --fields=+imaSft --extra=+q --language-force=Java'`
    * vim:  `'--fields=+mS --extra=+q'`

   Warning: This was renamed from `(bg):tags_options_{ft}` in version 2.0.0.
 * `(bg):tags_filename` defaults to `'tags'`; in case you want your `tags` file
   to have another name.
 * `(bg):tags_executable` defaults to `ctags`; you should not need to change
   it.
 * `(bg):tags_must_go_recursive` defaults to 1; set it to 0 if you really want
   to not explore subdirectories.
 * `(bg):tags_select` defaults to `'expand('<cword>')'`; this policy says how
   the current word under the cursor is selected by normal mode mapping
   `META-W-META-DOWN`.
 * `(bg):tags_options.no_auto` defaults to 1; set it to 0 if you want to enable the
   automatic incremental update.  
   Warning: this has changed in version 2.0.0; it used to be named
   `(bg):LHT_no_auto`, and it have the opposite default value.
 * `(bg):tags_to_spellfile` defaults to empty string; this option permits to
   add all the tags to Vim spellchecker ignore list.
 * `(bg):tags_options.run_in_bg` ; set to 1 by default, if |+job|s are supported.
   Tells to execute `<Plug>CTagsUpdateCurrent` and `<Plug>CTagsUpdateAll` in
   background (through |+job| feature).  
   This option is best set in your `.vimrc`. If you want to change or toggle
   its value, you'd best use the menu `Project->Tags->Generate` when running
   gvim, or the `:Toggle` command: 

   ```vim
   :Toggle ProjectTagsGenerate
   ```

A typical configuration file for
[local_vimrc](http://github.com/LucHermitte/local_vimrc) will be:

```vim
" #### In _vimrc_local.vim
" spell files
setlocal spellfile=
exe 'setlocal spellfile+='.lh#path#fix(b:project_sources_dir).'/ignore.utf-8.add'
let b:tags_to_spellfile = 'code-symbols.utf-8.add'
exe 'setlocal spellfile+='.lh#path#fix(b:project_sources_dir.'/'.b:tags_to_spellfile)
```

## Mappings and commands

 * The tags for the current file can be explicitly updated with `CTRL-X_tc` --
   this mappings defaults to `<Plug>CtagsUpdateCurrent`
 * All the tags for the current project can be explicitly updated with
   `CTRL-X_ta` -- this mappings defaults to `<Plug>CtagsUpdateAll`
 * Tags matching the current word (or selection) will be presented on
   `META-W-META-DOWN` -- these two mappings default to `<Plug>CtagsSplitOpen`

 * We can also present the tags that match a pattern with `:LHTags` command
   (this command supports auto-completion on tag names)

## To Do

 * Have behaviour similar to the one from the quickfix mode (possibility to
   close and reopen the search window; prev&next moves)
 * Show/hide declarations -- merge declaration and definitions
 * Pluggable filters (that will check the number of parameters, their type, etc)


## Design Choices

## Installation
  * Requirements: Vim 7.+, [lh-vim-lib](http://github.com/LucHermitte/lh-vim-lib) v3.13.1
  * With [vim-addon-manager](https://github.com/MarcWeber/vim-addon-manager), install lh-tags (this is the preferred method because of the dependencies)
```vim
ActivateAddons lh-tags
```
  * or with [vim-flavor](http://github.com/kana/vim-flavor) which also supports
    dependencies
```
flavor 'LucHermitte/lh-tags'
```
  * or you can clone the git repositories
```
git clone git@github.com:LucHermitte/lh-vim-lib.git
git clone git@github.com:LucHermitte/lh-tags.git
```
  * or with Vundle/NeoBundle:
```vim
Bundle 'LucHermitte/lh-vim-lib'
Bundle 'LucHermitte/lh-tags'
```

[![Project Stats](https://www.openhub.net/p/21020/widgets/project_thin_badge.gif)](https://www.openhub.net/p/21020)
