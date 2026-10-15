#!/usr/bin/perl
# tools/lineids.pl  -  Phase 5 tests 2 and 6 (docs/18): every line id of docs/05 appears exactly once in
# src/ReplicatedStorage/Shared/Dialogue, and no line is over 120 characters. Run: perl tools/lineids.pl .
use strict; use warnings;
my $root = shift or die "root?";
open my $d, '<:encoding(UTF-8)', "$root/docs/05_chapter1_script.md" or die;
my %doc; my $scene = "";
while (my $l = <$d>) {
	$scene = $1 if $l =~ /^## (S\d\d)/;
	# "ID | speaker | text" lines in the script blocks
	# (radio speakers are written [M]; conditional lines start with [if FLAG])
	if ($l =~ /^\s*(?:\[if [^\]]+\]\s*)?([A-Z][A-Z0-9_]*\d[A-Za-z0-9_]*)\s*\|\s*\[?[A-Z]+\]?\s*\|/) { $doc{$1} //= $scene; }
	# inline `ID | S | text` in prose
	while ($l =~ /`([A-Z][A-Z0-9_]*\d[a-z]?)\s*\|\s*\[?[A-Z]+\]?\s*\|/g) { $doc{$1} //= $scene; }
	# inline ids in tables: `S02_PHOTO_1 [E-thought] ...`
	while ($l =~ /`([A-Z][A-Z0-9]*_[A-Z0-9_]*\d[a-z]?)\s+(?:\[|[A-Z]{1,2}\s)/g) { $doc{$1} //= $scene; }
}
close $d;
my %data; my %text;
for my $f (glob("$root/src/ReplicatedStorage/Shared/Dialogue/*.lua")) {
	next if $f =~ /Speakers/;
	open my $h, '<:encoding(UTF-8)', $f or die; local $/; my $s = <$h>; close $h;
	# { "MH_01", "M", "text" ...  (chain entries)
	while ($s =~ /\{\s*"([A-Z][A-Z0-9_]*\d[a-z]?)",\s*"[A-Z]+",\s*"((?:[^"\\]|\\.)*)"/g) { $data{$1}++; $text{$1} = $2; }
	# single("radio", "PA_A1", "PA", "text"
	while ($s =~ /single\("\w+",\s*"([A-Z][A-Z0-9_]*\d[a-z]?)",\s*"[A-Z]+",\s*"((?:[^"\\]|\\.)*)"/g) { $data{$1}++; $text{$1} = $2; }
	# S02_PHOTO_1 = { speaker = ..., text = "..." }   and   MH_10 = { speaker = "M", text = "..."
	while ($s =~ /\b([A-Z][A-Z0-9_]*\d[a-z]?)\s*=\s*\{\s*speaker\s*=\s*"[A-Z]+",[^}]*?text\s*=\s*"((?:[^"\\]|\\.)*)"/g) { $data{$1}++; $text{$1} = $2; }
}
my (@missing, @dupes, @long, @extra);
for my $id (sort keys %doc) { push @missing, "$id ($doc{$id})" unless $data{$id}; }
for my $id (sort keys %data) {
	push @dupes, "$id x$data{$id}" if $data{$id} > 1;
	push @extra, $id unless $doc{$id};
	my $t = $text{$id}; $t =~ s/\\"/"/g;
	push @long, "$id (" . length($t) . ")" if length($t) > 120;
}
printf "doc ids: %d, data ids: %d\n", scalar(keys %doc), scalar(keys %data);
print "missing from data: ", scalar(@missing), "\n  ", join(", ", @missing), "\n";
print "duplicated in data: ", join(", ", @dupes) || "none", "\n";
print "in data, not in doc: ", join(", ", @extra) || "none", "\n";
print "over 120 chars: ", join(", ", @long) || "none", "\n";
