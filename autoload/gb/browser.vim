" Directory browser for gb.vim.

let s:save_cpo = &cpo
set cpo&vim

function! gb#browser#open(parsed) abort
  let l:resolved = gb#cache#resolve_ref(a:parsed)
  let l:target_winid = get(b:, 'gb_target_winid', 0)
  if &filetype !=# 'gb-browser'
    let l:target_winid = win_getid()
    execute 'topleft vertical ' . get(g:, 'gb_browser_width', 32) . 'new'
    setlocal winfixwidth
  endif
  execute 'noautocmd edit ' . fnameescape(gb#path#canonical(l:resolved))
  call gb#browser#render(l:resolved, l:target_winid)
endfunction

function! gb#browser#render(parsed, ...) abort
  let l:resolved = gb#cache#resolve_ref(a:parsed)
  let l:target_winid = a:0 ? a:1 : get(b:, 'gb_target_winid', 0)
  let l:children = gb#cache#children(l:resolved)
  let l:repo_line = 'github://' . l:resolved.owner . '/' . l:resolved.repo . '@' . l:resolved.ref . ':' . l:resolved.path
  let l:lines = []
  if get(g:, 'gb_browser_show_help', 1)
    call add(l:lines, '"Quick help"')
    call add(l:lines, '============')
    call add(l:lines, 'Key    Action')
    call add(l:lines, '---    ------')
    call add(l:lines, 'Enter  Open')
    call add(l:lines, '-      Parent')
    call add(l:lines, 'r      Refresh')
    call add(l:lines, 'y      Copy URL')
    call add(l:lines, 'c      Clone')
    call add(l:lines, 'q      Close')
    call add(l:lines, repeat('-', 24))
  endif
  call add(l:lines, l:repo_line)
  call add(l:lines, repeat('-', 24))
  call add(l:lines, '')
  let l:first_child_lnum = 0
  if gb#path#lookup_key(l:resolved.path) !=# ''
    call add(l:lines, '../')
  endif
  for l:child in l:children
    if l:first_child_lnum == 0
      let l:first_child_lnum = len(l:lines) + 1
    endif
    let l:name = l:child.name . (get(l:child.entry, 'type', '') ==# 'tree' ? '/' : '')
    call add(l:lines, l:name)
  endfor

  setlocal modifiable noreadonly
  silent %delete _
  call setline(1, l:lines)
  let b:gb_path = l:resolved
  let b:gb_children = l:children
  let b:gb_target_winid = l:target_winid
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  setlocal filetype=gb-browser
  setlocal readonly nomodifiable nomodified
  if l:first_child_lnum > 0
    call cursor(l:first_child_lnum, 1)
  elseif gb#path#lookup_key(l:resolved.path) !=# ''
    call cursor(len(l:lines), 1)
  else
    call cursor(1, 1)
  endif
  nnoremap <silent><buffer> <CR> :call gb#browser#open_under_cursor()<CR>
  nnoremap <silent><buffer> - :call gb#browser#parent()<CR>
  nnoremap <silent><buffer> r :GBRefresh<CR>
  nnoremap <silent><buffer> y :GBCopyUrl<CR>
  nnoremap <silent><buffer> c :GBClone<CR>
  nnoremap <silent><buffer> q :close<CR>
endfunction

function! gb#browser#open_under_cursor() abort
  let l:path = gb#browser#entry_at_cursor()
  if empty(l:path)
    return
  endif
  let l:entry = gb#cache#tree_entry(l:path)
  if get(l:entry, 'type', '') ==# 'tree'
    call gb#browser#render(l:path)
  else
    call gb#browser#open_file(l:path)
  endif
endfunction

function! gb#browser#open_file(parsed) abort
  let l:browser_winid = win_getid()
  let l:target_winid = get(b:, 'gb_target_winid', 0)
  if !win_gotoid(l:target_winid)
    rightbelow vertical new
    let l:target_winid = win_getid()
    call win_gotoid(l:browser_winid)
    let b:gb_target_winid = l:target_winid
    call win_gotoid(l:target_winid)
  endif
  execute 'edit ' . fnameescape(gb#path#canonical(a:parsed))
  if has_key(a:parsed, 'line_start') && a:parsed.line_start > 0
    execute a:parsed.line_start
    normal! zz
  else
    call cursor(1, 1)
    normal! zt
  endif
  call win_gotoid(l:browser_winid)
endfunction

function! gb#browser#parent() abort
  if !exists('b:gb_path')
    return
  endif
  let l:path = copy(b:gb_path)
  let l:path.path = gb#path#parent(l:path.path)
  call gb#browser#render(l:path)
endfunction

function! gb#browser#entry_at_cursor() abort
  if !exists('b:gb_path')
    return {}
  endif
  let l:line = getline('.')
  if l:line =~# '^github://' || empty(l:line) || l:line ==# '"Quick help"' || l:line =~# '^=\{3,}$' || l:line ==# 'Key    Action' || l:line ==# '---    ------' || l:line =~# '^Enter\s\+Open$' || l:line =~# '^- \+Parent$' || l:line =~# '^r \+Refresh$' || l:line =~# '^y \+Copy URL$' || l:line =~# '^c \+Clone$' || l:line =~# '^q \+Close$' || l:line =~# '^-\{3,}$'
    return {}
  endif
  let l:path = copy(b:gb_path)
  if l:line ==# '../'
    let l:path.path = gb#path#parent(l:path.path)
    return l:path
  endif
  let l:name = substitute(l:line, '/$', '', '')
  let l:path.path = gb#path#join(l:path.path, l:name)
  return l:path
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
