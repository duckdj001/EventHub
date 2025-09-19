-- Drop unique constraint that prevented multiple participant reviews per organizer
ALTER TABLE "Review" DROP CONSTRAINT IF EXISTS "Review_eventId_authorId_target_key";
