implement Misc;

include "sys.m";
	sys: Sys;
include "draw.m";
include "string.m";
	str: String;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "keyring.m";
	keyring: Keyring;
include "regex.m";
	regex: Regex;
include "misc.m";

fprint, print: import sys;


rdstr(b: ref Iobuf, sep, clearsep: int): string
{
	s := b.gets(sep);
	if(s == "")
		return s;
	if(s[len s - 1] == sep && clearsep)
		s = s[:len s - 1];
	return s;
}

droptl(s, cl: string): string
{
	while(s != nil)
		if(str->in(s[len s - 1], cl))
			s = s[:len s - 1];
		else
			break;
	return s;
}

strip(s, cl: string): string
{
	return str->drop(droptl(s, cl), cl);
}

join(l: list of string, s: string): string
{
	r := "";
	middle := 0;
	for(; l != nil; l = tl l) {
		if(middle)
			r += s;
		r += hd l;
		middle = 1;
	}
	return r;
}

reverse(l: list of string): list of string
{
	r: list of string;
	for(; l != nil; l = tl l)
		r = hd l :: r;
	return r;
}


readfile(fd: ref Sys->FD): array of byte
{
	(ok, d) := sys->fstat(fd);
	if(ok != 0)
		raise sys->sprint("fstat-ing file (%d)", ok);
	a := array[int d.length] of byte;
	buf := array[8*1024] of byte;
	n := 0;
	for(;;) {
		have := sys->read(fd, buf, 8*1024);
		if(have == 0)
			break;
		if(have < 0)
			raise "reading from file";
		if(n+have > len a) {
			anew := array[n+have] of byte;
			anew[:] = a[:n];
			a = anew;
		}
		a[n:] = buf[:have];
		n += have;
	}
	return a[:n];
}

byte2str(a: array of byte): string
{
	s := "";
	for(i := 0; i < len a; i++)
		s += sys->sprint("%02x", int a[i]);
	return s;
}

sha1(a: array of byte): string
{
	r := array[keyring->SHA1dlen] of byte;
	keyring->sha1(a, len a, r, nil);
	return byte2str(r);
}

md5(a: array of byte): string
{
	r := array[keyring->MD5dlen] of byte;
	keyring->md5(a, len a, r, nil);
	return byte2str(r);
}

warn(s: string)
{
	sys->fprint(sys->fildes(2), "%s: %r\n", s);
}

warnx(s: string)
{
	sys->fprint(sys->fildes(2), "%s\n", s);
}

error(s: string)
{
	warn(s);
	raise sys->sprint("fail:%s: %r", s);
}

errorx(s: string)
{
	warnx(s);
	raise sys->sprint("fail:%s", s);
}

debug(s: string)
{
	sys->fprint(sys->fildes(2), "%s: %r\n", s);
}

debugx(s: string)
{
	sys->fprint(sys->fildes(2), "%s\n", s);
}

suffix(suf, s: string): int
{
	if(len suf > len s)
		return 0;
	for(i := 0; i < len suf; i++)
		if(s[len s - i - 1] != suf[len suf - i - 1])
			return 0;
	return 1;
}

infix(instr, s: string): int
{
	for(i := 0; i < len s - len instr + 1; i++)
		if(str->prefix(instr, s[i:]))
			return 1;
	return 0;
}


hasmatch(restr, s: string): int
{
	(re, err) := regex->compile(restr, 0);
	if(err != nil)
		return 0;
	a := regex->execute(re, s);
	if(a == nil)
		return 0;
	return 1;
}

rematch(restr, s: string): (array of string, string)
{
	(re, err) := regex->compile(restr, 1);
	if(err != nil)
		return (nil, sys->sprint("compiling regex %q: %s", restr, err));
	return (match(re, s), nil);
}

match(re: Regex->Re, s: string): array of string
{
	a := regex->executese(re, s, (0, len s), 1, 1);
	if(a == nil)
		return nil;
	e := array[len a] of string;
	for(i := 0; i < len a; i++) {
		(start, end) := a[i];
		if(start == -1 || end == -1)
			e[i] = nil;
		else
			e[i] = s[start:end];
	}
	return e;
}

matchall(re: Regex->Re, s: string): list of array of string
{
	se := (0, len s);
	l: list of array of string;
	for(;;) {
		a := regex->executese(re, s, se, 1, 1);
		if(a == nil)
			break;
		e := array[len a] of string;
		for(i := 0; i < len a; i++) {
			(start, end) := a[i];
			if(start == -1 || end == -1)
				e[i] = "";
			else
				e[i] = s[start:end];
		}
		(nil, end) := a[0];
		se = (end, len s);
		l = e :: l;
	}
	return rev(l);
}

rev[t](l: list of t): list of t
{
	r: list of t;
	for(; l != nil; l = tl l)
		r = hd l :: r;
	return r;
}

has(l: list of string, s: string): int
{
	for(; l != nil; l = tl l)
		if(s == hd l)
			return 1;
	return 0;
}

split(s, splitstr: string): list of string
{
	l: list of string;
	for(;;) {
		(left, right) := str->splitstrl(s, splitstr);
		l = left::l;
		if(right == nil)
			break;
		s = right[len splitstr:];
	}
	return rev(l);
}

splitcl(s, splitcl: string): list of string
{
	l: list of string;
	for(;;) {
		(left, right) := str->splitl(s, splitcl);
		l = left::l;
		if(right == nil)
			break;
		s = right[1:];
	}
	return rev(l);
}

taketl(s, cl: string): string
{
	i := len s;
	while(i >= 0)
		if(str->in(s[i-1], cl))
			i--;
		else
			break;
	return s[i:];
}

insertsort[T](a: array of T)
	for { T =>	cmp:	fn(a, b: T): int; }
{
	for(i := 1; i < len a; i++) {
		tmp := a[i];
		for(j := i; j > 0 && T.cmp(a[j-1], tmp) > 0; j--)
			a[j] = a[j-1];
		a[j] = tmp;
	}
}

_qsort[T](a: array of T, left, right: int)
	for { T =>	cmp:	fn(a, b: T): int; }
{
	if(left >= right)
		return;
	store := left;
	for(i := left; i < right; i++)
		if(T.cmp(a[i], a[right]) <= 0) {
			(a[store], a[i]) = (a[i], a[store]);
			store++;
		}
	(a[store], a[right]) = (a[right], a[store]);
	_qsort(a, left, store-1);
	_qsort(a, store+1, right);
}

qsort[T](a: array of T)
	for { T =>	cmp:	fn(a, b: T): int; }
{
	_qsort(a, 0, len a-1);
}

insertsort2[T](a: array of T)
	for { T =>	cmp:	fn(a, b: T): int; }
{
	for(i := 0; i < len a; i++)
		for(j := 0; j < i; j++) # xxx use binary search?
			if(T.cmp(a[i], a[j]) > 0) {
				tmp := a[i];
				for(k := i; k > j; k--)
					a[k] = a[k-1];
				a[j] = tmp;
				break;
			}
}


init()
{
	sys = load Sys Sys->PATH;
	str = load String String->PATH;
	bufio = load Bufio Bufio->PATH;
	keyring = load Keyring Keyring->PATH;
	regex = load Regex Regex->PATH;
	if(sys == nil || str == nil || bufio == nil || keyring == nil || regex == nil)
		raise "fail:loading sys,str,bufio,keyring,regex";
}
