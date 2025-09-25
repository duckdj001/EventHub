// src/auth/auth.service.ts
import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  BadRequestException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { PrismaService } from '../common/prisma.service';
import { JwtService } from '@nestjs/jwt';
import { RegisterDto, LoginDto, VerifyEmailDto } from './dto';
import * as bcrypt from 'bcrypt';
import { MailService } from '../common/mail.service';
import { Prisma } from '@prisma/client';
import * as crypto from 'crypto';

// 6-значный код (криптографически корректно)
function genCode6(): string {
  // randomInt(0, 1000000) → паддинг нулями до 6 символов
  const n = crypto.randomInt(0, 1000000);
  return n.toString().padStart(6, '0');
}

// TTL кода (10 минут)
const VERIFY_CODE_TTL_MS = 10 * 60 * 1000;
// throttle на resend (напр., не чаще 60 сек)
const RESEND_THROTTLE_MS = 60 * 1000;

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly mail: MailService,
    private readonly jwt: JwtService,
  ) {}

  async register(dto: RegisterDto) {
    if (!dto.acceptedTerms) {
      throw new BadRequestException('Необходимо согласиться с пользовательским соглашением');
    }
    const exists = await this.prisma.user.findUnique({
      where: { email: dto.email },
      select: { id: true, deletedAt: true },
    });
    if (exists && exists.deletedAt == null) {
      throw new ConflictException('Этот e-mail уже зарегистрирован');
    }

    const categoriesInput = dto.categories ?? [];
    const categories = Array.from(
      new Set(
        categoriesInput
          .map((id) => id.trim())
          .filter((id) => id.length > 0),
      ),
    );
    if (categories.length > 0 && categories.length !== 5) {
      throw new BadRequestException('Выберите ровно 5 категорий интересов');
    }
    if (categories.length) {
      const valid = await this.prisma.category.findMany({
        where: { id: { in: categories } },
        select: { id: true },
      });
      if (valid.length !== categories.length) {
        throw new BadRequestException('Некорректный идентификатор категории');
      }
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const code = genCode6();
    const expiresAt = new Date(Date.now() + VERIFY_CODE_TTL_MS);

    try {
      const user = await this.prisma.$transaction(async (tx) => {
        const created = await tx.user.create({
          data: {
            email: dto.email,
            passwordHash,
            firstName: dto.firstName,
            lastName: dto.lastName,
            birthDate: new Date(dto.birthDate),
            avatarUrl: dto.avatarUrl,
            termsAcceptedAt: new Date(),
            emailVerified: false,
            emailVerifyCode: code,
            emailVerifyExpires: expiresAt,
          },
        });

        if (categories.length > 0) {
          await tx.userCategoryPreference.createMany({
            data: categories.map((categoryId) => ({
              userId: created.id,
              categoryId,
            })),
          });
        }

        return created;
      });

      await this.mail.send(
        user.email,
        'Подтверждение e-mail',
        `<p>Ваш код подтверждения: <b>${code}</b></p>`,
      );

      return { ok: true };
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException('Этот e-mail уже зарегистрирован');
      }
      throw e;
    }
  }

  async resend(email: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) throw new BadRequestException('Пользователь не найден');
    if (user.emailVerified) return { ok: true };

    // throttle: если не прошло 60 сек. с последней выдачи — стоп
    if (user.emailVerifyExpires) {
      const msLeft = user.emailVerifyExpires.getTime() - (Date.now() - (VERIFY_CODE_TTL_MS - RESEND_THROTTLE_MS));
      // эквивалентно: прошло ли хотя бы RESEND_THROTTLE_MS с момента последней отправки?
      const lastIssuedAt = new Date(user.emailVerifyExpires.getTime() - VERIFY_CODE_TTL_MS);
      if (Date.now() - lastIssuedAt.getTime() < RESEND_THROTTLE_MS) {
        throw new HttpException('Слишком часто. Попробуйте позже.', HttpStatus.TOO_MANY_REQUESTS);
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

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user || user.deletedAt != null) {
      throw new UnauthorizedException('Invalid credentials');
    }
    if (!user.passwordHash) throw new UnauthorizedException('Invalid credentials');

    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) throw new UnauthorizedException('Invalid credentials');

    // (опционально) можно не пускать, если e-mail не подтверждён
    // if (!user.emailVerified) throw new UnauthorizedException('Подтвердите e-mail');

    const payload = { sub: user.id };
    return {
      accessToken: await this.jwt.signAsync(payload),
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        emailVerified: user.emailVerified,
        mustChangePassword: user.mustChangePassword,
      },
    };
  }

  async verifyEmail(dto: VerifyEmailDto) {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user || !user.emailVerifyCode) throw new UnauthorizedException('Invalid code');
    if (!user.emailVerifyExpires || user.emailVerifyExpires.getTime() < Date.now()) {
      throw new UnauthorizedException('Код истёк, запросите новый');
    }
    if (user.emailVerifyCode !== dto.code) throw new UnauthorizedException('Неверный код');

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

  async forgotPassword(email: string) {
    const normalized = email.trim().toLowerCase();
    if (!normalized.length) {
      return { ok: true };
    }

    const user = await this.prisma.user.findUnique({ where: { email: normalized } });
    if (!user || user.deletedAt != null) {
      return { ok: true };
    }

    const tempPassword = crypto.randomBytes(4).toString('hex');
    const hash = await bcrypt.hash(tempPassword, 10);

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash: hash,
        mustChangePassword: true,
      },
    });

    await this.mail.send(
      user.email,
      'Восстановление пароля',
      `<p>Ваш временный пароль: <b>${tempPassword}</b></p><p>Войдите с ним и задайте новый пароль в настройках профиля.</p>`,
    );

    return { ok: true };
  }
}
