" Caching and GitHub object model for gb.vim.

let s:save_cpo = &cpo
set cpo&vim

let s:tree_cache = {}
let s:content_cache = {}
let s:default_branch_cache = {}
let s:branches_cache = {}
let s:search_cache = {}
let s:dir_entry = {'type': 'tree', 'size': 0, 'sha': '', 'mode': '040000'}
let s:marker_prefix = '__gb_internal__:'

function! gb#cache#resolve_ref(parsed) abort
  let l:parsed = copy(a:parsed)
  if !empty(get(l:parsed, 'ref', ''))
    return l:parsed
  endif
  let l:repo_id = gb#path#repo_id(l:parsed)
  if !has_key(s:default_branch_cache, l:repo_id)
    let l:data = gb#github#get('repos/' . l:repo_id)
    let s:default_branch_cache[l:repo_id] = get(l:data, 'default_branch', 'main')
  endif
  let l:parsed.ref = s:default_branch_cache[l:repo_id]
  return l:parsed
endfunction

function! gb#cache#ensure_tree(parsed) abort
  let l:resolved = gb#cache#resolve_ref(a:parsed)
  let l:key = gb#path#repo_key(l:resolved)
  if !has_key(s:tree_cache, l:key)
    let s:tree_cache[l:key] = gb#cache#fetch_tree(l:resolved)
  endif
  return s:tree_cache[l:key]
endfunction

function! gb#cache#fetch_tree(parsed) abort
  let l:endpoint = 'repos/' . a:parsed.owner . '/' . a:parsed.repo . '/git/trees/' . gb#github#encode(a:parsed.ref) . '?recursive=1'
  let l:data = gb#github#get(l:endpoint)
  let l:tree = {'': copy(s:dir_entry), '/': copy(s:dir_entry)}
  if get(l:data, 'truncated', v:false)
    let l:tree[s:marker_prefix . 'truncated'] = 1
    echomsg 'Github Browser: tree truncated for ' . gb#path#repo_key(a:parsed) . ', fetching directories on demand'
  endif

  for l:item in get(l:data, 'tree', [])
    let l:path = get(l:item, 'path', '')
    if empty(l:path)
      continue
    endif
    let l:entry = {
          \ 'type': get(l:item, 'type', ''),
          \ 'size': get(l:item, 'size', 0),
          \ 'sha': get(l:item, 'sha', ''),
          \ 'mode': get(l:item, 'mode', '100644'),
          \ }
    let l:tree[l:path] = l:entry
    let l:parts = split(l:path, '/')
    if len(l:parts) > 1
      for l:i in range(1, len(l:parts) - 1)
        let l:dir = join(l:parts[0 : l:i - 1], '/')
        if !has_key(l:tree, l:dir)
          let l:tree[l:dir] = copy(s:dir_entry)
        endif
      endfor
    endif
  endfor
  return l:tree
endfunction

function! gb#cache#tree_entry(parsed) abort
  let l:resolved = gb#cache#resolve_ref(a:parsed)
  let l:tree = gb#cache#ensure_tree(l:resolved)
  let l:key = gb#path#lookup_key(get(l:resolved, 'path', '/'))
  if has_key(l:tree, l:key)
    return l:tree[l:key]
  endif
  if has_key(l:tree, s:marker_prefix . 'truncated') && !empty(l:key)
    let l:parent = l:key =~# '/' ? gb#path#lookup_key(fnamemodify(l:key, ':h')) : ''
    if !has_key(l:tree, s:marker_prefix . 'fetched:' . l:parent)
      call gb#cache#fetch_directory(l:resolved, l:parent, l:tree)
    endif
    return get(l:tree, l:key, {})
  endif
  return {}
endfunction

function! gb#cache#children(parsed) abort
  let l:resolved = gb#cache#resolve_ref(a:parsed)
  let l:tree = gb#cache#ensure_tree(l:resolved)
  let l:dir = gb#path#lookup_key(get(l:resolved, 'path', '/'))
  if has_key(l:tree, s:marker_prefix . 'truncated') && !has_key(l:tree, s:marker_prefix . 'fetched:' . l:dir)
    call gb#cache#fetch_directory(l:resolved, l:dir, l:tree)
  endif

  let l:prefix = empty(l:dir) ? '' : l:dir . '/'
  let l:children = []
  for l:path in keys(l:tree)
    if stridx(l:path, s:marker_prefix) == 0
      continue
    endif
    if !empty(l:prefix) && stridx(l:path, l:prefix) != 0
      continue
    endif
    if empty(l:prefix) && l:path =~# '/'
      continue
    endif
    if l:path ==# l:dir || empty(l:path)
      continue
    endif
    let l:name = empty(l:prefix) ? l:path : strpart(l:path, strlen(l:prefix))
    if l:name =~# '/'
      continue
    endif
    if !get(g:, 'gb_browser_show_hidden', 1) && l:name =~# '^\.\%([^/.]\|$\)'
      continue
    endif
    call add(l:children, {'name': l:name, 'path': l:path, 'entry': l:tree[l:path]})
  endfor
  return sort(l:children, {a, b -> a.name ==# b.name ? 0 : a.name ># b.name ? 1 : -1})
endfunction

function! gb#cache#fetch_directory(parsed, dir_key, tree) abort
  let l:path = empty(a:dir_key) ? '' : '/' . gb#github#encode(a:dir_key)
  let l:endpoint = 'repos/' . a:parsed.owner . '/' . a:parsed.repo . '/contents' . l:path . '?ref=' . gb#github#encode(a:parsed.ref)
  try
    let l:data = gb#github#get(l:endpoint)
  catch
    let a:tree[s:marker_prefix . 'fetched:' . a:dir_key] = 1
    return
  endtry
  let a:tree[s:marker_prefix . 'fetched:' . a:dir_key] = 1
  if type(l:data) != v:t_list
    return
  endif
  for l:item in l:data
    let l:path = get(l:item, 'path', '')
    if empty(l:path) || has_key(a:tree, l:path)
      continue
    endif
    let l:type = get(l:item, 'type', '') ==# 'dir' ? 'tree' : 'blob'
    let a:tree[l:path] = {
          \ 'type': l:type,
          \ 'size': get(l:item, 'size', 0),
          \ 'sha': get(l:item, 'sha', ''),
          \ 'mode': l:type ==# 'tree' ? '040000' : '100644',
          \ }
  endfor
endfunction

function! gb#cache#file_content(parsed) abort
  let l:resolved = gb#cache#resolve_ref(a:parsed)
  let l:path = gb#path#relative(l:resolved.path)
  let l:endpoint = 'repos/' . l:resolved.owner . '/' . l:resolved.repo . '/contents/' . gb#github#encode(l:path) . '?ref=' . gb#github#encode(l:resolved.ref)
  let l:data = gb#github#get(l:endpoint)
  let l:sha = get(l:data, 'sha', '')
  if !empty(l:sha) && has_key(s:content_cache, l:sha)
    return s:content_cache[l:sha]
  endif

  if get(l:data, 'encoding', '') ==# 'base64' && has_key(l:data, 'content')
    let l:content = gb#cache#decode_base64(get(l:data, 'content', ''))
  else
    let l:content = gb#cache#fetch_blob(l:resolved, l:sha)
  endif
  if !empty(l:sha)
    let s:content_cache[l:sha] = l:content
  endif
  return l:content
endfunction

function! gb#cache#fetch_blob(parsed, sha) abort
  if empty(a:sha)
    return ''
  endif
  let l:endpoint = 'repos/' . a:parsed.owner . '/' . a:parsed.repo . '/git/blobs/' . a:sha
  let l:data = gb#github#get(l:endpoint)
  return gb#cache#decode_base64(get(l:data, 'content', ''))
endfunction

function! gb#cache#decode_base64(value) abort
  let l:raw = substitute(a:value, '\n', '', 'g')
  if executable('base64')
    let l:tmp = tempname()
    call writefile([l:raw], l:tmp)
    let l:decoded = system('base64 --decode ' . shellescape(l:tmp))
    if v:shell_error != 0
      let l:decoded = system('base64 -D ' . shellescape(l:tmp))
    endif
    call delete(l:tmp)
    if v:shell_error == 0
      return l:decoded
    endif
  endif
  if exists('*base64_decode')
    let l:decoded = base64_decode(l:raw)
    if type(l:decoded) == v:t_blob
      return join(map(blob2list(l:decoded), 'nr2char(v:val)'), '')
    endif
    return l:decoded
  endif
  throw 'Github Browser: base64 decoding is not available'
endfunction

function! gb#cache#search_repos(query) abort
  let l:query = a:query
  if strlen(l:query) < 3
    return []
  endif
  let l:cached = gb#cache#ttl_get(s:search_cache, l:query)
  if l:cached[0]
    return l:cached[1]
  endif

  let l:slash = stridx(l:query, '/')
  if l:slash >= 0
    for l:key in keys(s:search_cache)
      let l:cached_parent = gb#cache#ttl_get(s:search_cache, l:key)
      if l:cached_parent[0] && stridx(l:query, l:key) == 0 && strlen(l:key) < strlen(l:query) && strlen(l:key) <= l:slash
        return filter(copy(l:cached_parent[1]), 'stridx(v:val, l:query) == 0')
      endif
    endfor
  endif

  let l:search = gb#cache#search_query(l:query)
  try
    let l:data = gb#github#get('search/repositories?q=' . gb#github#encode(l:search) . '&per_page=30')
  catch
    return []
  endtry
  let l:results = map(get(l:data, 'items', []), 'get(v:val, "full_name", "")')
  call filter(l:results, '!empty(v:val)')
  call gb#cache#ttl_put(s:search_cache, l:query, l:results)
  return l:results
endfunction

function! gb#cache#search_query(input) abort
  let l:slash = stridx(a:input, '/')
  if l:slash >= 0
    let l:owner = strpart(a:input, 0, l:slash)
    let l:repo_part = strpart(a:input, l:slash + 1)
    return empty(l:repo_part) ? 'user:' . l:owner : l:repo_part . ' in:name user:' . l:owner
  endif
  return a:input . ' in:name'
endfunction

function! gb#cache#branches(owner, repo) abort
  let l:key = a:owner . '/' . a:repo
  let l:cached = gb#cache#ttl_get(s:branches_cache, l:key)
  if l:cached[0]
    return l:cached[1]
  endif
  try
    let l:data = gb#github#get('repos/' . l:key . '/branches?per_page=100')
  catch
    return []
  endtry
  let l:branches = map(l:data, 'get(v:val, "name", "")')
  call filter(l:branches, '!empty(v:val)')
  call gb#cache#ttl_put(s:branches_cache, l:key, l:branches)
  return l:branches
endfunction

function! gb#cache#ttl_get(cache, key) abort
  if !has_key(a:cache, a:key)
    return [0, []]
  endif
  let l:item = a:cache[a:key]
  let l:ttl = get(g:, 'gb_cache_ttl', 300)
  if l:ttl > 0 && localtime() - l:item.time > l:ttl
    call remove(a:cache, a:key)
    return [0, []]
  endif
  return [1, l:item.value]
endfunction

function! gb#cache#ttl_put(cache, key, value) abort
  let a:cache[a:key] = {'time': localtime(), 'value': a:value}
endfunction

function! gb#cache#clear_repo(parsed) abort
  let l:resolved = gb#cache#resolve_ref(a:parsed)
  let l:tree_key = gb#path#repo_key(l:resolved)
  let l:repo_id = gb#path#repo_id(l:resolved)
  if has_key(s:tree_cache, l:tree_key)
    call remove(s:tree_cache, l:tree_key)
  endif
  if has_key(s:branches_cache, l:repo_id)
    call remove(s:branches_cache, l:repo_id)
  endif
endfunction

function! gb#cache#clear_all() abort
  let s:tree_cache = {}
  let s:content_cache = {}
  let s:default_branch_cache = {}
  let s:branches_cache = {}
  let s:search_cache = {}
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
