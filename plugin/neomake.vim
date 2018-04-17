if exists('g:loaded_neomake') || &compatible
    finish
endif
let g:loaded_neomake = 1

command! -nargs=* -bang -bar -complete=customlist,neomake#cmd#complete_makers
            \ Neomake call neomake#Make(<bang>1, [<f-args>])

" These commands are available for clarity
command! -nargs=* -bar -complete=customlist,neomake#cmd#complete_makers
            \ NeomakeProject Neomake! <args>
command! -nargs=* -bar -complete=customlist,neomake#cmd#complete_makers
            \ NeomakeFile Neomake <args>

command! -nargs=+ -bang -complete=shellcmd
            \ NeomakeSh call neomake#ShCommand(<bang>0, <q-args>)
command! NeomakeListJobs call neomake#ListJobs()
command! -bang -nargs=1 -complete=custom,neomake#cmd#complete_jobs
            \ NeomakeCancelJob call neomake#CancelJob(<q-args>, <bang>0)
command! -bang NeomakeCancelJobs call neomake#CancelJobs(<bang>0)

command! -bang -bar NeomakeInfo call neomake#debug#display_info(<bang>0)

" Enable/disable/toggle commands.  {{{
function! s:toggle(scope) abort
    let new = !get(get(a:scope, 'neomake', {}), 'disabled', 0)
    if new
        call neomake#config#set_dict(a:scope, 'neomake.disabled', 1)
        call s:handle_disabled_status(a:scope, 1, 1)
    else
        call neomake#config#unset_dict(a:scope, 'neomake.disabled')
        call s:handle_disabled_status(a:scope, 0, 1)
    endif
endfunction

function! s:handle_disabled_status(scope, disabled, verbose) abort
    if a:scope is# g:
        if a:disabled
            call neomake#log#debug('Disabled globally.')
            autocmd! neomake
            augroup! neomake
            call neomake#configure#reset_automake()
        else
            call neomake#log#debug('Enabled globally.')
            call s:setup_autocmds()
        endif
    elseif a:scope is# t:
        if a:disabled
            call neomake#log#debug(printf('Disabled for tab %d.', tabpagenr()))
            for b in neomake#compat#uniq(sort(tabpagebuflist()))
                call neomake#configure#reset_automake_for_buffer(b)
            endfor
        else
            call neomake#log#debug(printf('Enabled for tab %d.', tabpagenr()))
        endif
    elseif a:scope is# b:
        let bufnr = bufnr('%')
        if a:disabled
            call neomake#log#debug(printf('Disabled for buffer %d.', bufnr))
            call neomake#configure#reset_automake_for_buffer(bufnr)
        else
            call neomake#log#debug(printf('Enabled for buffer %d.', bufnr))
        endif
    endif
    call neomake#statusline#clear_cache()
    if a:verbose
        call s:display_status()
    endif
endfunction

function! s:disable(scope) abort
    let old = get(get(a:scope, 'neomake', {}), 'disabled', -1)
    if old ==# 1
        return
    endif
    call neomake#config#set_dict(a:scope, 'neomake.disabled', 1)
    call s:handle_disabled_status(a:scope, 1, &verbose)
endfunction

function! s:enable(scope) abort
    let old = get(get(a:scope, 'neomake', {}), 'disabled', -1)
    if old != 1
        return
    endif
    call neomake#config#set_dict(a:scope, 'neomake.disabled', 0)
    call s:handle_disabled_status(a:scope, 0, &verbose)
endfunction

function! s:display_status() abort
    let [disabled, source] = neomake#config#get_with_source('disabled', 0)
    let msg = 'Neomake is ' . (disabled ? 'disabled' : 'enabled')
    if source !=# 'default'
        let msg .= ' ('.source.')'
    endif
    echom msg.'.'
endfunction

command! -bar NeomakeToggle call s:toggle(g:)
command! -bar NeomakeToggleBuffer call s:toggle(b:)
command! -bar NeomakeToggleTab call s:toggle(t:)
command! -bar NeomakeDisable call s:disable(g:)
command! -bar NeomakeDisableBuffer call s:disable(b:)
command! -bar NeomakeDisableTab call s:disable(t:)
command! -bar NeomakeEnable call s:enable(g:)
command! -bar NeomakeEnableBuffer call s:enable(b:)
command! -bar NeomakeEnableTab call s:enable(t:)

command! NeomakeStatus call s:display_status()
" }}}

function! s:define_highlights() abort
    if g:neomake_place_signs
        call neomake#signs#DefineHighlights()
    endif
    if get(g:, 'neomake_highlight_columns', 1)
                \ || get(g:, 'neomake_highlight_lines', 0)
        call neomake#highlights#DefineHighlights()
    endif
endfunction

function! s:setup_autocmds() abort
    augroup neomake
        au!
        if !exists('*nvim_buf_add_highlight')
            autocmd BufEnter * call neomake#highlights#ShowHighlights()
        endif
        if has('timers')
            autocmd CursorMoved * call neomake#CursorMovedDelayed()
            " Force-redraw display of current error after resizing Vim, which appears
            " to clear the previously echoed error.
            autocmd VimResized * call timer_start(100, function('neomake#EchoCurrentError'))
        else
            autocmd CursorMoved * call neomake#CursorMoved()
        endif
        autocmd VimLeave * call neomake#VimLeave()
        autocmd ColorScheme * call s:define_highlights()
    augroup END
endfunction

if has('signs')
    let g:neomake_place_signs = get(g:, 'neomake_place_signs', 1)
else
    let g:neomake_place_signs = 0
    lockvar g:neomake_place_signs
endif

call s:setup_autocmds()

" vim: sw=4 et
