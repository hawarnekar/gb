# gb.vim

Browse GitHub repositories in Vim without cloning them.

`gb.vim` provides read-only browsing for GitHub repositories using the GitHub REST API. `:GBrowse` opens a left-side repository browser panel, while selected files open in the editing window on the right.

This plugin is inspired by [remoto.el](https://github.com/agzam/remoto.el), which brings the same “browse a GitHub repository without cloning it” workflow to Emacs.

Development of this plugin was assisted by Codex using the `gpt-5.5 high` model.

## Features

- Browse public and private GitHub repositories without cloning.
- Open repositories from `owner/repo`, GitHub URLs, SSH remote URLs, or canonical `github://` paths.
- Navigate remote directories in a left-side browser panel.
- Open remote files with filetype detection where possible.
- Copy GitHub web URLs for files, line ranges, and browser entries.
- Cache repository trees, file contents, branches, searches, and default branches in memory.
- Reuse `$GITHUB_TOKEN` or `gh auth token` for authenticated requests.

## Requirements

- Vim 8.2 or newer
- `json_decode()` support
- `curl`
- Optional: GitHub CLI (`gh`) for token lookup

Check your Vim:

```vim
:echo exists('*json_decode')
:echo executable('curl')
```

## Installation

### vim-plug

```vim
Plug 'hawarnekar/gb.vim'
```

Then run:

```vim
:PlugInstall
:helptags ALL
```

### Pathogen

```sh
cd ~/.vim/bundle
git clone https://github.com/hawarnekar/gb.vim.git
vim -c 'helptags ~/.vim/bundle/gb.vim/doc' -c 'qa!'
```

### Native Vim packages

```sh
mkdir -p ~/.vim/pack/plugins/start
git clone https://github.com/hawarnekar/gb.vim.git ~/.vim/pack/plugins/start/gb.vim
vim -c 'helptags ~/.vim/pack/plugins/start/gb.vim/doc' -c 'qa!'
```

## Quick Start

Open a repository:

```vim
:GBrowse torvalds/linux
```

Open a specific branch, tag, or commit:

```vim
:GBrowse vim/vim@master
:GBrowse tpope/vim-fugitive@master
```

Paste a GitHub URL:

```vim
:GBrowse https://github.com/vim/vim/tree/master/runtime
:GBrowse https://github.com/vim/vim/blob/master/runtime/doc/help.txt
```

Open a canonical remote path directly:

```vim
:edit github://vim/vim@master:/runtime/doc/help.txt
```

The canonical format is:

```text
github://OWNER/REPO@REF:/PATH
```

The colon before `/PATH` keeps branch names with slashes unambiguous, for example:

```vim
:edit github://owner/repo@feature/topic:/src/main.c
```

## Browser Keys

`:GBrowse` opens a left-side browser panel using the `gb-browser` filetype. Pressing `<CR>` on a directory updates the left panel to show that directory. Pressing `<CR>` on a file opens the file in the right-side window and keeps focus in the browser. The panel shows a clearly marked `"Quick help"` section above the current repo path.

| Key | Action |
| --- | --- |
| `<CR>` | Open file or enter directory |
| `-` | Go to parent directory |
| `r` | Refresh current repository cache |
| `y` | Copy GitHub URL for current entry |
| `c` | Clone repository locally |
| `q` | Close browser buffer |

## Commands

| Command | Description |
| --- | --- |
| `:GBrowse [input]` | Browse a repository, directory, or file |
| `:GBOpen {input}` | Open a parsed remote input |
| `:GBRefresh` | Clear current repo cache and reload |
| `:[range]GBCopyUrl` | Copy GitHub URL for current file, range, or browser entry |
| `:GBClone` | Prompt for a destination path and clone the current repository |
| `:GBClearCache` | Clear all in-memory caches |

`:GBClone` does not assume a default destination. It prompts with an empty path field, and relative paths are accepted exactly as typed.

## Authentication

Public repositories work without a token, but GitHub applies a lower rate limit to unauthenticated requests.

Token lookup order:

1. `g:gb_github_token`
2. `$GITHUB_TOKEN`
3. `gh auth token`, when enabled
4. unauthenticated requests

Recommended:

```sh
export GITHUB_TOKEN=ghp_xxx
```

or:

```sh
gh auth login
```

Avoid committing tokens to dotfiles or repository files.

## Configuration

Set options before the plugin loads:

```vim
let g:gb_github_token = ''
let g:gb_use_gh_token = 1
let g:gb_cache_ttl = 300
let g:gb_curl_command = 'curl'
let g:gb_github_api_url = 'https://api.github.com'
let g:gb_browser_show_hidden = 1
let g:gb_browser_show_help = 1
let g:gb_browser_width = 32
```

For full documentation:

```vim
:help gb
```

## Testing

Offline smoke test:

```sh
vim -Nu NONE -i NONE -n -es -S test/smoke.vim
```

Networked GitHub API smoke test:

```sh
vim -Nu NONE -i NONE -n -es -S test/integration.vim
```

Networked browser layout smoke test:

```sh
vim -Nu NONE -i NONE -n -es -S test/layout.vim
```

## Limitations

- Read-only.
- GitHub only.
- Uses the GitHub REST API, not the Git protocol.
- Does not support commits, pushes, blame, log, or diff.
- Remote `github://` buffers cannot be saved. If you force-edit a buffer and run `:write`, Github Browser rejects the save because the file is not present locally, while keeping your unsaved buffer changes.
- Very large repositories may fall back to per-directory API calls when GitHub truncates recursive tree responses.

## License

This project is licensed under the GNU GPLv3 - see the [LICENSE](LICENSE) file for details.
