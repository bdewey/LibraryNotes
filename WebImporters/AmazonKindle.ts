const title = window.document.querySelector("h3.kp-notebook-metadata")?.textContent
const author = window.document.querySelector("p.kp-notebook-metadata.a-color-secondary")?.textContent
const elements = Array.from(window.document.getElementsByClassName("kp-notebook-highlight"));
const quotes = elements.map(e => `> ${e.textContent}`).join("\n\n");

`# ${title}: ${author}\n\n${quotes}`