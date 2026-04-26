" Public entry points for gb.vim.

let s:save_cpo = &cpo
set cpo&vim

function! gb#browse(input) abort
  let l:input = empty(a:input) ? input('GitHub repo: ', '', 'customlist,gb#completion#browse') : a:input
  let l:parsed = gb#path#parse_input(l:input)
  let l:resolved = gb#cache#resolve_ref(l:parsed)
  call gb#cache#ensure_tree(l:resolved)
  let l:entry = gb#cache#tree_entry(l:resolved)
  if empty(l:entry)
    throw 'Github Browser: path not found: ' . gb#path#canonical(l:resolved)
  endif
  if get(l:entry, 'type', '') ==# 'tree'
    call gb#browser#open(l:resolved)
  else
    let l:parent = copy(l:resolved)
    let l:parent.path = gb#path#parent(l:resolved.path)
    call gb#browser#open(l:parent)
    call gb#browser#open_file(l:resolved)
  endif
endfunction

function! gb#open(path) abort
  let l:parsed = gb#path#parse_input(a:path)
  let l:resolved = gb#cache#resolve_ref(l:parsed)
  let l:entry = gb#cache#tree_entry(l:resolved)
  if empty(l:entry)
    throw 'Github Browser: path not found: ' . gb#path#canonical(l:resolved)
  endif
  if get(l:entry, 'type', '') ==# 'tree'
    call gb#browser#open(l:resolved)
  else
    execute 'edit ' . fnameescape(gb#path#canonical(l:resolved))
  endif
endfunction

function! gb#read(path) abort
  let l:parsed = gb#path#parse_input(a:path)
  let l:resolved = gb#cache#resolve_ref(l:parsed)
  let l:entry = gb#cache#tree_entry(l:resolved)
  if empty(l:entry)
    throw 'Github Browser: path not found: ' . a:path
  endif
  if get(l:entry, 'type', '') ==# 'tree'
    call gb#browser#render(l:resolved)
    return
  endif

  let l:content = gb#cache#file_content(l:resolved)
  setlocal modifiable noreadonly
  silent %delete _
  if type(l:content) == v:t_list
    call setline(1, l:content)
  else
    call setline(1, split(l:content, "\n", 1))
    if l:content =~# "\n$"
      silent $delete _
    endif
  endif
  let b:gb_path = l:resolved
  let b:gb_entry = l:entry
  let &l:statusline = '%f %r%m%=%{get(b:, "gb_repo", "")}'
  let b:gb_repo = l:resolved.owner . '/' . l:resolved.repo . '@' . l:resolved.ref
  setlocal readonly nomodifiable noswapfile
  setlocal buftype=
  setlocal bufhidden=hide
  setlocal nomodified
  let &l:filetype = gb#path#filetype(l:resolved.path)

  if has_key(l:resolved, 'line_start') && l:resolved.line_start > 0
    execute l:resolved.line_start
    normal! zz
  else
    call cursor(1, 1)
    normal! zt
  endif
endfunction

function! gb#refresh() abort
  let l:parsed = gb#current_path()
  if empty(l:parsed)
    throw 'Github Browser: not in a Github Browser buffer'
  endif
  let l:resolved = gb#cache#resolve_ref(l:parsed)
  call gb#cache#clear_repo(l:resolved)
  if &filetype ==# 'gb-browser'
    call gb#browser#render(l:resolved)
  else
    edit!
  endif
endfunction

function! gb#copy_url(line1, line2, range_given) abort
  let l:path = gb#current_path()
  if empty(l:path)
    throw 'Github Browser: not in a Github Browser buffer'
  endif

  if &filetype ==# 'gb-browser'
    let l:entry_path = gb#browser#entry_at_cursor()
    if !empty(l:entry_path)
      let l:path = l:entry_path
    endif
    let l:url = gb#path#github_url(l:path, 0, 0)
  else
    let l:start = a:range_given ? a:line1 : line('.')
    let l:end = a:range_given ? a:line2 : line('.')
    let l:url = gb#path#github_url(l:path, l:start, l:end)
  endif

  try
    call setreg('+', l:url)
  catch
  endtry
  call setreg('"', l:url)
  echo 'Copied: ' . l:url
endfunction

function! gb#clear_cache() abort
  call gb#cache#clear_all()
  echo 'Github Browser: cache cleared'
endfunction

function! gb#clone(...) abort
  let l:parsed = gb#current_path()
  if empty(l:parsed)
    throw 'Github Browser: not in a Github Browser buffer'
  endif
  let l:dest = a:0 ? a:1 : input('Clone destination path: ', '', 'file')
  let l:dest = trim(l:dest)
  if empty(l:dest)
    throw 'Github Browser: clone destination path is required'
  endif
  if !executable('git')
    throw 'Github Browser: git executable not found'
  endif

  let l:repo = l:parsed.owner . '/' . l:parsed.repo
  let l:url = 'https://github.com/' . l:repo . '.git'
  let l:cmd = 'git clone ' . shellescape(l:url) . ' ' . shellescape(l:dest) . ' 2>&1'
  echo 'Github Browser: cloning ' . l:repo . ' to ' . l:dest
  let l:out = systemlist(l:cmd)
  if v:shell_error != 0
    throw 'Github Browser: git clone failed: ' . join(l:out, "\n")
  endif
  echo 'Github Browser: cloned ' . l:repo . ' to ' . l:dest
endfunction

function! gb#readonly_error() abort
  throw 'Github Browser: cannot save this buffer because the file is not present locally. Your changes remain in the buffer; clone the repository or save to a local path.'
endfunction

function! gb#current_path() abort
  if exists('b:gb_path')
    return copy(b:gb_path)
  endif
  if expand('%') =~# '^github://'
    return gb#path#parse_input(expand('%'))
  endif
  return {}
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
