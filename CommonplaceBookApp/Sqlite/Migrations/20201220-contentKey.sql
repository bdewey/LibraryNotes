ALTER TABLE "content" ADD COLUMN "role" TEXT;
ALTER TABLE "content" ADD COLUMN "key" TEXT;

UPDATE "content" SET "role" = 'primary', "key" = 'primary';

CREATE TABLE IF NOT EXISTS "new_content"(
  "noteId" TEXT NOT NULL UNIQUE REFERENCES "note"("id") ON DELETE CASCADE,
  "key" TEXT NOT NULL,
  "role" TEXT NOT NULL,
  "mimeType" TEXT NOT NULL,
  "text" TEXT NOT NULL,
  PRIMARY KEY("noteId", "key")
);

INSERT INTO "new_content"
SELECT
  "noteId",
  "key",
  "role",
  "mimeType",
  "text"
FROM "content";

DROP TABLE "content";

ALTER TABLE "new_content" RENAME TO "content";
