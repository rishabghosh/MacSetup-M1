---
name: privatepdf-e2e-tests
description: >
  Generate, complete, or extend Playwright E2E tests for the PrivatePdf application.
  Use this skill whenever the user asks to write, create, add, generate, or fix Playwright
  tests for any PrivatePdf tool, including requests like "test all tools", "add e2e tests
  for [tool]", "write integration tests for the upload → convert → download flow", or
  "record test executions with video". Also use it when the user wants to understand the
  existing test structure or run tests with video recording enabled.
---

# PrivatePdf Playwright E2E Test Skill

## Project Layout (key paths)

```
/Users/rishabghosh/projects/PrivatePdf/
├── src/js/config/tools.ts              # canonical tool list with slugs
├── integration-tests/
│   ├── playwright.config.ts            # test runner config (video, timeouts, browsers)
│   ├── helpers/
│   │   └── test-helpers.ts             # ALL shared helpers + fixtures object
│   ├── plans/<slug>.md                 # per-tool plan: existing coverage + missing scenarios
│   ├── fixtures/                       # test fixture files (PDFs, images, docs)
│   └── tests/
│       ├── popular/                    # PDF Workflow, Multi Tool, Merge, Split, Compress, etc.
│       ├── convert-to-pdf/             # JPG/PNG/DOCX/XLSX/etc → PDF tools
│       ├── convert-from-pdf/           # PDF → JPG/PNG/CSV/DOCX/etc tools
│       ├── edit-annotate/              # Bookmarks, Watermark, Page Numbers, etc.
│       ├── organize-manage/            # Merge, Split, Overlay, Metadata, etc.
│       ├── optimize-repair/            # Compress, Linearize, Repair, etc.
│       └── secure/                     # Encrypt, Decrypt, Sanitize, Sign, etc.
```

## Available Helpers (import from `../../helpers/test-helpers`)

```typescript
// Navigation
navigateToTool(page, 'tool-slug')   // goes to tool-slug.html, waits for UI

// File upload
uploadFile(page, fixtures.samplePdf)                       // single file
uploadFile(page, [fixtures.samplePdf, fixtures.multiPagePdf]) // multiple files
uploadTwoFiles(page, file1, file2)                         // two separate inputs (overlay tool)
uploadViaDragDrop(page, filePath)                          // drag-drop to #drop-zone

// Processing
clickProcessButton(page)             // finds and clicks the process/convert/download button
waitForProcessing(page, timeoutMs)   // waits for #loader-modal to appear then disappear

// Download (wraps the process click and handles staged downloads)
waitForDownload(page, async () => { await clickProcessButton(page); })

// Assertions
expectPageLoaded(page, toolSlug)     // h1 visible + drop zone / editor visible
expectFileUploaded(page)             // 3s wait for UI to update after upload
expectDownloadTriggered(download)    // asserts download object is non-null with a filename
expectNoErrorAlert(page)             // fails if #alert-modal shows an error message
dismissAlertIfPresent(page)          // clicks #alert-ok if visible

// Full happy-path shortcut
runToolE2E(page, 'tool-slug', fixtures.samplePdf)
// optionally: runToolE2E(page, slug, file, { beforeProcess: async (page) => { ... } })
```

## Fixture Reference

```typescript
// PDFs
fixtures.samplePdf        // 1-page PDF  → use for most single-file tools
fixtures.multiPagePdf     // 20-page PDF → use when page operations matter
fixtures.largePdf         // 50-page PDF → use for performance / large-file tests
fixtures.encryptedPdf     // password-protected PDF (password: "test123")
fixtures.formPdf          // PDF with form fields
fixtures.bookmarkedPdf    // PDF with bookmarks/TOC
fixtures.annotatedPdf     // PDF with annotations
fixtures.scannedPdf       // image-based / scanned PDF
fixtures.attachmentsPdf   // PDF with embedded attachments
fixtures.layersPdf        // PDF with OCG layers
fixtures.signedPdf        // digitally signed PDF
fixtures.blankPagesPdf    // PDF with some blank pages
fixtures.colorPdf         // color PDF (for greyscale / color tests)
fixtures.corruptedPdf     // for repair tests
fixtures.restrictedPdf    // permissions-restricted PDF
fixtures.metadataPdf      // PDF with author/title/subject metadata
fixtures.tablesPdf        // PDF containing tables

// Images
fixtures.sampleJpg / .samplePng / .sampleWebp / .sampleSvg
fixtures.sampleBmp / .sampleHeic / .sampleTiff / .samplePsd

// Documents
fixtures.sampleDocx / .sampleXlsx / .samplePptx
fixtures.sampleOdt / .sampleOds / .sampleOdp / .sampleOdg
fixtures.sampleRtf / .sampleCsv / .sampleTxt / .sampleMd
fixtures.sampleJson / .sampleXml / .sampleXps
fixtures.sampleEpub / .sampleMobi / .sampleFb2 / .sampleCbz
fixtures.sampleWpd / .sampleWps / .samplePages / .samplePub / .sampleVsd
fixtures.sampleEml / .sampleMsg

// Certificate
fixtures.sampleCert       // .p12 certificate for digital signing
```

## Tool Reference Table

| Slug | Name | Input Fixture | Output Ext | Category Dir |
|------|------|--------------|------------|--------------|
| `pdf-workflow` | PDF Workflow Builder | — | — | popular/ |
| `pdf-multi-tool` | PDF Multi Tool | `samplePdf` | `.pdf` | popular/ |
| `merge-pdf` | Merge PDF | `[samplePdf, samplePdf]` | `.pdf` | popular/ |
| `split-pdf` | Split PDF | `multiPagePdf` | `.pdf` | popular/ |
| `compress-pdf` | Compress PDF | `samplePdf` | `.pdf` | popular/ |
| `edit-pdf` | PDF Editor | `samplePdf` | `.pdf` | popular/ |
| `jpg-to-pdf` | JPG to PDF | `sampleJpg` | `.pdf` | popular/ |
| `sign-pdf` | Sign PDF | `samplePdf` | `.pdf` | popular/ |
| `crop-pdf` | Crop PDF | `samplePdf` | `.pdf` | popular/ |
| `extract-pages` | Extract Pages | `multiPagePdf` | `.pdf` | popular/ |
| `organize-pdf` | Duplicate & Organize | `multiPagePdf` | `.pdf` | popular/ |
| `delete-pages` | Delete Pages | `multiPagePdf` | `.pdf` | popular/ |
| `bookmark` | Edit Bookmarks | `bookmarkedPdf` | `.pdf` | edit-annotate/ |
| `table-of-contents` | Table of Contents | `bookmarkedPdf` | `.pdf` | edit-annotate/ |
| `page-numbers` | Page Numbers | `samplePdf` | `.pdf` | edit-annotate/ |
| `add-page-labels` | Add Page Labels | `samplePdf` | `.pdf` | edit-annotate/ |
| `bates-numbering` | Bates Numbering | `samplePdf` | `.pdf` | edit-annotate/ |
| `add-watermark` | Add Watermark | `samplePdf` | `.pdf` | edit-annotate/ |
| `header-footer` | Header & Footer | `samplePdf` | `.pdf` | edit-annotate/ |
| `invert-colors` | Invert Colors | `samplePdf` | `.pdf` | edit-annotate/ |
| `scanner-effect` | Scanner Effect | `samplePdf` | `.pdf` | edit-annotate/ |
| `adjust-colors` | Adjust Colors | `samplePdf` | `.pdf` | edit-annotate/ |
| `background-color` | Background Color | `samplePdf` | `.pdf` | edit-annotate/ |
| `text-color` | Change Text Color | `samplePdf` | `.pdf` | edit-annotate/ |
| `add-stamps` | Add Stamps | `samplePdf` | `.pdf` | edit-annotate/ |
| `remove-annotations` | Remove Annotations | `annotatedPdf` | `.pdf` | edit-annotate/ |
| `form-filler` | PDF Form Filler | `formPdf` | `.pdf` | edit-annotate/ |
| `form-creator` | Create PDF Form | `samplePdf` | `.pdf` | edit-annotate/ |
| `remove-blank-pages` | Remove Blank Pages | `blankPagesPdf` | `.pdf` | edit-annotate/ |
| `image-to-pdf` | Images to PDF | `sampleJpg` | `.pdf` | convert-to-pdf/ |
| `jpg-to-pdf` | JPG to PDF | `sampleJpg` | `.pdf` | convert-to-pdf/ |
| `png-to-pdf` | PNG to PDF | `samplePng` | `.pdf` | convert-to-pdf/ |
| `webp-to-pdf` | WebP to PDF | `sampleWebp` | `.pdf` | convert-to-pdf/ |
| `svg-to-pdf` | SVG to PDF | `sampleSvg` | `.pdf` | convert-to-pdf/ |
| `bmp-to-pdf` | BMP to PDF | `sampleBmp` | `.pdf` | convert-to-pdf/ |
| `heic-to-pdf` | HEIC to PDF | `sampleHeic` | `.pdf` | convert-to-pdf/ |
| `tiff-to-pdf` | TIFF to PDF | `sampleTiff` | `.pdf` | convert-to-pdf/ |
| `txt-to-pdf` | Text to PDF | `sampleTxt` | `.pdf` | convert-to-pdf/ |
| `markdown-to-pdf` | Markdown to PDF | `sampleMd` | `.pdf` | convert-to-pdf/ |
| `json-to-pdf` | JSON to PDF | `sampleJson` | `.pdf` | convert-to-pdf/ |
| `odt-to-pdf` | ODT to PDF | `sampleOdt` | `.pdf` | convert-to-pdf/ |
| `csv-to-pdf` | CSV to PDF | `sampleCsv` | `.pdf` | convert-to-pdf/ |
| `rtf-to-pdf` | RTF to PDF | `sampleRtf` | `.pdf` | convert-to-pdf/ |
| `word-to-pdf` | Word to PDF | `sampleDocx` | `.pdf` | convert-to-pdf/ |
| `excel-to-pdf` | Excel to PDF | `sampleXlsx` | `.pdf` | convert-to-pdf/ |
| `powerpoint-to-pdf` | PowerPoint to PDF | `samplePptx` | `.pdf` | convert-to-pdf/ |
| `xps-to-pdf` | XPS to PDF | `sampleXps` | `.pdf` | convert-to-pdf/ |
| `mobi-to-pdf` | MOBI to PDF | `sampleMobi` | `.pdf` | convert-to-pdf/ |
| `epub-to-pdf` | EPUB to PDF | `sampleEpub` | `.pdf` | convert-to-pdf/ |
| `fb2-to-pdf` | FB2 to PDF | `sampleFb2` | `.pdf` | convert-to-pdf/ |
| `cbz-to-pdf` | CBZ to PDF | `sampleCbz` | `.pdf` | convert-to-pdf/ |
| `wpd-to-pdf` | WPD to PDF | `sampleWpd` | `.pdf` | convert-to-pdf/ |
| `wps-to-pdf` | WPS to PDF | `sampleWps` | `.pdf` | convert-to-pdf/ |
| `xml-to-pdf` | XML to PDF | `sampleXml` | `.pdf` | convert-to-pdf/ |
| `pages-to-pdf` | Pages to PDF | `samplePages` | `.pdf` | convert-to-pdf/ |
| `odg-to-pdf` | ODG to PDF | `sampleOdg` | `.pdf` | convert-to-pdf/ |
| `ods-to-pdf` | ODS to PDF | `sampleOds` | `.pdf` | convert-to-pdf/ |
| `odp-to-pdf` | ODP to PDF | `sampleOdp` | `.pdf` | convert-to-pdf/ |
| `pub-to-pdf` | PUB to PDF | `samplePub` | `.pdf` | convert-to-pdf/ |
| `vsd-to-pdf` | VSD to PDF | `sampleVsd` | `.pdf` | convert-to-pdf/ |
| `psd-to-pdf` | PSD to PDF | `samplePsd` | `.pdf` | convert-to-pdf/ |
| `email-to-pdf` | Email to PDF | `sampleEml` | `.pdf` | convert-to-pdf/ |
| `pdf-to-jpg` | PDF to JPG | `samplePdf` | `.zip`/`.jpg` | convert-from-pdf/ |
| `pdf-to-png` | PDF to PNG | `samplePdf` | `.zip`/`.png` | convert-from-pdf/ |
| `pdf-to-webp` | PDF to WebP | `samplePdf` | `.zip`/`.webp` | convert-from-pdf/ |
| `pdf-to-bmp` | PDF to BMP | `samplePdf` | `.zip`/`.bmp` | convert-from-pdf/ |
| `pdf-to-tiff` | PDF to TIFF | `samplePdf` | `.tiff` | convert-from-pdf/ |
| `pdf-to-cbz` | PDF to CBZ | `samplePdf` | `.cbz` | convert-from-pdf/ |
| `pdf-to-svg` | PDF to SVG | `samplePdf` | `.zip`/`.svg` | convert-from-pdf/ |
| `pdf-to-csv` | PDF to CSV | `tablesPdf` | `.csv` | convert-from-pdf/ |
| `pdf-to-excel` | PDF to Excel | `tablesPdf` | `.xlsx` | convert-from-pdf/ |
| `pdf-to-greyscale` | PDF to Greyscale | `colorPdf` | `.pdf` | convert-from-pdf/ |
| `pdf-to-json` | PDF to JSON | `samplePdf` | `.json` | convert-from-pdf/ |
| `pdf-to-docx` | PDF to Word | `samplePdf` | `.docx` | convert-from-pdf/ |
| `extract-images` | Extract Images | `samplePdf` | `.zip` | convert-from-pdf/ |
| `pdf-to-markdown` | PDF to Markdown | `samplePdf` | `.md` | convert-from-pdf/ |
| `prepare-pdf-for-ai` | Prepare PDF for AI | `samplePdf` | `.json` | convert-from-pdf/ |
| `pdf-to-text` | PDF to Text | `samplePdf` | `.txt` | convert-from-pdf/ |
| `extract-tables` | Extract Tables | `tablesPdf` | `.zip`/`.csv` | convert-from-pdf/ |
| `ocr-pdf` | OCR PDF | `scannedPdf` | `.pdf` | convert-from-pdf/ |
| `alternate-merge` | Alternate & Mix Pages | `[samplePdf, samplePdf]` | `.pdf` | organize-manage/ |
| `overlay-pdf` | PDF Overlay | two files | `.pdf` | organize-manage/ |
| `add-attachments` | Add Attachments | `samplePdf` | `.pdf` | organize-manage/ |
| `extract-attachments` | Extract Attachments | `attachmentsPdf` | `.zip` | organize-manage/ |
| `edit-attachments` | Edit Attachments | `attachmentsPdf` | `.pdf` | organize-manage/ |
| `pdf-layers` | PDF OCG | `layersPdf` | `.pdf` | organize-manage/ |
| `divide-pages` | Divide Pages | `samplePdf` | `.pdf` | organize-manage/ |
| `add-blank-page` | Add Blank Page | `samplePdf` | `.pdf` | organize-manage/ |
| `reverse-pages` | Reverse Pages | `multiPagePdf` | `.pdf` | organize-manage/ |
| `rotate-pdf` | Rotate PDF | `samplePdf` | `.pdf` | organize-manage/ |
| `rotate-custom` | Rotate by Custom Degrees | `samplePdf` | `.pdf` | organize-manage/ |
| `n-up-pdf` | N-Up PDF | `multiPagePdf` | `.pdf` | organize-manage/ |
| `pdf-booklet` | PDF Booklet | `multiPagePdf` | `.pdf` | organize-manage/ |
| `combine-single-page` | Combine to Single Page | `multiPagePdf` | `.pdf` | organize-manage/ |
| `view-metadata` | View Metadata | `metadataPdf` | — | organize-manage/ |
| `edit-metadata` | Edit Metadata | `metadataPdf` | `.pdf` | organize-manage/ |
| `pdf-to-zip` | PDFs to ZIP | `[samplePdf, samplePdf]` | `.zip` | organize-manage/ |
| `compare-pdfs` | Compare PDFs | two files | — | organize-manage/ |
| `posterize-pdf` | Posterize PDF | `samplePdf` | `.pdf` | organize-manage/ |
| `page-dimensions` | Page Dimensions | `samplePdf` | — | organize-manage/ |
| `remove-metadata` | Remove Metadata | `metadataPdf` | `.pdf` | organize-manage/ |
| `compress-pdf` | Compress PDF | `samplePdf` | `.pdf` | optimize-repair/ |
| `pdf-to-pdfa` | PDF to PDF/A | `samplePdf` | `.pdf` | optimize-repair/ |
| `fix-page-size` | Fix Page Size | `samplePdf` | `.pdf` | optimize-repair/ |
| `linearize-pdf` | Linearize PDF | `samplePdf` | `.pdf` | optimize-repair/ |
| `remove-restrictions` | Remove Restrictions | `restrictedPdf` | `.pdf` | optimize-repair/ |
| `repair-pdf` | Repair PDF | `corruptedPdf` | `.pdf` | optimize-repair/ |
| `rasterize-pdf` | Rasterize PDF | `samplePdf` | `.pdf` | optimize-repair/ |
| `deskew-pdf` | Deskew PDF | `scannedPdf` | `.pdf` | optimize-repair/ |
| `font-to-outline` | Font to Outline | `samplePdf` | `.pdf` | optimize-repair/ |
| `encrypt-pdf` | Encrypt PDF | `samplePdf` | `.pdf` | secure/ |
| `sanitize-pdf` | Sanitize PDF | `samplePdf` | `.pdf` | secure/ |
| `decrypt-pdf` | Decrypt PDF | `encryptedPdf` | `.pdf` | secure/ |
| `flatten-pdf` | Flatten PDF | `formPdf` | `.pdf` | secure/ |
| `change-permissions` | Change Permissions | `samplePdf` | `.pdf` | secure/ |
| `digital-sign-pdf` | Digital Signature | `samplePdf` + `sampleCert` | `.pdf` | secure/ |
| `validate-signature-pdf` | Validate Signature | `signedPdf` | — | secure/ |
| `timestamp-pdf` | Timestamp PDF | `samplePdf` | `.pdf` | secure/ |

## Test Patterns

### 1. Simple happy path (use `runToolE2E` when possible)

```typescript
import { test, expect } from '@playwright/test';
import {
  navigateToTool, uploadFile, expectFileUploaded,
  clickProcessButton, waitForDownload, expectDownloadTriggered,
  expectNoErrorAlert, runToolE2E, fixtures,
} from '../../helpers/test-helpers';

test.describe('Rotate PDF', () => {
  test('page loads', async ({ page }) => {
    await navigateToTool(page, 'rotate-pdf');
    await expect(page.locator('h1').first()).toContainText(/rotate/i);
  });

  test('upload and rotate PDF, download result', async ({ page }) => {
    test.slow();
    const download = await runToolE2E(page, 'rotate-pdf', fixtures.samplePdf);
    expect(download!.suggestedFilename()).toMatch(/\.pdf$/i);
  });
});
```

### 2. Expanded form (when you need control between steps)

```typescript
test('compress PDF and verify download', async ({ page }) => {
  test.slow();
  await navigateToTool(page, 'compress-pdf');
  await uploadFile(page, fixtures.multiPagePdf);
  await expectFileUploaded(page);
  await expectNoErrorAlert(page);

  const download = await waitForDownload(page, async () => {
    await clickProcessButton(page);
  });
  await expectDownloadTriggered(download);
  expect(download.suggestedFilename()).toMatch(/\.pdf$/i);
  await expectNoErrorAlert(page);
});
```

### 3. Multi-file upload (output is usually a ZIP)

```typescript
test('merge multiple PDFs', async ({ page }) => {
  test.slow();
  await navigateToTool(page, 'merge-pdf');
  await uploadFile(page, [fixtures.samplePdf, fixtures.multiPagePdf]);
  await expectFileUploaded(page);
  const download = await waitForDownload(page, () => clickProcessButton(page));
  await expectDownloadTriggered(download);
  // merge → single PDF, not ZIP
  expect(download.suggestedFilename()).toMatch(/\.pdf$/i);
});
```

### 4. Two-input tools (overlay, compare)

```typescript
test('overlay two PDFs', async ({ page }) => {
  test.slow();
  await navigateToTool(page, 'overlay-pdf');
  // uploadTwoFiles uses #file-input-1 / #base-file-input and #file-input-2 / #overlay-file-input
  await uploadTwoFiles(page, fixtures.samplePdf, fixtures.multiPagePdf);
  await expectFileUploaded(page);
  const download = await waitForDownload(page, () => clickProcessButton(page));
  await expectDownloadTriggered(download);
  expect(download.suggestedFilename()).toMatch(/\.pdf$/i);
});
```

### 5. Tool-specific options before processing

```typescript
test('encrypt PDF with password', async ({ page }) => {
  test.slow();
  await navigateToTool(page, 'encrypt-pdf');
  await uploadFile(page, fixtures.samplePdf);
  await expectFileUploaded(page);

  // Fill tool-specific controls found in the plan file
  await page.fill('#user-password', 'mypassword');
  await page.fill('#owner-password', 'ownerpass');

  const download = await waitForDownload(page, () => clickProcessButton(page));
  await expectDownloadTriggered(download);
  expect(download.suggestedFilename()).toMatch(/\.pdf$/i);
});
```

### 6. Tools with no download (view/display only)

```typescript
test('view metadata', async ({ page }) => {
  await navigateToTool(page, 'view-metadata');
  await uploadFile(page, fixtures.metadataPdf);
  await expectFileUploaded(page);
  await clickProcessButton(page);
  await expectNoErrorAlert(page);
  // assert the metadata table or result panel is visible
  await expect(page.locator('#metadata-result, #result-panel').first()).toBeVisible({ timeout: 15_000 });
});
```

## Workflow: How to Generate Tests for a Tool

1. **Read the plan** — `integration-tests/plans/<slug>.md`
   - Note "Existing Playwright Coverage" (don't duplicate)
   - Note "Missing Automation Scenarios" (implement these)
   - Note "Source-Derived Controls and Behaviors" (exact button/input IDs)
   - Note "Playwright spec" path

2. **Check if a spec file exists**
   - If yes → add new `test(...)` blocks inside the existing `test.describe` block
   - If no → create a new file in the right category dir with the next sequence number

3. **Write the tests**
   - Always start with a page-load test (non-slow, no `test.slow()`)
   - Add an E2E happy-path test with `test.slow()`
   - Add missing scenario tests from the plan
   - For tests that exercise buttons/checkboxes, wrap in `if (await btn.isVisible(...).catch(() => false))` so tests don't fail on hidden controls

4. **Assert correctly**
   - Check output filename extension from the Tool Reference Table
   - For multi-file → ZIP tools, use `toMatch(/\.zip$/i)`
   - Always call `expectNoErrorAlert(page)` after a successful operation

5. **Run to verify**
   ```bash
   cd integration-tests && npm run test:local -- <spec-path>
   ```

6. **If a fixture file doesn't exist**, mark the test:
   ```typescript
   test.skip(true, 'fixtures.sampleHeic not available in this environment');
   ```

## Video Recording

To capture `.webm` video of every test execution:

**Per run (recommended during development):**
```bash
cd integration-tests && npm run test:local -- tests/organize-manage/09-rotate-pdf.spec.ts --video=on
```
Videos are saved in `integration-tests/test-results/<test-title>/video.webm`.

**Permanent (for CI or always-on recording):**
Edit `integration-tests/playwright.config.ts`:
```typescript
// Change:
video: 'retain-on-failure',
// To:
video: 'on',
```
This records video for every test on every browser, including the 6 configured projects (Chromium, Firefox, WebKit, 3 mobile).

## Handling "All Tools"

When the user asks to test all tools or a whole category:

1. List the tools from `src/js/config/tools.ts` or the Tool Reference Table above
2. For each tool (in category order):
   - Check for an existing spec; skip if fully covered
   - Write/extend the spec following the patterns above
3. Work sequentially — don't try to write 100 test files in one shot. Batch by category or ask the user which category to start with.

## Notes on Slow / Flaky Tests

- WASM-heavy tools (OCR, LibreOffice conversions) can take 30–90 seconds — always `test.slow()`
- `compress-pdf` with large/multi-file input is known flaky — mark `test.fixme()` if it times out in CI
- `waitForDownload` has a 300s internal timeout for the download event; the overall test timeout is 120s (set in playwright.config.ts) — increase with `test.setTimeout(300_000)` for very heavy tools
- Some tools show a "staged" download button (#alert-download-btn / #processing-download-btn) rather than triggering a direct browser download — `waitForDownload` handles this automatically
