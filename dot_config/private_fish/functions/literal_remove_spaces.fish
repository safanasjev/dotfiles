function remove_spaces
    for f in *
          set new (string replace -a ' ' '_' -- $f)
          if test "$f" != "$new"
              mv -- "$f" "$new"
          end
    end
end
