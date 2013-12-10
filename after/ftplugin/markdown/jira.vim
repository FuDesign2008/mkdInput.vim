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

function! s:FullUrl (url)
    if match(a:url, '^http') > -1
        return a:url
    endif
    if match(a:url, '^[a-zA-Z]\+-[0-9]\+$')
        return "http://jira.corp.youdao.com/browse/" . a:url
    endif
endfun

"
function! s:InsertJiraAsOrderedList (url)
    let fullUrl = s:FullUrl(a:url)
    if strlen(fullUrl) < 2
        echomsg "Url is not valid: " . a:url
        return
    endif
    let content = s:ReadHtml(fullUrl)
    "let content = s:ReadTest()
    let title = s:ExtractTitle(content)
    echo title
    if strlen(title) < 2
        echomsg 'Can not find title at ' . fullUrl
        return
    endif
    let line = '1. [' . title . '](' . fullUrl .')'
    call append('.', line)
endfun

function! s:InsertJiraAsUnorderedList (url)
    let fullUrl = s:FullUrl(a:url)
    if strlen(fullUrl) < 2
        echomsg "Url is not valid: " . a:url
        return
    endif
    let content = s:ReadHtml(fullUrl)
    "let content = s:ReadTest()
    let title = s:ExtractTitle(content)
    echo title
    if strlen(title) < 2
        echomsg 'Can not find title at ' . fullUrl
        return
    endif
    let line = '    * [' . title . '](' . fullUrl .')'
    call append('.', line)
endfun

function! s:UpdateCurrentLine()
    let line = getline('.')
    let flag = matchstr(line, '\/[a-zA-Z]\+-[0-9]\+')
    let flag = strpart(flag, 1)
    if strlen(flag) < 2
        echomsg "Can't find jira on this line!"
    endif
    let fullUrl = s:FullUrl(flag)
    if strlen(fullUrl) < 2
        echomsg "Url is not valid: " . flag
        return
    endif
    let content = s:ReadHtml(fullUrl)
    let title = s:ExtractTitle(content)
    if strlen(title) < 2
        echomsg 'Can not find title at ' . fullUrl
        return
    endif
    if match(line, '^1\. ')
        let new_line = '1. [' . title . '](' . fullUrl .')'
    else
        let new_line = '    * [' . title . '](' . fullUrl .')'
    endif
    call setline('.', new_line)
endfun

command! -nargs=* OlJira call s:InsertJiraAsOrderedList('<args>')
command! -nargs=* UlJira call s:InsertJiraAsUnorderedList('<args>')
command! -nargs=0 UpdateJira call s:UpdateCurrentLine()

let &cpo = s:save_cpo

