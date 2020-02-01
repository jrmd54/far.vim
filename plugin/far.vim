" File: far.vim
" Description: Find And Replace
" Author: Oleg Khalidov <brooth@gmail.com>
" License: MIT

if exists('g:loaded_far') && !far#tools#isdebug() "{{{
    finish
endif "}}}

" TODO beta3 {{{
" (?) FIXME: highlight issue: Far number num **/*.py --win=top --preview=right
" refar in current result (special source..)
" nodes.
" nodes nesting param: how many modes to show. the rest show as one node
" smart nesting: group same nodes in one: [foo/bar]/baz.py and [foo/bar]/boo.py
" quickfix as --win-layout
" async build_far_buffer (https://gist.github.com/mhinz/1d62b803d328f83551e15c97a4b57868)
" vim8 async support
" test coverage
"}}}



function! Find(rngmode, rngline1, rngline2, cmdline, ...) range abort "{{{
    call far#tools#log('=============== FIND ================')
    call far#tools#log('cmdline: '.a:cmdline)

    let cargs = far#tools#splitcmd(a:cmdline)
    if len(cargs) == 1
        call add(cargs, g:far#default_file_mask)
    endif
    if len(cargs) < 2
        call far#tools#echo_err('Arguments required. Format :F <pattern> <filemask> [<param1>...]')
        return
    endif
    call add(cargs, '--result-preview=0')

    let far_params = {
        \   'pattern': cargs[0],
        \   'replace_with': cargs[0],
        \   'file_mask': cargs[1],
        \   'range': a:rngmode == -1? [-1,-1] : [a:rngline1, a:rngline2],
        \   }

    call far#find(far_params, cargs[2:])
endfunction
command! -complete=customlist,far#FindComplete -nargs=+ -range=-1 F
    \   call Find(<count>,<line1>,<line2>,<q-args>)
"}}}

function! Far(rngmode, rngline1, rngline2, cmdline) range abort "{{{
    call far#tools#log('=============== FAR ================')
    call far#tools#log('cmdline: '.a:cmdline)

    let cargs = far#tools#splitcmd(a:cmdline)
    if len(cargs) == 2
        call add(cargs, g:far#default_file_mask)
    endif
    if len(cargs) < 3
        call far#tools#echo_err('Arguments required. Format :Far <pattern> <replace> <filemask> [<param1>...]')
        return
    endif

    let far_params = {
        \   'pattern': cargs[0],
        \   'replace_with': cargs[1],
        \   'file_mask': cargs[2],
        \   'range': a:rngmode == -1? [-1,-1] : [a:rngline1, a:rngline2],
        \   }

    call far#find(far_params, cargs[3:])
endfunction
command! -complete=customlist,far#FarComplete -nargs=+ -range=-1 Far
    \   call Far(<count>,<line1>,<line2>,<q-args>)
"}}}


function! FarModePrompt(rngmode, rngline1, rngline2, substitute_open, cmdline, ...) abort range "{{{
    call far#tools#log('=========== FAR MODE PROMPT ============')

    let origin_bufnr = winbufnr(winnr())

    " close existing buffer in current tab
    for i in range(winnr('$'))
        let winnr = printf('%d', i+1)
        let bufnr = printf('%d', winbufnr(i+1))
        let bufname = bufname(winbufnr(i+1))
        if bufname =~ '\(^\|\W\)FAR [0-9]\+$'
            exe winnr . "wincmd w"
            call far#close_far_buff()
            " if origin_bufnr is not the far buffer closed just now, go back to origin_bufnr
            if bufnr != origin_bufnr
                exe printf('%d', bufwinnr(origin_bufnr)) . "wincmd w"
            endif
        endif
    endfor

    let current_winnr = printf('%d', bufwinnr(winbufnr(winnr())))
    " echo current_winnr expand('%:p') | sleep 1

    " new a buffer for searching mode bar
    call far#mode_prompt_open()

    " init mode status
    let g:far#mode_fix['substitute'] = 0
    let g:far#mode_open['substitute'] = a:substitute_open

    let cargs = far#tools#splitcmd(a:cmdline)

    let pattern = far#mode_prompt_get_item('Find', '', 'customlist,far#FarSearchComplete', 1)
    if pattern == '' | return | endif
    call far#tools#log('>pattern: '.pattern)

    if g:far#mode_open['substitute']
        let replace_with = far#mode_prompt_get_item('Replace with', '','customlist,far#FarReplaceComplete', 1)
        if replace_with == '' | return | endif
    endif
    let g:far#mode_fix['substitute'] = 1

    if !g:far#mode_open['substitute']
        let replace_with = pattern
        call add(cargs, '--result-preview=0')
    endif
    call far#tools#log('>replace_with: '.replace_with)

    let file_mask = far#mode_prompt_get_item('File mask', g:far#default_file_mask, 'customlist,far#FarFileMaskComplete', 0)
    if file_mask == '' | return | endif
    let g:far#default_file_mask = file_mask
    call far#tools#log('>file_mask: '.file_mask)

    " if file_mask == '%'
    "     let file_mask = source_fpath
    " endif

    call far#mode_prompt_close()

    exe current_winnr . "wincmd w"
    " echo current_winnr expand('%:p') | sleep 1


    " disable escaped sequence
    let pattern = g:far#mode_open['regex'] ? pattern : substitute(pattern, '\\', '\\\\', 'g')
    let pattern = (g:far#mode_open['case_sensitive'] ? '\C' : '\c') . pattern
    let pattern = g:far#mode_open['word']            ? ('\<'.pattern.'\>') : pattern
    let pattern = (g:far#mode_open['regex']          ? ''   : '\V') . pattern

    let far_params = {
        \   'pattern': pattern,
        \   'replace_with': replace_with,
        \   'file_mask': file_mask,
        \   'range': a:rngmode == -1? [-1,-1] : [a:rngline1, a:rngline2],
        \   }

    call far#find(far_params, cargs)

endfunction
command! -complete=customlist,far#FarArgsComplete -nargs=* -range=-1 Farr
    \  call FarModePrompt(<count>,<line1>,<line2>,1,<q-args>)
command! -complete=customlist,far#FarArgsComplete -nargs=* -range=-1 Farf
    \  call FarModePrompt(<count>,<line1>,<line2>,0,<q-args>)
"}}}



function! FarPrompt(rngmode, rngline1, rngline2, ...) abort range "{{{
    call far#tools#log('============ FAR PROMPT ================')

    let pattern = input('Search (pattern): ', '', 'customlist,far#FarSearchComplete')
    call far#tools#log('>pattern: '.pattern)
    if empty(pattern)
        call far#tools#echo_err('No pattern')
        return
    endif

    let replace_with = input('Replace with: ', '', 'customlist,far#FarReplaceComplete')
    call far#tools#log('>replace_with: '.replace_with)

    let file_mask = input('File mask: ', '', 'customlist,far#FarFileMaskComplete')
    call far#tools#log('>file_mask: '.file_mask)
    if empty(file_mask)
        call far#tools#echo_err('No file mask')
        return
    endif

    let far_params = {
        \   'pattern': pattern,
        \   'replace_with': replace_with,
        \   'file_mask': file_mask,
        \   'range': a:rngmode == -1? [-1,-1] : [a:rngline1, a:rngline2],
        \   }

    call far#find(far_params, a:000)
endfunction
command! -complete=customlist,far#FarArgsComplete -nargs=* -range=-1 Farp
    \   call FarPrompt(<count>,<line1>,<line2>,<f-args>)
"}}}

function! Refar(rngmode, rngline1, rngline2, ...) abort "{{{
    call far#tools#log('============== REFAR  ==============')
    call far#refind(a:rngmode == -1? [] : [a:rngline1, a:rngline2], a:000)
endfunction
command! -complete=customlist,far#RefarComplete -nargs=* -range=-1 Refar
    \   call Refar(<count>,<line1>,<line2>,<f-args>)
"}}}

function! FarDo(...) abort "{{{
    call far#tools#log('============= FAR DO ================')
    call far#replace(a:000)
endfunction
command! -complete=customlist,far#FardoComplete -nargs=* Fardo call FarDo(<f-args>)
"}}}

function! FarUndo(...) abort "{{{
    call far#tools#log('============= FAR UNDO ================')
    call far#undo(a:000)
endfunction
command! -complete=customlist,far#FarundoComplete -nargs=* Farundo call FarUndo(<f-args>)
"}}}

" loaded {{{
let g:loaded_far = 0
"}}}

" vim: set et fdm=marker sts=4 sw=4:
