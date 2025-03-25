const esbuild = require('esbuild');
const fs = require('fs').promises;
const path = require('path');
const fetch = require('node-fetch');

// Output directory (adjust to your Swift project's resources path)
const outputDir = path.join(__dirname, '..', 'Sources', 'MarkdownWebView', 'Resources');
const jsOutputFile = path.join(outputDir, 'markdown-it-bundle.js');

// CSS files to fetch
const cssFiles = [
  { url: 'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.1.1/css/all.min.css', name: 'font-awesome.css' },
  { url: 'https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/4.0.0/github-markdown.min.css', name: 'github-markdown.css' },
  { url: 'https://cdn.jsdelivr.net/npm/katex@0.16.10/dist/katex.min.css', name: 'katex.css' },
  { url: 'https://cdn.jsdelivr.net/npm/markdown-it-texmath@1.0.0/css/texmath.min.css', name: 'texmath.css' }
];

// Temporary entry file for JS bundling
const entryPoint = path.join(__dirname, 'entry.js');
const entryContent = `
const markdownit = require('markdown-it');
const markdownitMark = require('markdown-it-mark');
const markdownitTaskLists = require('markdown-it-task-lists');
const markdownitTexmath = require('markdown-it-texmath');
const markdownitSub = require('markdown-it-sub');
const markdownitSup = require('markdown-it-sup');
const markdownitFootnote = require('markdown-it-footnote');
const morphdom = require('morphdom');
const ClipboardJS = require('clipboard');
const katex = require('katex');

// Configure markdown-it with plugins
const md = markdownit({
  linkify: true,
  typographer: true
})
  .use(markdownitMark)
  .use(markdownitTaskLists, { enabled: true, label: true, labelAfter: true })
  .use(markdownitTexmath, {
    engine: katex,
    delimiters: ['dollars', 'brackets', 'doxygen', 'gitlab', 'julia', 'kramdown', 'beg_end'],
    katexOptions: { throwOnError: false, errorColor: '#cc0000' },
    breaks: false
  })
  .use(markdownitSub)
  .use(markdownitSup)
  .use(markdownitFootnote);

// Expose globals on window
window.markdownit = function() { return md; }; // Return configured instance
window.markdownitMark = markdownitMark;
window.markdownitTaskLists = markdownitTaskLists;
window.markdownitTexmath = markdownitTexmath;
window.markdownitSub = markdownitSub;
window.markdownitSup = markdownitSup;
window.markdownitFootnote = markdownitFootnote;
window.morphdom = morphdom;
window.ClipboardJS = ClipboardJS;
window.katex = katex;
`;

async function bundleResources() {
  // Create output directory if it doesn't exist
  await fs.mkdir(outputDir, { recursive: true });

  // Write temporary entry file for JS
  await fs.writeFile(entryPoint, entryContent);

  // Bundle JavaScript
  await esbuild.build({
    entryPoints: [entryPoint],
    outfile: jsOutputFile,
    bundle: true,
    minify: true,
    platform: 'browser',
    format: 'iife',
    // Removed globalName to avoid merging all exports into window
  }).then(() => console.log(`Bundled JS to ${jsOutputFile}`))
    .catch((err) => { console.error('JS Bundle failed:', err); process.exit(1); });

  // Clean up entry file
  await fs.unlink(entryPoint);

  // Fetch and save CSS files
  for (const { url, name } of cssFiles) {
    const response = await fetch(url);
    const cssContent = await response.text();
    const outputPath = path.join(outputDir, name);
    await fs.writeFile(outputPath, cssContent);
    console.log(`Saved CSS to ${outputPath}`);
  }
}

bundleResources().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
