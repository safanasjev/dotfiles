function __splitcue_one --argument-names cue do_rm do_fast artist_override continuous
    set -l dir (dirname -- $cue)
    set -l stem (string replace -r '\.[cC][uU][eE]$' '' -- (basename -- $cue))
    echo "== $cue"

    if test -d "$dir/tracks"
        echo "   skip: $dir/tracks already exists"
        return 0
    end

    # CUE -> clean UTF-8 (strip BOM, CRLF, tabs)
    set -l tmpcue (mktemp -t splitcue.XXXXXX)
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
/^ *FILE / {
  nfile++
  f = $0
  sub(/^ *FILE +/, "", f)
  if (f ~ /^"/) { sub(/^"/, "", f); sub(/".*$/, "", f) }
  else { sub(/ +[A-Za-z0-9]+ *$/, "", f) }
  fname[nfile] = f
  next
}
/^ *TRACK /      { n++; tfile[n] = nfile; intrack = 1; next }
/^ *REM +DATE /  { d = $0; sub(/^ *REM +DATE +/, "", d); gsub(/"/, "", d); rdate = d; next }
/^ *TITLE /      { if (intrack) title[n] = val($0); else album = val($0); next }
/^ *PERFORMER /  { if (intrack) perf[n] = val($0); else aperf = val($0); next }
/^ *INDEX +0?1 / { split($3, t, ":"); fr[n] = (t[1] * 60 + t[2]) * 75 + t[3]; hasfr[n] = 1; next }
END {
  if (mode == "meta") {
    print (album == "" ? "-" : album)
    print (aperf == "" ? "-" : aperf)
    print (rdate == "" ? "-" : rdate)
    print n + 0
    print nfile + 0
  }
  if (mode == "file") {
    for (i = 1; i <= nfile; i++) print fname[i]
  }
  if (mode == "track") {
    for (i = 1; i <= n; i++)
      printf "%d\t%d\t%s\t%s\n", tfile[i], (hasfr[i] ? fr[i] : -1), (title[i] == "" ? sprintf("Track %02d", i) : title[i]), (perf[i] == "" ? "-" : perf[i])
  }
}
'
    set -l m (awk -v mode=meta $prog $tmpcue)
    set -l fnames (awk -v mode=file $prog $tmpcue)
    set -l rows (awk -v mode=track $prog $tmpcue)
    rm -f $tmpcue

    set -l album $m[1]
    set -l aperf $m[2]
    set -l releasedate $m[3]
    set -l n $m[4]
    set -l nfile $m[5]
    test "$album" = "-"; and set album ""
    test "$aperf" = "-"; and set aperf ""
    test "$releasedate" = "-"; and set releasedate ""

    if not test "$n" -ge 1 2>/dev/null; or not test "$nfile" -ge 1 2>/dev/null; or test (count $rows) -ne $n; or test (count $fnames) -ne $nfile
        echo "   !! CUE not supported (need at least one FILE, and TRACKs with INDEX 01)"
        return 1
    end

    # match each FILE entry to a FLAC in this folder
    set -l flacs (find "$dir" -maxdepth 1 -type f -iname '*.flac' | sort)
    set -l files
    set -l unresolved 0
    for nm in $fnames
        set -l found ""
        if test -f "$dir/$nm"; and string match -qi '*.flac' -- $nm
            set found "$dir/$nm"
        else
            set -l want (string lower -- (string replace -r '\.[^./]*$' '' -- (basename -- $nm)))
            for c in $flacs
                set -l have (string lower -- (string replace -r '\.[^./]*$' '' -- (basename -- $c)))
                if test "$have" = "$want"
                    set found $c
                    break
                end
            end
        end
        test -z "$found"; and set unresolved 1
        set -a files "$found"
    end
    if test $unresolved -eq 1
        if test (count $flacs) -eq $nfile
            set files $flacs
            echo "   (FILE names don't match, using the FLACs in sorted order)"
        else
            echo "   !! can't match the CUE's FILE entries to the FLACs in this folder"
            return 1
        end
    end

    # per-file sample rate and length
    set -l rates
    set -l totals
    for f in $files
        set -l r (metaflac --show-sample-rate "$f" 2>/dev/null)
        set -l t (metaflac --show-total-samples "$f" 2>/dev/null)
        if test -z "$r"; or not test "$t" -gt 0 2>/dev/null
            echo "   !! can't read sample rate / total samples from $f"
            return 1
        end
        set -a rates $r
        set -a totals $t
    end

    # parse tracks: file index, start (samples), title, performer
    set -l tfi
    set -l tst
    set -l tti
    set -l tpf
    for row in $rows
        set -l p (string split \t -- $row)
        set -l fidx $p[1]
        set -l frames $p[2]
        if not test "$fidx" -ge 1 2>/dev/null; or test "$fidx" -gt $nfile; or test "$frames" -lt 0
            echo "   !! a track has no INDEX 01 or sits outside any FILE"
            return 1
        end
        set -l rt $rates[$fidx]
        set -a tfi $fidx
        set -a tst (math --scale=0 "round($frames * $rt / 75)")
        set -a tti $p[3]
        set -a tpf $p[4]
    end

    # end of each track, plus sanity checks
    set -l ten
    set -l ntf
    set -l seen
    for i in (seq 1 $nfile)
        set -a ntf 0
        set -a seen 0
    end
    set -l okc 1
    set -l allzero 1
    for k in (seq 1 $n)
        set -l fidx $tfi[$k]
        set -l e $totals[$fidx]
        if test $k -lt $n
            set -l nx (math $k + 1)
            if test "$tfi[$nx]" = "$fidx"
                set e $tst[$nx]
            end
        end
        if test $k -gt 1
            set -l pv (math $k - 1)
            test $fidx -ge $tfi[$pv]; or set okc 0
        end
        set -l sv $tst[$k]
        test $sv -ge 0; or set okc 0
        test $sv -lt $e; or set okc 0
        set -a ten $e
        set ntf[$fidx] (math $ntf[$fidx] + 1)
        if test $ntf[$fidx] -eq 1; and test $sv -ne 0
            set allzero 0
        end
    end
    for i in (seq 1 $nfile)
        if test $ntf[$i] -eq 0
            echo "   !! no tracks in the CUE belong to "$files[$i]
            return 1
        end
    end
    if test $okc != 1
        echo "   !! CUE times don't fit the audio files"
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

    set -l multi 0
    if test $nfile -gt 1; and test "$continuous" != 1
        set multi 1
    end

    echo "   $aperf - $album, $n tracks in $nfile file(s)"
    echo "   testing source..."
    for f in $files
        if not flac -t -s "$f"
            echo "   !! source FLAC is corrupt: $f (re-download/re-copy it and check the disk)"
            return 1
        end
    end

    set -l outdir "$dir/tracks.tmp"
    rm -rf "$outdir"
    mkdir -p "$outdir"; or return 1
    set -l outs
    set -l expected
    for i in (seq 1 $nfile)
        set seen[$i] 0
    end

    for k in (seq 1 $n)
        set -l fidx $tfi[$k]
        set -l img $files[$fidx]
        set -l rate $rates[$fidx]
        set -l s $tst[$k]
        set -l e $ten[$k]
        set seen[$fidx] (math $seen[$fidx] + 1)

        # coarse integer-second seek for speed, exact cut by sample number
        set -l coarse (math --scale=0 "max(0, floor($s / $rate) - 1)")
        set -l a (math --scale=0 "$s - $coarse * $rate")
        set -l b (math --scale=0 "$e - $coarse * $rate")

        set -l title $tti[$k]
        set -l artist $tpf[$k]
        test "$artist" = "-"; and set artist $aperf
        test -n "$artist_override"; and set artist $artist_override
        set -l safe (string replace -ra '[/\\\\:*?"<>|]' '-' -- $title)

        set -l tn $k
        set -l ttot $n
        set -l label (printf %02d $k)
        set -l out "$outdir/$label - $safe.flac"
        set -l meta
        if test $multi -eq 1
            set tn $seen[$fidx]
            set ttot $ntf[$fidx]
            set label $fidx"-"(printf %02d $tn)
            set out "$outdir/$label - $safe.flac"
            set meta -metadata "DISCNUMBER=$fidx" -metadata "DISCTOTAL=$nfile"
        end
        set meta $meta -metadata "TITLE=$title" -metadata "ARTIST=$artist" -metadata "ALBUMARTIST=$aperf" -metadata "ALBUM=$album" -metadata "TRACKNUMBER=$tn" -metadata "TRACKTOTAL=$ttot"
        test -n "$releasedate"; and set meta $meta -metadata "DATE=$releasedate"

        if not ffmpeg -nostdin -v error -y -ss $coarse -i "$img" -map 0:a:0 -map_metadata -1 -af "atrim=start_sample=$a:end_sample=$b" -c:a flac $meta "$out"
            echo "   !! encoding failed on track $label"
            return 1
        end
        metaflac --add-seekpoint=5s "$out"
        set -a outs "$out"
        set -a expected (math --scale=0 "$e - $s")
        printf '   %s %s\n' $label "$title"
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

    if test "$do_fast" != 1; and test $allzero -eq 1
        echo "   comparing decoded audio, source vs tracks (slow)..."
        set -l srcsum (for f in $files; ffmpeg -nostdin -v error -i "$f" -map 0:a:0 -c:a pcm_s32le -f s32le -; end | cksum)
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
        rm -f $files "$cue"
        command mv -f $outdir/* "$dir/"
        rmdir "$outdir"
        echo "   OK: $n tracks in $dir (original image(s) + CUE removed)"
    else
        command mv "$outdir" "$dir/tracks"
        echo "   OK: $n tracks in $dir/tracks"
    end
end

function splitcue --description 'Split single-FLAC (or one-FLAC-per-LP) + CUE albums into tagged, verified per-track FLACs'
    argparse r/rm f/fast c/continuous 'a/artist=' h/help -- $argv
    or return 1
    if set -q _flag_help
        echo "usage: splitcue [--rm] [--fast] [--continuous] [--artist NAME]"
        echo "  run inside a folder; finds every .cue below it"
        echo "  default:      writes <album>/tracks/ and keeps the originals"
        echo "  --rm:         after verification, puts tracks in the album folder and deletes the image FLAC(s) + CUE"
        echo "  --fast:       skip the full decoded-audio comparison"
        echo "  --continuous: for CUEs with several FILEs, number tracks straight through (no disc tags)"
        echo "                default: each FILE is one disc, tracks restart at 1 and DISCNUMBER is set"
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
    set -l cont_flag 0
    set -q _flag_rm; and set rm_flag 1
    set -q _flag_fast; and set fast_flag 1
    set -q _flag_continuous; and set cont_flag 1

    set -l cues (find . -type f -iname '*.cue' -not -path '*/tracks/*' -not -path '*/tracks.tmp/*' | sort)
    if test (count $cues) -eq 0
        echo "no .cue files under "(pwd)
        return 1
    end
    set -l failed 0
    for cue in $cues
        __splitcue_one "$cue" $rm_flag $fast_flag "$_flag_artist" $cont_flag
        or set failed (math $failed + 1)
    end
    echo "done, $failed album(s) failed"
    test $failed -eq 0
end
