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
die "Usage: $0 <notable-mentions.json> <notable-mentions-section.html>\n"
  if !defined $json_path || !defined $out_path;

open(my $in, '<', $json_path) or die "Cannot open $json_path: $!\n";
local $/;
my $json_text = <$in>;
close($in);

my $entries = decode_json($json_text);
die "Expected notable-mentions JSON array\n" if ref($entries) ne 'ARRAY';

my $html = "";
$html .= qq{    <div class="row">\n};
$html .= qq{      <div class="col-md-1"></div>\n};
$html .= qq{      <div class="col-md-10">\n};
$html .= qq{        <div class="highlight-grid">\n\n};

for my $e (@$entries) {
  my $title = esc($e->{title} // '');
  my $href  = esc($e->{href}  // '');
  my $blurb = $e->{blurb} // '';
  my $badge = (ref($e->{badge}) eq 'HASH') ? $e->{badge} : undef;

  $html .= qq{          <div class="highlight-card">\n};
  if ($href ne '') {
    $html .= qq{            <div class="hl-title"><a href="$href">$title</a></div>\n};
  } else {
    $html .= qq{            <div class="hl-title">$title</div>\n};
  }
  if (defined $badge) {
    my $bicon = esc($badge->{icon} // 'fa-star');
    my $btext = $badge->{text} // '';
    $html .= qq{            <div class="hl-badge"><i class="fa $bicon"></i> $btext</div>\n};
  }
  if ($blurb ne '') {
    $html .= qq{            <div class="hl-blurb">\n};
    $html .= qq{              $blurb\n};
    $html .= qq{            </div>\n};
  }
  $html .= qq{          </div>\n\n};
}

$html .= qq{        </div>\n};
$html .= qq{      </div>\n};
$html .= qq{      <div class="col-md-1"></div>\n};
$html .= qq{    </div>\n};

open(my $out, '>:encoding(UTF-8)', $out_path) or die "Cannot write $out_path: $!\n";
print {$out} $html;
close($out);
