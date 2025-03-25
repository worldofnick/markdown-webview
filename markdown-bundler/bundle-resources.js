const esbuild = require('esbuild');
const fs = require('fs').promises;
const path = require('path');
const fetch = require('node-fetch');

// Output directory (adjust to your Swift project's resources path)
const outputDir = path.join(__dirname, '..', 'Sources', 'MarkdownWebView', 'Resources');
const jsOutputFile = path.join(outputDir, 'markdown-it-bundle.js');

// CSS files to fetch
const cssFiles = [
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

// markdown-it-code-copy implementation
function markdownitCodeCopy(md, options = {}) {
  const defaultOptions = {
    buttonClass: 'copy-code-button',
    wrapperClass: 'code-block-wrapper',
    copyIcon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>',
    copiedIcon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"></polyline></svg>',
    copiedDelay: 2000
  };
  options = Object.assign({}, defaultOptions, options);

  function escapeHtml(unsafe) {
    return unsafe
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function renderCode(origRule) {
    return (...args) => {
      const [tokens, idx] = args;
      const content = tokens[idx].content.replace(/\\n+$/, ''); // Strip trailing newlines
      const escapedContent = escapeHtml(content); // Escape for HTML attribute
      const origRendered = origRule(...args);

      if (content.length === 0)
        return origRendered;

      return \`
<div class="\${options.wrapperClass}">
  \${origRendered}
  <button class="\${options.buttonClass}" data-clipboard-text="\${escapedContent}">\${options.copyIcon}</button>
</div>
\`;
    };
  }

  md.renderer.rules.code_block = renderCode(md.renderer.rules.code_block);
  md.renderer.rules.fence = renderCode(md.renderer.rules.fence);

  // Add CSS to prevent selection and customize focus
  const style = document.createElement('style');
  style.textContent = \`
    .\${options.buttonClass} {
      user-select: none; /* Prevent text selection */
      -webkit-user-select: none; /* Safari */
      -moz-user-select: none; /* Firefox */
      -ms-user-select: none; /* IE/Edge */
      outline: none; /* Remove default focus outline */
      background: none; /* Optional: cleaner look */
      border: none; /* Optional: cleaner look */
      cursor: pointer; /* Indicate clickability */
      padding: 4px; /* Optional: better click area */
    }
    .\${options.buttonClass}:focus {
      outline: none; /* Remove focus outline */
      /* Optional: Add subtle focus indicator for accessibility */
      /* box-shadow: 0 0 0 2px rgba(0, 0, 255, 0.3); */
    }
    .\${options.wrapperClass} {
      position: relative; /* Optional: for positioning button */
    }
  \`;
  document.head.appendChild(style);

  document.addEventListener('DOMContentLoaded', function () {
    const clipboard = new ClipboardJS('.' + options.buttonClass);
    clipboard.on('success', function (e) {
      const button = e.trigger;
      button.innerHTML = options.copiedIcon;
      button.classList.add('copied');
      setTimeout(() => {
        button.innerHTML = options.copyIcon;
        button.classList.remove('copied');
      }, options.copiedDelay);
      e.clearSelection(); // Clear any selection made by ClipboardJS
    });

    // Decode HTML entities when copying
    clipboard.on('success', function (e) {
      const decodedText = e.text
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'");
      e.clearSelection();
      navigator.clipboard.writeText(decodedText);
    });
  });
}

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
  .use(markdownitFootnote)
  .use(markdownitCodeCopy);

// Expose globals on window
window.markdownit = function() { return md; };
window.markdownitMark = markdownitMark;
window.markdownitTaskLists = markdownitTaskLists;
window.markdownitTexmath = markdownitTexmath;
window.markdownitSub = markdownitSub;
window.markdownitSup = markdownitSup;
window.markdownitFootnote = markdownitFootnote;
window.markdownitCodeCopy = markdownitCodeCopy;
window.morphdom = morphdom;
window.ClipboardJS = ClipboardJS;
window.katex = katex;
`;

async function bundleResources() {
  // Create output directory if it doesn’t exist
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
