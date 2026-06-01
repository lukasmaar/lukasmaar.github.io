#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOPBAR_TEMPLATE="$ROOT_DIR/templates/partials/topbar.html"
TALKS_DATA="$ROOT_DIR/templates/data/talks.json"
TALKS_PARTIAL="$ROOT_DIR/templates/partials/index/talks-section.html"
TALKS_RENDERER="$ROOT_DIR/templates/scripts/render_talks.pl"
AWARDS_DATA="$ROOT_DIR/templates/data/awards.json"
AWARDS_PARTIAL="$ROOT_DIR/templates/partials/index/awards-section.html"
AWARDS_RENDERER="$ROOT_DIR/templates/scripts/render_awards.pl"
PUBLICATIONS_DATA="$ROOT_DIR/templates/data/publications.json"
PUBLICATIONS_PARTIAL="$ROOT_DIR/templates/partials/index/publications-section.html"
PUBLICATIONS_RENDERER="$ROOT_DIR/templates/scripts/render_publications.pl"
BLOG_DATA="$ROOT_DIR/templates/data/blog.json"
BLOG_PARTIAL="$ROOT_DIR/templates/partials/index/blog-section.html"
BLOG_RENDERER="$ROOT_DIR/templates/scripts/render_blog.pl"

compile_post_tex_pdfs() {
  local tex_dir="$ROOT_DIR/templates/posts"
  local out_dir="$ROOT_DIR/posts"
  local tmp_dir
  local tex_rel tex_path tex_parent tex_name base_noext build_dir out_svg

  if ! command -v pdflatex >/dev/null 2>&1; then
    echo "Build failed: pdflatex not found (required for templates/posts/*.tex)." >&2
    exit 1
  fi
  if ! command -v pdftocairo >/dev/null 2>&1; then
    echo "Build failed: pdftocairo not found (required to render TEX figures as images)." >&2
    exit 1
  fi

  mkdir -p "$out_dir"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  while IFS= read -r tex_rel; do
    tex_rel="${tex_rel#./}"
    tex_path="$tex_dir/$tex_rel"
    tex_parent="$(dirname "$tex_path")"
    tex_name="$(basename "$tex_path")"
    base_noext="${tex_rel%.tex}"
    build_dir="$tmp_dir/$base_noext"
    out_svg="$out_dir/$base_noext.svg"

    mkdir -p "$build_dir" "$(dirname "$out_svg")"

    if ! (cd "$tex_parent" && pdflatex -interaction=nonstopmode -halt-on-error -file-line-error -output-directory "$build_dir" "$tex_name") >"$build_dir/build.log" 2>&1; then
      echo "Build failed: pdflatex failed for templates/posts/$tex_rel" >&2
      echo "---- pdflatex output ($base_noext) ----" >&2
      cat "$build_dir/build.log" >&2
      if [[ -f "$build_dir/${tex_name%.tex}.log" ]]; then
        echo "---- full log: $build_dir/${tex_name%.tex}.log ----" >&2
      fi
      exit 1
    fi

    # Keep the compiled PDF beside the TeX source; publish SVG under posts/ with the same relative path.
    cp "$build_dir/${tex_name%.tex}.pdf" "$tex_parent/${tex_name%.tex}.pdf"
    pdftocairo -svg "$build_dir/${tex_name%.tex}.pdf" "$out_svg"
    rm -f "${out_svg%.svg}.pdf" "${out_svg%.svg}.png"
  done < <(cd "$tex_dir" && find . -type f -name '*.tex' | sort)
}

render_talks_partial() {
  "$TALKS_RENDERER" "$TALKS_DATA" "$TALKS_PARTIAL"
}

render_awards_partial() {
  "$AWARDS_RENDERER" "$AWARDS_DATA" "$AWARDS_PARTIAL"
}

render_publications_partial() {
  "$PUBLICATIONS_RENDERER" "$PUBLICATIONS_DATA" "$PUBLICATIONS_PARTIAL"
}

render_blog_partial() {
  "$BLOG_RENDERER" "$BLOG_DATA" "$BLOG_PARTIAL"
}

render_page() {
  local src="$1"
  local dst="$2"
  local prefix="$3"
  local topbar

  topbar="$(sed "s|{{INDEX_PREFIX}}|$prefix|g" "$TOPBAR_TEMPLATE")"

  mkdir -p "$(dirname "$ROOT_DIR/$dst")"
  TOPBAR="$topbar" perl -0777 -pe 's/\{\{TOPBAR\}\}/$ENV{TOPBAR}/g' "$ROOT_DIR/$src" > "$ROOT_DIR/$dst"
}

index_prefix_for_post() {
  local dst="$1"
  local rel dir prefix
  rel="${dst#posts/}"
  dir="$(dirname "$rel")"
  prefix="../"

  if [[ "$dir" != "." ]]; then
    local -a parts
    local i
    IFS='/' read -r -a parts <<< "$dir"
    for ((i = 0; i < ${#parts[@]}; i++)); do
      prefix+="../"
    done
  fi

  printf '%s' "$prefix"
}

render_posts() {
  local posts_dir="$ROOT_DIR/templates/posts"
  local src_rel src_dir src_name dst_rel old_dst post_rel prefix
  local -n out_files=$1

  while IFS= read -r src_rel; do
    src_rel="${src_rel#./}"
    src_dir="$(dirname "$src_rel")"
    src_name="$(basename "$src_rel")"
    if [[ "$src_name" == "index.html" ]]; then
      post_rel="$src_dir"
    else
      post_rel="${src_rel%.html}"
    fi
    dst_rel="posts/$post_rel/index.html"
    old_dst="posts/$src_rel"
    prefix="$(index_prefix_for_post "$dst_rel")"
    render_page "templates/posts/$src_rel" "$dst_rel" "$prefix"
    if [[ "$old_dst" != "$dst_rel" && -f "$ROOT_DIR/$old_dst" ]]; then
      rm -f "$ROOT_DIR/$old_dst"
    fi
    out_files+=("$dst_rel")
  done < <(cd "$posts_dir" && find . -type f -name '*.html' ! -name 'template.html' | sort)
}

copy_post_assets() {
  local posts_dir="$ROOT_DIR/templates/posts"
  local asset_rel dst_dir

  while IFS= read -r asset_rel; do
    asset_rel="${asset_rel#./}"
    dst_dir="$ROOT_DIR/posts/$(dirname "$asset_rel")"
    mkdir -p "$dst_dir"
    cp "$posts_dir/$asset_rel" "$dst_dir/"
  done < <(
    cd "$posts_dir" && find . -type f \
      \( -name '*.webm' -o -name '*.mp4' -o -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.gif' -o -name '*.svg' \) \
      | sort
  )
}

sync_legacy_papers_dir() {
  local papers_dir="$ROOT_DIR/papers"
  local -a legacy_papers=(
    "usenix25-drivers.pdf"
    "usenix25-tlbsidechannel.pdf"
    "ndss25-kernelsnitch.pdf"
    "usenix24-defectsindepth.pdf"
    "usenix24-slubstick.pdf"
    "asiaccs24-hekcfi.pdf"
    "acsac23-dope.pdf"
  )
  local pdf_name

  mkdir -p "$papers_dir"
  find "$papers_dir" -maxdepth 1 -type l -name '*.pdf' -delete

  for pdf_name in "${legacy_papers[@]}"; do
    if [[ ! -f "$ROOT_DIR/publications/$pdf_name" ]]; then
      echo "Build failed: missing legacy paper target publications/$pdf_name" >&2
      exit 1
    fi
    ln -sfn "../publications/$pdf_name" "$papers_dir/$pdf_name"
  done
}

check_topbar_placeholder() {
  local file="$1"
  if grep -q "{{TOPBAR}}" "$ROOT_DIR/$file"; then
    echo "Build failed: unreplaced {{TOPBAR}} placeholder in $file" >&2
    exit 1
  fi
}

compute_counts() {
  local index_file="$ROOT_DIR/index.html"

  # Defaults in case a section/year is temporarily missing.
  export COUNT_BLOG_2026=0
  export COUNT_PUBLICATIONS_2026=0
  export COUNT_PUBLICATIONS_2025=0
  export COUNT_PUBLICATIONS_2024=0
  export COUNT_PUBLICATIONS_2023=0
  export COUNT_TALKS_2025=0
  export COUNT_TALKS_2024=0
  export COUNT_TALKS_2023=0
  export COUNT_AWARDS_2025=0
  export COUNT_AWARDS_2024=0
  export COUNT_AWARDS_2023=0

  while IFS='=' read -r key value; do
    export "$key=$value"
  done < <(
    awk '
      BEGIN { section=""; year="" }

      /<div id="blog" class="row">/   { section="blog";   year=""; next }
      /<div id="publications" class="row">/ { section="publications"; year=""; next }
      /<div id="talks" class="row">/  { section="talks";  year=""; next }
      /<div id="awards" class="row">/ { section="awards"; year=""; next }
      /<footer>/                    { section="";       year=""; next }

      {
        if (match($0, /id="(blog|publications|talks|awards)([0-9]{4})"/, m) && section == m[1]) {
          year = m[2]
        }
      }

      /<div class="timeline-entry">/ {
        if (section != "" && section != "awards" && year != "") {
          key = toupper(section) "_" year
          count[key]++
        }
      }

      /<a class="title"/ {
        if (section == "awards" && year != "") {
          awards_count[year]++
        }
      }

      END {
        print "COUNT_BLOG_2026=" (count["BLOG_2026"] + 0)
        print "COUNT_PUBLICATIONS_2026=" (count["PUBLICATIONS_2026"] + 0)
        print "COUNT_PUBLICATIONS_2025=" (count["PUBLICATIONS_2025"] + 0)
        print "COUNT_PUBLICATIONS_2024=" (count["PUBLICATIONS_2024"] + 0)
        print "COUNT_PUBLICATIONS_2023=" (count["PUBLICATIONS_2023"] + 0)
        print "COUNT_TALKS_2025=" (count["TALKS_2025"] + 0)
        print "COUNT_TALKS_2024=" (count["TALKS_2024"] + 0)
        print "COUNT_TALKS_2023=" (count["TALKS_2023"] + 0)
        print "COUNT_AWARDS_2025=" (awards_count["2025"] + 0)
        print "COUNT_AWARDS_2024=" (awards_count["2024"] + 0)
        print "COUNT_AWARDS_2023=" (awards_count["2023"] + 0)
      }
    ' "$index_file"
  )
}

apply_counts() {
  local file="$1"
  COUNT_BLOG_2026="$COUNT_BLOG_2026" \
  COUNT_PUBLICATIONS_2026="$COUNT_PUBLICATIONS_2026" \
  COUNT_PUBLICATIONS_2025="$COUNT_PUBLICATIONS_2025" \
  COUNT_PUBLICATIONS_2024="$COUNT_PUBLICATIONS_2024" \
  COUNT_PUBLICATIONS_2023="$COUNT_PUBLICATIONS_2023" \
  COUNT_TALKS_2025="$COUNT_TALKS_2025" \
  COUNT_TALKS_2024="$COUNT_TALKS_2024" \
  COUNT_TALKS_2023="$COUNT_TALKS_2023" \
  COUNT_AWARDS_2025="$COUNT_AWARDS_2025" \
  COUNT_AWARDS_2024="$COUNT_AWARDS_2024" \
  COUNT_AWARDS_2023="$COUNT_AWARDS_2023" \
  perl -0777 -i -pe '
    s/\{\{COUNT_BLOG_2026\}\}/$ENV{COUNT_BLOG_2026}/g;
    s/\{\{COUNT_PUBLICATIONS_2026\}\}/$ENV{COUNT_PUBLICATIONS_2026}/g;
    s/\{\{COUNT_PUBLICATIONS_2025\}\}/$ENV{COUNT_PUBLICATIONS_2025}/g;
    s/\{\{COUNT_PUBLICATIONS_2024\}\}/$ENV{COUNT_PUBLICATIONS_2024}/g;
    s/\{\{COUNT_PUBLICATIONS_2023\}\}/$ENV{COUNT_PUBLICATIONS_2023}/g;
    s/\{\{COUNT_TALKS_2025\}\}/$ENV{COUNT_TALKS_2025}/g;
    s/\{\{COUNT_TALKS_2024\}\}/$ENV{COUNT_TALKS_2024}/g;
    s/\{\{COUNT_TALKS_2023\}\}/$ENV{COUNT_TALKS_2023}/g;
    s/\{\{COUNT_AWARDS_2025\}\}/$ENV{COUNT_AWARDS_2025}/g;
    s/\{\{COUNT_AWARDS_2024\}\}/$ENV{COUNT_AWARDS_2024}/g;
    s/\{\{COUNT_AWARDS_2023\}\}/$ENV{COUNT_AWARDS_2023}/g;
  ' "$ROOT_DIR/$file"
}

check_count_placeholders() {
  local file="$1"
  if grep -q "{{COUNT_" "$ROOT_DIR/$file"; then
    echo "Build failed: unreplaced {{COUNT_...}} placeholder in $file" >&2
    exit 1
  fi
}

apply_last_updated() {
  local file="$1"
  local today
  today="$(date +%d.%m.%Y)"

  LAST_UPDATED="$today" perl -0777 -i -pe '
    s/\{\{LAST_UPDATED\}\}/$ENV{LAST_UPDATED}/g;
  ' "$ROOT_DIR/$file"
}

check_last_updated_placeholder() {
  local file="$1"
  if grep -q "{{LAST_UPDATED}}" "$ROOT_DIR/$file"; then
    echo "Build failed: unreplaced {{LAST_UPDATED}} placeholder in $file" >&2
    exit 1
  fi
}

expand_includes() {
  local file="$1"
  local target="$ROOT_DIR/$file"

  while grep -q "{{INCLUDE:" "$target"; do
    ROOT_DIR="$ROOT_DIR" perl -0777 -i -pe '
      s#\{\{INCLUDE:([^}]+)\}\}#do {
        my $path = $ENV{ROOT_DIR} . "/" . $1;
        open(my $fh, "<", $path) or die "Build failed: cannot open include $1\n";
        local $/;
        <$fh>;
      }#ge
    ' "$target"
  done
}

check_include_placeholders() {
  local file="$1"
  if grep -q "{{INCLUDE:" "$ROOT_DIR/$file"; then
    echo "Build failed: unreplaced {{INCLUDE:...}} placeholder in $file" >&2
    exit 1
  fi
}

render_talks_partial
render_awards_partial
render_publications_partial
render_blog_partial
compile_post_tex_pdfs
copy_post_assets
sync_legacy_papers_dir
render_page "templates/index.html" "index.html" ""

declare -a rendered_posts=()
render_posts rendered_posts

expand_includes "index.html"
for post_file in "${rendered_posts[@]}"; do
  expand_includes "$post_file"
done

compute_counts
apply_counts "index.html"
for post_file in "${rendered_posts[@]}"; do
  apply_counts "$post_file"
done

apply_last_updated "index.html"
for post_file in "${rendered_posts[@]}"; do
  apply_last_updated "$post_file"
done

check_topbar_placeholder "index.html"
for post_file in "${rendered_posts[@]}"; do
  check_topbar_placeholder "$post_file"
done

check_include_placeholders "index.html"
for post_file in "${rendered_posts[@]}"; do
  check_include_placeholders "$post_file"
done

check_count_placeholders "index.html"
for post_file in "${rendered_posts[@]}"; do
  check_count_placeholders "$post_file"
done

check_last_updated_placeholder "index.html"
for post_file in "${rendered_posts[@]}"; do
  check_last_updated_placeholder "$post_file"
done

echo "Build complete"
