function shrinkflac --description 'Shrink hi-res FLACs to 16-bit / <=48 kHz: verified, in place, dry run by default'
    argparse 'y/apply' 'b/bits=' 'r/rate=' 'h/help' -- $argv
    or return 1
    if set -q _flag_help
        echo "usage: shrinkflac [--apply] [--bits 16|24] [--rate MAX_HZ] [DIR]"
        echo "  default: dry run, only lists what would change"
        echo "  --apply: convert in place; each file is replaced only after it passes checks"
        echo "  --bits:  max bit depth (default 16)"
        echo "  --rate:  max sample rate (default 48000; 44.1k-family stays 44.1k, 48k-family stays 48k)"
        return 0
    end

    set -l bits 16
    set -l cap 48000
    set -q _flag_bits; and set bits $_flag_bits
    set -q _flag_rate; and set cap $_flag_rate
    if not contains -- $bits 16 24
        echo "--bits must be 16 or 24"; return 1
    end
    if not string match -qr '^\d+$' -- $cap; or test $cap -lt 44100
        echo "--rate must be a number >= 44100"; return 1
    end
    set -l root .
    test (count $argv) -gt 0; and set root $argv[1]
    if not test -d "$root"
        echo "not a directory: $root"; return 1
    end
    for t in ffmpeg flac metaflac find wc
        if not command -q $t
            echo "missing: $t   (macOS: brew install ffmpeg flac | Debian: sudo apt install ffmpeg flac)"
            return 1
        end
    end
    set -l apply 0
    set -q _flag_apply; and set apply 1

    # use soxr for resampling when this ffmpeg has it
    set -l soxr 0
    if ffmpeg -hide_banner -buildconf 2>/dev/null | string match -q '*--enable-libsoxr*'
        set soxr 1
    end

    set -l files (find "$root" -type f -iname '*.flac' -print0 | string split0 | sort)
    set -l todo 0
    set -l done_ok 0
    set -l failed 0
    set -l skipped 0
    set -l before_total 0
    set -l after_total 0

    for f in $files
        set -l sr (metaflac --show-sample-rate "$f" 2>/dev/null)
        set -l bps (metaflac --show-bps "$f" 2>/dev/null)
        set -l ch (metaflac --show-channels "$f" 2>/dev/null)
        set -l total (metaflac --show-total-samples "$f" 2>/dev/null)

        if test -z "$sr"; or test -z "$bps"; or test -z "$total"
            echo "skip (unreadable FLAC): $f"
            set skipped (math $skipped + 1)
            continue
        end
        if test "$total" = 0
            echo "skip (header has no total samples, repair it first): $f"
            set skipped (math $skipped + 1)
            continue
        end
        if test $bps -lt 16
            set skipped (math $skipped + 1)
            continue
        end

        # target rate: only reduce, stay in the same 44.1k/48k family
        set -l tr $sr
        if test $sr -gt $cap
            set -l base 48000
            test (math "$sr % 44100") -eq 0; and set base 44100
            set tr $base
            while test (math "$tr * 2") -le $cap
                set tr (math "$tr * 2")
            end
        end
        # target bit depth: only reduce
        set -l tb $bps
        test $bps -gt $bits; and set tb $bits

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
        set -l part "$f.part"
        rm -f "$part"

        set -l osf s16
        test $tb -gt 16; and set osf s32
        set -l af "aresample=osr=$tr:osf=$osf:dither_method=triangular"
        if test $soxr -eq 1
            set af "aresample=osr=$tr:osf=$osf:resampler=soxr:precision=28:dither_method=triangular"
        end
        set -l rawbits
        test $tb -gt 16; and set rawbits -bits_per_raw_sample $tb

        if not ffmpeg -nostdin -v error -xerror -y -i "$f" -map 0:a:0 -map 0:v? -c:v copy -disposition:v attached_pic -map_metadata 0 -af "$af" -c:a flac $rawbits -f flac "$part"
            echo "   !! ffmpeg failed, original untouched"
            rm -f "$part"
            set failed (math $failed + 1)
            continue
        end
        metaflac --add-seekpoint=5s "$part"
        metaflac --remove-all-tags "$part"
        metaflac --export-tags-to=- "$f" | metaflac --import-tags-from=- "$part"

        # verification
        set -l why
        flac -t -s "$part" 2>/dev/null; or set -a why "FLAC integrity test failed"
        set -l osr (metaflac --show-sample-rate "$part")
        set -l obps (metaflac --show-bps "$part")
        set -l och (metaflac --show-channels "$part")
        set -l ototal (metaflac --show-total-samples "$part")
        set -l expected (math "round($total * $tr / $sr)")
        set -l tol (math "round($tr / 100)")
        test "$osr" = "$tr"; or set -a why "sample rate is $osr"
        test "$obps" = "$tb"; or set -a why "bit depth is $obps"
        test "$och" = "$ch"; or set -a why "channels changed"
        test (math "abs($ototal - $expected)") -le $tol; or set -a why "length is off ($ototal samples, expected about $expected)"
        set -l tin (metaflac --export-tags-to=- "$f" | count)
        set -l tout (metaflac --export-tags-to=- "$part" | count)
        test $tout -ge $tin; or set -a why "tags lost ($tin -> $tout)"
        set -l pin (metaflac --list --block-type=PICTURE "$f" | string match -r 'type: 6' | count)
        set -l pout (metaflac --list --block-type=PICTURE "$part" | string match -r 'type: 6' | count)
        test $pout -ge $pin; or set -a why "embedded cover lost"

        if test (count $why) -gt 0
            echo "   !! not replaced: $why"
            rm -f "$part"
            set failed (math $failed + 1)
            continue
        end

        chmod --reference="$f" "$part" 2>/dev/null
        command mv -f "$part" "$f"
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
