CREATE TABLE IF NOT EXISTS "new_device"(
    "uuid" TEXT PRIMARY KEY,
    "name" TEXT NOT NULL,
    "updateSequenceNumber" INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS "new_changeLog"(
    "deviceID" TEXT NOT NULL REFERENCES "device"("uuid") ON DELETE CASCADE,
    "updateSequenceNumber" INTEGER NOT NULL,
    "timestamp" DATETIME NOT NULL,
    "changeDescription" TEXT NOT NULL,
    PRIMARY KEY("deviceID", "updateSequenceNumber")
);

CREATE INDEX "new_changeLog_on_deviceID" ON "changeLog"("deviceID");

CREATE TABLE IF NOT EXISTS "new_note"(
    "id" INTEGER PRIMARY KEY,
    "title" TEXT NOT NULL DEFAULT '',
    "modifiedTimestamp" DATETIME NOT NULL,
    "modifiedDevice" TEXT REFERENCES "device"("uuid") ON DELETE SET NULL,
    "hasText" BOOLEAN NOT NULL,
    "deleted" BOOLEAN NOT NULL DEFAULT 0,
    "updateSequenceNumber" INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX "new_note_on_modifiedDevice" ON "new_note"("modifiedDevice");

-- challenge

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
    "challengeTemplateId" INTEGER NOT NULL REFERENCES "challengeTemplate"("id") ON DELETE CASCADE,
    "modifiedDevice" TEXT NOT NULL REFERENCES "device"("uuid") ON DELETE CASCADE,
    "timestamp" DATETIME NOT NULL,
    "updateSequenceNumber" INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX "byChallengeTemplateId" ON "new_challenge"(
    "challengeTemplateId"
);
CREATE INDEX "byModifiedDevice" ON "new_challenge"(
    "modifiedDevice"
);
CREATE UNIQUE INDEX "new_byChallengeTemplateIndex" ON "new_challenge"(
    "index",
    "challengeTemplateId"
);

INSERT INTO
    new_device
SELECT
    uuid,
    name,
    updateSequenceNumber
FROM
    device;

INSERT INTO
    new_changeLog
SELECT
    uuid,
    cl.updateSequenceNumber,
    timestamp,
    changeDescription
FROM
    changeLog cl
    JOIN device ON device.id = cl.deviceID;

INSERT INTO
    new_note
SELECT
    n.id,
    title,
    modifiedTimestamp,
    device.uuid,
    hasText,
    deleted,
    n.updateSequenceNumber
FROM
    note n
    JOIN device on n.modifiedDevice = device.id;

INSERT INTO new_challenge
SELECT
    c.id,
    "index",
    reviewCount,
    totalCorrect,
    totalIncorrect,
    lastReview,
    due,
    spacedRepetitionFactor,
    lapseCount,
    idealInterval,
    challengeTemplateId,
    device.uuid,
    "timestamp",
    c.updateSequenceNumber
FROM
    challenge c
    JOIN device on c.modifiedDevice = device.id;

DROP TABLE note;

DROP TABLE changeLog;

DROP TABLE device;

DROP TABLE challenge;

ALTER TABLE
    new_note RENAME TO note;

ALTER TABLE
    new_changeLog RENAME TO changeLog;

ALTER TABLE
    new_device RENAME TO device;

ALTER TABLE
    new_challenge RENAME TO challenge;
