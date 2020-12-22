CREATE TABLE IF NOT EXISTS 'noteFullText_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'noteFullText_idx'(
  segid,
  term,
  pgno,
  PRIMARY KEY(segid, term)
) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'noteFullText_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'noteFullText_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS "studyLogEntry"(
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "timestamp" DATETIME NOT NULL,
  "correct" INTEGER NOT NULL DEFAULT 0,
  "incorrect" INTEGER NOT NULL DEFAULT 0,
  "challengeId" INTEGER NOT NULL REFERENCES "challenge"("id") ON DELETE CASCADE
);
CREATE TABLE sqlite_sequence(name,seq);
CREATE TABLE IF NOT EXISTS "asset"("id" TEXT PRIMARY KEY, "data" BLOB NOT NULL);
CREATE TABLE IF NOT EXISTS "noteText"(
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "text" TEXT NOT NULL,
  "noteId" INTEGER NOT NULL UNIQUE REFERENCES "note"("id") ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS "challengeTemplate"(
  "id" INTEGER PRIMARY KEY,
  "type" TEXT NOT NULL,
  "rawValue" TEXT NOT NULL,
  "noteId" INTEGER NOT NULL REFERENCES "note"("id") ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS "note"(
  "id" INTEGER PRIMARY KEY,
  "title" TEXT NOT NULL DEFAULT '',
  "modifiedTimestamp" DATETIME NOT NULL,
  "modifiedDevice" INTEGER REFERENCES "device"("id") ON DELETE SET NULL,
  "hasText" BOOLEAN NOT NULL,
  "deleted" BOOLEAN NOT NULL DEFAULT 0,
  "updateSequenceNumber" INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS "noteHashtag"(
  "noteId" INTEGER NOT NULL REFERENCES "note"("id") ON DELETE CASCADE,
  "hashtag" TEXT NOT NULL,
  PRIMARY KEY("noteId", "hashtag")
);
CREATE TABLE IF NOT EXISTS "challenge"(
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
  "challengeTemplateId" INTEGER NOT NULL REFERENCES "challengeTemplate"("id") ON DELETE CASCADE,
  "modifiedDevice" INTEGER NOT NULL REFERENCES "device"("id") ON DELETE CASCADE,
  "timestamp" DATETIME NOT NULL,
  "updateSequenceNumber" INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS "changeLog"(
  "deviceID" INTEGER NOT NULL REFERENCES "device"("id") ON DELETE CASCADE,
  "updateSequenceNumber" INTEGER NOT NULL,
  "timestamp" DATETIME NOT NULL,
  "changeDescription" TEXT NOT NULL,
  PRIMARY KEY("deviceID", "updateSequenceNumber")
);
CREATE TABLE IF NOT EXISTS "device"(
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "uuid" TEXT NOT NULL UNIQUE,
  "name" TEXT NOT NULL,
  "updateSequenceNumber" INTEGER NOT NULL
);
CREATE INDEX "temporaryMigration1756664091533850893_on_noteId" ON "challengeTemplate"(
  "noteId"
);
CREATE INDEX "temporaryMigration1787884213150801497_on_modifiedDevice" ON "note"(
  "modifiedDevice"
);
CREATE INDEX "temporaryMigration5200169568620969226_on_noteId" ON "noteHashtag"(
  "noteId"
);
CREATE INDEX "temporaryMigration5200169568620969226_on_hashtag" ON "noteHashtag"(
  "hashtag"
);
CREATE INDEX "temporaryMigration877671328872587430_on_challengeTemplateId" ON "challenge"(
  "challengeTemplateId"
);
CREATE INDEX "temporaryMigration877671328872587430_on_modifiedDevice" ON "challenge"(
  "modifiedDevice"
);
CREATE UNIQUE INDEX "byChallengeTemplateIndex" ON "challenge"(
  "index",
  "challengeTemplateId"
);
CREATE INDEX "changeLog_on_deviceID" ON "changeLog"("deviceID");
CREATE VIRTUAL TABLE "noteFullText" USING fts5(
  text,
  tokenize='porter unicode61',
  content='noteText',
  content_rowid='id'
)
/* noteFullText(
  text
) */;