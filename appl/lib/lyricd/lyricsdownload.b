implement Site;

include "lyricsite.m";

modname := "lyricsdownload";
urls := array[] of {"http://www.lyricsdownload.com/", "http://lyricsdownload.com/"};

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

	hits := googlesearch("lyricsdownload.com", title, artist);
	say(sprint("have %d raw hits", len hits));

	links := array[len hits] of ref Link;
	j := 0;
	for(i := 0; i < len hits; i++) {
		(url, nil) := hits[i];
		if(!infix("-lyrics.html", url) || score(url, title) < 60)
			continue;
		links[j++] = Link.mk(join(artist, " "), join(title, " "), url, modname, 0);
	}
	links = links[:j];
	say(sprint("have %d semi-raw hits", len links));
	rl := rate(links, BY_URL, title, artist);
	ll: list of ref Link;
	for(; rl != nil; rl = tl rl)
		if((hd rl).score < 75)
			break;
		else
			ll = hd rl::ll;
	return (ll, nil);
	say(sprint("have %d final hits", len ll));
	return (ll, nil);
}

get(url: string): (ref Lyric, string)
{
	if(!urlallow(url, urls))
		return (nil, "bad url");

	(body, err) := httpget(url, "latin1");
	if(err != nil)
		return (nil, err);
	say("have html");

	restr := "\n\t\t<font class=\"txt_1\">(([.\n]*.*)*)</font> </center>\n[ \t]*\n<br>";
	hit := find(restr, body);
	if(hit == nil) {
		say("no lyric found");
		return (nil, "no lyric found");
	}
	text := hit[1];
	say(sprint("have text, len %d", len text));
	text = replace(text, "\n<br />\n", "\n");
	text = sanitize(text);
	say("have lyric");
	return (Lyric.mk(name, url, text, 0), nil);
}

say(s: string)
{
	fprint(sys->fildes(2), "%s: %s\n", name, s);
}
