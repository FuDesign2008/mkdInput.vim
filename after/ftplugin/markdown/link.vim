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


function! s:InsertLink(url)
    let http = s:Httplize(a:url)
    let line = s:CreateLink(http)
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
    let new_line = s:CreateLink(url)
    if !empty(new_line)
        call setline('.', new_line)
    endif
endfun

command! -nargs=1 InsertLink call s:InsertLink('<args>')
command! -range UpdateLink <line1>,<line2>call s:UpdateCurrentLine()

let &cpo = s:save_cpo

