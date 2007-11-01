implement Lyric;

include "sys.m";
include "draw.m";
include "arg.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "regex.m";
include "lyrics.m";

sys: Sys;
lyrics: Lyrics;
Lsrv, ALL, FIRST, LINKS: import lyrics;
print, fprint, sprint: import sys;

addr := "tcp!localhost!7115";
dflag := 1;
vflag := 1;
sites: list of string;
rtype := FIRST;	# = 0, default for fetch, meaning false as parameter for search
progname: string;

Lyric: module {
	init:	fn(nil: ref Draw->Context, nil: list of string);
};

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	arg := load Arg Arg->PATH;
	lyrics = load Lyrics Lyrics->PATH;
	if(lyrics == nil)
		nomod(Lyrics->PATH);

	arg->init(args);
	arg->setusage("lyric [-dv] [-a addr] [-s sites] [-t type] [get site url | search title artist | fetch title artist]");
	progname = arg->progname();
	while((c := arg->opt()) != 0)
		case c {
		'a' =>	addr = arg->earg();
		'd' =>	dflag++;
		's' =>	sites = sys->tokenize(arg->earg(), ",").t1;
		't' =>	case arg->earg() {
			"all" =>	rtype = ALL;
			"first" =>	rtype = FIRST;
			"links" =>	rtype = LINKS;
			* => rtype = ALL+FIRST+LINKS;
			}
		'v' =>	vflag++;
		* =>	warn(sprint("bad option: -%c", c));
			arg->usage();
		}
	args = arg->argv();
	if(len args != 3) {
warn(sprint("have %d", len args));
		warn("need three arguments");
		arg->usage();
	}

	(lsrv, connerr) := lyrics->connect("tcp!knaagkever.ueber.net!7115");
	if(connerr != nil)
		error("connecting: "+connerr);

	op := hd args;
	args = tl args;
	case op {
	"get" =>
		(site, url) := (hd args, hd tl args);
		(lyric, err) := lsrv.get(site, url);
		if(err != nil)
			error("retrieving lyric: "+err);
		print("From %s (%s):\n\n%s\n", lyric.site, lyric.id, lyric.text);

	"search" =>
		(title, artist) := (hd args, hd tl args);
		searcherr := lsrv.search(artist, title, sites, rtype);
		if(searcherr != nil)
			error("search request: "+searcherr);
		for(;;) {
			(r, err) := lsrv.searchresp();
			if(err != nil)
				error("search response: "+err);
			if(r == nil)
				break;
			printsearch(r);
		}
		
	"fetch" =>
		if(rtype != ALL && rtype != LINKS && rtype != FIRST) {
			warn("bad type");
			arg->usage();
		}
		(title, artist) := (hd args, hd tl args);
		fetcherr := lsrv.fetch(artist, title, sites, rtype);
		if(fetcherr != nil)
			error("fetch request: "+fetcherr);
		for(;;) {
			(r, l, err) := lsrv.fetchresp();
			if(err != nil)
				error("fetch response: "+err);
			if(r == nil && l == nil)
				break;
			if(r != nil)
				printsearch(r);
			if(l != nil)
				printlyric(l);
		}

	* =>
		warn("bad request");
		arg->usage();
	}
}

printsearch(r: ref Lyrics->Result)
{
	if(r.hit) {
		print("# result for %s: %s\n", r.site, r.id);
		if(vflag)
			print("%s -a %s get %s %s\n", progname, addr, r.site, r.id);
	} else {
		print("# nothing for %s\n", r.site);
	}
}

printlyric(l: ref Lyrics->Lyric)
{
	if(vflag)
		print("From %s (%s):\n\n", l.site, l.id);
	else
		print("From %s:\n\n", l.site);
	print("%s\n", l.text);
}

warn(s: string)
{
	fprint(sys->fildes(2), "%s\n", s);
}

error(s: string)
{
	fprint(sys->fildes(2), "%s\n", s);
	raise "fail:"+s;
}

nomod(m: string)
{
	sys->fprint(sys->fildes(2), "loading %s: %r\n", m);
	raise "fail:load";
}
