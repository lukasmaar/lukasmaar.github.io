#!/usr/bin/env python3
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "templates/data/publications.json"

head_html = subprocess.check_output(["git", "show", "HEAD:index.html"], text=True, encoding="utf-8", errors="strict")

start = head_html.find('<div id="publications" class="row">')
end = head_html.find('<div id="talks" class="row">', start)
if start == -1 or end == -1:
    raise SystemExit("Could not locate publications section in HEAD:index.html")
sec = head_html[start:end]

row_start_pat = re.compile(r'<div class="row">\s*<div class="timeline-entry">', re.S)
year_anchor_pat = re.compile(r'<span id="publications(\d{4})" class="anchor">')


def find_matching_div(s: str, start_idx: int) -> int:
    # start_idx must point to '<div'
    i = start_idx
    depth = 0
    token = re.compile(r'<div\b|</div>')
    for m in token.finditer(s, start_idx):
        t = m.group(0)
        if t.startswith('<div'):
            depth += 1
        else:
            depth -= 1
            if depth == 0:
                return m.end()
    raise ValueError("unbalanced div")


def normalize_badges_html(badges: str) -> str:
    b = badges
    b = b.replace('style="color:#6e6e6e;"', 'class="text-muted"')
    b = b.replace('class="fa fa-certificate" style="color:#8c41ca;"', 'class="fa fa-certificate text-purple"')
    b = b.replace('class="fa fa-bug" style="color:#000000;"', 'class="fa fa-bug text-black"')
    b = b.replace('class="fa fa-star" style="color:#eccb11;"', 'class="fa fa-star text-gold"')
    return b


def parse_badges(badges_html: str) -> dict:
    artifacts = []
    cves = []
    awards = []
    s = badges_html or ""
    if not s:
        return {"artifacts": artifacts, "cves": cves, "awards": awards}

    def extract_segment(icon_class: str) -> str:
        m = re.search(
            rf'<i class="fa {re.escape(icon_class)}"></i>\s*(.*?)(?=(?:<i class="fa [^"]+"></i>|$))',
            s,
            re.S,
        )
        if not m:
            return ""
        text = m.group(1)
        text = re.sub(r"&ensp;|&nbsp;", " ", text)
        text = re.sub(r"\s+", " ", text).strip(" ,")
        return text

    art_text = extract_segment("fa-certificate text-purple")
    if art_text:
        art_text = re.sub(r"^Artifacts evaluated:\s*", "", art_text, flags=re.I).strip(" ,")
        artifacts = [x.strip() for x in art_text.split(",") if x.strip()]

    bug_text = extract_segment("fa-bug text-black")
    if bug_text:
        cves = re.findall(r"CVE-\d{4}-\d+", bug_text)

    star_text = extract_segment("fa-star text-gold")
    if star_text:
        awards = [star_text]

    return {"artifacts": artifacts, "cves": cves, "awards": awards}


def normalize_info_inner(inner: str) -> str:
    s = inner
    s = s.replace('style="float: left; margin: 0 10px 5px 0; max-width: 100%; height: auto;"', 'class="thumb-left-responsive"')
    s = s.replace('style="float: left; margin: 0 10px 0 0;"', 'class="thumb-left-small"')
    s = s.replace('style="float: left; margin: 10px 10px 0 0;"', 'class="thumb-left-top"')
    s = s.replace('style="float: left; margin: 0 15px 0 0;"', 'class="thumb-left"')
    # Keep info HTML as a single line in JSON/output to simplify diffs and templating.
    s = re.sub(r"\s*\n\s*", " ", s).strip()
    return s


def extract_div_with_id(block: str, prefix: str):
    m = re.search(
        rf'<div id="({re.escape(prefix)}[^"]*)"[^>]*class="([^"]+)"([^>]*)>',
        block,
        re.S,
    )
    if not m:
        return None
    div_start = m.start()
    open_end = block.find('>', m.start()) + 1
    div_end = find_matching_div(block, div_start)
    inner = block[open_end:div_end - len('</div>')]
    attrs_tail = m.group(3) or ""
    return m.group(1), m.group(2), attrs_tail, inner


entries = []
current_year = None
scan_pos = 0

while True:
    ym = year_anchor_pat.search(sec, scan_pos)
    rm = row_start_pat.search(sec, scan_pos)
    if ym and (not rm or ym.start() < rm.start()):
        current_year = int(ym.group(1))
        scan_pos = ym.end()
        continue
    if not rm:
        break
    if current_year is None:
        raise SystemExit("Timeline entry found before any publicationsYYYY anchor")

    row_start = rm.start()
    row_end = find_matching_div(sec, row_start)
    block = sec[row_start:row_end]

    title_m = re.search(r'<a class="title" href="([^"]+)">\s*(.*?)\s*</a>', block, re.S)
    if not title_m:
        scan_pos = row_end
        continue

    href = title_m.group(1)
    title = re.sub(r'\s+', ' ', title_m.group(2)).strip()

    small_m = re.search(r'<small>\s*(.*?)\s*</small>', block, re.S)
    if not small_m:
        raise SystemExit(f"Missing <small> for publication: {title}")
    small = small_m.group(1)

    first_br = re.search(r'<br\s*/?>', small, re.I)
    second_br = re.search(r'<br\s*/?>', small[first_br.end():], re.I) if first_br else None
    if not first_br or not second_br:
        raise SystemExit(f"Could not parse authors/venue for publication: {title}")

    authors = small[:first_br.start()].strip()
    venue = small[first_br.end():first_br.end() + second_br.start()].strip()
    tail = small[first_br.end() + second_br.end():].strip()

    badges_html = ""
    badges_m = re.search(r'<span style="color:#6e6e6e;">\s*(.*?)\s*</span>', tail, re.S)
    if badges_m:
        badges_html = normalize_badges_html(badges_m.group(1).strip())
    badges = parse_badges(badges_html)

    actions = []
    for am in re.finditer(r'<span class="sbtn"(?:\s+onclick="toggleBox\(\'([^\']+)\'\)")?>\s*<a href="([^"]*)">\s*<i\s+class="fa\s+([^"]+)"></i>\s*(.*?)</a></span>', tail, re.S):
        target_id, ahref, icon, label = am.groups()
        actions.append({
            "kind": "toggle" if target_id else "link",
            "target_id": target_id,
            "href": ahref,
            "icon": icon.strip(),
            "label": re.sub(r'\s+', ' ', label).strip(),
        })

    info = extract_div_with_id(block, "info:")
    bib = extract_div_with_id(block, "bibtex:")

    info_obj = {"id": "", "class": "", "html": ""}
    if info:
        iid, iclass, iattrs_tail, ihtml = info
        if "max-height" in iattrs_tail or "overflow" in iattrs_tail:
            iclass = "infobox is-hidden-overflow"
        elif iclass.startswith("infobox"):
            iclass = "infobox is-hidden"
        info_obj = {
            "id": iid,
            "class": iclass,
            "html": normalize_info_inner(ihtml.strip()),
        }

    bib_obj = {"id": "", "class": "", "text": ""}
    if bib:
        bid, bclass, _battrs_tail, binner = bib
        text_m = re.search(r'<pre[^>]*>\s*(.*?)\s*</pre>', binner, re.S)
        bib_obj = {
            "id": bid,
            "class": "box is-hidden",
            "text": text_m.group(1).strip() if text_m else "",
        }

    entries.append({
        "year": current_year,
        "href": href,
        "title": title,
        "authors": authors,
        "venue": venue,
        "badges": badges,
        "actions": actions,
        "info": info_obj,
        "bibtex": bib_obj,
    })

    scan_pos = row_end

OUT.write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Wrote {OUT} with {len(entries)} entries")
