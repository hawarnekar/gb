" GitHub REST transport for gb.vim.

let s:save_cpo = &cpo
set cpo&vim

let s:token_cache = ''
let s:token_checked = 0

function! gb#github#get(endpoint) abort
  if !exists('*json_decode')
    throw 'Github Browser: Vim must provide json_decode()'
  endif
  if !executable(get(g:, 'gb_curl_command', 'curl'))
    throw 'Github Browser: curl executable not found'
  endif

  let l:url = substitute(get(g:, 'gb_github_api_url', 'https://api.github.com'), '/$', '', '') . '/' . substitute(a:endpoint, '^/', '', '')
  let l:cmd = [get(g:, 'gb_curl_command', 'curl'), '-sS', '-L', '-w', "\n%{http_code}",
        \ '-H', 'Accept: application/vnd.github+json',
        \ '-H', 'X-GitHub-Api-Version: 2022-11-28']

  let l:token = gb#github#token()
  if !empty(l:token)
    call add(l:cmd, '-H')
    call add(l:cmd, 'Authorization: Bearer ' . l:token)
  endif
  call add(l:cmd, l:url)

  let l:cmdline = join(map(copy(l:cmd), 'shellescape(v:val)'), ' ')
  let l:out = systemlist(l:cmdline)
  let l:status = v:shell_error
  if l:status != 0
    throw 'Github Browser: curl failed for ' . a:endpoint . ': ' . join(l:out, "\n")
  endif

  let l:code = empty(l:out) ? 0 : str2nr(remove(l:out, -1))
  let l:body = join(l:out, "\n")
  if l:code < 200 || l:code >= 300
    let l:message = gb#github#error_message(l:body)
    if l:code == 401
      throw 'Github Browser: authentication failed: ' . l:message
    elseif l:code == 403
      throw 'Github Browser: access denied or rate limited: ' . l:message
    elseif l:code == 404
      throw 'Github Browser: not found: ' . a:endpoint
    endif
    throw 'Github Browser: GitHub API error ' . l:code . ': ' . l:message
  endif

  if empty(l:body)
    return {}
  endif
  try
    return json_decode(l:body)
  catch
    throw 'Github Browser: could not parse GitHub response for ' . a:endpoint
  endtry
endfunction

function! gb#github#error_message(body) abort
  if empty(a:body) || !exists('*json_decode')
    return ''
  endif
  try
    let l:data = json_decode(a:body)
    return get(l:data, 'message', a:body)
  catch
    return a:body
  endtry
endfunction

function! gb#github#token() abort
  if !empty(get(g:, 'gb_github_token', ''))
    return g:gb_github_token
  endif
  if !empty($GITHUB_TOKEN)
    return $GITHUB_TOKEN
  endif
  if s:token_checked
    return s:token_cache
  endif
  let s:token_checked = 1
  if get(g:, 'gb_use_gh_token', 1) && executable('gh')
    let l:token = trim(system('gh auth token'))
    if v:shell_error == 0
      let s:token_cache = l:token
    endif
  endif
  return s:token_cache
endfunction

function! gb#github#encode(value) abort
  if exists('*urlencode')
    return urlencode(a:value)
  endif
  let l:out = ''
  for l:char in split(a:value, '\zs')
    if l:char =~# '[A-Za-z0-9_.~-]'
      let l:out .= l:char
    elseif l:char ==# '/'
      let l:out .= '%2F'
    else
      let l:out .= printf('%%%02X', char2nr(l:char))
    endif
  endfor
  return l:out
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
