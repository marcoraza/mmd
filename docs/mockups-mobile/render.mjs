import puppeteer from "puppeteer";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { mkdir } from "node:fs/promises";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const html = `file://${path.join(__dirname, "mockups.html")}`;
const out = path.join(__dirname, "out");
await mkdir(out, { recursive: true });

const ids = ["m1a","m1b","m2a","m2b","m3a","m3b","m4a","m4b","m5a","m5b"];
const pairs = [["m1a","m1b","01-ring-rfid"],["m2a","m2b","02-packing-color-tag"],["m3a","m3b","03-geiger"],["m4a","m4b","04-kit-combo"],["m5a","m5b","05-guided-picking"]];

const browser = await puppeteer.launch({
  headless: true,
  args: ["--no-sandbox","--disable-setuid-sandbox","--font-render-hinting=none"],
});
const page = await browser.newPage();
await page.setViewport({ width: 1300, height: 1000, deviceScaleFactor: 2 });
await page.goto(html, { waitUntil: "networkidle0" });
// wait for fonts
await page.evaluate(() => document.fonts.ready);

for (const id of ids) {
  const el = await page.$(`#${id}`);
  if (!el) { console.error("missing", id); continue; }
  await el.screenshot({ path: path.join(out, `${id}.png`), omitBackground: false });
  console.log("ok", id);
}

await browser.close();
console.log("done — individuals in", out);
