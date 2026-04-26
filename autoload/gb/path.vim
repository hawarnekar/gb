" Path parsing and formatting for gb.vim.

let s:save_cpo = &cpo
set cpo&vim

function! gb#path#parse_input(input) abort
  let l:input = trim(a:input)
  let l:parsed = gb#path#parse_canonical(l:input)
  if !empty(l:parsed)
    return l:parsed
  endif

  let l:parsed = gb#path#parse_github_url(l:input)
  if !empty(l:parsed)
    return l:parsed
  endif

  let l:parsed = gb#path#parse_git_remote(l:input)
  if !empty(l:parsed)
    return l:parsed
  endif

  let l:parsed = gb#path#parse_shorthand(l:input)
  if !empty(l:parsed)
    return l:parsed
  endif

  if l:input =~# '^/\?github\.com/'
    return gb#path#parse_github_url('https://' . substitute(l:input, '^/', '', ''))
  endif

  throw 'Github Browser: cannot parse input: ' . a:input
endfunction

function! gb#path#parse_canonical(input) abort
  if a:input !~# '^github://'
    return {}
  endif

  let l:rest = substitute(a:input, '^github://', '', '')
  let l:colon = stridx(l:rest, ':')
  if l:colon < 0
    return {}
  endif

  let l:repo_part = strpart(l:rest, 0, l:colon)
  let l:path = strpart(l:rest, l:colon + 1)
  if empty(l:path)
    let l:path = '/'
  endif
  if l:path[0] !=# '/'
    let l:path = '/' . l:path
  endif

  let l:slash = stridx(l:repo_part, '/')
  if l:slash < 1
    return {}
  endif
  let l:owner = strpart(l:repo_part, 0, l:slash)
  let l:repo_ref = strpart(l:repo_part, l:slash + 1)
  let l:at = stridx(l:repo_ref, '@')
  if l:at >= 0
    let l:repo = strpart(l:repo_ref, 0, l:at)
    let l:ref = strpart(l:repo_ref, l:at + 1)
  else
    let l:repo = l:repo_ref
    let l:ref = ''
  endif

  if empty(l:owner) || empty(l:repo)
    return {}
  endif

  return {'owner': l:owner, 'repo': l:repo, 'ref': l:ref, 'path': gb#path#normalize(l:path)}
endfunction

function! gb#path#parse_github_url(input) abort
  let l:input = substitute(a:input, '#.*$', '', '')
  let l:fragment = matchstr(a:input, '#L\d\+\%(-L\d\+\)\?$')
  let l:line_start = 0
  let l:line_end = 0
  if !empty(l:fragment)
    let l:nums = matchlist(l:fragment, '#L\(\d\+\)\%(-L\(\d\+\)\)\?')
    let l:line_start = str2nr(l:nums[1])
    let l:line_end = empty(l:nums[2]) ? l:line_start : str2nr(l:nums[2])
  endif

  let l:m = matchlist(l:input, '^https://github\.com/\([^/]\+\)/\([^/#. ][^/# ]*\)\%(/\?\)$')
  if !empty(l:m)
    return {'owner': l:m[1], 'repo': substitute(l:m[2], '\.git$', '', ''), 'ref': '', 'path': '/', 'line_start': l:line_start, 'line_end': l:line_end}
  endif

  let l:m = matchlist(l:input, '^https://github\.com/\([^/]\+\)/\([^/# ]\+\)/\(tree\|blob\)/\([^/]\+\)\%(/\(.*\)\)\?$')
  if !empty(l:m)
    let l:path = empty(l:m[5]) ? '/' : '/' . l:m[5]
    return {'owner': l:m[1], 'repo': substitute(l:m[2], '\.git$', '', ''), 'ref': l:m[4], 'path': gb#path#normalize(l:path), 'line_start': l:line_start, 'line_end': l:line_end}
  endif

  return {}
endfunction

function! gb#path#parse_git_remote(input) abort
  let l:m = matchlist(a:input, '^git@github\.com:\([^/]\+\)/\([^ ]\+\)$')
  if empty(l:m)
    return {}
  endif
  return {'owner': l:m[1], 'repo': substitute(l:m[2], '\.git$', '', ''), 'ref': '', 'path': '/'}
endfunction

function! gb#path#parse_shorthand(input) abort
  let l:m = matchlist(a:input, '^\([^/@ ]\+\)/\([^@ ]\+\)\%(@\(.\+\)\)\?$')
  if empty(l:m)
    return {}
  endif
  return {'owner': l:m[1], 'repo': l:m[2], 'ref': l:m[3], 'path': '/'}
endfunction

function! gb#path#canonical(parsed) abort
  let l:ref = empty(get(a:parsed, 'ref', '')) ? '' : '@' . a:parsed.ref
  let l:path = get(a:parsed, 'path', '/')
  if empty(l:path)
    let l:path = '/'
  endif
  if l:path[0] !=# '/'
    let l:path = '/' . l:path
  endif
  return 'github://' . a:parsed.owner . '/' . a:parsed.repo . l:ref . ':' . l:path
endfunction

function! gb#path#repo_key(parsed) abort
  return a:parsed.owner . '/' . a:parsed.repo . '@' . (empty(get(a:parsed, 'ref', '')) ? 'HEAD' : a:parsed.ref)
endfunction

function! gb#path#repo_id(parsed) abort
  return a:parsed.owner . '/' . a:parsed.repo
endfunction

function! gb#path#relative(path) abort
  return substitute(a:path, '^/', '', '')
endfunction

function! gb#path#lookup_key(path) abort
  let l:p = substitute(a:path, '/\+', '/', 'g')
  let l:p = substitute(l:p, '^/', '', '')
  let l:p = substitute(l:p, '/$', '', '')
  return l:p
endfunction

function! gb#path#normalize(path) abort
  let l:parts = split(a:path, '/')
  let l:out = []
  for l:part in l:parts
    if empty(l:part) || l:part ==# '.'
      continue
    elseif l:part ==# '..'
      if !empty(l:out)
        call remove(l:out, -1)
      endif
    else
      call add(l:out, l:part)
    endif
  endfor
  let l:normalized = '/' . join(l:out, '/')
  if a:path =~# '/$' && l:normalized !~# '/$'
    let l:normalized .= '/'
  endif
  return l:normalized
endfunction

function! gb#path#join(base, name) abort
  return gb#path#normalize(a:base . '/' . a:name)
endfunction

function! gb#path#parent(path) abort
  let l:key = gb#path#lookup_key(a:path)
  if empty(l:key) || l:key !~# '/'
    return '/'
  endif
  return '/' . substitute(l:key, '/[^/]*$', '', '')
endfunction

function! gb#path#github_url(parsed, line_start, line_end) abort
  let l:entry = gb#cache#tree_entry(a:parsed)
  let l:type = get(l:entry, 'type', '') ==# 'tree' ? 'tree' : 'blob'
  let l:path = gb#path#relative(get(a:parsed, 'path', '/'))
  let l:url = 'https://github.com/' . a:parsed.owner . '/' . a:parsed.repo . '/' . l:type . '/' . a:parsed.ref
  if !empty(l:path)
    let l:url .= '/' . l:path
  elseif l:type ==# 'tree'
    let l:url .= '/'
  endif
  if l:type ==# 'blob' && a:line_start > 0
    let l:url .= '#L' . a:line_start
    if a:line_end > 0 && a:line_end != a:line_start
      let l:url .= '-L' . a:line_end
    endif
  endif
  return l:url
endfunction

function! gb#path#filetype(path) abort
  let l:name = fnamemodify(a:path, ':t')
  let l:ext = fnamemodify(l:name, ':e')
  let l:map = {
        \ 'vim': 'vim',
        \ 'lua': 'lua',
        \ 'py': 'python',
        \ 'js': 'javascript',
        \ 'ts': 'typescript',
        \ 'go': 'go',
        \ 'rs': 'rust',
        \ 'c': 'c',
        \ 'h': 'c',
        \ 'cpp': 'cpp',
        \ 'hpp': 'cpp',
        \ 'java': 'java',
        \ 'rb': 'ruby',
        \ 'el': 'lisp',
        \ 'md': 'markdown',
        \ 'org': 'org',
        \ 'json': 'json',
        \ 'yml': 'yaml',
        \ 'yaml': 'yaml',
        \ 'toml': 'toml',
        \ 'sh': 'sh',
        \ 'zsh': 'zsh',
        \ }
  if has_key(l:map, l:ext)
    return l:map[l:ext]
  endif
  if l:name ==# 'Makefile'
    return 'make'
  endif
  return ''
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
