ALTER TABLE
    note
ADD
    COLUMN new_id text;

UPDATE
    note
SET
    new_id = lower(hex(randomblob(16)));

CREATE TABLE "new_note"(
    "id" TEXT PRIMARY KEY,
    "title" TEXT NOT NULL DEFAULT '',
    "modifiedTimestamp" DATETIME NOT NULL,
    "modifiedDevice" TEXT REFERENCES "device"("uuid") ON DELETE SET NULL,
    "hasText" BOOLEAN NOT NULL,
    "deleted" BOOLEAN NOT NULL DEFAULT 0,
    "updateSequenceNumber" INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX "20201214_on_modifiedDevice" ON "note"("modifiedDevice");

INSERT INTO "new_note"
SELECT
    new_id,
    title,
    modifiedTimestamp,
    modifiedDevice,
    hasText,
    deleted,
    updateSequenceNumber
FROM note;

CREATE TABLE IF NOT EXISTS "new_challengeTemplate"(
  "id" INTEGER PRIMARY KEY,
  "type" TEXT NOT NULL,
  "rawValue" TEXT NOT NULL,
  "noteId" TEXT NOT NULL REFERENCES "note"("id") ON DELETE CASCADE
);

CREATE INDEX "20201214_challengeTemplate_on_noteId" ON "challengeTemplate"(
  "noteId"
);

INSERT INTO "new_challengeTemplate"
SELECT
    ct.id,
    ct.type,
    ct.rawValue,
    n.new_id
FROM
    challengeTemplate ct
    JOIN note n on n.id = ct.noteId;

CREATE TABLE "new_noteHashtag"(
  "noteId" TEXT NOT NULL REFERENCES "note"("id") ON DELETE CASCADE,
  "hashtag" TEXT NOT NULL,
  PRIMARY KEY("noteId", "hashtag")
);
CREATE INDEX "20201214_on_noteId" ON "noteHashtag"(
  "noteId"
);
CREATE INDEX "20201214_on_hashtag" ON "noteHashtag"(
  "hashtag"
);

INSERT INTO "new_noteHashtag"
SELECT
    n.new_id,
    nh.hashtag
FROM
    noteHashtag nh
    JOIN note n on n.id = nh.noteId;

CREATE TABLE "new_noteText"(
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "text" TEXT NOT NULL,
  "noteId" TEXT NOT NULL UNIQUE REFERENCES "note"("id") ON DELETE CASCADE
);

INSERT INTO "new_noteText"
SELECT
    nt.id,
    nt.text,
    n.new_id
FROM
    noteText nt
    JOIN note n on n.id = nt.noteId;

DROP TABLE note;

ALTER TABLE new_note RENAME TO note;

DROP TABLE challengeTemplate;

ALTER TABLE new_challengeTemplate RENAME TO challengeTemplate;

DROP TABLE noteHashtag;

ALTER TABLE new_noteHashtag RENAME TO noteHashtag;

DROP TABLE noteText;

ALTER TABLE new_noteText RENAME TO noteText;
