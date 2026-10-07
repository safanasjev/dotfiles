function bulk_rename
    if test (count $argv) -ne 2
        echo "usage: bulk_rename OLD NEW" >&2
        return 1
    end
    set old $argv[1]
    set new $argv[2]

    set files (string match -- "$old-*.png" *.png)
    if test (count $files) -eq 0
        echo "error: no files matching $old-<number>.png" >&2
        return 1
    end

    # validate everything first, so nothing is renamed if any file is bad
    for f in $files
        set rest (string replace -- "$old-" "" $f)
        if not string match -qr '^[0-9]+\.png$' -- $rest
            echo "error: '$f' must be named $old-<number>.png" >&2
            return 1
        end
    end

    for f in $files
        mv -- $f (string replace -- "$old-" "$new-" $f)
    end
end
