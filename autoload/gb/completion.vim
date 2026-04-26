" Completion helpers for gb.vim.

let s:save_cpo = &cpo
set cpo&vim

function! gb#completion#browse(ArgLead, CmdLine, CursorPos) abort
  let l:query = a:ArgLead
  let l:at = stridx(l:query, '@')
  if l:at >= 0
    let l:repo_part = strpart(l:query, 0, l:at)
    let l:branch_prefix = strpart(l:query, l:at + 1)
    let l:m = matchlist(l:repo_part, '^\([^/]\+\)/\(.+\)$')
    if empty(l:m)
      return []
    endif
    let l:branches = gb#cache#branches(l:m[1], l:m[2])
    return map(filter(l:branches, 'empty(l:branch_prefix) || stridx(v:val, l:branch_prefix) == 0'), 'l:m[1] . "/" . l:m[2] . "@" . v:val')
  endif
  return gb#cache#search_repos(l:query)
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
