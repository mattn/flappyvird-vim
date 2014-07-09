scriptencoding utf-8

let s:datadir = expand('<sfile>:h:h') . '/data'

let s:cursor_off = 0
let s:cursor_on = 1
let s:t_ve = &t_ve

function! s:toggle_cursor(f)
  let &t_ve = a:f ? s:t_ve : ''
endfunction

let s:STATE_LOOP     = 1
let s:STATE_DIE      = 2
let s:STATE_GAMEOVER = 3
let s:STATE_FINISH   = 4

let s:seed = 0
function! s:srand(seed) abort
  let s:seed = a:seed
endfunction

function! s:rand() abort
  let s:seed = s:seed * 214013 + 2531011
  return (s:seed < 0 ? s:seed - 0x80000000 : s:seed) / 0x10000 % 0x8000
endfunction

function! s:stage_init() abort
  " open new buffer
  silent edit `='==FlappyVird=='`
  silent normal! gg0
  silent only!
  setlocal buftype=nowrite
  setlocal noswapfile
  setlocal bufhidden=wipe
  setlocal buftype=nofile
  setlocal nonumber
  setlocal nolist
  setlocal nowrap
  setlocal nocursorline
  setlocal nocursorcolumn
  syn match FlappyVirdGreen1 '\~'
  hi FlappyVirdGreen1 ctermfg=black ctermbg=green guifg=black guibg=green
  syn match FlappyVirdGreen2 '\^'
  hi FlappyVirdGreen2 ctermfg=yellow ctermbg=yellow guifg=yellow guibg=yellow
  syn match FlappyVirdBar '*'
  hi FlappyVirdBar ctermfg=magenta ctermbg=magenta guifg=magenta guibg=magenta
  call s:toggle_cursor(s:cursor_off)
  redraw
endfunction

function! s:stage_wipeout() abort
  call s:toggle_cursor(s:cursor_on)
  bdelete
endfunction

function! s:loaddata() abort
  return eval(join(readfile(s:datadir . '/stage.json'), ''))
endfunction

function! s:loop()
  let sf = s:loaddata()

  call s:stage_init()

  " clear whole screen
  let ww = winwidth('.')  " window width
  let wh = winheight('.') " window height
  let sh = 20

  " fill screen
  for i in range(1, wh)
    call setline(i, repeat(' ', ww + 10))
  endfor

  " draw ground
  call setline(sh+1, repeat("~", ww))
  let state = s:STATE_LOOP

  let rate = 100
  let jx = 20
  let jy = 1600
  let ry = jy / rate

  let dy = 40
  let si = 0
  let sc = 0
  let st = sf[si][0]
  let cf = get(g:, 'flappyvird_face', '(; @_@)')
  let cw = len(cf)
  let cb = getline(ry)[jx :jx+cw-1]

  let ss = 20
  let rt = reltime()

  call s:srand(localtime())

  call setline(sh + 2, printf(" SCORE: %6d", 0))

  let pause = 0
  let retry = 0
  while 1
    let c = getchar(0)
    if c == 27 || c == 113 " esc or q to quit
      " quit loop
      break
    elseif c == 112 " p to pause
      let pause = !pause
    endif

    if pause
      continue
    endif
    if state == s:STATE_FINISH
      if c == 114 " r to retry
        let retry = 1
        break
      endif
      " do nothing
      continue
    endif

    " erase character
    if ry > 0
      let l = getline(ry)
      let l = l[:jx] . cb . l[jx+cw+1:]
      call setline(ry, l)
    endif

    " calculate next position
    let jy -= dy
    let dy -= 1
    let ry = jy / rate

    if state == s:STATE_LOOP
      " move left screen
      for i in range(1, sh)
        call setline(i, getline(i)[1:] . ' ')
      endfor

      " move ground
      let l = getline(sh + 1)
      let l = l[1:] . (s:rand() < 2000 ? '^' : '~')
      call setline(sh + 1, l)

      if getline(sh)[jx-2: jx-1] == '* '
        let sc += 1
        call setline(sh + 2, printf(" SCORE: %6d", sc))
      endif
    endif

    " redraw character
    if ry > 0 
      let l = getline(ry)
      let cb = l[jx+1 :jx+cw]
      let l = l[:jx] . cf . l[jx+cw+1:]
      call setline(ry, l)
    endif

    redraw

    " calculate diff times to sleep
    let dt = str2float(reltimestr(reltime(rt))) * 1000.0
    let ds = float2nr(ss - dt)
    if ds > 0
      exe 'sleep' ds . 'ms'
    endif
    let rt = reltime()

    if state == s:STATE_DIE
      if ry >= sh
        let state = s:STATE_FINISH
      endif
      continue
    endif

    " if contains non-space characters, or overrun, it's hit!
    if cb =~ '\S' || ry < 1 || ry >= sh
      let state = s:STATE_DIE
      let dy = 0
      continue
    endif

    if c == 32 " space key
      let dy = 40
    endif

    if st == 0
      " draw bar
      for i in range(1, sh)
        let l = getline(i)
        let of = i >= sf[si][1] && i <= sf[si][1] + sf[si][2]
        call setline(i, l[:ww-sf[si][3]] . repeat(of ? ' ' : '*', sf[si][3]))
      endfor

      " shift to next bar
      let si += 1

      " if it's end of bars, finish
      if si == len(sf)
        let state = s:STATE_FINISH
        continue
      endif
      " set next bar timer
      let st = sf[si][0]
    else
      let st -= 1
    endif
  endwhile

  call s:stage_wipeout()
  return retry
endfunction

function! flappyvird#start() abort
  while s:loop()
  endwhile
endfunction

" vim:set et:
