implement Lyricutils;

include "sys.m";
include "draw.m";
include "arg.m";
include "string.m";
include "convcs.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "regex.m";
include "misc.m";
include "cgi.m";
include "filter.m";
include "ohttp.m";
include "htmlent.m";
include "lyricutils.m";


sys: Sys;
str: String;
misc: Misc;
cgi: Cgi;

regex: Regex;
convcs: Convcs;
http: Http;
htmlent: Htmlent;
Url, Rbuf: import http;
fprint, print, sprint: import sys;

convencs := array[] of {"latin1", "windows-1252"};
convs: array of (string, Btos);

httpcache: array of (string, string);
httpold := 0;

init()
{
	sys = load Sys Sys->PATH;
	str = load String String->PATH;
	regex = load Regex Regex->PATH;
	bufio = load Bufio Bufio->PATH;
	convcs = load Convcs Convcs->PATH;
	err := convcs->init(nil);
	if(err != nil)
		error("convcs init: "+err);
	convs = array[len convencs] of (string, Btos);
	for(i := 0; i < len convencs; i++) {
		enc := convencs[i];
		(mod, btoserr) := convcs->getbtos(enc);
		if(btoserr != nil)
			error("loading convcs btos module: "+btoserr);
		convs[i] = (enc, mod);
	}
	misc = load Misc Misc->PATH;
	http = load Http Http->PATH;
	cgi = load Cgi Cgi->PATH;
	htmlent = load Htmlent Htmlent->PATH;
	if(misc == nil || http == nil || cgi == nil || htmlent == nil)
		error("loading misc,http,cgi,htmlent");
	misc->init();
	cgi->init();
	htmlent->init();
	http->init(bufio);

	httpcache = array[10] of (string, string);
}

Lyric.mk(site, url, text: string, score: int): ref Lyric
{
	return ref Lyric(site, url, text, score);
}

Link.mk(artist, title, url, site: string, score: int): ref Link
{
	return ref Link(artist, title, url, site, score);
}

Link.cmp(a, b: ref Link): int
{
	return b.score-a.score;
}

# used by the site modules

httpget(urlstr, enc: string): (string, string)
{
	for(i := 0; i < len httpcache; i++) {
		(u, b) := httpcache[i];
		if(u == urlstr) {
			say("httpget, using cached text");
			return (b, nil);
		}
	}
	(url, urlerr) := Url.parse(urlstr);
	if(urlerr != nil)
		return (nil, urlerr);
	(rbuf, err) := http->get(url, nil);
	data: array of byte;
	if(err == nil)
		(data, err) = rbuf.readall();
	if(err != nil)
		return (nil, err);

	body: string;
	if(enc == nil)
		body = string data;
	else
		body = conv(enc, data);
	httpcache[httpold] = (urlstr, body);
	httpold = (httpold+1) % len httpcache;
	return (body, nil);
}

conv(enc: string, a: array of byte): string
{
	mod: Btos;
	for(i := 0; i < len convs; i++) {
		(e, convmod) := convs[i];
		if(enc == e)
			mod = convmod;
	}
	if(mod == nil) {
		say("missing btos: "+enc);
		raise "fail:missing btos: "+enc;
	}
	(nil, body, n) := mod->btos(nil, a, len a);
	if(n != len a)
		say(sprint("btos consumed only %d out of %d bytes", n, len a));
	return body;
}

find(rstr, body: string): array of string
{
	(re, err) := regex->compile(rstr, 1);
	if(err != nil) {
		say("find: "+err);
		raise err;
	}
	return match(re, body);
}

findall(rstr, body: string): array of array of string
{
	(re, err) := regex->compile(rstr, 1);
	if(err != nil) {
		say("find: "+err);
		raise err;
	}
	return l2a(matchall(re, body));
}

match(re: Regex->Re, s: string): array of string
{
	a := regex->executese(re, s, (0, len s), 0, 0);
	if(a == nil)
		return nil;
	e := array[len a] of string;
	for(i := 0; i < len a; i++) {
		(start, end) := a[i];
		if(start == -1 || end == -1)
			e[i] = nil;
		else
			e[i] = s[start:end];
	}
	return e;
}

matchall(re: Regex->Re, s: string): list of array of string
{
	se := (0, len s);
	l: list of array of string;
	for(;;) {
		a := regex->executese(re, s, se, 0, 0);
		if(a == nil)
			break;
		e := array[len a] of string;
		for(i := 0; i < len a; i++) {
			(start, end) := a[i];
			if(start == -1 || end == -1)
				e[i] = "";
			else
				e[i] = s[start:end];
		}
		(nil, end) := a[0];
		se = (end, len s);
		l = e :: l;
	}
	return rev(l);
}


htmlstrip(s: string): string
{
	r: string;
	skip := 0;
	for(i := 0; i < len s; i++) {
		if(!skip && s[i] == '<')
			skip = 1;
		else if(skip && s[i] == '>')
			skip = 0;
		else if(!skip)
			r[len r] = s[i];
	}
	return r;
}

urlallow(url: string, urls: array of string): int
{
	for(i := 0; i < len urls; i++)
		if(str->prefix(urls[i], url))
			return 1;
	return 0;
}

sanitize(s: string): string
{
	s = htmlstrip(s);
	s = htmlfmt(s);

	a := l2a(split(s, "\n"));
	for(i := 0; i < len a; i++)
		a[i] = misc->strip(a[i], " \t\r\n");
	s = join(a2l(a), "\n");
	s = misc->strip(s, " \t\r\n");
	return s;
}

htmlfmt(s: string): string
{
	return htmlent->conv(s);
}

hasterms(s: string, l: list of string): int
{
	s = str->tolower(s);
	for(; l != nil; l = tl l)
		if(!misc->infix(str->tolower(hd l), s))
			return 0;
	return 1;
}

score(s: string, words: list of string): int
{
	s = str->tolower(s);
	n := 0;
	for(l := words; l != nil; l = tl l)
		if(misc->infix(hd l, s))
			n++;
	if(len words == 0)
		return 0;
	return 100*n/len words;
}

rate(links: array of ref Link, how: int, title, artist: list of string): list of ref Link
{
	for(i := 0; i < len links; i++) {
		v := 0;
		n := 0;
		terms := append(title, artist);
		if(how & BY_URL) {
			v += score(links[i].url, terms);
			n++;
		}
		if(how & BY_TITLE) {
			v += score(links[i].title, title);
			n++;
		}
		if(how & BY_ARTIST) {
			v += score(links[i].artist, artist);
			n++;
		}
		if(n > 0)
			v /= n;
		links[i].score = v;
	}
	misc->insertsort(links);
	return a2l(links);
}

googlesearch(domain: string, title, artist: list of string): array of (string, string)
{
	q := sprint("site:%s \"%s\"", domain, join(title, " "));
	if(artist != nil)
		q += sprint(" \"%s\"", join(artist, " "));
	url := "http://www.google.com/search?"+cgi->pack(("q", q)::nil);
	say("google: "+url);
	(body, err) := httpget(url, "latin1");
	if(err != nil) {
		say("searching google: "+err);
		return nil;
	}
	restr := "<h2 class=r><a href=\"([^\"]+)\" class=l>([^=]+)</a></h2>";
	hits := findall(restr, body);
	a := array[len hits] of (string, string);
	for(i := 0; i < len a; i++)
		a[i] = (htmlfmt(hits[i][1]), htmlstrip(hits[i][2]));
	return a;
}

replace(s, src, dst: string): string
{
	b, rem: string;
	r := "";
	while(s != nil) {
		(b, rem) = str->splitstrl(s, src);
		r += b;
		if(rem == nil)
			break;
		r += dst;
		s = rem[len src:];
	}
	return r;
}

# generic helper functions


split(s, splitstr: string): list of string
{
	return misc->split(s, splitstr);
}

splitcl(s, splitcl: string): list of string
{
	return misc->splitcl(s, splitcl);
}

l2a[T](l: list of T): array of T
{
	a := array[len l] of T;
	i := 0;
	for(; l != nil; l = tl l)
		a[i++] = hd l;
	return a;
}

a2l[T](a: array of T): list of T
{
	l: list of T;
	for(i := len a-1; i >= 0; i--)
		l = a[i]::l;
	return l;
}

rev[T](l: list of T): list of T
{
	r: list of T;
	for(; l != nil; l = tl l)
		r = hd l :: r;
	return r;
}

append[T](l1, l2: list of T): list of T
{
	l: list of T;
	for(t := rev(l2); t != nil; t = tl t)
		l = hd t::l;
	for(t = rev(l1); t != nil; t = tl t)
		l = hd t::l;
	return l;
}

join(l: list of string, sep: string): string
{
	if(l == nil)
		return "";
	s := hd l;
	for(l = tl l; l != nil; l = tl l)
		s += sep+hd l;
	return s;
}

error(s: string)
{
	sys->fprint(sys->fildes(2), "%s\n", s);
	raise "fail:"+s;
}

say(s: string)
{
	# xxx if(dflag)
	sys->fprint(sys->fildes(2), "%s\n", s);
}
