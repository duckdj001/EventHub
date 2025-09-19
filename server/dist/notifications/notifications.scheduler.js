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
var NotificationScheduler_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotificationScheduler = void 0;
const common_1 = require("@nestjs/common");
const notifications_service_1 = require("./notifications.service");
const REMINDER_INTERVAL_MS = 60 * 60 * 1000;
let NotificationScheduler = NotificationScheduler_1 = class NotificationScheduler {
    constructor(notifications) {
        this.notifications = notifications;
        this.logger = new common_1.Logger(NotificationScheduler_1.name);
        this.timer = null;
    }
    onModuleInit() {
        this.startTimer();
    }
    onModuleDestroy() {
        if (this.timer) {
            clearInterval(this.timer);
            this.timer = null;
        }
    }
    startTimer() {
        const run = async () => {
            try {
                await this.notifications.sendEventReminders();
            }
            catch (err) {
                this.logger.error('Failed to send event reminders', err instanceof Error ? err.stack : err);
            }
        };
        run();
        this.timer = setInterval(run, REMINDER_INTERVAL_MS);
    }
};
exports.NotificationScheduler = NotificationScheduler;
exports.NotificationScheduler = NotificationScheduler = NotificationScheduler_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [notifications_service_1.NotificationsService])
], NotificationScheduler);
//# sourceMappingURL=notifications.scheduler.js.map