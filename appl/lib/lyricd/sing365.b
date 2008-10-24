implement Site;

include "lyricsite.m";

modname := "sing365";
urls := array[] of {"http://www.sing365.com/"};

fprint, sprint: import sys;


init()
{
	sys = load Sys Sys->PATH;
	str = load String String->PATH;
	cgi = load Cgi Cgi->PATH;
	lyricutils = load Lyricutils Lyricutils->PATH;

	if(cgi == nil)
		raise "fail:loading modules";
	cgi->init();
	lyricutils->init();

	name = modname;
}

search(title, artist: list of string): (list of ref Link, string)
{
	terms := rev(artist);
	for(l := rev(title); l != nil; l = tl l)
		terms = hd l::terms;

	hits := googlesearch("www.sing365.com", title, artist);
	say(sprint("have %d raw hits", len hits));

	links := array[len hits] of ref Link;
	j := 0;
	for(i := 0; i < len hits; i++) {
		(url, nil) := hits[i];
		if(hasterms(url, "-lyrics-"::"/lyric.nsf/"::terms))
			links[j++] = Link.mk(join(artist, " "), join(title, " "), url, modname, 0);
	}
	links = links[:j];
	return (rate(links, BY_URL, title, artist), nil);
}

get(url: string): (ref Lyric, string)
{
	if(!urlallow(url, urls))
		return (nil, "bad url");

	(body, err) := httpget(url, nil);
	if(err != nil)
		return (nil, err);
	say("have html");

	#restr := "<font color=Blue>Print the Lyrics</font></a><br></TD></TR>\n</TABLE>(([.\n]*.*)*)<hr size=1 color=#cccccc>If you find some error in";
	restr := "<br><br></div>(([.\n]*.*)*)<br>\n<div align=\"center\"><br><br>";
	hit := find(restr, body);
	if(hit == nil) {
		say("no lyric found");
		return (nil, "no lyric found");
	}
	text := hit[1];
	text = sanitize(text);
	say("have lyric");
	return (Lyric.mk(name, url, text, 0), nil);
}

say(s: string)
{
	fprint(sys->fildes(2), "%s: %s\n", name, s);
}
