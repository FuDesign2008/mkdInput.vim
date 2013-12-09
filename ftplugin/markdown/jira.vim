"
" insert jira content into markdown as a list item with link
"

if &cp || exists('b:mkdInput_jira')
    finish
endif
let b:mkdInput_jira = 1
let s:save_cpo = &cpo
set cpo&vim


if exist('s:mkdInput_jira')
    finish
endif

let s:mkdInput_jira = 1

" @param {String} url
" @return {String}
function! s:ReadHtml(url)
    if empty(a:url)
        return ''
    endif
    if executable('curl')
        if !exists('g:jira_username')
            let path = expand('~/jira.vim')
            if filereadable(path)
                source path
            else
                echomsg "~/jira.vim does not exists!"
                return ''
            endif
        endif
        if !exists('g:jira_username') || !exists('g:jira_password')
            echo "~/jira.vim is not valid"
            return ''
        endif
        let params = '--data "os_username='. g:jira_username . '&os_password=' . g:jira_password . '" ' . a:url
        let content = system("curl ", shellescape(params))
        return content
    else
        echoerr 'mkdInput_jira need curl support!'
    endif
endfunction

function! s:ReadTest()
    enew
    setlocal noswapfile buftype=nofile  bufhidden=hide nobuflisted nowrap
    let path = expand('~/jira-test.html')
    if filereadable(path)
        execute ':read ' . path
    else
        echo path . 'is NOT readable'
    endif
    let lines = getline(1, '$')
    bd!
    return join(lines, '')
endfun

"@param {String} content
"@return {String}
function! s:ExtractTitle (content)
    let h2 = matchstr(a:content, '<h2[^>]\+>[^<]*<a[^>]\+>[^<]\+</a>[^<]*</h2>')
    let title = matchstr(h2, '>[^<]\+')
    return strpart(title, 1)
endfun

"
function! s:InsertJiraAsOrderedList (url)
    let content = s:ReadHtml(a:url)
    "let content = s:ReadTest()
    let title = s:ExtractTitle(content)
    echo title
    if strlen(title) < 2
        echomsg 'Can not find title at ' . a:url
        return
    endif
    let line = '1. [' . title . '](' . a:url .')'
    call append('.', line)
endfun

function! s:InsertJiraAsUnorderedList (url)
    let content = s:ReadHtml(a:url)
    "let content = s:ReadTest()
    let title = s:ExtractTitle(content)
    echo title
    if strlen(title) < 2
        echomsg 'Can not find title at ' . a:url
        return
    endif
    let line = '    * [' . title . '](' . a:url .')'
    call append('.', line)
endfun

command! -nargs=* OlJira call s:InsertJiraAsOrderedList('<args>')
command! -nargs=* UlJira call s:InsertJiraAsUnorderedList('<args>')

let &cpo = s:save_cpo

