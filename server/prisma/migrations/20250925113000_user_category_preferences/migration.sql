CREATE TABLE "UserCategoryPreference" (
  "userId" TEXT NOT NULL,
  "categoryId" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "UserCategoryPreference_pkey" PRIMARY KEY ("userId", "categoryId"),
  CONSTRAINT "UserCategoryPreference_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "UserCategoryPreference_categoryId_fkey"
    FOREIGN KEY ("categoryId") REFERENCES "Category"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
