-- Extend notification types
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'PARTICIPATION_APPROVED';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'NEW_FOLLOWER';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'EVENT_STORY_ADDED';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'EVENT_PHOTO_ADDED';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'FOLLOWED_STORY_ADDED';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'EVENT_UPDATED';

-- Adjust notifications table structure
DROP INDEX IF EXISTS "Notification_userId_type_eventId_key";
ALTER TABLE "Notification" ADD COLUMN IF NOT EXISTS "actorId" TEXT;
ALTER TABLE "Notification" ADD COLUMN IF NOT EXISTS "contextId" TEXT;
ALTER TABLE "Notification" ADD COLUMN IF NOT EXISTS "meta" JSONB;

ALTER TABLE "Notification" DROP CONSTRAINT IF EXISTS "Notification_actorId_fkey";
ALTER TABLE "Notification"
  ADD CONSTRAINT "Notification_actorId_fkey"
  FOREIGN KEY ("actorId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE UNIQUE INDEX IF NOT EXISTS "Notification_userId_type_eventId_actorId_contextId_key"
  ON "Notification" ("userId", "type", "eventId", "actorId", "contextId");

-- Notification preferences
CREATE TABLE IF NOT EXISTS "NotificationPreference" (
  "userId" TEXT NOT NULL,
  "newEvent" BOOLEAN NOT NULL DEFAULT TRUE,
  "eventReminder" BOOLEAN NOT NULL DEFAULT TRUE,
  "participationApproved" BOOLEAN NOT NULL DEFAULT TRUE,
  "newFollower" BOOLEAN NOT NULL DEFAULT TRUE,
  "organizerContent" BOOLEAN NOT NULL DEFAULT TRUE,
  "followedStory" BOOLEAN NOT NULL DEFAULT TRUE,
  "eventUpdated" BOOLEAN NOT NULL DEFAULT TRUE,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "NotificationPreference_pkey" PRIMARY KEY ("userId"),
  CONSTRAINT "NotificationPreference_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
