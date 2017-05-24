set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'
" molokai colorscheme
Plugin 'tomasr/molokai'
" added syntax highlighting
Plugin 'tpope/vim-rails'
" never type end again !
Plugin 'tpope/vim-endwise'
" handles closer
Plugin 'tpope/vim-surround'
" json stuf
Plugin 'leshill/vim-json'
call vundle#end()
filetype plugin indent on
" Configuration file for vim
set modelines=0		" CVE-2007-2438

colorscheme molokai
let g:rehash256 = 1

" Normally we use vim-extensions. If you want true vi-compatibility
" remove change the following statements
set backspace=2		" more powerful backspacing

" Don't write backup file if vim is being called by "crontab -e"
au BufWrite /private/tmp/crontab.* set nowritebackup nobackup
" Don't write backup file if vim is being called by "chpass"
au BufWrite /private/etc/pw.* set nowritebackup nobackup

set expandtab
set tabstop=2
set shiftwidth=2
syntax on
set incsearch
set vb
set showmatch
set nu
cmap w!! %!sudo tee > /dev/null %
set title
set smarttab
set showcmd
set incsearch
set wildmenu
set wildmode=longest:full,full
if $TERM == 'xterm-color' && &t_Co == 8
  set t_Co=256
endif
