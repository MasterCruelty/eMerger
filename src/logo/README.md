`big_name.svg` is the source: four blades turning around a hub with an
upward arrow, and the name below. The name is converted to outlines (Inter
Display ExtraBold, SIL Open Font License 1.1), so the file does not depend
on installed fonts. `big_name.png` is a 512 px wide export:

```
inkscape big_name.svg --export-type=png --export-width=512 --export-filename=big_name.png
```

Colors:

| part | colors |
|---|---|
| blades | `#BBF7D0`, `#4ADE80`, `#16A34A`, `#166534` |
| arrow and name | `#22C55E` to `#15803D` |

The terminal logo uses the nearest 256-color greens (`UI_GRADIENT` in
`src/lib/ui/term.sh` and `src/pslib/ui/Term.ps1`).

`logo.txt` is the terminal logo, drawn by hand in block characters for this project.
