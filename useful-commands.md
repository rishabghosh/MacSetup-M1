# Useful commands

Commands from the old Mac's shell history that are worth keeping.

## Images

These change every PNG in the current folder in place, so run them on a copy if you want to keep the originals. They need ImageMagick (`imagemagick` in `apps/install-coding.sh`).

Trim the empty or transparent border off every PNG:

```bash
mogrify -trim +repage *.png
```

`+repage` resets the canvas to the trimmed size. Without it, the image keeps its old canvas offset.

Shrink every PNG to half its width and height:

```bash
mogrify -resize 50% *.png
```

## Ports

See what's using port 4321 (Astro's dev server port):

```bash
lsof -i :4321
```

To free the port, stop that process with `kill <PID>`, using the PID from the output. Use `kill -9 <PID>` only if it doesn't stop.
