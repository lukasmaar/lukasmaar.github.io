#!/usr/bin/env perl
use strict;
use warnings;
use JSON::PP;
use File::Path qw(make_path);

my $root = shift // die "usage: $0 <repo-root>\n";
my $src = "$root/templates/partials/index/publications-section.html";
my $out_dir = "$root/templates/data/publications";
my $json_path = "$root/templates/data/publications.json";

open(my $fh, '<', $src) or die "cannot open $src: $!\n";
my @lines = <$fh>;
close($fh);

make_path($out_dir);

my @entries;
my $current_year = undef;
my %year_seq;

for (my $i = 0; $i <= $#lines; $i++) {
  my $line = $lines[$i];

  if ($line =~ /<span id="publications(\d{4})" class="anchor">/) {
    $current_year = int($1);
    next;
  }

  next unless defined $current_year;

  if ($line =~ /^\s*<div class="row">\s*$/ && $i + 1 <= $#lines && $lines[$i + 1] =~ /^\s*<div class="timeline-entry">\s*$/) {
    my $depth = 0;
    my @block;
    my $j = $i;

    for (; $j <= $#lines; $j++) {
      my $ln = $lines[$j];
      push @block, $ln;

      my $opens = () = ($ln =~ /<div\b/g);
      my $closes = () = ($ln =~ /<\/div>/g);
      $depth += $opens - $closes;

      if ($depth == 0) {
        last;
      }
    }

    die "unbalanced div block around line $i\n" if $depth != 0;

    $year_seq{$current_year}++;
    my $seq = $year_seq{$current_year};
    my $fname = sprintf("publications-%d-%02d.html", $current_year, $seq);
    my $rel = "templates/data/publications/$fname";

    open(my $out, '>', "$root/$rel") or die "cannot write $rel: $!\n";
    print {$out} @block;
    close($out);

    push @entries, {
      year => $current_year,
      entry_file => $rel,
    };

    $i = $j;
  }
}

my $json = JSON::PP->new->ascii->pretty->canonical->encode(\@entries);
open(my $jf, '>', $json_path) or die "cannot write $json_path: $!\n";
print {$jf} $json;
close($jf);

print "Wrote $json_path with " . scalar(@entries) . " entries\n";
