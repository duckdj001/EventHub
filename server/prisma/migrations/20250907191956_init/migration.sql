-- AlterTable
ALTER TABLE "User" ADD COLUMN     "emailVerifyCode" TEXT,
ADD COLUMN     "emailVerifyExpires" TIMESTAMP(3);
