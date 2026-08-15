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
die "Usage: $0 <blog.json> <blog-section.html>\n"
  if !defined $json_path || !defined $out_path;

open(my $in, '<', $json_path) or die "Cannot open $json_path: $!\n";
local $/;
my $json_text = <$in>;
close($in);

my $entries = decode_json($json_text);
die "Expected blog JSON array\n" if ref($entries) ne 'ARRAY';

# Well-known link keys -> [icon, label], rendered in this order.
my @LINK_ORDER = qw(github);
my %LINK_META = (
  github => ['fa-github', 'GitHub'],
);

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

  my $href = esc($e->{href} // '');
  my $title = esc($e->{title} // '');
  my $authors = $e->{authors} // '';
  my $id = $e->{id} // '';
  my $info_id = $id ne '' ? "info:$id" : '';
  my $info_body = defined($e->{info}) && !ref($e->{info}) ? $e->{info} : '';
  my $badges = $e->{badges};

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
  $html .= qq{                  $authors\n};

  my @badge_chunks = ();
  if (defined($badges) && ref($badges) eq 'HASH') {
    my $artifacts = $badges->{artifacts};
    my $cves = $badges->{cves};
    my $awards = $badges->{awards};
    my $applied = $badges->{applied};

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
    if (defined($applied) && ref($applied) eq 'ARRAY' && scalar(@$applied) > 0) {
      my $ap = join(", ", map { esc($_ // '') } @$applied);
      push @badge_chunks, qq{<i class="fa fa-bolt text-black"></i> Applied: $ap};
    }
  }
  if (scalar(@badge_chunks) > 0) {
    $html .= qq{                  <br>\n};
    $html .= qq{                  <span class="text-muted">\n};
    $html .= qq{                    } . join("&ensp;\n                    ", @badge_chunks) . qq{\n};
    $html .= qq{                  </span>\n};
  }

  # Action row: Info auto-emitted; then well-known links; then extra_links.
  $html .= qq{                  <br>\n};
  if ($info_body ne '' && $info_id ne '') {
    my $iid = esc($info_id);
    (my $jstitle = $e->{title} // '') =~ s/'/\\'/g;
    $jstitle = esc($jstitle);
    $html .= qq{                  <span class="sbtn" onclick="showInfo('$iid', '$jstitle')"><a href="#0"><i class="fa fa-info-circle"></i>\n};
    $html .= qq{                      Info</a></span>\n};
  }
  my $links = (ref($e->{links}) eq 'HASH') ? $e->{links} : {};
  for my $k (@LINK_ORDER) {
    next if !defined $links->{$k} || $links->{$k} eq '';
    my ($icon, $label) = @{$LINK_META{$k}};
    my $lhref = esc($links->{$k});
    $html .= qq{                  <span class="sbtn"><a href="$lhref"><i class="fa $icon"></i>\n};
    $html .= qq{                      $label</a></span>\n};
  }
  my $extra = (ref($e->{extra_links}) eq 'ARRAY') ? $e->{extra_links} : [];
  for my $a (@$extra) {
    my $ahref = esc($a->{href} // '#');
    my $icon = esc($a->{icon} // 'fa-link');
    my $label = esc($a->{label} // 'Link');
    $html .= qq{                  <span class="sbtn"><a href="$ahref"><i class="fa $icon"></i>\n};
    $html .= qq{                      $label</a></span>\n};
  }

  $html .= qq{                </small>\n};

  if ($info_body ne '' && $info_id ne '') {
    my $iid = esc($info_id);
    my $ibody = $info_body;
    $ibody =~ s/\r?\n/ /g;
    $ibody =~ s/\s{2,}/ /g;
    $ibody =~ s/^\s+|\s+$//g;
    $html .= qq{                <div id="$iid" class="is-hidden">\n};
    $html .= qq{                  $ibody\n};
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
