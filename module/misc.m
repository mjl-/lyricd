Misc: module
{
	PATH:	con "/dis/lib/misc.dis";
	init:	fn();
	rdstr:	fn(b: ref Iobuf, sep, clearsep: int): string;
	strip:	fn(s, cl: string): string;
	join:	fn(l: list of string, s: string): string;
	reverse:	fn(l: list of string): list of string;
	readfile:	fn(fd: ref Sys->FD): array of byte;
	sha1:	fn(a: array of byte): string;
	md5:	fn(a: array of byte): string;
	warn, warnx, error, errorx, debug, debugx:	fn(s: string);
	suffix:	fn(suf, s: string): int;
	infix:	fn(instr, s: string): int;
	hasmatch:	fn(restr, s: string): int;
	rematch:	fn(restr, s: string): (array of string, string);
	match:		fn(re: Regex->Re, s: string): array of string;
	matchall:	fn(re: Regex->Re, s: string): list of array of string;
	has:		fn(l: list of string, s: string): int;
	split:		fn(s, splitstr: string): list of string;
	splitcl:	fn(s, splitcl: string): list of string;
	taketl:		fn(s, cl: string): string;
	droptl:		fn(s, cl: string): string;
	insertsort:	fn[T](a: array of T)
		for { T =>	cmp:     fn(a, b: T): int; };
	qsort:	fn[T](a: array of T)
		for { T =>	cmp:     fn(a, b: T): int; };
};
