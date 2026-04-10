#!/usr/bin/env perl
use strict;
use warnings;
use JSON::PP qw(decode_json);
use utf8;

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
die "Usage: $0 <publications.json> <publications-section.html>\n" if !defined $out_path;

open(my $in, '<', $json_path) or die "Cannot open $json_path: $!\n";
local $/;
my $json_text = <$in>;
close($in);

my $entries = decode_json($json_text);
die "Expected publications JSON array\n" if ref($entries) ne 'ARRAY';

my $html = "";
$html .= qq{    <div class="row">\n};
$html .= qq{      <div class="col-md-1">\n};
$html .= qq{      </div>\n};
$html .= qq{      <div class="col-md-10">\n};
$html .= qq{        <div class="timeline">\n\n};

my $current_year;
for my $e (@$entries) {
  my $year = $e->{year};
  die "Missing year in publications entry\n" if !defined $year;

  if (!defined($current_year) || $year ne $current_year) {
    $html .= qq{          <div class="row">\n};
    $html .= qq{            <div class="timeline-date">\n};
    $html .= qq{              <span id="publications$year" class="anchor">\n};
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

  my $href = esc($e->{href} // '');
  my $title = esc($e->{title} // '');
  my $authors = $e->{authors} // '';
  my $venue = $e->{venue} // '';
  my $badges = $e->{badges};

  $html .= qq{          <div class="row">\n};
  $html .= qq{            <div class="timeline-entry">\n};
  $html .= qq{              <div class="col-md-1">\n};
  $html .= qq{              </div>\n};
  $html .= qq{              <div class="col-md-11">\n};
  $html .= qq{                <i class="fa fa-file">\n};
  $html .= qq{                </i>\n};
  $html .= qq{                <a class="title" href="$href">\n};
  $html .= qq{                  $title\n};
  $html .= qq{                </a>\n};
  $html .= qq{                <br>\n};
  $html .= qq{                <small>\n};
  $html .= qq{                  $authors\n};
  $html .= qq{                  <br>\n};
  $html .= qq{                  $venue\n};

  my @badge_chunks = ();
  if (defined($badges) && ref($badges) eq 'HASH') {
    my $artifacts = $badges->{artifacts};
    my $cves = $badges->{cves};
    my $awards = $badges->{awards};

    if (defined($artifacts) && ref($artifacts) eq 'ARRAY' && scalar(@$artifacts) > 0) {
      my $art = join(", ", map { esc($_ // '') } @$artifacts);
      push @badge_chunks, qq{<i class="fa fa-certificate text-purple"></i> Artifacts evaluated: $art};
    }
    if (defined($cves) && ref($cves) eq 'ARRAY' && scalar(@$cves) > 0) {
      my $cv = join(", ", map { esc($_ // '') } @$cves);
      push @badge_chunks, qq{<i class="fa fa-bug text-black"></i> $cv};
    }
    if (defined($awards) && ref($awards) eq 'ARRAY' && scalar(@$awards) > 0) {
      my $aw = join(", ", map { esc($_ // '') } @$awards);
      push @badge_chunks, qq{<i class="fa fa-star text-gold"></i> $aw};
    }
  }

  if (scalar(@badge_chunks) > 0) {
    $html .= qq{                  <br>\n};
    $html .= qq{                  <span class="text-muted">\n};
    $html .= qq{                    } . join("&ensp;\n                    ", @badge_chunks) . qq{\n};
    $html .= qq{                  </span>\n};
  }

  my $actions = $e->{actions};
  if (defined($actions) && ref($actions) eq 'ARRAY' && scalar(@$actions) > 0) {
    $html .= qq{                  <br>\n};
    for my $a (@$actions) {
      my $kind = $a->{kind} // 'link';
      my $target_id = $a->{target_id} // '';
      my $ahref = esc($a->{href} // '#');
      my $icon = esc($a->{icon} // 'fa-link');
      my $label = esc($a->{label} // 'Link');

      if ($kind eq 'toggle' && $target_id ne '') {
        my $tid = esc($target_id);
        $html .= qq{                  <span class="sbtn" onclick="toggleBox('$tid')"><a href="$ahref"><i class="fa $icon"></i>\n};
        $html .= qq{                      $label</a></span>\n};
      } else {
        $html .= qq{                  <span class="sbtn"><a href="$ahref"><i class="fa $icon"></i>\n};
        $html .= qq{                      $label</a></span>\n};
      }
    }
  }

  $html .= qq{                </small>\n};

  my $info = $e->{info};
  if (defined($info) && ref($info) eq 'HASH' && ($info->{id} // '') ne '') {
    my $iid = esc($info->{id});
    my $iclass = esc($info->{class} // 'infobox is-hidden');
    my $ibody = $info->{html} // '';
    $ibody =~ s/\r?\n/ /g;
    $ibody =~ s/\s{2,}/ /g;
    $ibody =~ s/^\s+|\s+$//g;
    $html .= qq{                <div id="$iid" class="$iclass">\n};
    if ($ibody ne '') {
      $html .= qq{                  $ibody\n};
    }
    $html .= qq{                </div>\n};
  }

  my $bib = $e->{bibtex};
  if (defined($bib) && ref($bib) eq 'HASH' && ($bib->{id} // '') ne '') {
    my $bid = esc($bib->{id});
    my $bclass = esc($bib->{class} // 'box is-hidden');
    my $btext = $bib->{text} // '';
    $html .= qq{                <div id="$bid" class="$bclass">\n};
    $html .= qq{                  <pre class="pre-wrap">\n};
    $html .= qq{$btext</pre>\n};
    $html .= qq{                </div>\n};
  }

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
