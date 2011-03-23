implement Lyrics;

include "sys.m";
	sys: Sys;
include "draw.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "dial.m";
	dial: Dial;
include "string.m";
	str: String;
include "lyrics.m";


sprint, fprint, print: import sys;


init()
{
	if(sys != nil)
		return;
	sys = load Sys Sys->PATH;
	dial = load Dial Dial->PATH;
	str = load String String->PATH;
	bufio = load Bufio Bufio->PATH;
}

getline(buf: ref Iobuf): (int, string)
{
	l := buf.gets('\n');
	if(l == nil)
		return (1, nil);
	if(l != nil && l[len l - 1] == '\n')
		l = l[:len l - 1];
	if(l != nil && l[len l - 1] == '\r')
		l = l[:len l - 1];
	return (0, l);
}

egetline(buf: ref Iobuf): string
{
	(eof, l) := getline(buf);
	if(eof)
		raise "eof";
	return l;
}

egettext(buf: ref Iobuf): string
{
	text := "";
	for(;;) {
		l := egetline(buf);
		if(l == ".")
			return text;
		if(l != nil && l[0] == '.')
			l = l[1:];
		text += l+"\n";
	}
	return text;
}

rev[t](l: list of t): list of t
{
	r: list of t;
	for(; l != nil; l = tl l)
		r = hd l :: r;
	return r;
}

connect(addr: string): (ref Lsrv, string)
{
	init();

	addr = dial->netmkaddr(addr, "net", "7115");
	cc := dial->dial(addr, nil);
	if(cc == nil)
		return (nil, sprint("dial %s: %r", addr));
	fd := cc.dfd;
	bin := bufio->fopen(fd, bufio->OREAD);
	if(bin == nil)
		return (nil, sprint("bufio open fd: %r"));

	(eof, l) := getline(bin);
	if(eof)
		return (nil, "eof from server during handshake");
	if(l != VERSION)
		return (nil, sprint("server version=%s, our verion=%s", l, VERSION));
	fprint(fd, "%s\n", VERSION);
	(eof, l) = getline(bin);
	if(eof)
		return (nil, "eof from server during handshake");
	sites: list of string;
	while(l != nil) {
		site: string;
		(site, l) = str->splitl(l, ",");
		sites = site::sites;
		if(l != nil)
			l = l[1:];
	}
	sites = rev(sites);
	return (ref Lsrv(fd, bin, sites, VERSION), nil);
}

getreq(lsrv: ref Lsrv, site, id: string): string
{
	if(fprint(lsrv.fd, "get\n%s\n%s\n", site, id) < 0)
		return sprint("error writing request: %r");
	return nil;
}

getresp(lsrv: ref Lsrv): (ref Lyric, string)
{
	{
		lines := array[4] of string;
		for(i := 0; i < len lines; i++)
			lines[i] = egetline(lsrv.in);
		text := egettext(lsrv.in);
		if(lines[0] != "success")
			return (nil, text);
		site := lines[1];
		id := lines[2];
		score := real lines[3];
		return (ref Lyric(1, site, id, score, text), nil);
	} exception e {
	"eof" =>
		return (nil, "eof from server");
	"*" =>
		raise e;
	};
}

Lsrv.get(lsrv: self ref Lsrv, site, id: string): (ref Lyric, string)
{
	init();
	err := getreq(lsrv, site, id);
	if(err != nil)
		return (nil, err);

	return getresp(lsrv);
}

sitestr(sites: list of string): string
{
	sitestr := "";
	if(sites != nil) {
		sitestr += hd sites;
		for(sites = tl sites; sites != nil; sites = tl sites)
			sitestr += ","+hd sites;
	}
	return sitestr;
}

Lsrv.search(lsrv: self ref Lsrv, artist, title: string, sites: list of string, one: int): string
{
	init();
	onestr := "";
	if(one)
		onestr = "yes";
	if(fprint(lsrv.fd, "search\n%s\n%s\n%s\n%s\n", artist, title, sitestr(sites), onestr) < 0)
		return sprint("error writing request: %r");
	return nil;
}

Lsrv.searchresp(lsrv: self ref Lsrv): (ref Result, string)
{
	init();
	{
		l := egetline(lsrv.in);
		if(l == "done") {
			return (nil, nil);
		} else if(len l >= len "hit " && l[:len "hit "] == "hit ") {
			origl := l;
			site, score, id: string;
			(site, l) = str->splitl(l[len "hit ":], " ");
			if(l == nil)
				return(nil, "invalid response: +"+origl);
			(score, l) = str->splitl(l[1:], " ");
			if(l == nil)
				return(nil, "invalid response: +"+origl);
			id = l[1:];
			return (ref Result(1, site, id, real score), nil);
		} else if(len l >= len "miss " && l[:len "miss "] == "miss ") {
			l = l[len "miss ":];
			while(l != nil && l[len l - 1] == ' ')
				l = l[:len l - 1];
			return (ref Result(0, l, nil, 0.0), nil);
		} else {
			return (nil, "unexpected response: "+l);
		}
	} exception e {
	"eof" =>
		return (nil, "eof from server");
	* =>
		raise e;
	}
}

Lsrv.searchrespall(lsrv: self ref Lsrv): (list of ref Result, string)
{
	init();
	resps: list of ref Result;
	for(;;) {
		(result, err) := lsrv.searchresp();
		if(err != nil)
			return (nil, err);
		if(result == nil)
			break;
		resps = result::resps;
	}
	return (rev(resps), nil);
}

Lsrv.fetch(lsrv: self ref Lsrv, artist, title: string, sites: list of string, which: int): string
{
	init();
	whichstr: string;
	case which {
	FIRST =>		whichstr = "first";
	LINKS =>		whichstr = "links";
	ALL =>		whichstr = "all";
	* =>
		return "invalid which";
	}
	if(fprint(lsrv.fd, "fetch\n%s\n%s\n%s\n%s\n", artist, title, sitestr(sites), whichstr) < 0)
		return sprint("error writing: %r");
	return nil;
}

Lsrv.fetchresp(lsrv: self ref Lsrv): (ref Result, ref Lyric, string)
{
	init();
	{
		l := egetline(lsrv.in);
		if(l == "done") {
			return (nil, nil, nil);
		} else if(l == "search") {
			(result, err) := lsrv.searchresp();
			return (result, nil, err);
		} else if(l == "get") {
			(lyric, err) := getresp(lsrv);
			return (nil, lyric, err);
		} else {
			return (nil, nil, "unexpected response: "+l);
		}
	} exception e {
	"eof" =>
		return (nil, nil, "eof from server");
	* =>
		raise e;
	}
}
