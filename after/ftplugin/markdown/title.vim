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

" @return {Node}
" Node properties:
"  * name {String} tag name
"  * [attrs] {Array<AttributeNode>} optional
"  * [innerContent] {String} optional
"  * startIndex {Integer} start index in original html
"  * endIndex {Integer}  end index in original html
"
function! s:ParseNode(tagname, html, startToken, endToken)
    " echo 'ParseNode -----'
    " echo 'html: ' . a:html
    " echo 'tagname: ' . a:tagname
    " echo 'startToken: ' . a:startToken
    " echo 'endToken: ' . a:endToken

    let node = {}
    let node['name'] = a:tagname
    let attributes = {}

    let startTokenLen = strlen(a:startToken)
    let startTokenIndex = stridx(a:html, a:startToken, 0)
    " echomsg 'startTokenIndex: ' .startTokenIndex

    let htmlWithAttrs = ''

     " <tagname>xxx</tagname>
    if stridx(a:startToken, '>') > -1
        let htmlWithAttrs = ''
        let needleStart = startTokenIndex + startTokenLen
        let endTokenIndex = stridx(a:html, a:endToken, needleStart)
        if endTokenIndex > -1
            let innerContentLength = endTokenIndex - needleStart
            let innerContent = strpart(a:html, needleStart, innerContentLength)
            let node['innerContent'] = innerContent
        endif
    else
        let attrStartIndex = startTokenIndex + startTokenLen
        let attrEndIndex = -1
        " <tagname abc />
        if a:endToken == s:generalEndToken
            let endTokenIndex = stridx(a:html, a:endToken, attrStartIndex)
        else
            " <tagname abc > xxxx </tagname>
            let endMark = '>'
            let attrEndIndex = stridx(a:html, endMark, attrStartIndex)
            if attrEndIndex > -1
                let needleStart = attrEndIndex + strlen(endMark)
                let endTokenIndex = stridx(a:html, a:endToken, needleStart)
                if endTokenIndex > -1
                    let innerContentLength = endTokenIndex - needleStart
                    let innerContent = strpart(a:html, needleStart, innerContentLength)
                    let node['innerContent'] = innerContent
                endif
            endif
        endif

        let htmlWithAttrs = strpart(a:html, attrStartIndex, attrEndIndex - attrStartIndex)
    endif

    if !empty(htmlWithAttrs)
        let node['attrs'] = htmlWithAttrs
    endif

    return node
endfunction



" @return {Array<Node>}
function! s:ParseTag(tagname, html)
    let startToken = '<' . a:tagname
    let startTokenWithClose = startToken . '>'
    let startTokenWithSpace = startToken . ' '
    let startTokenWithEndLine  = startToken . '\n'
    let realStartToken = ''
    let endToken = '</' . a:tagname .'>'
    let realEndToken = ''

    let needleIndex = 0
    let len = strlen(a:html)
    let nodeList = []

    while needleIndex < len
        let startIndex = stridx(a:html, startTokenWithClose, needleIndex)
        let realStartToken = startTokenWithClose

        if startIndex == -1
            let startIndex = stridx(a:html, startTokenWithSpace, needleIndex)
            " echomsg 'startTokenWithSpace: ' . startTokenWithSpace
            let realStartToken = startTokenWithSpace
        endif

        if startIndex == -1
            " echomsg 'startTokenWithEndLine: ' .startTokenWithEndLine
            let startIndex = stridx(a:html, startTokenWithEndLine, needleIndex)
            let realStartToken = startTokenWithEndLine
        endif

        if startIndex > -1
            let nearstEndTokenIndex = stridx(a:html, endToken, startIndex)
            let nearstGeneralEndTokenIndex = stridx(a:html, s:generalEndToken, startIndex)
            let endIndex = -1
            let endTokenIndex = -1
            if nearstEndTokenIndex > -1 && nearstGeneralEndTokenIndex > -1
                let indexList = [nearstEndTokenIndex, nearstGeneralEndTokenIndex]
                let endTokenIndex = min(indexList)
                if endTokenIndex == nearstGeneralEndTokenIndex
                    let realEndToken = s:generalEndToken
                else
                    let realEndToken = endToken
                endif
            elseif nearstEndTokenIndex > -1
                let endTokenIndex = nearstEndTokenIndex
                let realEndToken = endToken
            elseif nearstGeneralEndTokenIndex > -1
                let endTokenIndex = nearstGeneralEndTokenIndex
                let realEndToken = s:generalEndToken
            else
                echoerr 'Can not find end token for ' . startToken
            endif
            if endTokenIndex > -1
                let node = s:ParseNode(a:tagname, a:html, realStartToken, realEndToken)
                let endIndex = endTokenIndex + strlen(realEndToken)
                if !empty(node)
                    let node['startIndex'] = startIndex
                    let node['endIndex'] = endIndex
                    call add(nodeList, node)
                endif
                let needleIndex = endIndex
            else
                let needleIndex = len
            endif

        else
            let needleIndex = len
        endif
    endwhile

    return nodeList
endfunction

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

function! s:ExtractTitle(html)
    let titleNodeList = s:ParseTag('title', a:html)
    " echo 'string : ' . strpart(a:html, 0, 1200)
    " echo 'titleNodeList'
    " echo titleNodeList
    if empty(titleNodeList)
        return ''
    endif

    let titleNode = get(titleNodeList, 0)
    if empty(titleNode)
        return ''
    endif

    let title = get(titleNode, 'innerContent', '')
    return title
endfunction

function! s:DownloadAndGetTitleJira(url)
    let command = s:BuildDownloadCommandJira(a:url, 0)
    let responseText = system(command)
    let title = s:ExtractTitle(responseText)

    if empty(title) || stridx(title, '403') > -1 || stridx(title, 'Forbidden') > -1
        let loginCommand = s:BuildDownloadCommandJira(a:url, 1)
        call system(loginCommand)
        let responseText = system(command)
        let title = s:ExtractTitle(responseText)
    endif

    if exists('*JiraTitleFilter')
        let title = JiraTitleFilter(title, a:url)
    endif

    return title
endfunction

function! s:DownloadAndGetTitle(url)
    let command = s:BuildDownloadCommand(a:url)
    let responseText = system(command)
    let title = s:ExtractTitle(responseText)
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

