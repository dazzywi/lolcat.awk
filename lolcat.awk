#!/usr/bin/awk -f
# lolcat - colorize terminal text like a rainbow

# Number from the environment, or the fallback when it is unset
function env_or(var, fallback) { return (var in ENVIRON ? ENVIRON[var] + 0 : fallback) }

# Index in the 6x6x6 color cube, which starts at 16
function palette(r, g, b) { return 16 + 36 * int(r / 43) + 6 * int(g / 43) + int(b / 43) }

# Set r, g, b from hue h, saturation s, value v
function hsv_to_rgb(h, s, v,	sector, f, p, q, t) {
	if (s == 0) { r = g = b = v * 255; return }
	h_sector = h / 60
	sector = int(h_sector) # slice of the wheel, 0..5
	f = h_sector - sector  # where we are inside that slice
	p = v * (1 - s)
	q = v * (1 - s * f)
	t = v * (1 - s * (1 - f))
	if (sector == 0) {r = v; g = t; b = p}
	else if (sector == 1) {r = q; g = v; b = p}
	else if (sector == 2) {r = p; g = v; b = t}
	else if (sector == 3) {r = p; g = q; b = v}
	else if (sector == 4) {r = t; g = p; b = v}
	else {r = v; g = p; b = q}
	r = int(r * 255)
	g = int(g * 255)
	b = int(b * 255)
}

BEGIN {
	FS = RS = "" # one field per character
	seed = env_or("SEED", -1)
	if (seed > 0) srand(seed)
	hue = env_or("START", 360 * rand()) % 360
	hue_shift = env_or("SHIFT", 360)
	saturation = env_or("SATURATION", 1.0) # [0.0, 1.0]
	value = env_or("VALUE", 1.0)           # [0.0, 1.0]
	ncolors = env_or("NCOLORS", 0)         # 0 = size the table from the input
}

# size the color table from the first line, so the hue lands at any line length
NR == 1 {
	n = length($0)
	if (ncolors <= 0 && n > 0)
		ncolors = int((n * 0.6) ** 2 / n * 12)
	if (ncolors > 1) {
		step = hue_shift / (ncolors - 1)
		for (i = 1; i <= ncolors; i++) {
			hsv_to_rgb(hue, saturation, value)
			colors[i] = palette(r, g, b)
			hue += step
			hue -= hue_shift * int(hue / hue_shift) # keep 0 <= hue < hue_shift
		}
	}
	else {
		ncolors = 1
		hsv_to_rgb(hue, saturation, value)
		colors[1] = palette(r, g, b)
	}
}

{
	i = 1
	for (k = 1; k <= NF; k++) {
		if (in_escape) {
			# copy the escape sequence through
			printf "%s", $k
			if ($k ~ /[A-Za-z]/)
				in_escape = 0
		}
		else if ($k == "\033") {
			printf "%s", $k
			in_escape = 1
		}
		else {
			printf "\033[38;5;%03dm%s", colors[i], $k
			i = (i % ncolors) + 1
		}
	}
	printf "\033[0m\n"
}
