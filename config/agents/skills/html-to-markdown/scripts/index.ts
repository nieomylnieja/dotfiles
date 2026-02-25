import { convert } from "html-to-markdown-node";

const url = process.argv[2];

if (!url) {
  console.error("Usage: bun run index.ts <url>");
  process.exit(1);
}

const response = await fetch(url);
const html = await response.text();
const markdown = convert(html);

console.log(markdown);