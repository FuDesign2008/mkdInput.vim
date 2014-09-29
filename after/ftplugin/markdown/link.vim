"
" insert jira content into markdown as a list item with link
"

if &cp || exists('b:mkdInput_link')
    finish
endif
let b:mkdInput_link = 1
let s:save_cpo = &cpo
set cpo&vim


if exists('s:mkdInput_link')
    finish
endif

let s:mkdInput_link = 1
let s:cachedTitles = {}

function! s:Httplize(url)
    let lowerUrl = tolower(a:url)
    if stridx(lowerUrl, 'http', 0) == 0
        return a:url
    endif
    return 'http://' . a:url
endfun

" @param {String} url
" @return {String}
function! s:DownloadHtml(url)
    if empty(a:url)
        return ''
    endif
    if executable('curl')
        return system("curl -s " . a:url)
    else
        echoerr 'mkdInput_link need curl support!'
    endif
endfunction

"@param {String} content
"@return {String}
function! s:ExtractTitle (content)
    let title = matchstr(a:content, '<title>[^<]\+</title>')
    let title = matchstr(title, '>[^<]\+')
    let title = strpart(title, 1)
    let title = substitute(title, '^[[:space:][:blank:]]\+', '', '')
    let title = substitute(title, '[[:space:][:blank:]]\+$', '', '')
    return title
endfun

" @param {String} url
" @return {String}
function! s:CreateLink (url)
    let title = ''
    if empty(a:url)
        echomsg "Url is not valid: " . a:url
        return
    endif
    if has_key(s:cachedTitles, a:url)
        let title = get(s:cachedTitles, a:url, '')
    else
        let content = s:DownloadHtml(a:url)
        let title = s:ExtractTitle(content)
        if !empty(title)
            let s:cachedTitles[a:url] = title
        endif
    endif

    if !empty(title)
        return '[' . title . '](' . a:url . ')'
    endif
    echomsg 'Can not find title at ' . a:url
endfun



function! s:UpdateCurrentLine()
    let line = getline('.')
    let url = matchstr(line, 'https\?:\/\/[a-zA-Z0-9%#\-.\/]\+')
    if empty(url)
        let url = matchstr(line, 'www.[a-zA-Z0-9%#\-.\/]\+')
        if !empty(url)
            let url = s:Httplize(url)
        endif
    endif
    if empty(url)
        echomsg "Can't find valid url on this line!"
        return
    endif
    let markdownLink = s:CreateLink(url)
    if !empty(markdownLink)
        let index = stridx(line, '1. ', 0)
        if index > -1
            let line = strpart(line, 0, index + strlen('1. '))
            let line = line . markdownLink
        else
            let index = stridx(line, '* ', 0)
            if index > - 1
                let line = strpart(line, 0, index + strlen('* '))
                let line = line . markdownLink
            else
                let line = '1. ' . markdownLink
            endif
        endif

        call setline('.', line)
    endif
endfun

command! -range UpdateLink <line1>,<line2>call s:UpdateCurrentLine()

let &cpo = s:save_cpo

