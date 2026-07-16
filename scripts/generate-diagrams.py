#!/usr/bin/env python3
"""Generate docs/assets/diagrams/*.svg and *.png for Docker Lab docs.

Requires: rsvg-convert (brew install librsvg)
"""
from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "assets" / "diagrams"

TEAL = "#00897B"
TEAL_DARK = "#00695C"
TEAL_LIGHT = "#E0F2F1"
AMBER_DARK = "#FF8F00"
INK = "#1A2332"
MUTED = "#5A6A7A"
LINE = "#B0BEC5"
BG = "#FAFBFC"
WHITE = "#FFFFFF"
OK = "#2E7D32"


def svg_wrap(w: int, h: int, body: str, title: str = "") -> str:
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img" aria-label="{title}">
  <defs>
    <style>
      .title {{ font: 700 15px 'IBM Plex Sans', 'Helvetica Neue', Helvetica, Arial, sans-serif; fill: {INK}; }}
      .label {{ font: 600 13px 'IBM Plex Sans', 'Helvetica Neue', Helvetica, Arial, sans-serif; fill: {INK}; }}
      .label-w {{ font: 600 13px 'IBM Plex Sans', 'Helvetica Neue', Helvetica, Arial, sans-serif; fill: {WHITE}; }}
      .small {{ font: 500 11px 'IBM Plex Sans', 'Helvetica Neue', Helvetica, Arial, sans-serif; fill: {MUTED}; }}
      .small-w {{ font: 500 11px 'IBM Plex Sans', 'Helvetica Neue', Helvetica, Arial, sans-serif; fill: rgba(255,255,255,0.9); }}
    </style>
    <marker id="arrow" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto">
      <path d="M0,0 L6,3 L0,6 Z" fill="{TEAL}"/>
    </marker>
  </defs>
  <rect width="{w}" height="{h}" rx="12" fill="{BG}"/>
{body}
</svg>
'''


def pill(x: float, y: float, w: float, h: float, text: str, fill: str = TEAL, sub: str | None = None) -> str:
    cy = y + h / 2 + 1
    parts = [
        f'  <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{fill}"/>',
        f'  <text class="label-w" x="{x + w / 2}" y="{cy if not sub else cy - 7}" text-anchor="middle">{text}</text>',
    ]
    if sub:
        parts.append(
            f'  <text class="small-w" x="{x + w / 2}" y="{cy + 10}" text-anchor="middle">{sub}</text>'
        )
    return "\n".join(parts)


def arrow_h(x1: float, y: float, x2: float) -> str:
    return f'  <line x1="{x1}" y1="{y}" x2="{x2}" y2="{y}" stroke="{TEAL}" stroke-width="2" marker-end="url(#arrow)"/>'


def write_install_flow() -> None:
    steps = [
        ("ducker install", TEAL_DARK, None),
        ("Dependencies", TEAL, "Brewfile"),
        ("Lima", TEAL, "Debian 13"),
        ("Docker", TEAL, "rootless"),
        ("Config", TEAL, "DOCKER_HOST"),
        ("Verify", TEAL, "health checks"),
        ("Ready", OK, None),
    ]
    bw, bh, gap = 118, 56, 28
    start_x, y = 24, 48
    total_w = start_x * 2 + len(steps) * bw + (len(steps) - 1) * gap
    body = ['  <text class="title" x="24" y="28">Docker Lab — install path</text>']
    x = start_x
    for i, (label, fill, sub) in enumerate(steps):
        h = 64 if sub else bh
        yy = y - (4 if sub else 0)
        body.append(pill(x, yy, bw, h, label, fill=fill, sub=sub))
        if i < len(steps) - 1:
            body.append(arrow_h(x + bw + 4, y + bh / 2, x + bw + gap - 4))
        x += bw + gap
    body.append(
        f'  <text class="small" x="24" y="{y + 90}">One command. Re-run safe. UI is optional and separate.</text>'
    )
    (OUT / "install-flow.svg").write_text(svg_wrap(total_w, 150, "\n".join(body), "Docker Lab install flow"))


def write_stack() -> None:
    body = [
        '  <text class="title" x="24" y="24">How the stack fits together</text>',
        # macOS host
        f'  <rect x="24" y="40" width="520" height="420" rx="12" fill="{TEAL_DARK}"/>',
        '  <text class="label-w" x="40" y="66">macOS (Apple Silicon)</text>',
        '  <text class="small-w" x="40" y="84">host</text>',
        # Homebrew
        f'  <rect x="44" y="100" width="480" height="72" rx="10" fill="{TEAL}"/>',
        '  <text class="label-w" x="60" y="128">Homebrew</text>',
        '  <text class="small-w" x="60" y="148">limactl · docker CLI · compose · buildx</text>',
        # DOCKER_HOST bridge
        f'  <rect x="64" y="192" width="440" height="44" rx="10" fill="{AMBER_DARK}"/>',
        '  <text class="label-w" x="284" y="219" text-anchor="middle">DOCKER_HOST → ~/.lima/docker/sock/docker.sock</text>',
        # Lima VM container
        f'  <rect x="64" y="256" width="440" height="184" rx="10" fill="{TEAL}"/>',
        '  <text class="label-w" x="80" y="280">Lima VM · vz + virtiofs + Rosetta</text>',
        # nested guest layers
        f'  <rect x="84" y="296" width="400" height="36" rx="6" fill="{TEAL_DARK}"/>',
        '  <text class="label-w" x="284" y="319" text-anchor="middle">Debian 13 (aarch64)</text>',
        f'  <rect x="104" y="344" width="360" height="32" rx="6" fill="#00796B"/>',
        '  <text class="label-w" x="284" y="365" text-anchor="middle">Docker Engine (rootless)</text>',
        f'  <rect x="124" y="388" width="320" height="28" rx="6" fill="#00695C"/>',
        '  <text class="label-w" x="284" y="407" text-anchor="middle">containerd + runc → containers</text>',
        '  <text class="small-w" x="40" y="444">Validated against Lima 2.x and Docker 29.x</text>',
    ]
    (OUT / "stack.svg").write_text(svg_wrap(568, 480, "\n".join(body), "Docker Lab stack diagram"))


def write_install_steps() -> None:
    detail = [
        ("1. deps", "Install Homebrew packages from Brewfile"),
        ("2. config", "CLI plugins + DOCKER_HOST in ~/.zshrc"),
        ("3. lima", "Create/start VM from lima-docker.yaml"),
        ("4. daemon", "Apply guest daemon.json + restart Docker"),
        ("5. verify", "Health checks until the lab is ready"),
    ]
    body = [
        '  <text class="title" x="24" y="28">What <tspan font-family="IBM Plex Mono, Menlo, monospace">ducker install</tspan> does</text>'
    ]
    y = 48
    for i, (step, desc) in enumerate(detail):
        body.append(f'  <rect x="24" y="{y}" width="140" height="40" rx="8" fill="{TEAL}"/>')
        body.append(f'  <text class="label-w" x="94" y="{y + 25}" text-anchor="middle">{step}</text>')
        body.append(f'  <rect x="176" y="{y}" width="360" height="40" rx="8" fill="{TEAL_LIGHT}"/>')
        body.append(f'  <text class="label" x="192" y="{y + 25}">{desc}</text>')
        if i < len(detail) - 1:
            body.append(
                f'  <line x1="94" y1="{y + 40}" x2="94" y2="{y + 56}" stroke="{TEAL}" stroke-width="2" marker-end="url(#arrow)"/>'
            )
        y += 56
    body.append(f'  <text class="small" x="24" y="{y + 16}">Safe to re-run. Does not install a UI.</text>')
    (OUT / "install-steps.svg").write_text(svg_wrap(560, y + 36, "\n".join(body), "ducker install steps"))


def write_roadmap() -> None:
    items = [
        ("Docker Lab", True),
        ("Compose Lab", False),
        ("Kind Lab", False),
        ("Talos Lab", False),
        ("Kubernetes Lab", False),
        ("GitOps Lab", False),
        ("Platform Lab", False),
    ]
    body = ['  <text class="title" x="24" y="28">Where this is heading</text>']
    y = 48
    for i, (name, current) in enumerate(items):
        fill = TEAL if current else WHITE
        tcls = "label-w" if current else "label"
        badge = "today" if current else "next"
        badge_fill = OK if current else LINE
        body.append(
            f'  <rect x="80" y="{y}" width="280" height="40" rx="8" fill="{fill}" stroke="{TEAL}" stroke-width="2"/>'
        )
        body.append(f'  <text class="{tcls}" x="220" y="{y + 25}" text-anchor="middle">{name}</text>')
        body.append(f'  <rect x="376" y="{y + 8}" width="56" height="24" rx="6" fill="{badge_fill}"/>')
        body.append(f'  <text class="small-w" x="404" y="{y + 24}" text-anchor="middle">{badge}</text>')
        if i < len(items) - 1:
            body.append(
                f'  <line x1="220" y1="{y + 40}" x2="220" y2="{y + 56}" stroke="{TEAL}" stroke-width="2" marker-end="url(#arrow)"/>'
            )
        y += 56
    body.append(
        f'  <text class="small" x="24" y="{y + 8}">Same CLI habits: install → verify → doctor → upgrade → backup</text>'
    )
    (OUT / "roadmap.svg").write_text(svg_wrap(460, y + 28, "\n".join(body), "Docker Lab roadmap"))


def write_release_channels() -> None:
    body = [
        '  <text class="title" x="24" y="28">How a release ships</text>',
        f'  <rect x="200" y="40" width="160" height="40" rx="8" fill="{TEAL_DARK}"/>',
        '  <text class="label-w" x="280" y="65" text-anchor="middle">GitHub Release</text>',
        f'  <line x1="280" y1="80" x2="110" y2="140" stroke="{TEAL}" stroke-width="2" marker-end="url(#arrow)"/>',
        f'  <line x1="280" y1="80" x2="280" y2="140" stroke="{TEAL}" stroke-width="2" marker-end="url(#arrow)"/>',
        f'  <line x1="280" y1="80" x2="450" y2="140" stroke="{TEAL}" stroke-width="2" marker-end="url(#arrow)"/>',
        f'  <rect x="40" y="140" width="140" height="48" rx="8" fill="{TEAL}"/>',
        '  <text class="label-w" x="110" y="160" text-anchor="middle">install.sh</text>',
        '  <text class="small-w" x="110" y="176" text-anchor="middle">curl | bash</text>',
        f'  <rect x="210" y="140" width="140" height="48" rx="8" fill="{TEAL}"/>',
        '  <text class="label-w" x="280" y="160" text-anchor="middle">Homebrew</text>',
        '  <text class="small-w" x="280" y="176" text-anchor="middle">ducker-lab</text>',
        f'  <rect x="380" y="140" width="140" height="48" rx="8" fill="{TEAL}"/>',
        '  <text class="label-w" x="450" y="160" text-anchor="middle">Docs site</text>',
        '  <text class="small-w" x="450" y="176" text-anchor="middle">GitHub Pages</text>',
    ]
    (OUT / "release-channels.svg").write_text(
        svg_wrap(560, 220, "\n".join(body), "Release distribution channels")
    )


def export_pngs() -> None:
    for svg in sorted(OUT.glob("*.svg")):
        png = svg.with_suffix(".png")
        subprocess.run(
            ["rsvg-convert", "-d", "144", "-p", "144", str(svg), "-o", str(png)],
            check=True,
        )
        print(f"  {png.name} ({png.stat().st_size} bytes)")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    write_install_flow()
    write_stack()
    write_install_steps()
    write_roadmap()
    write_release_channels()
    print("SVGs written; exporting PNGs…")
    export_pngs()


if __name__ == "__main__":
    main()
