"""Render the print sources in this folder to the PDFs served by the site.

Runs in the first stage of the Dockerfile on every image build; the PDFs are
build output and are not committed. For a local preview (from the repo root):
    pip install -r print/requirements.txt
    python -m playwright install chromium
    python print/render.py

Playwright is pinned (here and in the Dockerfile image tag): each release
bundles its own Chromium, which lays out and embeds fonts differently.

Writes site/files/1c-rabbitmq-presentation.pdf and site/files/1c-rabbitmq-plan.pdf.
"""
from pathlib import Path

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "site" / "files"

# Chromium header/footer templates cannot load page web fonts, so the footer
# uses a system font: Arial/Helvetica (a system-installed variable Inter would
# be embedded as Type 3). Kept dark grey for black-and-white printing.
PLAN_FOOTER = (
    '<div style="width:100%;font:9px Arial,Helvetica,sans-serif;color:#444;padding:0 18mm;'
    'display:flex;justify-content:space-between">'
    "<span>План работ для 1С-программиста · обмен через RabbitMQ</span>"
    '<span><span class="pageNumber"></span> / <span class="totalPages"></span></span></div>'
)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()

        # Presentation: page size (A4 landscape) comes from @page in the HTML.
        page.goto((HERE / "presentation.html").as_uri())
        page.wait_for_load_state("networkidle")
        page.evaluate("document.fonts.ready.then(() => true)")
        page.pdf(
            path=str(OUT / "1c-rabbitmq-presentation.pdf"),
            print_background=True,
            prefer_css_page_size=True,
        )

        # Plan: A4 portrait, page numbers in the footer.
        page.goto((HERE / "plan.html").as_uri())
        page.wait_for_load_state("networkidle")
        page.evaluate("document.fonts.ready.then(() => true)")
        page.pdf(
            path=str(OUT / "1c-rabbitmq-plan.pdf"),
            format="A4",
            print_background=True,
            prefer_css_page_size=True,
            display_header_footer=True,
            header_template="<span></span>",
            footer_template=PLAN_FOOTER,
        )

        browser.close()
    print(f"written to {OUT}")


if __name__ == "__main__":
    main()
