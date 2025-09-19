"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
var PushService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.PushService = void 0;
const common_1 = require("@nestjs/common");
const node_fetch_1 = __importDefault(require("node-fetch"));
const prisma_service_1 = require("../common/prisma.service");
const FCM_ENDPOINT = 'https://fcm.googleapis.com/fcm/send';
const MAX_TOKENS_PER_BATCH = 500;
let PushService = PushService_1 = class PushService {
    constructor(prisma) {
        this.prisma = prisma;
        this.logger = new common_1.Logger(PushService_1.name);
    }
    get serverKey() {
        const key = process.env.FCM_SERVER_KEY;
        if (!key || key.trim().length === 0)
            return null;
        return key.trim();
    }
    get enabled() {
        return !!this.serverKey;
    }
    async registerDevice(userId, token, platform) {
        if (!token)
            return;
        await this.prisma.deviceToken.upsert({
            where: { token },
            update: { userId, platform, lastSeenAt: new Date() },
            create: { token, userId, platform },
        });
    }
    async deregisterDevice(token) {
        if (!token)
            return;
        await this.prisma.deviceToken.deleteMany({ where: { token } });
    }
    async sendToUser(userId, payload) {
        await this.sendToUsers([userId], payload);
    }
    async sendToUsers(userIds, payload) {
        if (!this.enabled)
            return;
        const uniqueIds = Array.from(new Set(userIds)).filter((id) => !!id);
        if (uniqueIds.length === 0)
            return;
        const tokens = await this.prisma.deviceToken.findMany({
            where: { userId: { in: uniqueIds } },
            select: { token: true },
        });
        if (!tokens.length)
            return;
        const tokenValues = tokens.map((t) => t.token);
        const batches = [];
        for (let i = 0; i < tokenValues.length; i += MAX_TOKENS_PER_BATCH) {
            batches.push(tokenValues.slice(i, i + MAX_TOKENS_PER_BATCH));
        }
        await Promise.all(batches.map((batch) => this.dispatchBatch(batch, payload)));
    }
    async dispatchBatch(tokens, payload) {
        var _a, _b;
        if (!tokens.length)
            return;
        const key = this.serverKey;
        if (!key)
            return;
        try {
            const res = await (0, node_fetch_1.default)(FCM_ENDPOINT, {
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
                    data: (_a = payload.data) !== null && _a !== void 0 ? _a : {},
                }),
            });
            if (!res.ok) {
                const text = await res.text();
                this.logger.warn(`FCM request failed: ${res.status} ${res.statusText} ${text}`);
                return;
            }
            const json = await res.json();
            const results = (_b = json === null || json === void 0 ? void 0 : json.results) !== null && _b !== void 0 ? _b : [];
            const toRemove = [];
            results.forEach((result, index) => {
                const error = result === null || result === void 0 ? void 0 : result.error;
                if (!error)
                    return;
                const token = tokens[index];
                if (error === 'NotRegistered' ||
                    error === 'InvalidRegistration' ||
                    error === 'MismatchSenderId') {
                    toRemove.push(token);
                }
                else {
                    this.logger.warn(`FCM responded with error ${error} for token ${token}`);
                }
            });
            if (toRemove.length) {
                await this.prisma.deviceToken.deleteMany({ where: { token: { in: toRemove } } });
            }
        }
        catch (err) {
            this.logger.error(`Failed to deliver push notification`, err instanceof Error ? err.stack : err);
        }
    }
};
exports.PushService = PushService;
exports.PushService = PushService = PushService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], PushService);
//# sourceMappingURL=push.service.js.map