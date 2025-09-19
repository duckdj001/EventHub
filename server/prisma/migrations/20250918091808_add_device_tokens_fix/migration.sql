-- Drop unique constraint so organizer can review multiple participants
ALTER TABLE "Review" DROP CONSTRAINT IF EXISTS "Review_eventId_authorId_target_key";
