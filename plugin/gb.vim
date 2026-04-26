" gb.vim - Browse GitHub repositories without cloning.
" Maintainer: generated in this workspace
" License: GPL-3.0-or-later

if exists('g:loaded_gb')
  finish
endif
let g:loaded_gb = 1

if !exists('g:gb_github_token')
  let g:gb_github_token = ''
endif

if !exists('g:gb_use_gh_token')
  let g:gb_use_gh_token = 1
endif

if !exists('g:gb_cache_ttl')
  let g:gb_cache_ttl = 300
endif

if !exists('g:gb_curl_command')
  let g:gb_curl_command = 'curl'
endif

if !exists('g:gb_github_api_url')
  let g:gb_github_api_url = 'https://api.github.com'
endif

if !exists('g:gb_browser_show_hidden')
  let g:gb_browser_show_hidden = 1
endif

if !exists('g:gb_browser_show_help')
  let g:gb_browser_show_help = 1
endif

if !exists('g:gb_browser_width')
  let g:gb_browser_width = 32
endif

command! -nargs=? -complete=customlist,gb#completion#browse GBrowse call gb#browse(<q-args>)
command! -nargs=1 GBOpen call gb#open(<q-args>)
command! -nargs=0 GBRefresh call gb#refresh()
command! -nargs=0 -range GBCopyUrl call gb#copy_url(<line1>, <line2>, <range>)
command! -nargs=0 GBClearCache call gb#clear_cache()
command! -nargs=0 GBClone call gb#clone()

augroup gb
  autocmd!
  autocmd BufReadCmd github://* call gb#read(expand('<amatch>'))
  autocmd FileReadCmd github://* call gb#read(expand('<amatch>'))
  autocmd BufWriteCmd github://* call gb#readonly_error()
augroup END
