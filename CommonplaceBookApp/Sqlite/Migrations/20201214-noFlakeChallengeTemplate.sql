ALTER TABLE challengeTemplate ADD COLUMN new_id TEXT;

UPDATE challengeTemplate SET new_id = lower(hex(randomblob(16)));

CREATE TABLE IF NOT EXISTS "new_challengeTemplate"(
  "id" TEXT PRIMARY KEY,
  "type" TEXT NOT NULL,
  "rawValue" TEXT NOT NULL,
  "noteId" TEXT NOT NULL REFERENCES "note"("id") ON DELETE CASCADE
);

INSERT INTO new_challengeTemplate
SELECT
    new_id,
    type,
    rawValue,
    noteId
FROM challengeTemplate;

CREATE TABLE IF NOT EXISTS "new_challenge"(
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "index" INTEGER NOT NULL,
  "reviewCount" INTEGER NOT NULL DEFAULT 0,
  "totalCorrect" INTEGER NOT NULL DEFAULT 0,
  "totalIncorrect" INTEGER NOT NULL DEFAULT 0,
  "lastReview" DATETIME,
  "due" DATETIME,
  "spacedRepetitionFactor" DOUBLE NOT NULL DEFAULT 2.5,
  "lapseCount" DOUBLE NOT NULL DEFAULT 0,
  "idealInterval" DOUBLE,
  "challengeTemplateId" TEXT NOT NULL REFERENCES "challengeTemplate"("id") ON DELETE CASCADE,
  "modifiedDevice" TEXT NOT NULL REFERENCES "device"("uuid") ON DELETE CASCADE,
  "timestamp" DATETIME NOT NULL,
  "updateSequenceNumber" INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX "20201214_byChallengeTemplateId" ON "new_challenge"("challengeTemplateId");
CREATE INDEX "20201214_byModifiedDevice" ON "new_challenge"("modifiedDevice");
CREATE UNIQUE INDEX "20201214_byChallengeTemplateIndex" ON "new_challenge"(
  "index",
  "challengeTemplateId"
);

INSERT INTO new_challenge
SELECT
    c."id",
    "index",
    "reviewCount",
    "totalCorrect",
    "totalIncorrect",
    "lastReview",
    "due",
    "spacedRepetitionFactor",
    "lapseCount",
    "idealInterval",
    ct.new_id,
    "modifiedDevice",
    "timestamp",
    "updateSequenceNumber"
FROM
    challenge c
    JOIN challengeTemplate ct on ct.id = c.challengeTemplateId;

DROP TABLE challenge;

ALTER TABLE new_challenge RENAME TO challenge;

DROP TABLE challengeTemplate;

ALTER TABLE new_challengeTemplate RENAME TO challengeTemplate;