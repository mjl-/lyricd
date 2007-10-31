implement Site;

include "lyricsite.m";

modname := "elyrics";
urls := array[] of {"http://www.elyrics.net/"};

fprint, sprint: import sys;


init()
{
	sys = load Sys Sys->PATH;
	str = load String String->PATH;
	cgi = load Cgi Cgi->PATH;
	misc = load Misc Misc->PATH;
	lyricutils = load Lyricutils Lyricutils->PATH;

	if(cgi == nil || misc == nil)
		raise "fail:loading modules";
	cgi->init();
	misc->init();
	lyricutils->init();

	name = modname;
}

search(title, artist: list of string): (list of ref Link, string)
{
	terms := rev(artist);
	for(l := rev(title); l != nil; l = tl l)
		terms = hd l::terms;

	hits := googlesearch("www.elyrics.net", title, artist);
	say(sprint("have %d raw hits", len hits));

	links: list of ref Link;
	for(i := 0; i < len hits; i++) {
		(url, nil) := hits[i];
		if(!misc->infix("/read/", url))
			continue;
		link := Link.mk(join(artist, " "), join(title, " "), url, modname, score(url, terms));
		if(link.score < 60)
			continue;
		links = link::links;
	}
	say(sprint("have %d hits", len links));
	return (rate(l2a(links), BY_URL, title, artist), nil);
}

get(url: string): (ref Lyric, string)
{
	if(!urlallow(url, urls))
		return (nil, "bad url");

	(body, err) := httpget(url, "latin1");
	if(err != nil)
		return (nil, err);
	say("have html");

	rstr := "<strong>[^<]* lyrics</strong>(([.\n]*.*)*)<!-- .* Lyrics -->";
	hit := find(rstr, body);
	if(hit == nil)
		return (nil, "no lyric found");
	text := hit[1];
	text = sanitize(text);
	say("have lyric");
	return (Lyric.mk(name, url, text, 0), nil);
}

say(s: string)
{
	fprint(sys->fildes(2), "%s: %s\n", name, s);
}
