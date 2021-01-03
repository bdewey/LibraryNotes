CREATE TABLE "new_content"(
  "noteId" TEXT NOT NULL REFERENCES "note"("id") ON DELETE CASCADE,
  "key" TEXT NOT NULL,
  "role" TEXT NOT NULL,
  "mimeType" TEXT NOT NULL,
  "text" TEXT NOT NULL,
  PRIMARY KEY("noteId", "key")
);

INSERT INTO new_content SELECT * FROM content;

DROP TABLE content;

ALTER TABLE new_content RENAME TO content;

INSERT INTO content
SELECT
    "noteId",
    "id",
    printf('prompt=%s', "type"),
    'text/markdown',
    "rawValue"
FROM challengeTemplate;

CREATE TABLE "promptCounters"(
  "noteId" TEXT NOT NULL,
  "promptKey" TEXT NOT NULL,
  "promptIndex" INTEGER NOT NULL,
  "reviewCount" INTEGER NOT NULL DEFAULT 0,
  "totalCorrect" INTEGER NOT NULL DEFAULT 0,
  "totalIncorrect" INTEGER NOT NULL DEFAULT 0,
  "lastReview" DATETIME,
  "due" DATETIME,
  "spacedRepetitionFactor" DOUBLE NOT NULL DEFAULT 2.5,
  "lapseCount" DOUBLE NOT NULL DEFAULT 0,
  "idealInterval" DOUBLE,
  "modifiedDevice" TEXT NOT NULL REFERENCES "device"("uuid") ON DELETE CASCADE,
  "timestamp" DATETIME NOT NULL,
  "updateSequenceNumber" INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY("noteId", "promptKey", "promptIndex"),
  FOREIGN KEY("noteId", "promptKey") REFERENCES "content"("noteId", "key") ON DELETE CASCADE
);

INSERT INTO promptCounters
SELECT
  challengeTemplate."noteId",
  challengeTemplate.id,
  challenge."index",
  "reviewCount",
  "totalCorrect",
  "totalIncorrect",
  "lastReview",
  "due",
  "spacedRepetitionFactor",
  "lapseCount",
  "idealInterval",
  "modifiedDevice",
  "timestamp",
  "updateSequenceNumber"
FROM challenge JOIN challengeTemplate on challenge.challengeTemplateId = challengeTemplate.id;

CREATE INDEX "20201221_byPromptKey" ON "promptCounters"(
  "noteId", "promptKey"
);
CREATE INDEX "20201221_byModifiedDevice" ON "promptCounters"("modifiedDevice");

CREATE TABLE "promptHistory"(
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "timestamp" DATETIME NOT NULL,
  "correct" INTEGER NOT NULL DEFAULT 0,
  "incorrect" INTEGER NOT NULL DEFAULT 0,
  "noteId" TEXT NOT NULL REFERENCES "note"("id") ON DELETE CASCADE,
  "promptKey" TEXT NOT NULL,
  "promptIndex" INTEGER NOT NULL,
  FOREIGN KEY("noteId", "promptKey", "promptIndex") REFERENCES "promptCounters"("noteId", "promptKey", "promptIndex") ON DELETE CASCADE
);

INSERT INTO "promptHistory"
SELECT
    sl.id,
    sl."timestamp",
    correct,
    incorrect,
    ct.noteId,
    ct.id,
    c."index"
FROM 
    studyLogEntry sl 
    JOIN challenge c on sl.challengeId = c.id
    JOIN challengeTemplate ct on c.challengeTemplateId = ct.id;

DROP TABLE challengeTemplate;
DROP TABLE challenge;
DROP TABLE studyLogEntry;

CREATE TRIGGER "__noteFullText_ai" AFTER INSERT ON "content" BEGIN
    INSERT INTO "noteFullText"("rowid", "text") VALUES (new."rowid", new."text");
END;
CREATE TRIGGER "__noteFullText_ad" AFTER DELETE ON "content" BEGIN
    INSERT INTO "noteFullText"("noteFullText", "rowid", "text") VALUES('delete', old."rowid", old."text");
END;
CREATE TRIGGER "__noteFullText_au" AFTER UPDATE ON "content" BEGIN
    INSERT INTO "noteFullText"("noteFullText", "rowid", "text") VALUES('delete', old."rowid", old."text");
    INSERT INTO "noteFullText"("rowid", "text") VALUES (new."rowid", new."text");
END;