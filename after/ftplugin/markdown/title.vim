"
" insert jira content into markdown as a list item with link
"

let s:isTesting = 0

if !s:isTesting
    if &compatible || exists('b:mkdInput_title')
        finish
    endif
    let b:mkdInput_title = 1
    let s:save_cpo = &cpoptions
    set cpoptions&vim


    if exists('s:mkdInput_title')
        finish
    endif
endif


let s:mkdInput_title = 1
let s:generalEndToken =  '/>'
let s:jiraCookieFile = tempname()


function! s:SoJiraConfigIfNeed()
    " if exists('g:jira_username') && exists('g:jira_password') && exists('g:jira_url_prefix')
        " return
    " endif

    let path = expand('~/jira.vim')
    if filereadable(path)
        exec ':so ' . path
    else
        echomsg '~/jira.vim does not exists or is not readable!'
        return
    endif

    if !exists('g:jira_username') || !exists('g:jira_password') || !exists('g:jira_url_prefix')
        echo '~/jira.vim is not valid'
    endif

endfun


function! s:BuildCurlCommandJira(url, userName, password, isLogin)
    if !executable('curl')
        return ''
    endif
    let loginUrl = '"' . g:jira_url_prefix . 'login.jsp"'
    let loginData =  "--data 'os_username=" . a:userName . '&os_password='. a:password ."&os_destination=&user_role=&atl_token=&login=Log+In'"

    let wrappedUrl = '"' . a:url . '"'
    let theUrl = a:isLogin ? loginUrl : wrappedUrl
    let theData = a:isLogin ? loginData : ''

    let cookies =  '--cookie "' . s:jiraCookieFile .'" --cookie-jar "' . s:jiraCookieFile . '"'

    let textList = [ 'curl',
                \ theUrl,
                \ '--max-time 3',
                \ "-H 'Connection: keep-alive'",
                \ "-H 'Pragma: no-cache'",
                \ "-H 'Cache-Control: no-cache'",
                \ "-H 'Origin: http://jira.corp.youdao.com'",
                \ "-H 'Upgrade-Insecure-Requests: 1'",
                \ "-H 'Content-Type: application/x-www-form-urlencoded'",
                \ "-H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.157 Safari/537.36'",
                \ "-H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3'",
                \ "-H 'Referer: http://jira.corp.youdao.com/login.jsp'",
                \ "-H 'Accept-Encoding: gzip, deflate'",
                \ "-H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-TW;q=0.7,zh-CN;q=0.6,und;q=0.5'",
                \ theData,
                \ cookies,
                \ '--compressed'
                \]

    let text = join(textList, ' ')
    return text
endfunction

function! s:BuildDownloadCommandJira(url, isLogin)
    call s:SoJiraConfigIfNeed()
    if !exists('g:jira_username') || !exists('g:jira_password')
        return ''
    endif
    let userName = g:jira_username
    let password = g:jira_password

    let command = s:BuildCurlCommandJira(a:url, userName, password, a:isLogin)
    " TODO if curl is not support, can create others
    return command
endfunction

function! s:BuildCurlCommand(url)
    if !executable('curl')
        return ''
    endif

    let wrappedUrl = '"' . a:url . '"'
    let theUrl =  wrappedUrl
    let theData = ''
    let cookies =  ''

    let textList = [ 'curl',
                \ theUrl,
                \ '--max-time 3',
                \ "-H 'Connection: keep-alive'",
                \ "-H 'Pragma: no-cache'",
                \ "-H 'Cache-Control: no-cache'",
                \ "-H 'Upgrade-Insecure-Requests: 1'",
                \ "-H 'Content-Type: application/x-www-form-urlencoded'",
                \ "-H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.157 Safari/537.36'",
                \ "-H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3'",
                \ "-H 'Accept-Encoding: gzip, deflate'",
                \ "-H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-TW;q=0.7,zh-CN;q=0.6,und;q=0.5'",
                \ theData,
                \ cookies,
                \ '--compressed'
                \]

    let text = join(textList, ' ')
    return text
endfunction


function! s:BuildDownloadCommand(url)
    let command = s:BuildCurlCommand(a:url)
    " TODO if curl is not support, can create others
    return command
endfunction

function! s:IsFromWeChat(url)
    return stridx(a:url, 'https://mp.weixin.qq.com/') > -1
endfunction

" 微信公众号平台的原始html中， <title/> 为空
" 标题书写在 <meta /> 标签中
"
" https://mp.weixin.qq.com/s/wTVbioBftHVs1Z_4FIDFmw
"   <meta property="og:title" content="xxxx" />
"
" @param {string[]} htmlLines
" @return {string}
function! s:ExtractTitleForWeChat(htmlLines)
    let htmlAsText = join(a:htmlLines, '')

    let startFlag = '<meta property="og:title" content="'
    let endFlag = '" />'

    let startIndex = stridx(htmlAsText, startFlag)
    if startIndex == -1
        return ''
    endif

    let titleStartIndex = startIndex + strlen(startFlag)
    let endIndex = stridx(htmlAsText, endFlag, titleStartIndex)
    if endIndex == -1
        return ''
    endif

    let titleLength = endIndex - titleStartIndex
    let title = strpart(htmlAsText, titleStartIndex, titleLength)

    return title
endfunction

" 使用正则匹配获取 title
"
"@param {string[]} htmlLines
"@return {string}
"
function! s:ExtractTitleFromHtml(htmlLines) 
    let htmlAsText = a:htmlLines.join('')
    let startOpen = '<title'
    let startClose = '>'
    let endOpen = '<'

    let startOpenIndex = stridx(htmlAsText, startOpen)
    if startOpenIndex == -1
        return ''
    endif

    let searchStart = startOpenIndex + strlen(startOpen)
    let startCloseIndex = stridx(htmlAsText, startClose, searchStart)
    if startCloseIndex == -1
        return ''
    endif

    let titleStart = startCloseIndex + strlen(startClose)
    let titleEnd = stridx(htmlAsText, endOpen, titleStart)
    if titleEnd == -1
        return ''
    endif

    let titleLength = titleEnd  - titleStart
    let title = strpart(htmlAsText, titleStart, titleLength)
    return title
endfunction


" @param {string[]} htmlLines
" @param {string} url
" @return {string}
"
function! s:ExtractTitle(htmlLines, url)
    let isFromWeChat = s:IsFromWeChat(a:url)
    if isFromWeChat
        let title = s:ExtractTitleForWeChat(a:htmlLines)
        return title
    endif

    let title = s:ExtractTitleFromHtml(a:htmlLines)
    return title
endfunction

function! s:DownloadAndGetTitleJira(url)
    let command = s:BuildDownloadCommandJira(a:url, 0)
    let lines = systemlist(command)
    let title = s:ExtractTitle(lines, a:url)

    if empty(title) || stridx(title, '403') > -1 || stridx(title, 'Forbidden') > -1
        let loginCommand = s:BuildDownloadCommandJira(a:url, 1)
        call system(loginCommand)
        let lines = systemlist(command)
        let title = s:ExtractTitle(lines, a:url)
    endif

    if exists('*JiraTitleFilter')
        let title = JiraTitleFilter(title, a:url)
    endif

    return title
endfunction

function! s:DownloadAndGetTitle(url)
    let command = s:BuildDownloadCommand(a:url)
    let lines = systemlist(command)
    let title = s:ExtractTitle(lines, a:url)
    return title
endfunction

" @return {String}
function! s:GetTitleRemote(url, isJira)
    let title = ''

    if a:isJira
        let title = s:DownloadAndGetTitleJira(a:url)
    else
        let title = s:DownloadAndGetTitle(a:url)
    endif

    let title = trim(title)

    return title
endfunction



function! s:ExtractUrlPattern(list, line, pattern, isJiraShort)

    let start = 0
    let str = matchstr(a:line, a:pattern, start)
    let len = strlen(str)

    while len > 0
        let index = stridx(a:line, str, start)
        let end = index + len

        let url = str

        if a:isJiraShort
            call s:SoJiraConfigIfNeed()
            if exists('g:jira_url_prefix')
                let url = g:jira_url_prefix . 'browse/' . str
            else
                break
            endif
        endif

        if stridx(url, 'www') == 0
            let url = 'http://' . url
        endif

        call add(a:list, {'start': index, 'str': str, 'end': end, 'url': url})

        let start = end
        let str = matchstr(a:line, a:pattern, start)
        let len = strlen(str)
    endwhile

endfunction


function! s:ExtractJiraUrl(line)
    " http://jira.example.com/xxx/project-8
    let pattern = 'https\?:\/\/jira[a-zA-Z0-9%#&_?=,:+\-.\/@]\+'
    " project-8
    let shortPattern = '[a-zA-Z]\+-[0-9]\+'
    let matchList = []

    call s:ExtractUrlPattern(matchList, a:line, pattern, 0)

    if len(matchList) > 0
        return matchList
    endif

    call s:ExtractUrlPattern(matchList, a:line, shortPattern, 1)

    return matchList
endfun

" @param {String} line
" @return {List}
function! s:ExtractUrl(line)

    " javascript reg
    " var URI_REG = /^(https?:\/\/|www\.|ssh:\/\/|ftp:\/\/)[a-z0-9&_+\-\?\/\.=\#,:]+$/i
    let pattern = '\(https\?:\/\/\|www\)[a-zA-Z0-9%#&_?=,:+\-.\/@]\+'
    let matchList = []

    call s:ExtractUrlPattern(matchList, a:line, pattern, 0)

    return matchList
endfun

"@param {Dictionary} urlInfo
"@param {String} line
"@return {String}
function! s:UpdateUrlForLine(urlInfo, line)
    let title = a:urlInfo.title
    let newLine = a:line

    if len(title) > 1
        let before = strpart(newLine, 0, a:urlInfo.start)
        let after = strpart(newLine, a:urlInfo.end)
        let middle = '[' . title  . '](' . a:urlInfo.url .')'
        let newLine = before . middle . after
    endif

    return newLine
endfun

"@param {List} urlList
"@param {String} line
"@return {String}
function! s:UpdateUrlListForLine(urlList, line)
    let index = len(a:urlList) - 1
    let newLine = a:line

    while index >= 0
        let urlInfo = a:urlList[index]
        let newLine = s:UpdateUrlForLine(urlInfo, newLine)
        let index = index - 1
    endwhile

    return newLine
endfun

function! s:UpdateJira()
    let line = getline('.')
    let urlList = s:ExtractJiraUrl(line)

    if empty(urlList)
        echomsg "Can't find jira on this line!"
        return
    endif

    for urlItem in urlList
        let title = s:GetTitleRemote(urlItem.url, 1)
        let urlItem.title = title
    endfor

    let newLine = s:UpdateUrlListForLine(urlList, line)
    if !empty(newLine) && newLine != line
        call setline('.', newLine)
    endif

endfun


function! s:UpdateLink()
    let line = getline('.')
    let urlList = s:ExtractUrl(line)

    if empty(urlList)
        echomsg "Can't find valid url on this line!"
        return
    endif

    for urlItem in urlList
        let title = s:GetTitleRemote(urlItem.url, 0)
        let urlItem.title = title
    endfor

    let newLine = s:UpdateUrlListForLine(urlList, line)
    if !empty(newLine) && newLine != line
        call setline('.', newLine)
    endif

endfun

command! -range UpdateJira <line1>,<line2>call s:UpdateJira()
command! -range UpdateLink <line1>,<line2>call s:UpdateLink()

if !s:isTesting
    let &cpoptions = s:save_cpo
endif

if s:isTesting
    let testingUrl = 'http://jira.corp.youdao.com/browse/HWWEB-464'
    let title = s:GetTitleRemote(testingUrl, 1)
    echo 'title: |' . title . '|'

    let testingUrl = 'https://www.huxiu.com/article/300899.html'
    let title = s:GetTitleRemote(testingUrl, 0)
    echo 'title: |' . title . '|'
endif

