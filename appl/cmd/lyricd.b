implement Lyricd;

include "sys.m";
include "draw.m";
include "arg.m";
include "string.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "regex.m";
include "cgi.m";
include "lyricutils.m";

sys: Sys;
str: String;
fprint, print, sprint: import sys;
lyricutils: Lyricutils;
Link, Lyric, split, splitcl, append: import lyricutils;


Lyricd: module {
	init:	fn(nil: ref Draw->Context, args: list of string);
};


version: con "pylyrics-12";

addr := "net!localhost!7115";
dflag := 0;
timeout := 10;	# seconds

files := array[] of {"azlyrics", "elyrics", "lyrc", "sing365", "rarelyrics", "lyricsdownload", "plyrics", "darklyrics"};
sites: array of Site;
sitenames: string;


init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	str = load String String->PATH;
	arg := load Arg Arg->PATH;
	bufio = load Bufio Bufio->PATH;
	lyricutils = load Lyricutils Lyricutils->PATH;
	if(lyricutils == nil)
		error(sprint("loading lyricutils: %r"));
	lyricutils->init();

	arg->init(args);
	arg->setusage("lyricd [-d] [-a addr]");
	while((c := arg->opt()) != 0)
		case c {
		'd' =>	dflag = 1;
		'a' =>	addr = arg->earg();
		}
	args = arg->argv();
	if(len args != 0)
		arg->usage();

	sites = array[len files] of Site;
	for(i := 0; i < len files; i++) {
		disfile := "/dis/lib/lyricd/"+files[i]+".dis";
		sites[i] = load Site disfile;
		if(sites[i] == nil)
			error(sprint("loading %s: %r", disfile));
		sites[i]->init();

		if(sitenames != "")
			sitenames += ",";
		sitenames += sites[i]->name;
	}

	(aok, aconn) := sys->announce(addr);
	if(aok != 0)
		error(sprint("announce %s: %r", addr));

	for(;;) {
		(lok, lconn) := sys->listen(aconn);
		if(lok != 0) {
			say(sprint("listen: %r"));
			continue;
		}
		fd := sys->open(lconn.dir+"/data", sys->ORDWR);
		if(fd == nil) {
			say(sprint("accepting: %r"));
			continue;
		}
		spawn serve(fd);
		fd = nil;
	}
}

serve(fd: ref Sys->FD)
{
	pid := sys->pctl(sys->NEWPGRP, nil);
	cfd := sys->open("/prog/"+string pid+"/ctl", sys->OWRITE);
	fprint(cfd, "exceptions notifyleader");
	cfd = nil;

	bio := bufio->fopen(fd, bufio->OREAD);
	if(bio == nil)
		return say(sprint("bufio fopen: %r"));

	{
		write(fd, version);
		cversion := read(bio);
		if(version != cversion)
			return say("different protocol version, client has "+cversion);

		write(fd, sitenames);
		while(cmd(fd, bio))
			;
	} exception e {
	"read error*" or "write error*" =>
		say("network "+e);
	}
}

cmd(fd: ref Sys->FD, bio: ref Iobuf): int
{
	case op := read(bio) {
	"get" =>
		sitename := read(bio);
		url := read(bio);
		site: Site;
		for(i := 0; i < len sites; i++)
			if(sites[i]->name == sitename) {
				site = sites[i];
				break;
			}
		if(site == nil)
			return respond(fd, sitename, "failure", url, "no such site: "+sitename);
		(lyric, err) := site->get(url);
		if(err != nil)
			return respond(fd, sitename, "failure", url, err);
		if(lyric.text == nil)
			return respond(fd, sitename, "failure", url, "lyric empty");
		return respond(fd, sitename, "success", url, lyric.text);

	"search" or "fetch" =>
		artist := read(bio);
		title := read(bio);
		if(title == "") {
			say("title must be non-empty");
			return 0;
		}
		snamestr := read(bio);
		(ssites, err) := findsites(snamestr);
		if(err != nil) {
			say("bad sites: "+snamestr);
			return 0;
		}

		firsthit: string;
		withget := 0;
		case op {
		"search" =>
			firsthit = "first";
			if(read(bio) == nil)
				firsthit = "all";
		"fetch" =>
			withget = 1;
			firsthit = read(bio);
			if(firsthit != "all" && firsthit != "first" && firsthit != "links") {
				say("invalid firsthit value");
				return 0;
			}
		}
		return searchget(fd, ssites, artist, title, withget, firsthit);
		
	* =>
		write(fd, "invalid command: "+op);
		return 0;
	}
	return 1;
}

timer(ch: chan of int)
{
	sys->sleep(timeout*1000);
	ch <-= 0;
}


findsites(nstr: string): (array of Site, string)
{
	if(nstr == nil)
		return (sites, nil);

	ns := split(nstr, ",");
	ss := array[len ns] of Site;

	i := 0;
loop:
	for(; ns != nil; ns = tl ns) {
		name := hd ns;
		for(j := 0; j < len sites; j++)
			if(name == sites[j]->name) {
				ss[i++] = sites[j];
				continue loop;
			}
		return (nil, "no such site: "+name);
	}
	return (ss, nil);
}

search(site: Site, title, artist: string, ch: chan of (list of ref Link, string, string))
{
	(links, err) := site->search(splitcl(str->tolower(title), " \t"), splitcl(str->tolower(artist), " \t"));
	ch <-= (links, site->name, err);
}

get(sitename: string, url: string, ch: chan of (ref Lyric, string, string, string))
{
	for(i := 0; i < len sites; i++)
		if(sites[i]->name == sitename) {
			(lyric, err) := sites[i]->get(url);
			ch <-= (lyric, sitename, url, err);
			return;
		}
	ch <-= (nil, sitename, url, "get: unknown site: "+sitename);
}

searchget(fd: ref Sys->FD, ssites: array of Site, artist, title: string, withget: int, firsthit: string): int
{
	lyricchan := chan of (ref Lyric, string, string, string);
	linkchan := chan of (list of ref Link, string, string);
	for(i := 0; i < len ssites; i++)
		spawn search(ssites[i], title, artist, linkchan);
	timerch := chan of int;
	spawn timer(timerch);
	ntimer := 1;

	nlinkprocs := len ssites;
	nlyricprocs := 0;
	havelyric := 0;
	llinks: list of ref Link;
	done := 0;
	ok := 1;
loop:
	while(nlyricprocs+nlinkprocs > 0) {
		alt {
		(links, name, err) := <- linkchan =>
			nlinkprocs--;
			if(err != nil) {
				say("search error: "+err);
				break;
			}
			if(len links == 0) {
				if(withget)
					write(fd, "search");
				write(fd, sprint("miss %s  ", name));
			} else {
				for(l := links; l != nil; l = tl l) {
					link := hd l;
					if(withget)
						write(fd, "search");
					write(fd, sprint("hit %s %.2f %s", link.site, real link.score/100.0, link.url));
				}

				if(withget && (!havelyric || firsthit != "links")) {
					if(firsthit != "all") {
						llinks = append(llinks, tl links);
						links = hd links::nil;
					}
					for(l = links; l != nil; l = tl l) {
						link := hd l;
						spawn get(link.site, link.url, lyricchan);
						nlyricprocs++;
					}
				} else {
					if(firsthit == "first")
						break;
				}
			}

		(lyric, site, url, err) := <- lyricchan =>
			nlyricprocs--;
			if(havelyric && firsthit != "all")
				break;

			if(err != nil) {
				write(fd, "get");
				write(fd, "failure");
				write(fd, site);
				write(fd, url);
				write(fd, "0.00");
				writemsg(fd, "error retrieving lyric: "+err);
			} else {
				write(fd, "get");
				write(fd, "success");
				write(fd, lyric.site);
				write(fd, lyric.url);
				write(fd,  sprint("%.2f", real lyric.score/100.0));
				writemsg(fd, lyric.text);
				havelyric = 1;
				if(firsthit == "first")
					break;
			}

		<- timerch =>
			ntimer--;
			# xxx should have protocol message for timeout?  or send misses for all unanswered requests
			# or just have "done" before all responses implicate timeout?
			ok = 0;
			break loop;
		}

		if(!havelyric && withget && len llinks > 0 && nlyricprocs == 0) {
			link := hd llinks;
			llinks = tl llinks;
			spawn get(link.site, link.url, lyricchan);
			nlyricprocs++;
		}
		if(!done && havelyric && nlinkprocs == 0) {
			done = 1;
			write(fd, "done");
		}
	}

	if(!done)
		write(fd, "done");

	spawn reaper(linkchan, nlinkprocs, lyricchan, nlyricprocs, timerch, ntimer);
	return ok;
}

reaper(linkc: chan of (list of ref Link, string, string), nlink: int, lyricc: chan of (ref Lyric, string, string, string), nlyric: int, timerc: chan of int, ntimer: int)
{
	while(nlink > 0 || nlyric > 0 || ntimer > 0)
		alt {
		<-linkc =>	nlink--;
		<-lyricc =>	nlyric--;
		<-timerc =>	ntimer--;
		}
}

respond(fd: ref Sys->FD, site, status, url, text: string): int
{
	write(fd, status);
	write(fd, site);
	write(fd, url);
	write(fd, "0.0");
	writemsg(fd, text);
	return 1;
}

write(fd: ref Sys->FD, s: string)
{
	if(fprint(fd, "%s\n", s) < 0)
		raise sprint("write error: %r");
	say("> "+s);
}

writemsg(fd: ref Sys->FD, s: string)
{
	for(l := split(s, "\n"); l != nil; l = tl l) {
		line := hd l;
		if(line != nil && line[0] == '.')
			line = "."+line;
		write(fd, line);
	}
	write(fd, ".");
}

read(bio: ref Iobuf): string
{
	l := bio.gets('\n');
	if(l == nil)
		raise sprint("read error");
	if(l != nil && l[len l - 1] == '\n')
		l = l[:len l - 1];
	if(l != nil && l[len l - 1] == '\r')
		l = l[:len l - 1];
	say("< "+l);
	return l;
}

error(s: string)
{
	fprint(sys->fildes(2), "%s\n", s);
	raise "fail:"+s;
}

say(s: string)
{
	fprint(sys->fildes(2), "%s\n", s);
}
