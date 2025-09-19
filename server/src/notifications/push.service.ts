import { Injectable, Logger } from '@nestjs/common';
import fetch from 'node-fetch';
import { PrismaService } from '../common/prisma.service';

const FCM_ENDPOINT = 'https://fcm.googleapis.com/fcm/send';
const MAX_TOKENS_PER_BATCH = 500;

type PushPayload = {
  title: string;
  body: string;
  data?: Record<string, string>;
  badge?: number;
};

@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);

  constructor(private readonly prisma: PrismaService) {}

  private get serverKey(): string | null {
    const key = process.env.FCM_SERVER_KEY;
    if (!key || key.trim().length === 0) return null;
    return key.trim();
  }

  private get enabled(): boolean {
    return !!this.serverKey;
  }

  async registerDevice(userId: string, token: string, platform: string) {
    if (!token) return;
    await this.prisma.deviceToken.upsert({
      where: { token },
      update: { userId, platform, lastSeenAt: new Date() },
      create: { token, userId, platform },
    });
  }

  async deregisterDevice(token: string) {
    if (!token) return;
    await this.prisma.deviceToken.deleteMany({ where: { token } });
  }

  async sendToUser(userId: string, payload: PushPayload) {
    await this.sendToUsers([userId], payload);
  }

  async sendToUsers(userIds: string[], payload: PushPayload) {
    if (!this.enabled) return;
    const uniqueIds = Array.from(new Set(userIds)).filter((id) => !!id);
    if (uniqueIds.length === 0) return;

    const tokens = await this.prisma.deviceToken.findMany({
      where: { userId: { in: uniqueIds } },
      select: { token: true },
    });
    if (!tokens.length) return;

    const tokenValues = tokens.map((t) => t.token);
    const batches: string[][] = [];
    for (let i = 0; i < tokenValues.length; i += MAX_TOKENS_PER_BATCH) {
      batches.push(tokenValues.slice(i, i + MAX_TOKENS_PER_BATCH));
    }

    await Promise.all(
      batches.map((batch) => this.dispatchBatch(batch, payload)),
    );
  }

  private async dispatchBatch(tokens: string[], payload: PushPayload) {
    if (!tokens.length) return;
    const key = this.serverKey;
    if (!key) return;

    try {
      const res = await fetch(FCM_ENDPOINT, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `key=${key}`,
        },
        body: JSON.stringify({
          registration_ids: tokens,
          notification: {
            title: payload.title,
            body: payload.body,
            badge: payload.badge,
          },
          data: payload.data ?? {},
        }),
      });

      if (!res.ok) {
        const text = await res.text();
        this.logger.warn(`FCM request failed: ${res.status} ${res.statusText} ${text}`);
        return;
      }

      const json: any = await res.json();
      const results: Array<{ error?: string }> = json?.results ?? [];
      const toRemove: string[] = [];
      results.forEach((result, index) => {
        const error = result?.error;
        if (!error) return;
        const token = tokens[index];
        if (
          error === 'NotRegistered' ||
          error === 'InvalidRegistration' ||
          error === 'MismatchSenderId'
        ) {
          toRemove.push(token);
        } else {
          this.logger.warn(`FCM responded with error ${error} for token ${token}`);
        }
      });

      if (toRemove.length) {
        await this.prisma.deviceToken.deleteMany({ where: { token: { in: toRemove } } });
      }
    } catch (err) {
      this.logger.error(`Failed to deliver push notification`, err instanceof Error ? err.stack : err);
    }
  }
}
