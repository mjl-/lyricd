implement Lyricscgi;

include "sys.m";
	sys: Sys;
	print, sprint: import sys;
include "draw.m";
include "env.m";
	env: Env;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "string.m";
	str: String;
include "lists.m";
	lists: Lists;
include "template.m";
	template: Template;
	Form: import template;
include "cgi.m";
	cgi: Cgi;
	Fields: import cgi;
include "lyrics.m";
	lyrics: Lyrics;
	Lsrv, Lyric, Result: import lyrics;

addr: con "net!localhost!7115";

Lyricscgi: module {
	modinit:	fn(): string;
	init:	fn(nil: ref Draw->Context, args: list of string);
};

modinit(): string
{
	sys = load Sys Sys->PATH;
	str = load String String->PATH;
	lists = load Lists Lists->PATH;
	bufio = load Bufio Bufio->PATH;
	env = load Env Env->PATH;
	template = load Template Template->PATH;
	cgi = load Cgi Cgi->PATH;
	lyrics = load Lyrics Lyrics->PATH;
	if(template == nil || cgi == nil || lyrics == nil)
		sys->sprint("loading template,cgi,lyrics: %r");

	cgi->init();
	template->init();
	return nil;
}

init(nil: ref Draw->Context, args: list of string)
{
	if(sys == nil)
		modinit();

	fields := cgi->unpackenv();
	if(fields == nil)
		error("could not initialize");

	form := ref Form("lyricscgi");

	path := env->getenv("PATH_INFO");
	elems := tokenize(path);
	case len elems {
	0 =>
		form.print("intro", nil);

	1 =>
		case elems[0] {
		"style" =>
			form.print("style", nil);

		"fetch" or "get" =>
			artist := fields.get("artist");
			title := fields.get("title");
			site := fields.get("site");

			if(artist == "")
				artist = "_";
			if(title == "")
				error("title can't be empty.  please go back and enter a title.");

			loc := artist+"/"+title;
			if(elems[0] == "get") {
				if(site == "")
					error("no site specified");
				loc += "/"+site;
			}


			host := env->getenv("HTTP_HOST");
			print("Status: 303 See other\r\n");
			print("location: http://%s%s%s\r\n\r\n", host, env->getenv("SCRIPT_NAME"), cgi->encodepath(loc));

		* =>
			badpath("no such page");
		}

	2 =>
		artist := cgi->decode(elems[0]);
		title := cgi->decode(elems[1]);
		if(artist == "_")
			artist = "";

		(lsrv, err) := lyrics->connect(addr);
		if(err != nil)
			error("connecting: "+err);

		err = lsrv.fetch(artist, title, nil, lyrics->LINKS);
		if(err != nil)
			error("error requesting lyric: "+err);

		vars := list of {
			("artist", artist),
			("title", title),
		};
		form.print("fetchstart", vars);
		hits: list of ref Result;
		ly: ref Lyric;
		for(;;) {
			(r, l, errmsg) := lsrv.fetchresp();
			if(errmsg != nil)
				form.print("lyricfail", ("text", errmsg)::nil);
			if(r != nil) {
				page := "fetchhit";
				if(!r.hit)
					page = "fetchmiss";
				form.print(page, resultvars(r));
				if(r.hit)
					hits = r::hits;
			} else if(l != nil) {
				page := "lyric";
				if(!l.success)
					page = "lyricfail";
				else
					ly = l;
				form.print(page, lyricvars(l));
			} else
				break;
		}
		if(ly == nil)
			form.print("fetchnolyric", nil);
		form.print("fetchstartlinks", nil);
		hitsa := l2a(hits);
		sort(hitsa, scorege);
		for(i := len hitsa-1; i >= 0; i--) {
			r := hitsa[i];
			if(ly != nil && r.id == ly.id)
				continue;
			vars = ("artist", artist)::("title", title)::resultvars(r);
			form.print("fetchlink", vars);
		}
		form.print("fetchend", nil);

	3 =>
		artist := cgi->decode(elems[0]);
		title := cgi->decode(elems[1]);
		site := cgi->decode(elems[2]);
		url := fields.get("url");

		if(site == nil)
			error("no site specified");

		if(artist == "_")
			artist = "";

		(lsrv, err) := lyrics->connect(addr);
		if(err != nil)
			error("connecting: "+err);

		vars := ("artist", artist)::("title", title)::nil;
		if(url == nil) {
			err = lsrv.search(artist, title, site::nil, 1);
			if(err != nil) {
				form.print("geterror", ("text", "error while searching: "+err)::vars);
				return;
			}
			results: list of ref Result;
			(results, err) = lsrv.searchrespall();
			if(results == nil) {
				form.print("geterror", ("text", "error while searching: no hits")::vars);
				return;
			}
			resultsa := l2a(results);
			sort(resultsa, scorege);
			r := resultsa[0];
			if(!r.hit) {
				form.print("geterror", ("text", "no lyrics found")::vars);
				return;
			}
			site = r.site;
			url = r.id;
		}

		l: ref Lyric;
		(l, err) = lsrv.get(site, url);
		if(err != nil)
			form.print("geterror", ("text", err)::vars);
		else
			form.print("getlyric", ("artist", artist)::("title", title)::lyricvars(l));

	* =>
		badpath("no such page");
	}
}

tokenize(s: string): array of string
{
	l: list of string;
	elem: string;
	while(s != nil) {
		(elem, s) = str->splitl(s, "/");
		l = elem::l;
		if(s != nil)
			s = s[1:];
	}
	return l2a(lists->reverse(l));
}

lyricvars(l: ref Lyric): list of (string, string)
{
	return list of {
		("success", string l.success),
		("site", l.site),
		("id", l.id),
		("score", sprint("%.02f", l.score)),
		("text", l.text),
	};
}

resultvars(r: ref Result): list of (string, string)
{
	return list of {
		("hit", string r.hit),
		("site", r.site),
		("id", r.id),
		("score", sprint("%.02f", r.score)),
	};
}

scorege(a, b: ref Result): int
{
	return a.score >= b.score;
}

# insertion sort, from local code i had.
sort[T](a: array of T, ge: ref fn(a, b: T): int)
{
	for(i := 1; i < len a; i++) {
		tmp := a[i];
		for(j := i; j > 0 && ge(a[j-1], tmp); j--)
			a[j] = a[j-1];
		a[j] = tmp;
	}
}

l2a[T](l: list of T): array of T
{
	a := array[len l] of T;
	i := 0;
	for(; l != nil; l = tl l)
		a[i++] = hd l;
	return a;
}

badpath(s: string)
{
	sys->fprint(sys->fildes(2), "badpath: %s", s);
	print("Status: 404 File not found\r\n");
	print("content-type: text/plain; charset=utf-8\r\n\r\nerror: %s\n", s);
	raise "fail:"+s;
}

error(s: string)
{
	sys->fprint(sys->fildes(2), "%s", s);
	print("Status: 200 OK\r\n");
	print("content-type: text/plain; charset=utf-8\r\n\r\nerror: %s\n", s);
	raise "fail:"+s;
}
