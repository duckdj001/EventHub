"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const core_1 = require("@nestjs/core");
const auth_module_1 = require("./auth/auth.module");
const jwt_guard_1 = require("./auth/jwt.guard");
const files_module_1 = require("./files/files.module");
const events_module_1 = require("./events/events.module");
const users_module_1 = require("./users/users.module");
const geo_module_1 = require("./geo/geo.module");
const participations_module_1 = require("./participations/participations.module");
const categories_module_1 = require("./categories/categories.module");
const follows_module_1 = require("./follows/follows.module");
const notifications_module_1 = require("./notifications/notifications.module");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            auth_module_1.AuthModule,
            files_module_1.FilesModule,
            events_module_1.EventsModule,
            users_module_1.UsersModule,
            geo_module_1.GeoModule,
            participations_module_1.ParticipationsModule,
            categories_module_1.CategoriesModule,
            follows_module_1.FollowsModule,
            notifications_module_1.NotificationsModule,
        ],
        providers: [
            { provide: core_1.APP_GUARD, useClass: jwt_guard_1.JwtAuthGuard },
        ],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map