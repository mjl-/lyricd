Lyrics: module {
	PATH:	con "/dis/lib/lyrics.dis";

	VERSION: con "pylyrics-12";
	FIRST, LINKS, ALL: con iota;

	connect:	fn(addr: string): (ref Lsrv, string);

	Result: adt {
		hit: int;
		site, id: string;
		score: real;
	};
	Lyric: adt {
		success: int;
		site, id: string;
		score: real;
		text: string;
	};
		
	Lsrv: adt {
		fd:	ref Sys->FD;
		in:	ref Iobuf;
		sites:	list of string;
		version:	string;
		get:		fn(lsrv: self ref Lsrv, site, id: string): (ref Lyric, string);
		search:		fn(lsrv: self ref Lsrv , artist, title: string, sites: list of string, one: int): string;
		searchresp:	fn(lsrv: self ref Lsrv): (ref Result, string);
		searchrespall:	fn(lsrv: self ref Lsrv): (list of ref Result, string);
		fetch:		fn(lsrv: self ref Lsrv, artist, title: string, sites: list of string, one: int): string;
		fetchresp:	fn(lsrv: self ref Lsrv): (ref Result, ref Lyric, string);
	};
};
