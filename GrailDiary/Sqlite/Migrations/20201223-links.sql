CREATE TABLE IF NOT EXISTS "noteLink"(
  "noteId" TEXT NOT NULL REFERENCES "note"("id") ON DELETE CASCADE,
  "targetTitle" TEXT NOT NULL,
  PRIMARY KEY("noteId", "targetTitle")
);

CREATE INDEX "20201223_linkSource" ON "noteLink"("noteId");
CREATE INDEX "20201223_linkTarget" ON "noteLink"("targetTitle");

INSERT INTO noteLink SELECT * from noteHashtag;
DROP TABLE noteHashtag;
