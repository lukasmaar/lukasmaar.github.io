#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use JSON::PP qw(decode_json);

# Emits the per-section navbar dropdown items (year: count) from the JSON data,
# so build.sh does not need to hardcode a year window.
#
# Usage: render_topbar_years.pl <data-dir> <out-dir>
# Writes: <out-dir>/topbar-{blog,publications,talks,awards}.html

my ($data_dir, $out_dir) = @ARGV;
die "Usage: $0 <data-dir> <out-dir>\n" if !defined $data_dir || !defined $out_dir;

sub load {
  my ($path) = @_;
  open(my $fh, '<', $path) or die "Cannot open $path: $!\n";
  local $/;
  my $d = decode_json(<$fh>);
  close($fh);
  die "Expected JSON array in $path\n" if ref($d) ne 'ARRAY';
  return $d;
}

sub write_items {
  my ($section, $counts, $out_dir) = @_;
  my $out = '';
  for my $year (sort { $b <=> $a } keys %$counts) {
    my $n = $counts->{$year};
    $out .= qq{          <a class="dropdown-item" href="{{INDEX_PREFIX}}index.html#${section}${year}">${year}: ${n}</a>\n};
  }
  my $path = "$out_dir/topbar-$section.html";
  open(my $fh, '>:encoding(UTF-8)', $path) or die "Cannot write $path: $!\n";
  print {$fh} $out;
  close($fh);
}

# blog / publications / talks: one entry per JSON element.
for my $section (qw(blog publications talks)) {
  my $entries = load("$data_dir/$section.json");
  my %counts;
  $counts{$_->{year}}++ for @$entries;
  write_items($section, \%counts, $out_dir);
}

# awards: count individual items[] per year.
{
  my $entries = load("$data_dir/awards.json");
  my %counts;
  for my $e (@$entries) {
    my $items = (ref($e->{items}) eq 'ARRAY') ? $e->{items} : [];
    $counts{$e->{year}} += scalar(@$items);
  }
  write_items('awards', \%counts, $out_dir);
}
