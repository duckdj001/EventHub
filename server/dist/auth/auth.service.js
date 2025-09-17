"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../common/prisma.service");
const jwt_1 = require("@nestjs/jwt");
const bcrypt = __importStar(require("bcrypt"));
const mail_service_1 = require("../common/mail.service");
const client_1 = require("@prisma/client");
const crypto = __importStar(require("crypto"));
function genCode6() {
    const n = crypto.randomInt(0, 1000000);
    return n.toString().padStart(6, '0');
}
const VERIFY_CODE_TTL_MS = 10 * 60 * 1000;
const RESEND_THROTTLE_MS = 60 * 1000;
let AuthService = class AuthService {
    constructor(prisma, mail, jwt) {
        this.prisma = prisma;
        this.mail = mail;
        this.jwt = jwt;
    }
    async register(dto) {
        const exists = await this.prisma.user.findUnique({ where: { email: dto.email } });
        if (exists)
            throw new common_1.ConflictException('Этот e-mail уже зарегистрирован');
        const passwordHash = await bcrypt.hash(dto.password, 10);
        const code = genCode6();
        const expiresAt = new Date(Date.now() + VERIFY_CODE_TTL_MS);
        try {
            const user = await this.prisma.user.create({
                data: {
                    email: dto.email,
                    passwordHash,
                    firstName: dto.firstName,
                    lastName: dto.lastName,
                    birthDate: new Date(dto.birthDate),
                    avatarUrl: dto.avatarUrl,
                    emailVerified: false,
                    emailVerifyCode: code,
                    emailVerifyExpires: expiresAt,
                },
            });
            await this.mail.send(user.email, 'Подтверждение e-mail', `<p>Ваш код подтверждения: <b>${code}</b></p>`);
            return { ok: true };
        }
        catch (e) {
            if (e instanceof client_1.Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
                throw new common_1.ConflictException('Этот e-mail уже зарегистрирован');
            }
            throw e;
        }
    }
    async resend(email) {
        const user = await this.prisma.user.findUnique({ where: { email } });
        if (!user)
            throw new common_1.BadRequestException('Пользователь не найден');
        if (user.emailVerified)
            return { ok: true };
        if (user.emailVerifyExpires) {
            const msLeft = user.emailVerifyExpires.getTime() - (Date.now() - (VERIFY_CODE_TTL_MS - RESEND_THROTTLE_MS));
            const lastIssuedAt = new Date(user.emailVerifyExpires.getTime() - VERIFY_CODE_TTL_MS);
            if (Date.now() - lastIssuedAt.getTime() < RESEND_THROTTLE_MS) {
                throw new common_1.HttpException('Слишком часто. Попробуйте позже.', common_1.HttpStatus.TOO_MANY_REQUESTS);
            }
        }
        const code = genCode6();
        const expiresAt = new Date(Date.now() + VERIFY_CODE_TTL_MS);
        await this.prisma.user.update({
            where: { id: user.id },
            data: { emailVerifyCode: code, emailVerifyExpires: expiresAt },
        });
        await this.mail.send(email, 'Подтверждение e-mail', `<p>Ваш код подтверждения: <b>${code}</b></p>`);
        return { ok: true };
    }
    async login(dto) {
        const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
        if (!user)
            throw new common_1.UnauthorizedException('Invalid credentials');
        if (!user.passwordHash)
            throw new common_1.UnauthorizedException('Invalid credentials');
        const ok = await bcrypt.compare(dto.password, user.passwordHash);
        if (!ok)
            throw new common_1.UnauthorizedException('Invalid credentials');
        const payload = { sub: user.id };
        return {
            accessToken: await this.jwt.signAsync(payload),
            user: {
                id: user.id,
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName,
                emailVerified: user.emailVerified,
            },
        };
    }
    async verifyEmail(dto) {
        const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
        if (!user || !user.emailVerifyCode)
            throw new common_1.UnauthorizedException('Invalid code');
        if (!user.emailVerifyExpires || user.emailVerifyExpires.getTime() < Date.now()) {
            throw new common_1.UnauthorizedException('Код истёк, запросите новый');
        }
        if (user.emailVerifyCode !== dto.code)
            throw new common_1.UnauthorizedException('Неверный код');
        await this.prisma.user.update({
            where: { id: user.id },
            data: {
                emailVerified: true,
                emailVerifyCode: null,
                emailVerifyExpires: null,
            },
        });
        return { ok: true };
    }
};
exports.AuthService = AuthService;
exports.AuthService = AuthService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        mail_service_1.MailService,
        jwt_1.JwtService])
], AuthService);
//# sourceMappingURL=auth.service.js.map