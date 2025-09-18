ALTER TABLE "Event"
  ADD COLUMN "isAdultOnly" BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "Review"
  ADD COLUMN "targetUserId" TEXT;

ALTER TABLE "Review"
  ADD CONSTRAINT "Review_targetUserId_fkey" FOREIGN KEY ("targetUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE UNIQUE INDEX "Review_eventId_targetUserId_target_key" ON "Review"("eventId", "targetUserId", "target");
