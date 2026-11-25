function __splitcue_one --argument-names cue do_rm do_fast artist_override
    set -l dir (dirname -- $cue)
    set -l stem (string replace -r '\.[cC][uU][eE]$' '' -- (basename -- $cue))
    echo "== $cue"

    if test -d "$dir/tracks"
        echo "   skip: $dir/tracks already exists"
        return 0
    end

    # which FLAC belongs to this CUE?
    set -l img "$dir/$stem.flac"
    if not test -f "$img"
        set -l flacs (find "$dir" -maxdepth 1 -type f -iname '*.flac')
        if test (count $flacs) -ne 1
            echo "   skip: can't tell which FLAC belongs to this CUE"
            return 1
        end
        set img $flacs[1]
    end

    # CUE -> clean UTF-8 (strip BOM, CRLF, tabs)
    set -l tmpcue (mktemp)
    if iconv -f UTF-8 -t UTF-16LE "$cue" >/dev/null 2>&1
        perl -pe 's/^\xEF\xBB\xBF// if $. == 1; s/\r//g; s/\t/ /g' "$cue" >$tmpcue
    else
        iconv -f CP1252 -t UTF-8 "$cue" | perl -pe 's/\r//g; s/\t/ /g' >$tmpcue
    end

    set -l prog '
function val(s,   t) {
  t = s
  sub(/^ *[A-Za-z_]+ +/, "", t)
  sub(/ +$/, "", t)
  if (t ~ /^".*"$/) t = substr(t, 2, length(t) - 2)
  return t
}
/^ *FILE /       { nfile++; next }
/^ *TRACK /      { n++; intrack = 1; next }
/^ *REM +DATE /  { d = $0; sub(/^ *REM +DATE +/, "", d); gsub(/"/, "", d); rdate = d; next }
/^ *TITLE /      { if (intrack) title[n] = val($0); else album = val($0); next }
/^ *PERFORMER /  { if (intrack) perf[n] = val($0); else aperf = val($0); next }
/^ *INDEX +0?1 / { split($3, t, ":"); start[n] = ((t[1] * 60 + t[2]) * 75 + t[3]) * sr / 75; next }
END {
  if (mode == "meta") {
    print (album == "" ? "-" : album)
    print (aperf == "" ? "-" : aperf)
    print (rdate == "" ? "-" : rdate)
    print n + 0
    print nfile + 0
    exit
  }
  for (i = 1; i <= n; i++) {
    if (mode == "start") { if (i in start) printf "%.0f\n", start[i]; else print -1 }
    if (mode == "title") print (title[i] == "" ? sprintf("Track %02d", i) : title[i])
    if (mode == "perf")  print (perf[i] == "" ? "-" : perf[i])
  }
}
'
    set -l rate (ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$img")
    set -l total (metaflac --show-total-samples "$img")
    set -l m (awk -v sr=$rate -v mode=meta $prog $tmpcue)
    set -l starts (awk -v sr=$rate -v mode=start $prog $tmpcue)
    set -l titles (awk -v sr=$rate -v mode=title $prog $tmpcue)
    set -l perfs (awk -v sr=$rate -v mode=perf $prog $tmpcue)
    rm -f $tmpcue

    set -l album $m[1]
    set -l aperf $m[2]
    set -l releasedate $m[3]
    set -l n $m[4]
    set -l nfile $m[5]
    test "$album" = "-"; and set album ""
    test "$aperf" = "-"; and set aperf ""
    test "$releasedate" = "-"; and set releasedate ""

    if test -z "$rate"; or not test "$total" -gt 0 2>/dev/null
        echo "   !! can't read sample rate / total samples from $img"
        return 1
    end
    if not test "$n" -ge 1 2>/dev/null; or test "$nfile" != 1; or test (count $starts) -ne $n
        echo "   !! CUE not supported (need exactly one FILE and at least one TRACK with INDEX 01)"
        return 1
    end

    # sanity: start points strictly increasing and inside the file
    set -l okc 1
    for i in (seq 1 $n)
        test $starts[$i] -ge 0; or set okc 0
        if test $i -gt 1
            test $starts[$i] -gt $starts[(math $i - 1)]; or set okc 0
        end
    end
    test $starts[$n] -lt $total; or set okc 0
    if test $okc != 1
        echo "   !! CUE times don't fit the audio file"
        return 1
    end

    # artist/album fallbacks from "Artist - Album.cue"
    set -l parts (string match -r '^(.+?) - (.+)$' -- $stem)
    if test -z "$aperf"; and test (count $parts) -eq 3
        set aperf $parts[2]
    end
    if test -z "$album"; and test (count $parts) -eq 3
        set album $parts[3]
    end
    test -n "$artist_override"; and set aperf $artist_override
    test -z "$album"; and set album $stem
    if test -z "$aperf"
        echo "   !! no artist found, rerun with --artist NAME"
        return 1
    end
    set album (string replace -ri '\s*[\(\[]\s*vinyl\s*[\)\]]\s*$' '' -- $album)

    echo "   $aperf - $album, $n tracks, $rate Hz"
    echo "   testing source..."
    if not flac -t -s "$img"
        echo "   !! source FLAC is corrupt, re-download/re-copy it (and check the disk)"
        return 1
    end

    set -l outdir "$dir/tracks.tmp"
    rm -rf "$outdir"
    mkdir -p "$outdir"; or return 1
    set -l outs
    set -l expected

    for i in (seq 1 $n)
        set -l s $starts[$i]
        set -l e $total
        if test $i -lt $n
            set e $starts[(math $i + 1)]
        end
        # coarse integer-second seek for speed, exact cut by sample number
        set -l coarse (math --scale=0 "max(0, floor($s / $rate) - 1)")
        set -l a (math --scale=0 "$s - $coarse * $rate")
        set -l b (math --scale=0 "$e - $coarse * $rate")
        set -l num (printf %02d $i)
        set -l title $titles[$i]
        set -l artist $perfs[$i]
        test "$artist" = "-"; and set artist $aperf
        test -n "$artist_override"; and set artist $artist_override
        set -l safe (string replace -ra '[/\\\\:*?"<>|]' '-' -- $title)
        set -l out "$outdir/$num - $safe.flac"
        set -l meta -metadata "TITLE=$title" -metadata "ARTIST=$artist" -metadata "ALBUMARTIST=$aperf" -metadata "ALBUM=$album" -metadata "TRACKNUMBER=$i" -metadata "TRACKTOTAL=$n"
        test -n "$releasedate"; and set meta $meta -metadata "DATE=$releasedate"

        if not ffmpeg -nostdin -v error -y -ss $coarse -i "$img" -map 0:a:0 -map_metadata -1 -af "atrim=start_sample=$a:end_sample=$b" -c:a flac $meta "$out"
            echo "   !! encoding failed on track $num"
            return 1
        end
        metaflac --add-seekpoint=5s "$out"
        set -a outs "$out"
        set -a expected (math --scale=0 "$e - $s")
        printf '   %s %s\n' $num "$title"
    end

    # cover: shortest image name that isn't back/insert/gatefold/etc.
    set -l imgs (find "$dir" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | string match -riv -- '[-_ \[(](back|insert|gatefold|booklet|label|spine|inlay|tray|inside|obi|sticker|cd|disc)[^/]*$')
    if test (count $imgs) -gt 0
        set -l front (for f in $imgs; echo (string length -- $f) $f; end | sort -n | head -1 | string replace -r '^\d+ ' '')
        ffmpeg -nostdin -v error -y -i "$front" -vf "scale='min(1400,iw)':-2" -frames:v 1 -update 1 -q:v 2 "$outdir/cover.jpg"
        or echo "   (cover conversion failed, continuing)"
    end

    echo "   verifying..."
    set -l bad 0
    for k in (seq 1 $n)
        set -l got (metaflac --show-total-samples "$outs[$k]")
        if test "$got" != "$expected[$k]"
            echo "   !! track $k: header says $got samples, expected $expected[$k]"
            set bad 1
        end
        if not flac -t -s "$outs[$k]"
            echo "   !! track $k fails FLAC integrity test"
            set bad 1
        end
    end

    if test "$do_fast" != 1; and test "$starts[1]" = 0
        echo "   comparing decoded audio, source vs tracks (slow)..."
        set -l srcsum (ffmpeg -nostdin -v error -i "$img" -map 0:a:0 -c:a pcm_s32le -f s32le - | cksum)
        set -l outsum (for f in $outs; ffmpeg -nostdin -v error -i "$f" -map 0:a:0 -c:a pcm_s32le -f s32le -; end | cksum)
        if test "$srcsum" != "$outsum"
            echo "   !! decoded audio differs from the source"
            set bad 1
        end
    end

    if test $bad -ne 0
        echo "   !! verification failed. Left $outdir for inspection, originals untouched"
        return 1
    end

    if test "$do_rm" = 1
        rm -f "$img" "$cue"
        command mv -f $outdir/* "$dir/"
        rmdir "$outdir"
        echo "   OK: $n tracks in $dir (original image + CUE removed)"
    else
        command mv "$outdir" "$dir/tracks"
        echo "   OK: $n tracks in $dir/tracks"
    end
end

function splitcue --description 'Split single-FLAC + CUE albums into tagged, verified per-track FLACs'
    argparse r/rm f/fast 'a/artist=' h/help -- $argv
    or return 1
    if set -q _flag_help
        echo "usage: splitcue [--rm] [--fast] [--artist NAME]"
        echo "  run inside a folder; finds every .cue below it"
        echo "  default: writes <album>/tracks/ and keeps the originals"
        echo "  --rm:   after verification, puts tracks in the album folder and deletes the image FLAC + CUE"
        echo "  --fast: skip the full decoded-audio comparison"
        return 0
    end
    for t in ffmpeg ffprobe flac metaflac awk perl iconv cksum find
        if not command -q $t
            echo "missing: $t   (macOS: brew install ffmpeg flac | Debian: sudo apt install ffmpeg flac)"
            return 1
        end
    end
    set -l rm_flag 0
    set -l fast_flag 0
    set -q _flag_rm; and set rm_flag 1
    set -q _flag_fast; and set fast_flag 1

    set -l cues (find . -type f -iname '*.cue' -not -path '*/tracks/*' -not -path '*/tracks.tmp/*' | sort)
    if test (count $cues) -eq 0
        echo "no .cue files under "(pwd)
        return 1
    end
    set -l failed 0
    for cue in $cues
        __splitcue_one "$cue" $rm_flag $fast_flag "$_flag_artist"
        or set failed (math $failed + 1)
    end
    echo "done, $failed album(s) failed"
    test $failed -eq 0
end
