#!/usr/bin/env perl
use strict;
use warnings;
use JSON::PP;

sub trim {
  my ($s) = @_;
  return '' if !defined $s;
  $s =~ s/^\s+//s;
  $s =~ s/\s+$//s;
  return $s;
}

sub squish {
  my ($s) = @_;
  $s = trim($s);
  $s =~ s/\s+/ /g;
  return $s;
}

my ($root) = @ARGV;
die "Usage: $0 <repo-root>\n" if !defined $root;

my $json_path = "$root/templates/data/publications.json";
open(my $jf, '<', $json_path) or die "Cannot open $json_path: $!\n";
local $/;
my $json_text = <$jf>;
close($jf);

my $index = JSON::PP::decode_json($json_text);
die "Expected publications.json array\n" if ref($index) ne 'ARRAY';

my @out;
for my $e (@$index) {
  my $year = $e->{year};
  my $entry_file = $e->{entry_file};
  die "Missing year/entry_file in index\n" if !defined($year) || !defined($entry_file);

  my $path = "$root/$entry_file";
  open(my $fh, '<', $path) or die "Cannot open $path: $!\n";
  local $/;
  my $block = <$fh>;
  close($fh);

  my ($href) = $block =~ /<a class="title" href="([^"]+)">/s;
  my ($title_raw) = $block =~ /<a class="title" href="[^"]+">\s*(.*?)\s*<\/a>/s;
  my $title = squish($title_raw // '');

  my ($small) = $block =~ /<small>\s*(.*?)\s*<\/small>/s;
  $small //= '';

  my ($authors, $rest) = $small =~ /\A(.*?)<br>\s*(.*)\z/s;
  my ($venue, $tail) = ($rest // '') =~ /\A(.*?)<br>\s*(.*)\z/s;
  $authors = trim($authors // '');
  $venue = trim($venue // '');
  $tail = trim($tail // '');

  my $badges_html = '';
  if ($tail =~ /\A<span class="text-muted">\s*(.*?)\s*<\/span>\s*<br>\s*(.*)\z/s) {
    $badges_html = trim($1);
    $tail = trim($2);
  }

  my @actions;
  while ($tail =~ /<span class="sbtn"(?:\s+onclick="toggleBox\('([^']+)'\)")?>\s*<a href="([^"]*)">\s*<i\s+class="fa\s+([^"]+)"><\/i>\s*(.*?)<\/a><\/span>/sg) {
    my ($target_id, $action_href, $icon, $label) = ($1, $2, $3, $4);
    push @actions, {
      kind => (defined($target_id) ? 'toggle' : 'link'),
      target_id => (defined($target_id) ? $target_id : undef),
      href => $action_href,
      icon => trim($icon),
      label => squish($label),
    };
  }

  my ($info_id, $info_class, $info_html) = $block =~ /<div id="([^"]+)" class="(infobox[^"]*)">\s*(.*?)\s*<\/div>/s;
  $info_html = trim($info_html // '');

  my ($bib_id, $bib_class, $bibtext) = $block =~ /<div id="([^"]+)" class="(box[^"]*)">\s*<pre class="pre-wrap">\s*(.*?)\s*<\/pre>\s*<\/div>/s;
  $bibtext = trim($bibtext // '');

  push @out, {
    year => $year + 0,
    href => ($href // ''),
    title => $title,
    authors => $authors,
    venue => $venue,
    badges_html => $badges_html,
    actions => \@actions,
    info => {
      id => ($info_id // ''),
      class => ($info_class // 'infobox is-hidden'),
      html => $info_html,
    },
    bibtex => {
      id => ($bib_id // ''),
      class => ($bib_class // 'box is-hidden'),
      text => $bibtext,
    },
  };
}

my $encoder = JSON::PP->new->canonical->pretty;
open(my $outf, '>', $json_path) or die "Cannot write $json_path: $!\n";
print {$outf} $encoder->encode(\@out);
close($outf);

print "Normalized publications data: " . scalar(@out) . " entries\n";
