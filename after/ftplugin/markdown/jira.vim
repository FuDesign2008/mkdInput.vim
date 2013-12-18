"
" insert jira content into markdown as a list item with link
"

if &cp || exists('b:mkdInput_jira')
    finish
endif
let b:mkdInput_jira = 1
let s:save_cpo = &cpo
set cpo&vim


if exists('s:mkdInput_jira')
    finish
endif

let s:mkdInput_jira = 1
let s:cachedTitles = {}

"@param {String} url
"@return {String}
function! s:FullUrl (url)
    if match(a:url, '^http') > -1
        return a:url
    endif
    if match(a:url, '^[a-zA-Z]\+-[0-9]\+$') > -1
        return "http://jira.corp.youdao.com/browse/" . a:url
    endif
endfun


" @param {String} url
" @return {String}
function! s:DownloadHtml(url)
    if empty(a:url)
        return ''
    endif
    if executable('curl')
        if !exists('g:jira_username')
            let path = expand('~/jira.vim')
            if filereadable(path)
                exec ':so ' . path
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
        "let content = system("curl ", shellescape(params))
        let content = system("curl -s " . params)
        return content
    else
        echoerr 'mkdInput_jira need curl support!'
    endif
endfunction
"@param {String} content
"@return {String}
function! s:ExtractTitle (content)
    let h2 = matchstr(a:content, '<h2[^>]\+>[^<]*<a[^>]\+>[^<]\+</a>[^<]*</h2>')
    let title = matchstr(h2, '>[^<]\+')
    let title = strpart(title, 1)
    let title = substitute(title, '^[[:space:][:blank:]]\+', '', '')
    let title = substitute(title, '[[:space:][:blank:]]\+$', '', '')
    return title
endfun

function! s:CreateListItem (title, url, ordered)
    if empty(a:title) || empty(a:url)
        return ''
    endif
    return (a:ordered ? '1.' : '    *') . ' [' . a:title . '](' . a:url .')'
endfun

" @param {String} url
" @param {Boolean} ordered
" @return {String}
function! s:GetListItem (url, ordered)
    let fullUrl = s:FullUrl(a:url)
    let title = ''
    if empty(fullUrl)
        echomsg "Url is not valid: " . a:url
        return
    endif
    if has_key(s:cachedTitles, fullUrl)
        let title = get(s:cachedTitles, fullUrl, '')
    else
        let content = s:DownloadHtml(fullUrl)
        let title = s:ExtractTitle(content)
        if !empty(title)
            let s:cachedTitles[fullUrl] = title
        endif
    endif

    if !empty(title)
        return s:CreateListItem(title, fullUrl, a:ordered)
    endif
    echomsg 'Can not find title at ' . fullUrl
endfun


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


"
function! s:InsertJiraAsOrderedList (url)
    let line = s:GetListItem(a:url, 1)
    if !empty(line)
        call append('.', line)
    endif
endfun

function! s:InsertJiraAsUnorderedList (url)
    let line = s:GetListItem(a:url, 0)
    if !empty(line)
        call append('.', line)
    endif
endfun

function! s:UpdateCurrentLine()
    let line = getline('.')
    let url = matchstr(line, '\/[a-zA-Z]\+-[0-9]\+')
    let url = strpart(url, 1)
    if empty(url)
        echomsg "Can't find jira on this line!"
        return
    endif
    let new_line = s:GetListItem(url, match(line, '^1\.') > -1)
    if !empty(new_line)
        call setline('.', new_line)
    endif
endfun

command! -nargs=* OlJira call s:InsertJiraAsOrderedList('<args>')
command! -nargs=* UlJira call s:InsertJiraAsUnorderedList('<args>')
command! -range UpdateJira <line1>,<line2>call s:UpdateCurrentLine()

let &cpo = s:save_cpo

