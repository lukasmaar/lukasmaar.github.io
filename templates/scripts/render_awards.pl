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
die "Usage: $0 <awards.json> <awards-section.html>\n" if !defined $json_path || !defined $out_path;

open(my $in, '<', $json_path) or die "Cannot open $json_path: $!\n";
local $/;
my $json_text = <$in>;
close($in);

my $entries = decode_json($json_text);
die "Expected awards JSON array\n" if ref($entries) ne 'ARRAY';

my $html = "";
$html .= qq{    <div class="row">\n};
$html .= qq{      <div class="col-md-1">\n};
$html .= qq{      </div>\n};
$html .= qq{      <div class="col-md-10">\n};
$html .= qq{        <div class="timeline">\n\n};

my $current_year = undef;
for my $e (@$entries) {
  my $year = $e->{year};
  die "Missing year in awards entry\n" if !defined $year;

  if (!defined($current_year) || $year ne $current_year) {
    $html .= qq{          <div class="row">\n};
    $html .= qq{            <div class="timeline-date">\n};
    $html .= qq{              <span id="awards$year" class="anchor">\n};
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

  my $icon = esc($e->{icon} // 'fa-bug');
  my $items = $e->{items};
  $items = [] if !defined($items) || ref($items) ne 'ARRAY';
  my $note = defined($e->{note}) ? esc($e->{note}) : '';

  $html .= qq{          <div class="row">\n};
  $html .= qq{            <div class="timeline-entry">\n};
  $html .= qq{              <div class="col-md-1">\n};
  $html .= qq{              </div>\n};
  $html .= qq{              <div class="col-md-11">\n};
  $html .= qq{                <i class="fa $icon">\n};
  $html .= qq{                </i>\n};

  for (my $i = 0; $i < scalar(@$items); $i++) {
    my $item = $items->[$i];
    my $label = esc($item->{label} // '');
    my $href = $item->{href};

    if (defined($href) && $href ne '') {
      $href = esc($href);
      $html .= qq{                <a class="title" href="$href">\n};
      $html .= qq{                  $label</a>};
    } else {
      $html .= qq{                <a class="title">\n};
      $html .= qq{                  $label</a>};
    }

    if ($i < scalar(@$items) - 1) {
      $html .= qq{,\n};
    } else {
      $html .= qq{\n};
    }
  }

  $html .= qq{                <br>\n};

  if ($note ne '') {
    $html .= qq{                <small>\n};
    $html .= qq{                  <span class="sbtn text-muted">\n};
    $html .= qq{                    $note\n};
    $html .= qq{                  </span>\n};
    $html .= qq{                </small>\n};
  }

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
