"
" insert jira content into markdown as a list item with link
"

if &cp || exists('b:mkdInput_title')
    finish
endif
let b:mkdInput_title = 1
let s:save_cpo = &cpo
set cpo&vim


if exists('s:mkdInput_title')
    finish
endif

let s:mkdInput_title = 1

"@param {String} fielPath
function! s:OpenFile(filePath)
    if has('mac')
        "let cmd = 'silent !open "' . a:filePath  . '"'
        let cmd = 'open "' . a:filePath  . '"'
    elseif has('win32') || has('win64') || has('win95') || has('win16')
        "let cmd = '!cmd /c start "' . a:filePath . '"'
        let cmd = '/c start "' . a:filePath . '"'
    endif
    "execute cmd
    call system(cmd)
endfunction

"@param {String} content
function! s:WriteToFileAndOpen(content)
    let tempFile = tempname() . '.html'
    let contentList = split(a:content, '\n', '')
    call writefile(contentList, tempFile, '')
    call s:OpenFile(tempFile)
endfunction



let s:so_jira_config = 0
function! s:SoJiraConfigIfNeed()

    if s:so_jira_config
        return
    endif

    let s:so_jira_config = 1

    let path = expand('~/jira.vim')
    if filereadable(path)
        exec ':so ' . path
    else
        echomsg "~/jira.vim does not exists or is not readable!"
        return
    endif

    if !exists('g:jira_username') || !exists('g:jira_password') || !exists('g:jira_url_prefix')
        echo "~/jira.vim is not valid"
    endif
endfun


" @param {String} url
" @return {String}
function! s:DownloadAndGetTitle(url, isJira)
    let html = ''
    let title = ''

    if a:isJira
        if !exists('g:jira_username')
            let path = expand('~/jira.vim')
            if filereadable(path)
                exec ':so ' . path
            else
                echomsg "~/jira.vim does not exists or is not readable!"
                return ''
            endif
        endif
        if !exists('g:jira_username') || !exists('g:jira_password')
            echo "~/jira.vim is not valid"
            return ''
        endif
    endif

python << EOF
import sys
reload(sys)
sys.setdefaultencoding('utf-8')
import vim
import urllib2
import base64
from HTMLParser import HTMLParser
import re


class TitleHTMLParser(HTMLParser):
    titleStart = False
    titleStr = ""

    def handle_starttag(self, tag, attrs):
        if tag == "title":
            self.titleStart = True

    def handle_endtag(self, tag):
        if tag == "title":
            self.titleStart = False
            self.close()

    def handle_data(self, data):
        if self.titleStart:
            self.titleStr += data


# @param {String} url
# @return {String}
def downloadFile(url="", userName="", password=""):

    if url == "":
        return ""

    responese = ""
    errorMsg = ""

    if userName and password:
        request = urllib2.Request(url)
        authStr = "%s:%s" % (userName, password)
        base64Str = base64.encodestring(authStr).replace('\n', '')
        request.add_header("Authorization", "Basic %s" % base64Str)
        try:
            responese = urllib2.urlopen(request)
        except Exception, ex:
            errorMsg = "error://There is a python error: %s" % ex

    else:
        try:
            responese = urllib2.urlopen(url)
        except Exception, ex:
            errorMsg = "error://There is a python error: %s" % ex

    if errorMsg != "":
        return errorMsg

    if responese == "":
        return ""

    html = responese.read()
    return html


def getTitle(html):
    parser = TitleHTMLParser()
    parser.feed(html)
    return parser.titleStr


def getJiraTitle(html):
    title = getTitle(html)
    reStart = re.compile(r"^\s*\[[#\w-]+\]\s*", re.IGNORECASE)
    title = reStart.sub('', title)
    reEnd = re.compile(r"\s+-\s+Youdao JIRA\s*$", re.IGNORECASE)
    title = reEnd.sub('', title)
    return title


isJiraStr = vim.eval('a:isJira')
isJira = isJiraStr == "1"
url = vim.eval('a:url')
html = ""
title = ""

if isJira:
    userName = vim.eval('g:jira_username')
    password = vim.eval('g:jira_password')
    html = downloadFile(url, userName, password)
    if html.find('error://') == -1 and html != "":
        title = getJiraTitle(html)
else:
    html = downloadFile(url)
    if html.find('error://') == -1 and html != "":
        title = getTitle(html)

title = title.strip()

if len(title) < 1:
    html = html.replace("'", "''")
    vim.command("let html='%s'" % html )
else:
    title = title.replace("'", "''")
    vim.command("let title='%s'" % title )

EOF

    if strlen(title) < 1
        call s:WriteToFileAndOpen(html)
    endif

    return title

endfunction


function! s:ExtractUrlPattern(list, line, pattern, urlPrefix)

    let start = 0
    let str = matchstr(a:line, a:pattern, start)
    let len = strlen(str)

    while len > 0
        let index = stridx(a:line, str, start)
        let end = index + len

        let url = str
        if a:urlPrefix
            if a:urlPrefix === 'jira_url_prefix'
                if !exists('g:jira_url_prefix')
                    call s:SoJiraConfigIfNeed()
                endif
                if exists('g:jira_url_prefix')
                    let url = g:jira_url_prefix . str
                else
                    break
                endif
            else
                let url = a:urlPrefix . str
            endif
        endif

        call add(matchList, {'start': index, 'str': str, 'end': end, 'url': str})

        let start = end
        let str = matchstr(a:line, a:pattern, start)
        let len = strlen(str)
    endwhile

endfunction


function! s:ExtractJiraUrl(line)
    " http://jira.example.com/xxx/project-8
    let pattern = 'https\?:\/\/jira[a-zA-Z0-9%#&_?=,:+\-.\/]\+'
    " project-8
    let shortPattern = '[a-zA-Z]\+-[0-9]\+'
    let matchList = []

    call s:ExtractUrlPattern(matchList, a:line, pattern, '')

    if len(matchList) > 0
        return matchList
    endif

    call s:ExtractUrlPattern(matchList, a:line, shortPattern, 'jira_url_prefix')

    return matchList
endfun

" @param {String} line
" @return {List}
function! s:ExtractUrl(line)

    " javascript reg
    " var URI_REG = /^(https?:\/\/|www\.|ssh:\/\/|ftp:\/\/)[a-z0-9&_+\-\?\/\.=\#,:]+$/i
    let pattern = 'https\?:\/\/[a-zA-Z0-9%#&_?=,:+\-.\/]\+'
    let wwwPattern = 'www.[a-zA-Z0-9%#&_?=,:+\-.\/]\+'
    let matchList = []

    call s:ExtractUrlPattern(matchList, a:line, pattern, '')
    call s:ExtractUrlPattern(matchList, a:line, wwwPattern, 'http://')

    return matchList
endfun

"@param {Dictionary} urlInfo
"@param {String} line
"@return {String}
function! s:UpdateUrlForLine(urlInfo, line)
    let title = a:urlInfo.title

    if len(title) > 1
        let before = strpart(line, 0, a:urlInfo.start)
        let after = strpart(line, a:urlInfo.end)
        let middle = '[' . title  . '](' . a:urlInfo.url .')'
        let line = before . middle . after
    endif

    return line
endfun

"@param {List} urlList
"@param {String} line
"@return {String}
function! s:UpdateUrlListForLine(urlList, line)
    let index = len(a:urlList) - 1

    while index >= 0
        let urlInfo = a:urlList[index]
        line = call s:UpdateUrlForLine(urlInfo, line)
        let index = index - 1
    endwhile

    return line
endfun

function! s:UpdateJira()
    let line = getline('.')
    let urlList = s:ExtractJiraUrl(line)

    if empty(urlList)
        echomsg "Can't find jira on this line!"
        return
    endif

    for urlItem in urlList
        let title = DownloadAndGetTitle(urlItem.url, 0)
        let urlItem.title = title
    endfor

    let newLine = s:UpdateUrlListForLine(urlList, line)
    if !empty(newLine) && newLine != line
        call setline('.', newLine)
    endif

endfun


function! s:UpdateLink()
    let line = getline('.')
    let urlList = s:extractUrl(line)

    if empty(urlList)
        echomsg "Can't find valid url on this line!"
        return
    endif

    for urlItem in urlList
        let title = DownloadAndGetTitle(urlItem.url, 0)
        let urlItem.title = title
    endfor

    let newLine = s:UpdateUrlListForLine(urlList, line)
    if !empty(newLine) && newLine != line
        call setline('.', newLine)
    endif

endfun

command! -range UpdateJira <line1>,<line2>call s:UpdateJira()
command! -range UpdateLink <line1>,<line2>call s:UpdateLink()

let &cpo = s:save_cpo

