ALTER TABLE "User"
  ADD COLUMN "pendingEmail" TEXT,
  ADD COLUMN "pendingEmailToken" TEXT,
  ADD COLUMN "pendingEmailExpires" TIMESTAMP(3);

ALTER TABLE "Review"
  ADD CONSTRAINT "Review_eventId_authorId_target_key" UNIQUE ("eventId", "authorId", "target");
