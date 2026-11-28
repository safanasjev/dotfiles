function __shrinkflac_plan --argument-names sr bps cap bits
    # prints target rate, then target bit depth. Only reduces, never exceeds the cap, never upsamples
    set -l tr $sr
    if test $sr -gt $cap
        set -l base 48000
        test (math "$sr % 44100") -eq 0; and set base 44100
        test $base -gt $cap; and set base 44100
        set tr $base
        while test (math "$tr * 2") -le $cap
            set tr (math "$tr * 2")
        end
        test $tr -gt $sr; and set tr $sr
    end
    set -l tb $bps
    test $bps -gt $bits; and set tb $bits
    printf '%s\n' $tr $tb
end

function __shrinkflac_copy_tags --argument-names src dst
    # groups the exported tags into NUL-terminated records, so multi-line values stay in one piece
    set -l grouper 's/\n\z//; my @r; for my $l (split /\n/, $_, -1) { if ($l =~ /^[\x20-\x3C\x3E-\x7D]+=/) { push @r, $l } elsif (@r) { $r[-1] .= "\n" . $l } } print map { "$_\0" } @r;'
    metaflac --remove-all-tags "$dst"; or return 1
    set -l recs (metaflac --no-utf8-convert --export-tags-to=- "$src" | perl -0777 -ne $grouper | string split0)
    for rec in $recs
        test -n "$rec"; or continue
        metaflac --no-utf8-convert --set-tag="$rec" "$dst"; or return 1
    end
    return 0
end

function __shrinkflac_verify --argument-names src dst tr tb
    # prints one line per problem, then "PASS" only if there were none
    set -l why
    set -l sr (metaflac --show-sample-rate "$src")
    set -l ch (metaflac --show-channels "$src")
    set -l total (metaflac --show-total-samples "$src")

    flac -t -s "$dst" 2>/dev/null; or set -a why "FLAC integrity test failed"

    set -l osr (metaflac --show-sample-rate "$dst")
    set -l obps (metaflac --show-bps "$dst")
    set -l och (metaflac --show-channels "$dst")
    set -l ototal (metaflac --show-total-samples "$dst")
    set -l expected (math "round($total * $tr / $sr)")
    set -l tol (math "round($tr / 100)")
    test "$osr" = "$tr"; or set -a why "sample rate is $osr"
    test "$obps" = "$tb"; or set -a why "bit depth is $obps"
    test "$och" = "$ch"; or set -a why "channels changed"
    test (math "abs($ototal - $expected)") -le $tol; or set -a why "length is off ($ototal samples, expected about $expected)"

    # tags: every tag must match the original exactly
    set -l ta (metaflac --no-utf8-convert --export-tags-to=- "$src" | env LC_ALL=C sort | string collect)
    set -l tb2 (metaflac --no-utf8-convert --export-tags-to=- "$dst" | env LC_ALL=C sort | string collect)
    test "$ta" = "$tb2"; or set -a why "tags differ from the original"
    set -l ca (metaflac --list --block-type=VORBIS_COMMENT "$src" | string match -r 'comments: \d+')
    set -l cb (metaflac --list --block-type=VORBIS_COMMENT "$dst" | string match -r 'comments: \d+')
    test "$ca" = "$cb"; or set -a why "tag count differs ($ca vs $cb)"

    # embedded cover
    set -l pin (metaflac --list --block-type=PICTURE "$src" | string match -r '\(PICTURE\)' | count)
    set -l pout (metaflac --list --block-type=PICTURE "$dst" | string match -r '\(PICTURE\)' | count)
    test $pout -ge $pin; or set -a why "embedded cover lost"

    for w in $why
        echo $w
    end
    test (count $why) -eq 0; and echo PASS
end

function __shrinkflac_clone_attrs --argument-names src dst keep_mtime
    # best effort: mode, group (owner when root), ACLs, optionally mtime
    set -l gnu 0
    stat -c %a / >/dev/null 2>&1; and set gnu 1
    set -l mode
    if test $gnu -eq 1
        set mode (stat -c %a "$src" 2>/dev/null)
    else
        set mode (stat -f %Lp "$src" 2>/dev/null)
    end
    test -n "$mode"; and chmod $mode "$dst" 2>/dev/null

    if test (id -u) -eq 0
        if test $gnu -eq 1
            chown --reference="$src" "$dst" 2>/dev/null
        else
            chown (stat -f %u:%g "$src") "$dst" 2>/dev/null
        end
    else
        if test $gnu -eq 1
            chgrp --reference="$src" "$dst" 2>/dev/null
        else
            chgrp (stat -f %g "$src") "$dst" 2>/dev/null
        end
    end

    if command -q getfacl; and command -q setfacl
        getfacl -p "$src" 2>/dev/null | setfacl --set-file=- "$dst" 2>/dev/null
    end
    test "$keep_mtime" = 1; and touch -r "$src" "$dst" 2>/dev/null
    return 0
end

function __shrinkflac_selftest
    for t in ffmpeg flac metaflac perl mktemp find
        command -q $t; or begin
            echo "selftest needs $t" >&2
            return 1
        end
    end
    set -l bad 0

    # ---- plan assertions: "source_rate bits cap max_bits -> rate bits" ----
    for row in \
        "96000 24 48000 16 48000 16" \
        "96000 24 44100 16 44100 16" \
        "48000 24 44100 16 44100 16" \
        "96000 24 46000 16 44100 16" \
        "88200 24 48000 16 44100 16" \
        "44100 16 48000 16 44100 16" \
        "44100 24 48000 16 44100 16" \
        "48000 24 48000 16 48000 16" \
        "32000 24 48000 16 32000 16" \
        "192000 24 96000 24 96000 24" \
        "176400 24 96000 24 88200 24" \
        "192000 24 48000 16 48000 16"
        set -l p (string split ' ' -- $row)
        set -l got (__shrinkflac_plan $p[1] $p[2] $p[3] $p[4])
        if test "$got[1]" != "$p[5]"; or test "$got[2]" != "$p[6]"
            echo "FAIL plan: $p[1]Hz/$p[2]bit cap $p[3] max $p[4]bit -> got $got[1]/$got[2], expected $p[5]/$p[6]"
            set bad 1
        end
    end

    # ---- functional tests on synthetic files ----
    set -l d (mktemp -d)
    test -n "$d"; and test -d "$d"; or return 1
    mkdir "$d/main" "$d/sub" "$d/keep"

    ffmpeg -nostdin -v error -f lavfi -i "color=c=red:s=64x64" -frames:v 1 "$d/c.jpg"
    or begin
        echo "selftest: couldn't create the test cover" >&2
        rm -rf -- $d
        return 1
    end

    set -l odd (printf 'odd name\nx.flac' | string collect)
    set -l oddf "$d/main/$odd"
    ffmpeg -nostdin -v error -f lavfi -i "sine=frequency=440:sample_rate=96000:duration=3" -i "$d/c.jpg" -map 0:a -map 1:v -c:a flac -sample_fmt s32 -bits_per_raw_sample 24 -c:v copy -disposition:v attached_pic "$oddf"
    and ffmpeg -nostdin -v error -f lavfi -i "sine=frequency=550:sample_rate=44100:duration=3" -c:a flac -sample_fmt s16 "$d/main/cd.flac"
    and ffmpeg -nostdin -v error -f lavfi -i "sine=frequency=660:sample_rate=192000:duration=3" -c:a flac -sample_fmt s32 -bits_per_raw_sample 24 "$d/sub/hi.flac"
    and ffmpeg -nostdin -v error -f lavfi -i "sine=frequency=770:sample_rate=96000:duration=3" -c:a flac -sample_fmt s32 -bits_per_raw_sample 24 "$d/keep/keep.flac"
    or begin
        echo "selftest: couldn't create the test audio" >&2
        rm -rf -- $d
        return 1
    end

    set -l multi (printf 'COMMENT=first line\nsecond line' | string collect)
    metaflac --set-tag="TITLE=Test" --set-tag="GENRE=Rock" --set-tag="GENRE=Metal" --set-tag="$multi" "$oddf"
    set -l tags_before (metaflac --no-utf8-convert --export-tags-to=- "$oddf" | env LC_ALL=C sort | string collect)
    set -l cd_before (cksum < "$d/main/cd.flac")
    touch -t 200001010000 "$oddf" "$d/keep/keep.flac"

    # run 1: defaults
    shrinkflac --apply "$d/main" >/dev/null
    test (metaflac --show-bps "$oddf") = 16; or begin; echo "FAIL: default run, bit depth"; set bad 1; end
    test (metaflac --show-sample-rate "$oddf") = 48000; or begin; echo "FAIL: default run, sample rate"; set bad 1; end
    set -l tags_after (metaflac --no-utf8-convert --export-tags-to=- "$oddf" | env LC_ALL=C sort | string collect)
    test "$tags_before" = "$tags_after"; or begin; echo "FAIL: tags changed (duplicate or multi-line tags?)"; set bad 1; end
    test (metaflac --list --block-type=PICTURE "$oddf" | string match -r '\(PICTURE\)' | count) -ge 1; or begin; echo "FAIL: embedded cover lost"; set bad 1; end
    flac -t -s "$oddf" 2>/dev/null; or begin; echo "FAIL: converted file is corrupt"; set bad 1; end
    test (find "$oddf" -newermt 2001-01-01 -print0 | string split0 | count) -ge 1; or begin; echo "FAIL: mtime should change by default"; set bad 1; end
    test "$cd_before" = (cksum < "$d/main/cd.flac"); or begin; echo "FAIL: a 16-bit/44.1k file was modified"; set bad 1; end

    # run 2: --bits 24 --rate 96000
    shrinkflac --apply --bits 24 --rate 96000 "$d/sub" >/dev/null
    test (metaflac --show-bps "$d/sub/hi.flac") = 24; or begin; echo "FAIL: --bits 24, bit depth"; set bad 1; end
    test (metaflac --show-sample-rate "$d/sub/hi.flac") = 96000; or begin; echo "FAIL: --rate 96000, sample rate"; set bad 1; end

    # run 3: --keep-mtime
    shrinkflac --apply --keep-mtime "$d/keep" >/dev/null
    test (metaflac --show-bps "$d/keep/keep.flac") = 16; or begin; echo "FAIL: keep-mtime run did not convert"; set bad 1; end
    test (find "$d/keep/keep.flac" -newermt 2001-01-01 -print0 | string split0 | count) -eq 0; or begin; echo "FAIL: --keep-mtime changed the mtime"; set bad 1; end

    test (find "$d" -name '.shrinkflac.*' | count) -eq 0; or begin; echo "FAIL: temp file left behind"; set bad 1; end

    rm -rf -- $d
    if test $bad -eq 0
        echo "selftest PASS"
        return 0
    end
    echo "selftest FAIL"
    return 1
end

function shrinkflac --description 'Shrink hi-res FLACs to 16-bit / <=48 kHz: verified, in place, dry run by default'
    argparse 'y/apply' 'b/bits=' 'r/rate=' 'k/keep-mtime' 's/selftest' 'h/help' -- $argv
    or return 1
    if set -q _flag_help
        echo "usage: shrinkflac [--apply] [--bits 16|24] [--rate MAX_HZ] [--keep-mtime] [DIR]"
        echo "       shrinkflac --selftest"
        echo "  default:      dry run, only lists what would change"
        echo "  --apply:      convert in place; each file is replaced only after it passes all checks"
        echo "  --bits:       max bit depth (default 16)"
        echo "  --rate:       max sample rate (default 48000). 44.1k-family sources stay 44.1k-family, 48k-family stay 48k-family;"
        echo "                a cap below 48000 sends 48k-family files to 44100"
        echo "  --keep-mtime: keep the original modification time (by default it changes, so scanners notice)"
        echo "  --selftest:   run plan assertions and convert synthetic files"
        return 0
    end
    if set -q _flag_selftest
        __shrinkflac_selftest
        return $status
    end

    set -l bits 16
    set -l cap 48000
    set -q _flag_bits; and set bits $_flag_bits
    set -q _flag_rate; and set cap $_flag_rate
    if not contains -- $bits 16 24
        echo "--bits must be 16 or 24" >&2; return 1
    end
    if not string match -qr '^\d+$' -- $cap; or test $cap -lt 44100
        echo "--rate must be a number >= 44100" >&2; return 1
    end
    set -l root .
    test (count $argv) -gt 0; and set root $argv[1]
    if not test -d "$root"
        echo "not a directory: $root" >&2; return 1
    end
    for t in ffmpeg flac metaflac find wc perl sort mktemp dirname env
        if not command -q $t
            echo "missing: $t   (macOS: brew install ffmpeg flac | Debian: sudo apt install ffmpeg flac perl)" >&2
            return 1
        end
    end
    set -l apply 0
    set -q _flag_apply; and set apply 1
    set -l keep 0
    set -q _flag_keep_mtime; and set keep 1

    # use soxr for resampling when this ffmpeg has it
    set -l soxr 0
    if ffmpeg -hide_banner -buildconf 2>/dev/null | string match -q '*--enable-libsoxr*'
        set soxr 1
    end

    set -l files (find "$root" -type f -iname '*.flac' -print0 | env LC_ALL=C sort -z | string split0)
    set -l todo 0
    set -l done_ok 0
    set -l failed 0
    set -l skipped 0
    set -l before_total 0
    set -l after_total 0

    for f in $files
        set -l sr (metaflac --show-sample-rate "$f" 2>/dev/null)
        set -l bps (metaflac --show-bps "$f" 2>/dev/null)
        set -l total (metaflac --show-total-samples "$f" 2>/dev/null)

        if test -z "$sr"; or test -z "$bps"; or test -z "$total"
            echo "skip (unreadable FLAC): $f" >&2
            set skipped (math $skipped + 1)
            continue
        end
        if test "$total" = 0
            echo "skip (header has no total samples, repair it first): $f" >&2
            set skipped (math $skipped + 1)
            continue
        end
        if test $bps -lt 16
            set skipped (math $skipped + 1)
            continue
        end

        set -l plan (__shrinkflac_plan $sr $bps $cap $bits)
        set -l tr $plan[1]
        set -l tb $plan[2]
        if test $tr -eq $sr; and test $tb -eq $bps
            continue
        end

        set todo (math $todo + 1)
        set -l size (wc -c < "$f" | string trim)
        set before_total (math $before_total + $size)

        if test $apply -eq 0
            echo "would convert: $bps-bit/$sr -> $tb-bit/$tr   $f"
            continue
        end

        echo "== $bps-bit/$sr -> $tb-bit/$tr   $f"
        set -l dir (dirname -- "$f")
        set -l part (mktemp "$dir/.shrinkflac.XXXXXX" 2>/dev/null)
        or begin
            echo "   !! can't create a temp file in $dir" >&2
            set failed (math $failed + 1)
            continue
        end

        set -l osf s16
        test $tb -gt 16; and set osf s32
        set -l af "aresample=osr=$tr:osf=$osf:dither_method=triangular"
        if test $soxr -eq 1
            set af "aresample=osr=$tr:osf=$osf:resampler=soxr:precision=28:dither_method=triangular"
        end
        set -l rawbits
        test $tb -gt 16; and set rawbits -bits_per_raw_sample $tb

        # audio + cover only; tags are copied separately with metaflac
        if not ffmpeg -nostdin -v error -xerror -y -i "$f" -map 0:a:0 -map 0:v? -c:v copy -disposition:v attached_pic -map_metadata -1 -af "$af" -c:a flac $rawbits -f flac "$part"
            echo "   !! ffmpeg failed, original untouched" >&2
            rm -f "$part"
            set failed (math $failed + 1)
            continue
        end

        if not metaflac --add-seekpoint=5s "$part"; or not __shrinkflac_copy_tags "$f" "$part"
            echo "   !! couldn't write the seek table or tags, original untouched" >&2
            rm -f "$part"
            set failed (math $failed + 1)
            continue
        end

        set -l why (__shrinkflac_verify "$f" "$part" $tr $tb)
        if test "$why" != PASS
            if test (count $why) -eq 0
                echo "   !! not replaced: verification produced no result" >&2
            else
                echo "   !! not replaced: $why" >&2
            end
            rm -f "$part"
            set failed (math $failed + 1)
            continue
        end

        __shrinkflac_clone_attrs "$f" "$part" $keep
        if not command mv -f "$part" "$f"
            echo "   !! replace failed, original untouched" >&2
            rm -f "$part"
            set failed (math $failed + 1)
            continue
        end

        set -l newsize (wc -c < "$f" | string trim)
        set after_total (math $after_total + $newsize)
        set done_ok (math $done_ok + 1)
    end

    if test $apply -eq 0
        echo "dry run: $todo file(s) would change, currently "(math --scale=1 "$before_total / 1073741824")" GiB. Rerun with --apply."
    else
        echo "done: $done_ok converted, $failed failed, $skipped skipped"
        echo "saved about "(math --scale=1 "($before_total - $after_total) / 1073741824")" GiB"
    end
    test $failed -eq 0
end
