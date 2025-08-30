" ENABLE ALL VIM FEATURES
set nocompatible

" FORMATTING
set tabstop=4
set shiftwidth=4
set expandtab
set smarttab
set textwidth=0
set guifont=Monaco:h14

" CONVENIENCE
set number                      " add line numbers
set ruler                       " show ruler
set showcmd                     " show command as they are being typed
set showmatch
set showmode
set hidden                      " allow leaving buffer without saving
set confirm                     " offer to save changes before leaving buffer
set foldenable                  " enable code folding

" SEARCHING
set hlsearch
set incsearch
set ignorecase
set smartcase
match errorMsg /[\t]/           " highlight all tabs

" PROGRAMMING
syntax on                       " enable syntax highlighting
filetype plugin indent on       " guess file type

" THE LOOK
"set bg=dark
colorscheme desert

" MODELINES
"set modeline                   " last lines in document sets vim mode
"set modelines=3                " number lines checked for modelines

" KEY MAPPINGS
"nnoremap <silent> <Space> :silent noh<Bar>echo<CR>  " hit space to clear search highlighting
noremap <silent> <c-l> :nohls<cr><c-l>
noremap <C-P> :!php -l %<CR>    " <CTRL>-P to run PHP parser check
nmap ,ev :tabedit $MYVIMRC<cr>  " edit my .vimrc in a new tab
nmap ,sv :source ~/.vimrc<cr>   " sournce my .vimrc
nmap ,ff :! open -a firefox.app %:p<cr> " open the current file in firefox
nnoremap <space> :
imap jj <esc>

" NO BACKUP
set nobackup                      " Don't make a backup before overwriting a file.
set nowritebackup                 " And again.
set directory=$HOME/.vim/tmp//,.  " Keep swap files in one location

" MISC
set history=100
set undolevels=100
set complete=.,w,b,u,t          " default is .,w,b,u,t,i
set completeopt=menuone,longest
set scrolloff=3                 " keep 3 lines when scrolling
set title                       " show title in console title bar
set backspace=indent,eol,start  " more powerful backspacing
set nostartofline
set visualbell
set cmdheight=2
" set nowrap
set wrap
set linebreak
set linespace=2                 " set space between lines
set wildmenu                    " better command line completion
set wildmode=longest,list
set virtualedit=all
"set wildchar=<Tab>
"set foldmethod=<marker|manual>

" USEFUL STATUS INFO AT BOTTOM OF SCREEN
set laststatus=2                " always show status line
set statusline=\%F%m%r%h%w\ \ \ \ Line:%l/%L[%p%%]\ \ \ \ Col:%c\ \ \ \ Buf:%n\ \ \ \ [%b][0x%B]

" REMOVE RH SCROLLBAR
if has ("gui_running")
  set guioptions-=R "remove right-hand scroll Bar
  set guioptions-=r "remove right-hand scroll Bar
  set guioptions-=l "remove right-hand scroll Bar
  set guioptions-=L "remove right-hand scroll bar
endif

" AUTOMATICALLY CD TO THE DIRECTORY CONTAINING THE CURRENT FILE
if exists('+autochdir')
  set autochdir
else
  autocmd BufEnter * silent! lcd %:p:h:gs/ /\\ /
endif

" HIDE GUI TOOLBAR AND MENUBAR
set guioptions-=T
"set guioptions-=M

" AUTO SAVE SETTINGS WITHOUT HAVING TO RESTART VIM
autocmd bufwritepost .vimrc source ~/.vimrc

"--------------------------
" Plugin-specific Settings
"--------------------------

" ZENCODING
"imap <Left> ,
"let g:user_zen_expandabbr_key = '<C-e>'

" NERD TREE
nmap ,nt :NERDTreeToggle<CR>
let NERDTreeShowHidden=1        " show hidden files too
