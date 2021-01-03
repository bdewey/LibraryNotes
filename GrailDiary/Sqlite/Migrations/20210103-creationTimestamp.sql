CREATE TABLE IF NOT EXISTS "new_note"(
  "id" TEXT PRIMARY KEY,
  "title" TEXT NOT NULL DEFAULT '',
  "creationTimestamp" DATETIME NOT NULL,
  "modifiedTimestamp" DATETIME NOT NULL,
  "modifiedDevice" TEXT REFERENCES "device"("uuid") ON DELETE SET NULL,
  "deleted" BOOLEAN NOT NULL DEFAULT 0,
  "updateSequenceNumber" INTEGER NOT NULL DEFAULT 0
);

INSERT INTO "new_note"
SELECT
  "id",
  "title",
  datetime('now'),
  "modifiedTimestamp",
  "modifiedDevice",
  "deleted",
  "updateSequenceNumber"
FROM note;

DROP TABLE note;
ALTER TABLE new_note RENAME TO note;
