CREATE TABLE "EventStory" (
    "id" TEXT NOT NULL,
    "eventId" TEXT NOT NULL,
    "authorId" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "EventStory_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "EventStory_eventId_createdAt_idx" ON "EventStory"("eventId", "createdAt");

ALTER TABLE "EventStory" ADD CONSTRAINT "EventStory_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "Event"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "EventStory" ADD CONSTRAINT "EventStory_authorId_fkey" FOREIGN KEY ("authorId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
