" ---------- Plugins ---------- "

call plug#begin('~/.config/nvim/plugged')

" Theme
Plug 'crusoexia/vim-monokai'
Plug 'dracula/vim', { 'as': 'dracula' }

" Interface
Plug 'airblade/vim-gitgutter'
Plug 'scrooloose/nerdtree'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" Language
Plug 'pangloss/vim-javascript'
Plug 'crusoexia/vim-javascript-lib'
Plug 'cespare/vim-toml', { 'branch': 'main' }

" Completion
Plug 'townk/vim-autoclose'

call plug#end()

" ---------- Settings ---------- "

" Set the Airline theme
let g:airline_theme='tomorrow'

" Set encoding to UTF-8
set encoding=UTF-8

" Enable syntax highlighting
syntax on

" Use better colors
set termguicolors

" Use the Dracula colorscheme
colorscheme dracula
set t_Co=256
autocmd ColorScheme * highlight Normal ctermbg=NONE guibg=NONE
set background=dark

" Set tab spacing and auto indetation
set tabstop=8 softtabstop=0 expandtab shiftwidth=4 smartindent

" Use line numbers (with relative numbers)
set relativenumber
set number
set numberwidth=4

" Allows signs to be displayed in the number column
" set signcolumn=number

" Disable swap files and backups
set noswapfile
set nobackup

" Set the backspace behavior
set backspace=indent,eol,start

" Allow mouse scrolling
set mouse=a

" Highlights a matched text pattern while searching
set incsearch
set nohlsearch

" Open splits intuitively
set splitbelow
set splitright

" Navigate buffers without losing unsaved work
set hidden

" Enable case-insensitive search (unless capital letters are used)
set ignorecase
set smartcase

" Always show status line
set laststatus=2

" Save undo history

set undofile

" Autohighlight all SSH config files
au BufNewFile,BufRead ~/.ssh/**/config set ft=sshconfig

" ---------- Mappings ---------- "

" Set leader key to space
let mapleader = ' '

" Leader + 'ev' to edit the .vimrc file
nmap <Leader>ev :tabedit ~/.config/nvim/init.vim<cr>

" Leader + 'ez' to edit the .zshrc file
nmap <Leader>ez :tabedit ~/.zshrc<cr>

" Leader + 'pi' to run :PlugInstall
nmap <Leader>pi :PlugInstall<cr>

" Leader + 'pd' to run :PlugUpdate
nmap <Leader>pd :PlugUpdate<cr>

" Leader + 'pg' to run :PlugUpgrade
nmap <Leader>pg :PlugUpgrade<cr>
