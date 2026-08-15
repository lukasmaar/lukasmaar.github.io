#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use JSON::PP qw(decode_json);

sub esc {
  my ($s) = @_;
  return '' if !defined $s;
  $s =~ s/&/&amp;/g;
  $s =~ s/</&lt;/g;
  $s =~ s/>/&gt;/g;
  $s =~ s/"/&quot;/g;
  return $s;
}

my ($json_path, $out_path) = @ARGV;
die "Usage: $0 <talks.json> <talks-section.html>\n"
  if !defined $json_path || !defined $out_path;

open(my $in, '<', $json_path) or die "Cannot open $json_path: $!\n";
local $/;
my $json_text = <$in>;
close($in);

my $entries = decode_json($json_text);
die "Expected talks JSON array\n" if ref($entries) ne 'ARRAY';

my $html = "";
$html .= qq{    <div class="row">\n};
$html .= qq{      <div class="col-md-1">\n};
$html .= qq{      </div>\n};
$html .= qq{      <div class="col-md-10">\n};
$html .= qq{        <div class="timeline">\n\n};

my $current_year;
for my $e (@$entries) {
  my $year = $e->{year};
  die "Missing year in talks entry\n" if !defined $year;

  if (!defined($current_year) || $year ne $current_year) {
    $html .= qq{          <div class="row">\n};
    $html .= qq{            <div class="timeline-date">\n};
    $html .= qq{              <span id="talks$year" class="anchor">\n};
    $html .= qq{              </span>\n};
    $html .= qq{              <div class="col-xs-1">\n};
    $html .= qq{                <b>\n};
    $html .= qq{                  $year\n};
    $html .= qq{                </b>\n};
    $html .= qq{              </div>\n};
    $html .= qq{              <div class="col-xs-11">\n};
    $html .= qq{              </div>\n};
    $html .= qq{            </div>\n};
    $html .= qq{          </div>\n\n};
    $current_year = $year;
  }

  my $title = esc($e->{title});
  my $href = esc($e->{href});
  my $authors = defined($e->{authors}) ? $e->{authors} : '';
  my $venue = esc($e->{venue});
  my $links = $e->{links};
  $links = [] if !defined($links) || ref($links) ne 'ARRAY';

  $html .= qq{          <div class="row">\n};
  $html .= qq{            <div class="timeline-entry">\n};
  $html .= qq{              <div class="col-md-1">\n};
  $html .= qq{              </div>\n};
  $html .= qq{              <div class="col-md-11">\n};
  $html .= qq{                <i class="fa fa-television">\n};
  $html .= qq{                </i>\n};
  $html .= qq{                <a class="title" href="$href">\n};
  $html .= qq{                  $title\n};
  $html .= qq{                </a>\n};
  $html .= qq{                <br>\n};
  $html .= qq{                <small>\n};
  $html .= qq{                  $authors\n};
  $html .= qq{                  <br>\n};
  $html .= qq{                  $venue\n};

  if (@$links) {
    $html .= qq{                  <br>\n};
    for my $lnk (@$links) {
      my $lhref = esc($lnk->{href});
      my $licon = esc($lnk->{icon});
      my $llabel = esc($lnk->{label});
      $html .= qq{                  <span class="sbtn"><a href="$lhref"><i class="fa $licon"></i>\n};
      $html .= qq{                      $llabel</a></span>\n};
    }
  }

  $html .= qq{                </small>\n};
  $html .= qq{              </div>\n};
  $html .= qq{            </div>\n};
  $html .= qq{          </div>\n\n};
}

$html .= qq{        </div>\n};
$html .= qq{      </div>\n};
$html .= qq{    </div>\n};

open(my $out, '>:encoding(UTF-8)', $out_path) or die "Cannot write $out_path: $!\n";
print {$out} $html;
close($out);
