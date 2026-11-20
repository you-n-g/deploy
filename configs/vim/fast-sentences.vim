" Saved sentences for vim-fast (Ctrl+G). One buffer, two parts:
"   draft text that is returned if no number is pressed
"   ────────
"   0-9 sentences loaded from disk
" Normal-mode 0-9 sends that sentence and quits. ga stores the current line
" (above the rule) in the first empty slot. Editing a numbered line and
" quitting writes the list back. The prompt file never receives the list.
let s:sentinel = '«fast-sentences»'

function s:Path()
  if $TMA_FAST_SENTENCES != ''
    return $TMA_FAST_SENTENCES
  endif
  " Same rule as helper_scripts/bin/vim-fast. The symlink is created there.
  let farside = expand('~/farside')
  if isdirectory(farside) && (isdirectory(farside . '/.git') || filereadable(farside . '/.git'))
    return farside . '/vim-fast-sentences'
  endif
  let base = $XDG_DATA_HOME != '' ? $XDG_DATA_HOME : expand('~/.local/share')
  return base . '/tma/vim-fast-sentences'
endfunction

function s:SID()
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction

function s:ReadDisk()
  let slots = repeat([''], 10)
  let path = s:Path()
  if !filereadable(path)
    return slots
  endif
  let seen = {}
  for line in readfile(path)
    if line == '' || line =~ '^#'
      continue
    endif
    if line !~ '^[0-9] '
      throw 'fast-sentences: bad line in ' . path . ': ' . line
    endif
    let i = str2nr(line[0])
    if has_key(seen, i)
      throw 'fast-sentences: duplicate slot ' . i . ' in ' . path
    endif
    let seen[i] = 1
    let slots[i] = line[2:]
  endfor
  return slots
endfunction

function s:WriteSlots(slots)
  if a:slots == get(b:, 'fast_disk', repeat([''], 10))
    return
  endif
  let path = s:Path()
  let dir = fnamemodify(path, ':h')
  if !isdirectory(dir) && mkdir(dir, 'p') != 1
    throw 'fast-sentences: cannot create ' . dir
  endif
  let lines = ['# vim-fast sentences. One slot per line: "<digit><space><text>".']
  for i in range(10)
    call add(lines, i . ' ' . a:slots[i])
  endfor
  call writefile(lines, path)
  let b:fast_disk = copy(a:slots)
endfunction

function s:SepLine()
  let n = line("'f")
  if n >= 1 && n <= line('$') && getline(n) == b:fast_rule
    return n
  endif
  let n = 0
  for lnum in range(1, line('$'))
    if getline(lnum) == b:fast_rule
      let n = lnum
    endif
  endfor
  if n < 1
    throw 'fast-sentences: separator missing'
  endif
  call setpos("'f", [0, n, 1, 0])
  return n
endfunction

function s:ParseSlots()
  let sep = s:SepLine()
  if line('$') != sep + 10
    throw 'fast-sentences: expected 10 numbered lines below the rule'
  endif
  let slots = []
  for i in range(10)
    let line = getline(sep + 1 + i)
    if line !~ '^' . i . ' '
      throw 'fast-sentences: slot ' . i . ' must stay "' . i . ' <text>"'
    endif
    call add(slots, line[2:])
  endfor
  return slots
endfunction

function s:WriteCmd()
  let path = expand('<afile>:p')
  if path == ''
    throw 'fast-sentences: no file name'
  endif
  if get(b:, 'fast_ready', 0) && !get(b:, 'fast_plain', 0)
    call s:WriteSlots(s:ParseSlots())
    call writefile(getline(1, s:SepLine() - 1), path)
  else
    call writefile(getline(1, '$'), path)
  endif
  setlocal nomodified
endfunction

function s:Send(n)
  let text = s:ParseSlots()[a:n]
  if text == ''
    echomsg a:n . ' 是空的'
    return
  endif
  call s:WriteSlots(s:ParseSlots())
  let b:fast_plain = 1
  silent %delete _
  call setline(1, text)
  wq
endfunction

function s:Add()
  let sep = s:SepLine()
  if line('.') >= sep
    echomsg '到横线上面，把要存的那一行留给 ga'
    return
  endif
  let text = getline('.')
  if text == ''
    echomsg '这一行是空的'
    return
  endif
  let slots = s:ParseSlots()
  let slot = index(slots, '')
  if slot < 0
    echomsg '0-9 已满；改某一编号行再退出即可替换'
    return
  endif
  call setline(sep + 1 + slot, slot . ' ' . text)
  call s:WriteSlots(s:ParseSlots())
  echomsg '已存到 ' . slot
endfunction

function s:Init()
  if argc() < 1 || &buftype != ''
    return
  endif
  let slots = s:ReadDisk()
  let width = winwidth(0) - 1 - strlen(s:sentinel)
  if width < 12
    let width = 12
  endif
  let b:fast_rule = repeat('─', width) . s:sentinel
  let b:fast_disk = copy(slots)
  let save_undo = &undolevels
  set undolevels=-1
  call append(line('$'), b:fast_rule)
  for i in range(10)
    call append(line('$'), i . ' ' . slots[i])
  endfor
  let &undolevels = save_undo
  call setpos("'f", [0, line('$') - 10, 1, 0])
  let b:fast_ready = 1
  setlocal nomodified
  let sid = s:SID()
  for i in range(10)
    execute 'nnoremap <buffer> <silent> <nowait> ' . i
          \ . ' :call <SNR>' . sid . '_Send(' . i . ')<CR>'
  endfor
  execute 'nnoremap <buffer> <silent> ga :call <SNR>' . sid . '_Add()<CR>'
  execute 'syntax match FastSentinel /' . s:sentinel . '/ conceal'
  execute 'syntax match FastRule /^' . escape(b:fast_rule, '/\^$.*[]~') . '$/'
  syntax match FastNum /^[0-9] /
  highlight FastNum ctermfg=14
  highlight FastRule ctermfg=8
  setlocal conceallevel=3 concealcursor=nvic
  set laststatus=2
  setlocal statusline=\ q\ 返回上文\ \|\ 0-9\ 发送\ \|\ ga\ 把当前行存入空位\ 
endfunction

augroup FastSentences
  autocmd!
  autocmd VimEnter * call s:Init()
  autocmd BufWriteCmd * call s:WriteCmd()
augroup END
