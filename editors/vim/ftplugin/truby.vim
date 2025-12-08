" Vim filetype plugin for T-Ruby
" Language: T-Ruby (Typed Ruby)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

" Use Ruby settings as base
runtime! ftplugin/ruby.vim

" Set comment format
setlocal commentstring=#\ %s
setlocal comments=:#

" Set indentation (same as Ruby)
setlocal shiftwidth=2
setlocal softtabstop=2
setlocal expandtab

" Set file format options
setlocal formatoptions-=t
setlocal formatoptions+=croql

" Define what constitutes a word
setlocal iskeyword+=!,?

" Set include/define patterns for type definitions
setlocal include=^\\s*\\(require\\|require_relative\\|load\\)
setlocal define=^\\s*\\(def\\|type\\|interface\\|class\\|module\\)

" Folding
setlocal foldmethod=indent
setlocal foldlevel=99

" Compiler settings
if executable('trc')
  setlocal makeprg=trc\ %
  setlocal errorformat=%f:%l:\ %m
endif

" Key mappings for T-Ruby
nnoremap <buffer> <leader>tc :!trc %<CR>
nnoremap <buffer> <leader>td :!trc --decl %<CR>

" Undo settings when filetype changes
let b:undo_ftplugin = "setlocal commentstring< comments< shiftwidth< softtabstop< expandtab< formatoptions< iskeyword< include< define< foldmethod< foldlevel< makeprg< errorformat<"
