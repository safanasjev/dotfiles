function renotes
    set n (count notes-*.png)
    set new
    for f in (ls -tr *.png | string match -v 'notes-*.png')
        set n (math $n + 1)
        if mv -n $f notes-$n.png
            echo "Renamed: $f -> notes-$n.png"
            set -a new notes-$n.png
        else
            echo "Error: could not rename $f" >&2
        end
    end

    if test (count $new) -eq 0
        echo "Nothing to rename."
        return 0
    end

    echo "Compressing "(count $new)" file(s)..."
    if pngquant --quality=1-10 --ext .png --force $new
        echo "Done."
    else
        echo "Error: pngquant failed or skipped some files." >&2
        return 1
    end
end
