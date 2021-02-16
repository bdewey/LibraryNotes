const importKindleHighlights = () => {
  const bookTitle = window.document.querySelector("h3.kp-notebook-metadata")
    ?.textContent;
  const bookAuthor = window.document.querySelector(
    "span.kp-notebook-metadata.a-color-secondary"
  )?.textContent;
  const annotations = window.document.getElementById("kp-notebook-annotations");
  const highlightDomElements = annotations?.querySelectorAll("div.a-row.a-spacing-base") || [];
  const locationRE = / (\S*)\)/;
  const quotes = Array.from(highlightDomElements).flatMap(e => {
    console.log(`Trying to match ${e.querySelector("span#annotationHighlightHeader")?.textContent}`)
    const location = e.querySelector("span#annotationHighlightHeader")?.textContent?.match(/\u00a0(\S+)$/);
    const locationSuffix = location ? ` (${location[1]})` : "";
    const highlight = e.querySelector("div.kp-notebook-highlight")?.textContent?.trim();
    return highlight ? [`> ${highlight}${locationSuffix}`] : [];
  }).join("\n\n");
  return `# ${bookTitle}: ${bookAuthor}\n\n${quotes}`;
};

importKindleHighlights();