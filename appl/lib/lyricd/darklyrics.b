implement Site;

include "lyricsite.m";

modname := "darklyrics";
urls := array[] of {"http://www.darklyrics.com/"};

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

lyricurl(url: string, title: list of string): string
{
	(body, err) := httpget(url, nil);
	if(err != nil)
		return nil;
	say("have lyric html");
	rstr := "<a href=\"#([0-9]+)\">([^<]*)</a><br>";
	hits := findall(rstr, body);
	say(sprint("lyric page has %d lyrics", len hits));
	
	for(i := 0; i < len hits; i++)
		if(score(str->tolower(hits[i][2]), title) >= 80) {
			say("lyric page does have lyric, id: "+hits[i][1]);
			return url+"#"+string int hits[i][1];
		}
	say("lyric page does not have lyric");
	return nil;
}

search(title, artist: list of string): (list of ref Link, string)
{
	terms := rev(artist);
	for(l := rev(title); l != nil; l = tl l)
		terms = hd l::terms;

	args := list of {("q", join(terms, " "))};
	url := "http://search.darklyrics.com/cgi-bin/dseek.cgi?"+cgi->pack(args);
	say("searching in url="+url);
	(body, err) := httpget(url, nil);
	if(err != nil)
		return (nil, err);
	say("have html");

	rstr := "<a href=\"(http://www.darklyrics.com/lyrics/.*\\.html)\".*><b>(.*) LYRICS - (.*)</b></a>";
	hits := findall(rstr, body);
	say(sprint("have %d hits", len hits));
	links := array[3] of ref Link;
	j := 0;
	for(i := 0; i < len hits; i++) {
		lurl := hits[i][1];
		lartist := htmlstrip(hits[i][2]);
		ltitle := htmlstrip(hits[i][3]);
		if((artist != nil || score(lurl, artist) >= 50) && (lurl = lyricurl(lurl, title)) != nil)
			links[j++] = Link.mk(lartist, ltitle, lurl, name, 0);
		if(j >= 3)
			break;
	}
	links = links[:j];
	return (rate(links, BY_ARTIST|BY_TITLE, title, artist), nil);
}


get(url: string): (ref Lyric, string)
{
	if(!urlallow(url, urls))
		return (nil, "bad url");

	numstr: string;
	(url, numstr) = str->splitstrr(url, "#");
	if(numstr == nil && url != nil)
		return (nil, "bad url");
	url = url[:len url-1];
	num := int numstr;

	(body, err) := httpget(url, nil);
	if(err != nil)
		return (nil, err);
	say("have html");

	text: string;
	rstr := sprint("<a name=%d><font color=#DDDDDD><b>.*</b></font><br>(([.\n]*.*)*)<a name=%d", num, num+1);
	hit := find(rstr, body);
	if(hit != nil) {
		text = hit[1];
	} else {
		rstr = sprint("<a name=%d><font color=#DDDDDD><b>.*</b></font><br>(([.\n]*.*)*)<br>", num);
		hit = find(rstr, body);
		if(hit == nil) {
			say("no lyric in html");
			return (nil, "no lyric found");
		}
		text = hit[1];
		rstr2 := sprint("(([.\n]*.*)*)<font size=1 color=#FFFFCC>.*");
		hit2 := find(rstr2, text);
		if(hit2 != nil) {
			say("found trailer in lyric, removing");
			text = hit2[1];
		}
	}
	text = sanitize(text);
	say("have lyric");
	return (Lyric.mk(name, url, text, 0), nil);
}

say(s: string)
{
	fprint(sys->fildes(2), "%s: %s\n", name, s);
}
