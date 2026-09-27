#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import functools
import http.server
import io
import json
import threading
from pathlib import Path

from PIL import Image, ImageCms, ImageEnhance
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "social-preview-v176.jpg"
WIDTH, HEIGHT = 1200, 630
DEVICE_SCALE = 2


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


@contextlib.contextmanager
def local_site():
    handler = functools.partial(QuietHandler, directory=str(ROOT))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        host, port = server.server_address
        yield f"http://{host}:{port}"
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)


CAPTURE_CSS = r"""
html,
body{
  width:100% !important;
  height:100% !important;
  min-height:100% !important;
  overflow:hidden !important;
  background:#050b12 !important;
}

#ipcdj-launch,
.pull-refresh,
.site-nav,
#panel-inicio > .playlist-card,
#current-song-cards ~ section,
#panel-inicio > footer{
  display:none !important;
}

html.ipcdj-launch-active,
html.ipcdj-launch-site-hidden{
  overflow:visible !important;
}

.shell{
  width:min(920px,calc(100% - 54px)) !important;
  max-width:920px !important;
  padding-top:28px !important;
  padding-bottom:0 !important;
}

.hero{
  margin-top:0 !important;
  margin-bottom:18px !important;
}

.hero .subtitle{
  max-width:820px !important;
  display:-webkit-box !important;
  -webkit-line-clamp:2 !important;
  -webkit-box-orient:vertical !important;
  overflow:hidden !important;
}

.reveal{
  opacity:1 !important;
  transform:none !important;
}

.current{
  margin-top:0 !important;
}

.current .timeline{
  display:none !important;
}

.ambient-blob,
.refresh-glyph{
  animation:none !important;
}

*,
*::before,
*::after{
  transition:none !important;
  caret-color:transparent !important;
}
"""


def normalize_page(page):
    page.evaluate(
        """
        () => {
          const root=document.documentElement;
          root.classList.remove(
            "ipcdj-launch-active",
            "ipcdj-launch-site-hidden",
            "ipcdj-ios-light-launch",
            "ipcdj-scroll-active"
          );

          const launch=document.getElementById("ipcdj-launch");
          if(launch) launch.remove();

          try{
            const inicio=document.querySelector('[data-site-tab="inicio"]');
            if(inicio && typeof activateSiteTab==="function"){
              activateSiteTab("inicio",{focus:false});
            }
          }catch(_){}

          document.querySelectorAll(".reveal").forEach(node=>{
            node.classList.add("visible");
          });

          window.scrollTo(0,0);
        }
        """
    )
    page.add_style_tag(content=CAPTURE_CSS)


def wait_for_landing(page):
    page.wait_for_selector(
        '#current-song-cards [data-current-song-card]',
        state="attached",
        timeout=15000,
    )

    try:
        page.wait_for_function(
            """
            () => {
              const card=document.querySelector('#current-song-cards [data-current-song-card]');
              if(!card) return false;
              const native=card.querySelector('.cover-native-fallback');
              const hasCss=card.classList.contains('cover-ready');
              return hasCss || !native || native.complete;
            }
            """,
            timeout=8000,
        )
    except PlaywrightTimeoutError:
        pass

    page.evaluate(
        """
        async () => {
          try{ await document.fonts.ready; }catch(_){}
          await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
        }
        """
    )


def screenshot_landing(url: str) -> tuple[bytes, dict]:
    with sync_playwright() as pw:
        browser = pw.chromium.launch(
            headless=True,
            args=[
                "--force-color-profile=srgb",
                "--disable-features=PaintHolding",
            ],
        )
        context = browser.new_context(
            viewport={"width": WIDTH, "height": HEIGHT},
            device_scale_factor=DEVICE_SCALE,
            color_scheme="dark",
            reduced_motion="reduce",
        )
        page = context.new_page()

        page.goto(
            url + "/?social-preview-capture=1",
            wait_until="domcontentloaded",
            timeout=30000,
        )

        normalize_page(page)
        wait_for_landing(page)
        normalize_page(page)

        # Let remote artwork decode and the real runtime palette settle once, then
        # freeze the exact landing-page state for the capture.
        page.wait_for_timeout(850)
        page.evaluate("window.scrollTo(0,0)")
        page.wait_for_timeout(100)

        meta = page.evaluate(
            """
            () => {
              const card=document.querySelector('#current-song-cards [data-current-song-card]');
              return {
                build:document.querySelector('meta[name="ipcdj-build"]')?.content||"",
                songId:card?.dataset.songId||"",
                phase:card?.dataset.phase||"",
                status:card?.querySelector('[data-role="status"]')?.textContent?.trim()||"",
                title:card?.querySelector('[data-role="song-name"]')?.textContent?.trim()||"",
                artworkReady:!!card && (
                  card.classList.contains("cover-ready") ||
                  card.classList.contains("has-native-cover")
                )
              };
            }
            """
        )

        png = page.screenshot(
            type="png",
            full_page=False,
            animations="disabled",
            scale="device",
        )

        context.close()
        browser.close()
        return png, meta


def encode_srgb_jpeg(png: bytes):
    image = Image.open(io.BytesIO(png)).convert("RGB")

    if image.size != (WIDTH, HEIGHT):
        image = image.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)

    # A very restrained sharpening pass compensates for the 2x -> 1x downsample
    # without changing authored color or creating a synthetic-looking preview.
    image = ImageEnhance.Sharpness(image).enhance(1.04)

    srgb_profile = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()

    image.save(
        OUTPUT,
        "JPEG",
        quality=91,
        optimize=True,
        progressive=True,
        subsampling=0,
        icc_profile=srgb_profile,
    )

    verify = Image.open(OUTPUT)
    if verify.size != (WIDTH, HEIGHT):
        raise SystemExit(f"Unexpected social preview size: {verify.size}")
    if verify.mode != "RGB":
        raise SystemExit(f"Unexpected social preview mode: {verify.mode}")
    if not verify.info.get("icc_profile"):
        raise SystemExit("Generated social preview is missing its sRGB ICC profile")

    size = OUTPUT.stat().st_size
    if not 10_000 < size < 400_000:
        raise SystemExit(f"Unexpected social preview byte size: {size}")


def render():
    with local_site() as url:
        png, meta = screenshot_landing(url)

    encode_srgb_jpeg(png)

    print(
        json.dumps(
            {
                "output": str(OUTPUT.relative_to(ROOT)),
                "bytes": OUTPUT.stat().st_size,
                "render": "browser-landing-snapshot",
                **meta,
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    render()
