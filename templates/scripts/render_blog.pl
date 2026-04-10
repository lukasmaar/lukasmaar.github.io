#!/usr/bin/env perl
use strict;
use warnings;
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
die "Usage: $0 <blog.json> <blog-section.html>\n" if !defined $out_path;

open(my $in, '<', $json_path) or die "Cannot open $json_path: $!\n";
local $/;
my $json_text = <$in>;
close($in);

my $entries = decode_json($json_text);
die "Expected blog JSON array\n" if ref($entries) ne 'ARRAY';

my $html = "";
$html .= qq{    <div class="row">\n};
$html .= qq{      <div class="col-md-1">\n};
$html .= qq{      </div>\n};
$html .= qq{      <div class="col-md-10">\n};
$html .= qq{        <div class="timeline">\n\n};

my $current_year;
for my $e (@$entries) {
  my $year = $e->{year};
  die "Missing year in blog entry\n" if !defined $year;

  if (!defined($current_year) || $year ne $current_year) {
    $html .= qq{          <div class="row">\n};
    $html .= qq{            <div class="timeline-date">\n};
    $html .= qq{              <span id="blog$year" class="anchor">\n};
    $html .= qq{              </span>\n};
    $html .= qq{              <div class="col-xs-1">\n};
    $html .= qq{                <b class="hi">\n};
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
  my $author_html = defined($e->{author_html}) ? $e->{author_html} : '';
  my $info_id = esc($e->{info_id} // '');
  my $github = esc($e->{github} // '#');
  my $info_html = '';
  if (defined $e->{info_html}) {
    $info_html = $e->{info_html};
  } elsif (ref($e->{info}) eq 'HASH' && defined $e->{info}->{html}) {
    $info_html = $e->{info}->{html};
  }

  $html .= qq{          <div class="row">\n};
  $html .= qq{            <div class="timeline-entry">\n};
  $html .= qq{              <div class="col-md-1">\n};
  $html .= qq{              </div>\n};
  $html .= qq{              <div class="col-md-11">\n};
  $html .= qq{                <i class="fa fa-edit">\n};
  $html .= qq{                </i>\n};
  $html .= qq{                <a class="title" href="$href">\n};
  $html .= qq{                  $title\n};
  $html .= qq{                </a>\n};
  $html .= qq{                <br>\n};
  $html .= qq{                <small>\n};
  $html .= qq{                  $author_html\n};
  $html .= qq{                  <br>\n};
  $html .= qq{                  <span class="sbtn" onclick="toggleBox('$info_id')"><a href="#0"><i class="fa fa-info-circle"></i>\n};
  $html .= qq{                      Info</a></span>\n};
  $html .= qq{                  <span class="sbtn"><a href="$github"><i class="fa fa-github"></i>\n};
  $html .= qq{                      GitHub</a></span>\n};
  $html .= qq{                </small>\n};
  $html .= qq{                <div id="$info_id" class="infobox is-hidden">\n};
  $html .= qq{                  $info_html\n};
  $html .= qq{                </div>\n};
  $html .= qq{              </div>\n};
  $html .= qq{            </div>\n};
  $html .= qq{          </div>\n\n};
}

$html .= qq{        </div>\n};
$html .= qq{      </div>\n};
$html .= qq{    </div>\n};

open(my $out, '>', $out_path) or die "Cannot write $out_path: $!\n";
print {$out} $html;
close($out);
