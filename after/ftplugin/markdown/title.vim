"
" insert jira content into markdown as a list item with link
"

"if &cp || exists('b:mkdInput_title')
    "finish
"endif
let b:mkdInput_title = 1
let s:save_cpo = &cpo
set cpo&vim


"if exists('s:mkdInput_title')
    "finish
"endif

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

"@param {String} url
"@return {String}
function! s:FullJiraUrl (url)
    if match(a:url, '^http') > -1
        return a:url
    endif
    if match(a:url, '^[a-zA-Z]\+-[0-9]\+$') > -1
        return "http://jira.corp.youdao.com/browse/" . a:url
    endif
endfun

function! s:Httplize(url)
    let lowerUrl = tolower(a:url)
    if stridx(lowerUrl, 'http', 0) == 0
        return a:url
    endif
    return 'http://' . a:url
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
                echomsg "~/jira.vim does not exists!"
                return ''
            endif
        endif
        if !exists('g:jira_username') || !exists('g:jira_password')
            echo "~/jira.vim is not valid"
            return ''
        endif
    endif

python << EOF
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

    def handle_data(self, data):
        if self.titleStart:
            self.titleStr += data


# @param {String} url
# @return {String}
def downloadFile(url="", userName="", password=""):

    if url == "":
        return ""

    TIMEOUT = 20
    responese = ""

    if userName and password:
        request = urllib2.Request(url)
        authStr = "%s:%s" % (userName, password)
        base64Str = base64.encodestring(authStr).replace('\n', '')
        request.add_header("Authorization", "Basic %s" % base64Str)
        responese = urllib2.urlopen(request)
    else:
        responese = urllib2.urlopen(url, None, TIMEOUT)

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

isJira = vim.eval('a:isJira')
url = vim.eval('a:url')
html = ""

if isJira:
    userName = vim.eval('g:jira_username')
    password = vim.eval('g:jira_password')
    html = downloadFile(url, userName, password)
    title = getJiraTitle(html)
else:
    html = downloadFile(url)
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


function! s:CreateListItem (title, url, ordered)
    if empty(a:title) || empty(a:url)
        return ''
    endif
    return (a:ordered ? '1.' : '    *') . ' [' . a:title . '](' . a:url .')'
endfun

" @param {String} url
" @param {Boolean} ordered
function! s:GetListItem (url, ordered)
    let fullUrl = s:FullJiraUrl(a:url)
    let title = ''
    let content = ''
    if empty(fullUrl)
        echomsg "Url is not valid: " . a:url
        return
    endif

    let title = s:DownloadAndGetTitle(fullUrl, 1)
    if strlen(title)
        let lineContent = s:CreateListItem(title, fullUrl, a:ordered)
        call setline('.', lineContent)
    else
        echomsg "Failed to get title of page!"
    endif
endfun

" @param {String} url
" @return {String}
function! s:CreateLink (url)
    if empty(a:url)
        echomsg "Url is not valid: " . a:url
        return ''
    endif

    let title = s:DownloadAndGetTitle(a:url, 0)
    if strlen(title)
        return '[' . title . '](' . a:url . ')'
    endif

    echomsg "Failed to get title of page!"
    return ''
endfun


function! s:UpdateJira()
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

function! s:UpdateLink()
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

command! -range UpdateJira <line1>,<line2>call s:UpdateJira()
command! -range UpdateLink <line1>,<line2>call s:UpdateLink()

let &cpo = s:save_cpo

