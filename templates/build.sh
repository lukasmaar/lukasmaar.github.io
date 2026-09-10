#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="$ROOT_DIR/templates/data"
PARTIALS_DIR="$ROOT_DIR/templates/partials/index"
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
NOTABLE_DATA="$ROOT_DIR/templates/data/notable-mentions.json"
NOTABLE_PARTIAL="$ROOT_DIR/templates/partials/index/notable-mentions-section.html"
NOTABLE_RENDERER="$ROOT_DIR/templates/scripts/render_notable_mentions.pl"

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

render_notable_mentions_partial() {
  "$NOTABLE_RENDERER" "$NOTABLE_DATA" "$NOTABLE_PARTIAL"
}

render_page() {
  local src="$1"
  local dst="$2"
  local prefix="$3"

  mkdir -p "$(dirname "$ROOT_DIR/$dst")"
  sed "s|{{INDEX_PREFIX}}|$prefix|g" "$ROOT_DIR/$src" > "$ROOT_DIR/$dst"
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
    rendered_posts+=("$dst_rel")
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

check_index_prefix_placeholder() {
  local file="$1"
  if grep -q "{{INDEX_PREFIX}}" "$ROOT_DIR/$file"; then
    echo "Build failed: unreplaced {{INDEX_PREFIX}} placeholder in $file" >&2
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
render_notable_mentions_partial
compile_post_tex_pdfs
copy_post_assets
sync_legacy_papers_dir
render_page "templates/index.html" "index.html" ""

declare -a rendered_posts=()
render_posts

all_files=(index.html "${rendered_posts[@]}")

for f in "${all_files[@]}"; do
  expand_includes "$f"
done

for f in "${all_files[@]}"; do
  apply_last_updated "$f"
done

for f in "${all_files[@]}"; do
  check_index_prefix_placeholder "$f"
done

for f in "${all_files[@]}"; do
  check_include_placeholders "$f"
done

for f in "${all_files[@]}"; do
  check_last_updated_placeholder "$f"
done

echo "Build complete"
