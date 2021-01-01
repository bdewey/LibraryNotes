CREATE TABLE IF NOT EXISTS "binaryContent"(
  "noteId" TEXT NOT NULL REFERENCES "note"("id") ON DELETE CASCADE,
  "key" TEXT NOT NULL,
  "role" TEXT NOT NULL,
  "mimeType" TEXT NOT NULL,
  "blob" BLOB NOT NULL,
  PRIMARY KEY("noteId", "key")
);