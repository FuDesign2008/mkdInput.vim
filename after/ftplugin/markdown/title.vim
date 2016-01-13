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
function! s:WriteToFileAndOpen(content, url)
    let tempFile = tempname() . '.txt'

    let allContentList = ['The content of ' . a:url . ' : ']
    let contentList = split(a:content, '\n', '')

    call extend(allContentList, contentList)

    call writefile(allContentList, tempFile, '')
    call s:OpenFile(tempFile)
endfunction



function! s:SoJiraConfigIfNeed()

    if exists('g:jira_username') && exists('g:jira_password') && exists('g:jira_url_prefix')
        return
    endif

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
        call s:SoJiraConfigIfNeed()
        if !exists('g:jira_username') || !exists('g:jira_password')
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
            self.reset()

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

    try:
        parser.feed(html)
    except:
        pass

    return parser.titleStr

isJiraStr = vim.eval('a:isJira')
isJira = isJiraStr == "1"
url = vim.eval('a:url')
html = ""
title = ""

if isJira:
    userName = vim.eval('g:jira_username')
    password = vim.eval('g:jira_password')
    html = downloadFile(url, userName, password)
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
        call s:WriteToFileAndOpen(html, a:url)
    endif

    if a:isJira && exists('*JiraTitleFilter')
        let title = JiraTitleFilter(title, a:url)
    endif

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
                let url = g:jira_url_prefix . str
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
    let pattern = 'https\?:\/\/jira[a-zA-Z0-9%#&_?=,:+\-.\/]\+'
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
    let pattern = '\(https\?:\/\/\|www\)[a-zA-Z0-9%#&_?=,:+\-.\/]\+'
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
        let title = s:DownloadAndGetTitle(urlItem.url, 1)
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
        let title = s:DownloadAndGetTitle(urlItem.url, 0)
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

