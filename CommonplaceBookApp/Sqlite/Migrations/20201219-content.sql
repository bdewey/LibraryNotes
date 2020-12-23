ALTER TABLE noteText ADD COLUMN mimeType TEXT;

ALTER TABLE noteText RENAME TO content;

UPDATE content SET mimeType = 'text/markdown';

CREATE TABLE IF NOT EXISTS "new_content"(
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "noteId" TEXT NOT NULL UNIQUE REFERENCES "note"("id") ON DELETE CASCADE,
  "mimeType" TEXT NOT NULL,
  "text" TEXT NOT NULL
);

INSERT INTO new_content
SELECT
    "id",
    "noteId",
    "mimeType",
    "text"
FROM content;

DROP TABLE content;

ALTER TABLE new_content RENAME TO content;