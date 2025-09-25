ALTER TABLE "EventPhoto" ADD COLUMN "authorId" TEXT;
ALTER TABLE "EventPhoto" ADD COLUMN "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

UPDATE "EventPhoto" SET "authorId" = (
  SELECT "ownerId" FROM "Event" WHERE "Event"."id" = "EventPhoto"."eventId"
);

ALTER TABLE "EventPhoto" ALTER COLUMN "authorId" SET NOT NULL;

ALTER TABLE "EventPhoto" ADD CONSTRAINT "EventPhoto_authorId_fkey" FOREIGN KEY ("authorId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE INDEX "EventPhoto_eventId_createdAt_idx" ON "EventPhoto"("eventId", "createdAt");
