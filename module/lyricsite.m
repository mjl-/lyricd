include "sys.m";
include "draw.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "string.m";
include "convcs.m";
include "cgi.m";
include "regex.m";
include "misc.m";
include "filter.m";
include "ohttp.m";
include "lyricutils.m";


sys: Sys;
str: String;
cgi: Cgi;
misc: Misc;
lyricutils: Lyricutils;
Lyric, Link, join, httpget, conv, find, findall, htmlstrip, urlallow, sanitize, htmlfmt, hasterms, rate, BY_URL, BY_TITLE, BY_ARTIST, googlesearch, score ,rev, l2a, a2l, replace: import lyricutils;
