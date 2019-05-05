"=============================================================================
" File:          delphi.vim
" Author:        Mattia72 
" Description:   plugin definitions
" Created:       16.03.2019
" Project Repo:  https://github.com/Mattia72/delphi
" License:       MIT license  {{{
"   Permission is hereby granted, free of charge, to any person obtaining
"   a copy of this software and associated documentation files (the
"   "Software"), to deal in the Software without restriction, including
"   without limitation the rights to use, copy, modify, merge, publish,
"   distribute, sublicense, and/or sell copies of the Software, and to
"   permit persons to whom the Software is furnished to do so, subject to
"   the following conditions:
"
"   The above copyright notice and this permission notice shall be included
"   in all copies or substantial portions of the Software.
"
"   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"   CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"   SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

scriptencoding utf-8

" Preprocessing
if exists('g:loaded_vim_delphi')
  "finish
elseif v:version < 700
  echoerr 'vim-delphi does not work this version of Vim "' . v:version . '".'
  finish
endif

let g:loaded_vim_delphi = 1

let s:save_cpo = &cpo
set cpo&vim

" ----------------------
" Global options 
" ----------------------

set mouse=a     "Enables mouse click

let delphi_space_errors = 1
let delphi_leading_space_error = 1
"let  delphi_leading_tab_error = 1
let delphi_trailing_space_error = 1
let delphi_highlight_function_parameters = 1

let g:delphi_build_config = 'Debug'

" ----------------------
" Functions
" ----------------------

function! g:delphi#SwitchPasOrDfm()
  if (expand ("%:e") == "pas")
    find %:t:r.dfm
  else
    find %:t:r.pas
  endif
endfunction

function! g:delphi#HighlightMsBuildOutput()
	let qf_cmd = getqflist({'title' : 1})['title']
	if (qf_cmd =~ 'rsvars\" && msbuild')
    "echom "Delphi msbuild finished. ".a:force_copen
    "if a:force_copen == 1
      "copen 
    "endif
    
    "http://docwiki.embarcadero.com/RADStudio/Rio/en/Error_and_Warning_Messages_(Delphi)
    syn match qfInfo "^||.*" 
    syn match qfErrorMsg " \zs\w\+ [EF]\d\{4}\ze:" 
    syn match qfErrorMsg " \zsLinker error\ze:" 
    syn match qfWarningMsg " \zs\w\+ [WH]\d\{4}\ze:"
    hi def link qfInfo Delimiter
    hi def link qfErrorMsg ErrorMsg
    hi def link qfWarningMsg WarningMsg 
  endif
endfunction

function! g:delphi#SetProjectSearchPath()
  if exists('g:delphi_project_path')
    " don't worry, nothing will be added twice :)
    execute 'set path+='.escape(g:delphi_project_path,' \|')
  endif
endfunction

function! g:delphi#FindProject(...)
  let active_file_dir = expand('%:p:h')
  let project_file = ''
  if a:0 != 0 && !empty(a:1)
    let project_name =  a:1
    redraw | echom 'Search '.project_name.' in path '.&path
    " find file in path 
    " set path +=...
    call delphi#SetProjectSearchPath()
    " faster if we are in the dir
    let project_file = findfile(project_name)
  else
    let cwd_orig = getcwd()
    let project_name = '*.dproj'
    while getcwd() =~ '^\[A-Z\]:\\\\$'
      redraw | echom 'Search downwards in '.getcwd()
      " find downwards 
      let project_file = globpath('.', "*.dproj") 
      if !empty(project_file) | break | else | chdir .. | endif
    endwhile
    execute 'chdir '.cwd_orig
  endif
  redraw
  if !empty(project_file) | return project_file | else | return 0 | endif
endfunction

function! g:delphi#SearchAndSaveRecentProjectFullPath(project_name)
  let g:delphi_recent_project = fnamemodify(findfile(a:project_name),':p')
endfunction

function! g:delphi#SetRecentProject(...)
  let g:delphi_recent_project = ''
  let project_name = ''

  if a:0 != 0 && !empty(a:1)
    let project_name = a:1
  else
    call inputsave()
    let project_name = input('Save project for later use (*.dproj): ', '', 'file_in_path') 
    call inputrestore()
  endif
  call delphi#SetProjectSearchPath()
  call delphi#SearchAndSaveRecentProjectFullPath(project_name)

  if empty(g:delphi_recent_project)
	  echohl ErrorMsg | redraw | echom 'Can''t find project "'.project_name.'". Set path or g:delphi_project_path and try again!' | echohl None
	  unlet g:delphi_recent_project
  endif
  redraw
endfunction

function! g:delphi#FindAndMake(...)
  if a:0 != 0 && !empty(a:1)
    let project_name =  a:1
    let project_file = delphi#FindProject(project_name)
  else
    let project_name = '*.dproj'
    let project_file = delphi#FindProject()
  endif
  "echom 'FindAndMake args: '.a:0.' "'.project_name.'" found: '.project_file
  if !empty(project_file) 
	  echohl ModeMsg | echo 'Make '.project_file | echohl None

    execute 'make! /p:config='.g:delphi_build_config.' '.project_file 
    "if len(getqflist()) > 0
      "call delphi#HighlightMsBuildOutput(1)
    "endif
  else  
	  echohl ErrorMsg | redraw | echom 'Can''t find project "'.project_name.'"' | echohl None
  endif
endfunction

function! g:delphi#SetRecentProjectAndMake(...)
  if a:0 != 0 && !empty(a:1)
    "echom 'set recent '.a:1
    call delphi#SetRecentProject(a:1) 
    "echom 'recent '.g:delphi_recent_project
  else
    if !exists('g:delphi_recent_project') || !filereadable(g:delphi_recent_project)
      call delphi#SetRecentProject() 
    endif                    
  endif

  if exists('g:delphi_recent_project') && filereadable(g:delphi_recent_project)
    call delphi#FindAndMake(g:delphi_recent_project)
  else
		echohl ErrorMsg | redraw | echom 'Project not found or g:delphi_recent_project is not defined properly.' | echohl None
  endif
endfunction

function! g:delphi#SetBuildConfig(config)
  if a:0 != 0 && !empty(a:1)
    let g:delphi_build_config = a:config
  endif
	echohl ModeMsg | echo 'Build config: '.g:delphi_build_config | echohl None
endfunction

function! g:delphi#SetQuickFixWindowProperties()
  set nocursorcolumn cursorline
  " highlight errors in reopened qf window
  call delphi#HighlightMsBuildOutput()
endfunction

"function! g:delphi#MakePostActions(force_copen)
  "let qf_cmd = getqflist({'title' : 1})['title']
  "if (qf_cmd =~ 'rsvars\" && msbuild')
    "echom "Delphi make post action. copen? ".a:force_copen
    "call delphi#HighlightMsBuildOutput(a:force_copen)
  "endif            
"endfunction

" ----------------------
" Autocommands
" ----------------------

augroup delphi_vim_global_command_group
  autocmd!
  autocmd FileType qf call delphi#SetQuickFixWindowProperties() 
  "autocmd QuickFixCmdPost make call delphi#MakePostActions(1) 
  "autocmd QuickFixCmdPost make echom "QFPost" | call delphi#MakePostActions(1) 
  " close with q or esc
  autocmd FileType qf if mapcheck('<esc>', 'n') ==# '' | nnoremap <buffer><silent> <esc> :cclose<bar>lclose<CR> | endif
  autocmd FileType qf nnoremap <buffer><silent> q :cclose<bar>lclose<CR>
  autocmd QuickFixCmdPost * copen 8 | wincmd J

  autocmd FileType delphi nnoremap <buffer> <F7> :wa <bar> call delphi#SetRecentProjectAndMake() <bar> cwindow<CR>
  "change trailing spaces to tabs
  autocmd FileType delphi vnoremap <buffer> tt :<C-U>silent! :retab!<CR>
  autocmd FileType delphi command! -nargs=0 DelphiSwitchToDfm call delphi#SwitchPasOrDfm()
  autocmd FileType delphi command! -nargs=0 DelphiSwitchToPas call delphi#SwitchPasOrDfm()
augroup END

" ----------------------
" Commands
" ----------------------
 
command! -nargs=* -complete=file_in_path DelphiMakeRecent call delphi#SetRecentProjectAndMake(<f-args>)
command! -nargs=* -complete=file_in_path DelphiMake call delphi#FindAndMake(<q-args>)
command! -nargs=? DelphiBuildConfig call delphi#SetBuildConfig(<q-args>)

" ----------------------
" Mappings
" ----------------------

" select inside a begin-end block with vif or vaf
vnoremap af :<C-U>silent! normal! [zV]z<CR>
vnoremap if :<C-U>silent! normal! [zjV]zk<CR>
omap af :normal Vaf<CR>
omap if :normal Vif<CR>

"FIXME read tabularize.doc for extension
if exists(':Tabularize') " Align selected assignes in nice columns with plugin
  vnoremap <leader>t= :Tabularize /:=<CR>
  vnoremap <leader>t: :Tabularize /:<CR>
endif

if exists(':RainbowToggle')
  let delphi_rainbow_conf = {
	      \	'separately': {
	      \		'delphi': {
	      \			'parentheses': ['start=/(/ end=/)/', 'start=/\[/ end=/\]/', 'start=/begin/ end=/end/'],
	      \		},
	      \	}
	      \}
  if exists('g:rainbow_conf')
	  call extend(g:rainbow_conf, delphi_rainbow_conf)
	else
	  let g:rainbow_conf = delphi_rainbow_conf
	endif
endif

" highlight selcted word
nnoremap <silent> <2-LeftMouse> :let @/='\V\<'.escape(expand('<cword>'), '\').'\>'<cr>:set hls<cr>

let &cpo = s:save_cpo
unlet s:save_cpo
