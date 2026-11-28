function __splitcue_awk --argument-names mode
    set -l prog '
function val(s,   t, i, bs) {
  t = s
  sub(/^ *[A-Za-z_]+ +/, "", t)
  sub(/ +$/, "", t)
  if (t ~ /^".*"$/) {
    t = substr(t, 2, length(t) - 2)
    bs = sprintf("%c", 92)
    while ((i = index(t, bs "\"")) > 0) t = substr(t, 1, i - 1) substr(t, i + 1)
  }
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
/^ *INDEX +0?1 / { split($3, tm, ":"); fr[n] = (tm[1] * 60 + tm[2]) * 75 + tm[3]; hasfr[n] = 1; next }
END {
  if (mode == "meta") {
    print (album == "" ? "-" : album)
    print (aperf == "" ? "-" : aperf)
    print (rdate == "" ? "-" : rdate)
    print n + 0
    print nfile + 0
  }
  if (mode == "file") {
    for (k = 1; k <= nfile; k++) print fname[k]
  }
  if (mode == "track") {
    for (k = 1; k <= n; k++)
      printf "%d\t%d\t%s\t%s\n", tfile[k], (hasfr[k] ? fr[k] : -1), (title[k] == "" ? sprintf("Track %02d", k) : title[k]), (perf[k] == "" ? "-" : perf[k])
  }
}
'
    awk -v mode=$mode $prog
end

function __splitcue_decode --argument-names cue enc
    # prints the CUE as clean UTF-8 (no BOM, no CR, no tabs); prints nothing on failure
    set -l from $enc
    if test -z "$from"
        set -l bom (head -c 2 "$cue" | od -An -tx1 | string trim)
        if test "$bom" = "ff fe"; or test "$bom" = "fe ff"
            set from UTF-16
        else if iconv -f UTF-8 -t UTF-8 "$cue" >/dev/null 2>&1
            set from UTF-8
        else if iconv -f CP1252 -t UTF-8 "$cue" >/dev/null 2>&1
            set from CP1252
        else
            set from ISO-8859-1
        end
    end
    iconv -f $from -t UTF-8 "$cue" >/dev/null 2>&1; or return 1
    test "$from" != UTF-8; and echo "   (CUE decoded as $from)" >&2
    iconv -f $from -t UTF-8 "$cue" | perl -pe 's/^\xEF\xBB\xBF// if $. == 1; s/\r//g; s/\t/ /g'
end

function __splitcue_match_files --argument-names dir
    # args after DIR: the FILE names from the CUE. Sets $__sc_files (one path per entry); returns 1 if it can't match
    set -l fnames $argv[2..-1]
    set -l flacs (find "$dir" -maxdepth 1 -type f -iname '*.flac' -print0 | env LC_ALL=C sort -z | string split0)
    set -g __sc_files
    set -l unresolved 0
    for nm in $fnames
        set -l found ""
        set -l want (string lower -- (string replace -r '\.[^./]*$' '' -- (basename -- "$nm")))
        if test -f "$dir/$nm"; and string match -qi '*.flac' -- "$nm"
            set found "$dir/$nm"
        else
            for c in $flacs
                set -l have (string lower -- (string replace -r '\.[^./]*$' '' -- (basename -- "$c")))
                if test "$have" = "$want"
                    set found $c
                    break
                end
            end
        end
        test -z "$found"; and set unresolved 1
        set -a __sc_files "$found"
    end
    if test $unresolved -eq 1
        if test (count $flacs) -eq (count $fnames)
            set -g __sc_files $flacs
            echo "   (FILE names don't match, using the FLACs in sorted order)" >&2
        else
            echo "   !! can't match the CUE's FILE entries to the FLACs in this folder" >&2
            return 1
        end
    end
    return 0
end

function __splitcue_pick_cover --argument-names dir override
    # prints the chosen front-cover image, or nothing
    if test -n "$override"
        test -f "$override"; and echo $override
        return 0
    end
    set -l imgs (find "$dir" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print0 | env LC_ALL=C sort -z | string split0)
    set -l best ""
    set -l bestscore 99999
    for p in $imgs
        set -l b (basename -- "$p")
        set -l stem (string replace -r '\.[^.]*$' '' -- $b)
        if string match -riq '(^|[-_ \[(])(back|rear|insert|gatefold|booklet|label|spine|inlay|tray|inside|obi|sticker|cd|disc)([^a-z]|$)' -- $stem
            continue
        end
        set -l score (string length -- $b)
        string match -riq '^(cover|front|folder|album)$' -- $stem; and set score 0
        if test $score -lt $bestscore
            set best $p
            set bestscore $score
        end
    end
    test -n "$best"; and echo $best
    return 0
end

function __splitcue_cut --argument-names img rate s e out
    # cut samples [s, e) of IMG into OUT; remaining args are ffmpeg -metadata options
    set -l meta $argv[6..-1]
    # coarse integer-second seek for speed, exact cut by sample number
    set -l coarse (math --scale=0 "max(0, floor($s / $rate) - 1)")
    set -l a (math --scale=0 "$s - $coarse * $rate")
    set -l b (math --scale=0 "$e - $coarse * $rate")
    ffmpeg -nostdin -v error -y -ss $coarse -i "$img" -map 0:a:0 -map_metadata -1 -af "atrim=start_sample=$a:end_sample=$b" -c:a flac $meta "$out"; or return 1
    metaflac --add-seekpoint=5s "$out"
end

function __splitcue_pcm_sum
    # args: START_SAMPLE FILE...   prints "CRC BYTES" of the decoded audio of the files, concatenated
    set -l s0 $argv[1]
    set -l fl $argv[2..-1]
    set -l af
    test "$s0" -gt 0 2>/dev/null; and set af -af "atrim=start_sample=$s0"
    for f in $fl
        ffmpeg -nostdin -v error -i "$f" -map 0:a:0 $af -c:a pcm_s32le -f s32le -
    end | cksum
end

function __splitcue_one --argument-names cue do_rm do_fast artist_override continuous cover_override no_cover enc
    set -l dir (dirname -- "$cue")
    set -l stem (string replace -r '\.[cC][uU][eE]$' '' -- (basename -- "$cue"))
    echo "== $cue"

    if test -d "$dir/tracks"
        echo "   skip: $dir/tracks already exists"
        return 0
    end

    # ---- read the CUE ----
    set -l cuetext (__splitcue_decode "$cue" "$enc" | string collect)
    if test -z "$cuetext"
        echo "   !! can't decode the CUE (try --cue-encoding ENC)" >&2
        return 1
    end
    set -l m (printf '%s\n' "$cuetext" | __splitcue_awk meta)
    set -l fnames (printf '%s\n' "$cuetext" | __splitcue_awk file)
    set -l rows (printf '%s\n' "$cuetext" | __splitcue_awk track)

    set -l album $m[1]
    set -l aperf $m[2]
    set -l releasedate $m[3]
    set -l n $m[4]
    set -l nfile $m[5]
    test "$album" = "-"; and set album ""
    test "$aperf" = "-"; and set aperf ""
    test "$releasedate" = "-"; and set releasedate ""

    if not test "$n" -ge 1 2>/dev/null; or not test "$nfile" -ge 1 2>/dev/null; or test (count $rows) -ne $n; or test (count $fnames) -ne $nfile
        echo "   !! CUE not supported (need at least one FILE, and TRACKs with INDEX 01)" >&2
        return 1
    end

    # ---- source files ----
    __splitcue_match_files "$dir" $fnames; or return 1
    set -l files $__sc_files
    set -e __sc_files

    set -l rates
    set -l totals
    set -l bpsf
    set -l chf
    for f in $files
        set -l r (metaflac --show-sample-rate "$f" 2>/dev/null)
        set -l t (metaflac --show-total-samples "$f" 2>/dev/null)
        if test -z "$r"; or not test "$t" -gt 0 2>/dev/null
            echo "   !! can't read $f (or its header has no total samples)" >&2
            return 1
        end
        set -a rates $r
        set -a totals $t
        set -a bpsf (metaflac --show-bps "$f")
        set -a chf (metaflac --show-channels "$f")
    end

    # ---- track table: fidx, start sample, end sample, title, performer ----
    set -l trk
    set -l lastfx 0
    for k in (seq 1 $n)
        set -l p (string split \t -- $rows[$k])
        set -l fx $p[1]
        set -l fr $p[2]
        if not test "$fx" -ge 1 2>/dev/null; or test "$fx" -gt $nfile; or test "$fr" -lt 0
            echo "   !! track $k has no INDEX 01 or sits outside any FILE" >&2
            return 1
        end
        test $fx -ge $lastfx; or begin
            echo "   !! tracks are not in FILE order" >&2
            return 1
        end
        set lastfx $fx
        set -l rt $rates[$fx]
        set -l s (math --scale=0 "round($fr * $rt / 75)")
        set -l e $totals[$fx]
        if test $k -lt $n
            set -l q (string split \t -- $rows[(math $k + 1)])
            if test "$q[1]" = "$fx"
                set e (math --scale=0 "round($q[2] * $rt / 75)")
            end
        end
        if not test $s -ge 0; or not test $s -lt $e; or test $e -gt $totals[$fx]
            echo "   !! CUE times don't fit the audio of "$files[$fx] >&2
            return 1
        end
        set -a trk (string join \t -- $fx $s $e "$p[3]" "$p[4]")
    end

    set -l ntf
    set -l first
    set -l seen
    for i in (seq 1 $nfile)
        set -a ntf 0
        set -a first -1
        set -a seen 0
    end
    for r in $trk
        set -l p (string split \t -- $r)
        set -l fx $p[1]
        set ntf[$fx] (math $ntf[$fx] + 1)
        test $first[$fx] -lt 0; and set first[$fx] $p[2]
    end
    for i in (seq 1 $nfile)
        if test $ntf[$i] -eq 0
            echo "   !! no tracks in the CUE belong to "$files[$i] >&2
            return 1
        end
    end

    # ---- artist / album ----
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
        echo "   !! no artist found, rerun with --artist NAME" >&2
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
            echo "   !! source FLAC is corrupt: $f (re-download/re-copy it and check the disk)" >&2
            return 1
        end
    end

    # ---- scratch folder ----
    set -l outdir "$dir/tracks.tmp"
    if test -e "$outdir"; or test -L "$outdir"
        set -l odd (find "$outdir" -mindepth 1 -not -iname '*.flac' -not -name cover.jpg -print)
        if test -L "$outdir"; or not test -d "$outdir"; or test (count $odd) -gt 0
            echo "   !! $outdir exists and holds unexpected files, not touching it" >&2
            return 1
        end
        rm -rf -- "$outdir"; or return 1
    end
    mkdir "$outdir"; or return 1

    # ---- cut ----
    set -l outs
    set -l expected
    for k in (seq 1 $n)
        set -l p (string split \t -- $trk[$k])
        set -l fx $p[1]
        set -l s $p[2]
        set -l e $p[3]
        set -l title $p[4]
        set -l artist $p[5]
        test "$artist" = "-"; and set artist $aperf
        test -n "$artist_override"; and set artist $artist_override
        set seen[$fx] (math $seen[$fx] + 1)

        set -l safe (string replace -ra '[/\\\\:*?"<>|]' '-' -- $title)
        set -l tn $k
        set -l ttot $n
        set -l label (printf %02d $k)
        set -l meta
        if test $multi -eq 1
            set tn $seen[$fx]
            set ttot $ntf[$fx]
            set label $fx"-"(printf %02d $tn)
            set meta -metadata "DISCNUMBER=$fx" -metadata "DISCTOTAL=$nfile"
        end
        set meta $meta -metadata "TITLE=$title" -metadata "ARTIST=$artist" -metadata "ALBUMARTIST=$aperf" -metadata "ALBUM=$album" -metadata "TRACKNUMBER=$tn" -metadata "TRACKTOTAL=$ttot"
        test -n "$releasedate"; and set meta $meta -metadata "DATE=$releasedate"

        set -l out "$outdir/$label - $safe.flac"
        if not __splitcue_cut "$files[$fx]" $rates[$fx] $s $e "$out" $meta
            echo "   !! encoding failed on track $label (partial results left in $outdir)" >&2
            return 1
        end
        set -a outs "$out"
        set -a expected (math --scale=0 "$e - $s")
        printf '   %s %s\n' $label "$title"
    end

    # ---- cover ----
    if test "$no_cover" != 1
        set -l front (__splitcue_pick_cover "$dir" "$cover_override")
        if test -n "$front"
            if ffmpeg -nostdin -v error -y -i "$front" -vf "scale='min(1400,iw)':-2" -frames:v 1 -update 1 -q:v 2 "$outdir/cover.jpg"
                echo "   cover: "(basename -- "$front")
            else
                echo "   (cover conversion failed, continuing without it)" >&2
                rm -f "$outdir/cover.jpg"
            end
        else
            echo "   (no cover image found)"
        end
    end

    # ---- verify ----
    echo "   verifying..."
    set -l bad 0
    for k in (seq 1 $n)
        set -l p (string split \t -- $trk[$k])
        set -l fx $p[1]
        set -l o $outs[$k]
        set -l got (metaflac --show-total-samples "$o")
        set -l orate (metaflac --show-sample-rate "$o")
        set -l obps (metaflac --show-bps "$o")
        set -l och (metaflac --show-channels "$o")
        test "$got" = "$expected[$k]"; or begin
            echo "   !! track $k: header says $got samples, expected $expected[$k]" >&2
            set bad 1
        end
        test "$orate" = "$rates[$fx]"; or begin
            echo "   !! track $k: sample rate is $orate" >&2
            set bad 1
        end
        test "$obps" = "$bpsf[$fx]"; or begin
            echo "   !! track $k: bit depth is $obps, source is $bpsf[$fx]" >&2
            set bad 1
        end
        test "$och" = "$chf[$fx]"; or begin
            echo "   !! track $k: channel count changed" >&2
            set bad 1
        end
        flac -t -s "$o"; or begin
            echo "   !! track $k fails the FLAC integrity test" >&2
            set bad 1
        end
    end

    if test "$do_fast" != 1
        echo "   comparing decoded audio, source vs tracks (slow)..."
        for i in (seq 1 $nfile)
            set -l mine
            for k in (seq 1 $n)
                set -l p (string split \t -- $trk[$k])
                test "$p[1]" = "$i"; and set -a mine $outs[$k]
            end
            set -l srcsum (__splitcue_pcm_sum $first[$i] "$files[$i]")
            set -l outsum (__splitcue_pcm_sum 0 $mine)
            set -l sp (string split ' ' -- $srcsum)
            if test "$srcsum" != "$outsum"; or not test "$sp[2]" -gt 0 2>/dev/null
                echo "   !! decoded audio differs from the source for "$files[$i] >&2
                set bad 1
            end
        end
    end

    if test $bad -ne 0
        echo "   !! verification failed. Left $outdir for inspection, originals untouched" >&2
        return 1
    end

    # ---- finish ----
    if test "$do_rm" = 1
        # 1. refuse to overwrite anything
        for f in $outdir/*
            set -l b (basename -- "$f")
            test "$b" = cover.jpg; and continue
            if test -e "$dir/$b"
                echo "   !! $dir/$b already exists, not overwriting. Originals kept, results left in $outdir" >&2
                return 1
            end
        end
        # 2. move the verified tracks in, with rollback
        set -l moved
        for f in $outdir/*
            set -l b (basename -- "$f")
            if test "$b" = cover.jpg; and test -e "$dir/cover.jpg"
                rm -f -- "$f"
                echo "   (kept the existing cover.jpg)"
                continue
            end
            if command mv -- "$f" "$dir/$b"
                set -a moved "$dir/$b"
            else
                echo "   !! couldn't move $b, rolling back. Originals kept" >&2
                for t in $moved
                    command mv -- "$t" "$outdir/"(basename -- "$t")
                end
                return 1
            end
        end
        rmdir "$outdir"; or begin
            echo "   !! couldn't remove $outdir. Tracks are in place, originals kept" >&2
            return 1
        end
        # 3. only now delete the originals
        rm -f -- $files "$cue"; or begin
            echo "   !! tracks are in place, but deleting the originals failed" >&2
            return 1
        end
        echo "   OK: $n tracks in $dir (original image(s) + CUE removed)"
    else
        command mv -- "$outdir" "$dir/tracks"; or begin
            echo "   !! couldn't rename $outdir to tracks" >&2
            return 1
        end
        echo "   OK: $n tracks in $dir/tracks"
    end
end

function __splitcue_selftest
    for t in ffmpeg flac metaflac mktemp
        command -q $t; or begin
            echo "selftest needs $t" >&2
            return 1
        end
    end
    set -l here (pwd)
    set -l d (mktemp -d)
    test -n "$d"; and test -d "$d"; or return 1
    cd $d; or return 1
    set -l bad 0

    ffmpeg -nostdin -v error -f lavfi -i "sine=frequency=440:sample_rate=96000:duration=6" -c:a flac -sample_fmt s32 -bits_per_raw_sample 24 LP1.flac
    and ffmpeg -nostdin -v error -f lavfi -i "sine=frequency=660:sample_rate=96000:duration=4" -c:a flac -sample_fmt s32 -bits_per_raw_sample 24 LP2.flac
    or begin
        echo "selftest: couldn't create test audio" >&2
        cd $here
        rm -rf -- $d
        return 1
    end
    printf '%s\n' \
        'PERFORMER "Test Artist"' \
        'TITLE "Test Album (Vinyl)"' \
        'REM DATE 2001' \
        'FILE "LP1.flac" WAVE' \
        '  TRACK 01 AUDIO' \
        '    TITLE "One"' \
        '    INDEX 01 00:00:00' \
        '  TRACK 02 AUDIO' \
        '    TITLE "Two: \"Quoted\""' \
        '    INDEX 01 00:02:00' \
        '  TRACK 03 AUDIO' \
        '    TITLE "Three"' \
        '    INDEX 01 00:04:00' \
        'FILE "LP2.flac" WAVE' \
        '  TRACK 04 AUDIO' \
        '    TITLE "Four"' \
        '    INDEX 01 00:00:30' \
        '  TRACK 05 AUDIO' \
        '    TITLE "Five"' \
        '    INDEX 01 00:02:00' >test.cue

    set -l t1 (metaflac --show-total-samples LP1.flac)
    set -l t2 (metaflac --show-total-samples LP2.flac)

    splitcue >/dev/null; or begin
        echo "FAIL: splitcue reported an error"
        set bad 1
    end
    set -l nout (count tracks/*.flac)
    test "$nout" = 5; or begin
        echo "FAIL: expected 5 tracks, found $nout"
        set bad 1
    end
    set -l f2 tracks/1-02*.flac
    test (metaflac --show-tag=TITLE $f2) = 'TITLE=Two: "Quoted"'; or begin
        echo "FAIL: title with escaped quotes"
        set bad 1
    end
    set -l f3 tracks/2-01*.flac
    test (metaflac --show-tag=DISCNUMBER $f3) = "DISCNUMBER=2"; or begin
        echo "FAIL: disc number"
        set bad 1
    end
    test (metaflac --show-tag=ALBUM $f3) = "ALBUM=Test Album"; or begin
        echo "FAIL: album name ((Vinyl) suffix not stripped?)"
        set bad 1
    end
    set -l f1 tracks/1-01*.flac
    set -l f5 tracks/2-02*.flac
    test (metaflac --show-total-samples $f1) = 192000; or begin
        echo "FAIL: track 1 length"
        set bad 1
    end
    test (metaflac --show-total-samples $f3) = 153600; or begin
        echo "FAIL: track 4 length (start offset not 0)"
        set bad 1
    end
    test (metaflac --show-total-samples $f5) = (math "$t2 - 192000"); or begin
        echo "FAIL: last track length"
        set bad 1
    end

    rm -rf -- tracks
    splitcue --rm >/dev/null; or begin
        echo "FAIL: splitcue --rm reported an error"
        set bad 1
    end
    if test -e LP1.flac; or test -e LP2.flac; or test -e test.cue
        echo "FAIL: originals were not removed"
        set bad 1
    end
    test (count 1-*.flac 2-*.flac) = 5; or begin
        echo "FAIL: tracks are not in the album folder after --rm"
        set bad 1
    end

    cd $here
    rm -rf -- $d
    if test $bad -eq 0
        echo "selftest PASS"
        return 0
    end
    echo "selftest FAIL"
    return 1
end

function splitcue --description 'Split single-FLAC (or one-FLAC-per-LP) + CUE albums into tagged, verified per-track FLACs'
    argparse r/rm f/fast c/continuous n/no-cover s/selftest 'a/artist=' 'C/cover=' 'e/cue-encoding=' h/help -- $argv
    or return 1
    if set -q _flag_help
        echo "usage: splitcue [--rm] [--fast] [--continuous] [--artist NAME] [--cover FILE | --no-cover] [--cue-encoding ENC]"
        echo "       splitcue --selftest"
        echo "  run inside a folder; finds every .cue below it"
        echo "  default:         writes <album>/tracks/ and keeps the originals"
        echo "  --rm:            after full verification, moves the tracks into the album folder, then deletes the image FLAC(s) + CUE"
        echo "  --fast:          skip the full decoded-audio comparison (not recommended together with --rm)"
        echo "  --continuous:    CUEs with several FILEs: number tracks straight through, no disc tags"
        echo "                   default: each FILE is one disc, tracks restart at 1 and DISCNUMBER is set"
        echo "  --cover FILE:    use this image as the cover; --no-cover: don't write one"
        echo "  --cue-encoding:  force the CUE's text encoding (for example SHIFT_JIS, UTF-16LE)"
        echo "  --selftest:      build a synthetic two-LP album and check the result"
        return 0
    end
    if set -q _flag_selftest
        __splitcue_selftest
        return $status
    end
    for t in ffmpeg flac metaflac awk perl iconv cksum find sort od head
        if not command -q $t
            echo "missing: $t   (macOS: brew install ffmpeg flac | Debian: sudo apt install ffmpeg flac perl)" >&2
            return 1
        end
    end
    set -l rm_flag 0
    set -l fast_flag 0
    set -l cont_flag 0
    set -l nocover_flag 0
    set -q _flag_rm; and set rm_flag 1
    set -q _flag_fast; and set fast_flag 1
    set -q _flag_continuous; and set cont_flag 1
    set -q _flag_no_cover; and set nocover_flag 1
    if test $rm_flag -eq 1; and test $fast_flag -eq 1
        echo "warning: --rm with --fast deletes the originals without the decoded-audio check" >&2
    end

    set -l cues (find . -type f -iname '*.cue' -not -path '*/tracks/*' -not -path '*/tracks.tmp/*' -print0 | env LC_ALL=C sort -z | string split0)
    if test (count $cues) -eq 0
        echo "no .cue files under "(pwd) >&2
        return 1
    end
    set -l failed 0
    for cue in $cues
        __splitcue_one "$cue" $rm_flag $fast_flag "$_flag_artist" $cont_flag "$_flag_cover" $nocover_flag "$_flag_cue_encoding"
        or set failed (math $failed + 1)
    end
    echo "done, $failed album(s) failed"
    test $failed -eq 0
end
