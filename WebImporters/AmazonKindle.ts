const bookTitle = window.document.querySelector("h3.kp-notebook-metadata")?.textContent
const bookAuthor = window.document.querySelector("span.kp-notebook-metadata.a-color-secondary")?.textContent
const elements = Array.from(window.document.getElementsByClassName("kp-notebook-highlight"));
const quotes = elements.map(e => `> ${e.textContent}`).join("\n\n");

`# ${bookTitle}: ${bookAuthor}\n\n${quotes}`