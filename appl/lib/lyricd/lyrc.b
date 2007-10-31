implement Site;

include "lyricsite.m";

modname := "lyrc";
urls := array[] of {"http://www.lyrc.com.ar/"};

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

	q := list of {
		("songname", join(title, " ")),
		("artist", join(artist, " ")),
	};
	url := "http://www.lyrc.com.ar/en/tema1en.php?"+cgi->pack(q);
	say("searching url="+url);

	(body, err) := httpget(url, "windows-1252");
	if(err != nil)
		return (nil, err);
	say("have search result html");

	restr1 := "Suggestions : <br>(.*)</form></font>";
	if(find(restr1, body) != nil) {
		say("received \"suggestion\", lyric not present");
		return (nil, nil);
	}

	restr2 := "<font size='2' *><b>(.*)</b><br><u>(<font size='2' *>)?([^<>]+)(</font>)?</u></font>";
	hit := find(restr2, body);
	if(hit == nil) {
		say("did not find expected lyric");
		return (nil, nil);
	}
	say("have match");
	t := htmlstrip(hit[1]);
	a := htmlstrip(hit[3]);

	links := Link.mk(a, t, url, modname, 0)::nil;
	return (rate(l2a(links), BY_URL|BY_ARTIST|BY_TITLE, title, artist), nil);
}

get(url: string): (ref Lyric, string)
{
	if(!urlallow(url, urls))
		return (nil, "bad url");

	(body, err) := httpget(url, "windows-1252");
	if(err != nil)
		return (nil, err);
	say("have html");

	rstr := "</td></tr></table>(([.\n]*.*)*)<br><br><a href=\"#\"";
	hit := find(rstr, body);
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
