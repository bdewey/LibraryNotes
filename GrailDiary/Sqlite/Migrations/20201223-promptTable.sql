CREATE TABLE IF NOT EXISTS "new_promptHistory"(
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "timestamp" DATETIME NOT NULL,
  "correct" INTEGER NOT NULL DEFAULT 0,
  "incorrect" INTEGER NOT NULL DEFAULT 0,
  "noteId" TEXT NOT NULL REFERENCES "note"("id") ON DELETE CASCADE,
  "promptKey" TEXT NOT NULL,
  "promptIndex" INTEGER NOT NULL,
  FOREIGN KEY("noteId", "promptKey", "promptIndex") REFERENCES "prompt"("noteId", "promptKey", "promptIndex") ON DELETE CASCADE
);

INSERT INTO "new_promptHistory"
SELECT * from promptHistory;

DROP TABLE promptHistory;
ALTER TABLE "new_promptHistory" RENAME TO promptHistory;

ALTER TABLE promptCounters RENAME TO prompt;
DROP TABLE changeLog;
