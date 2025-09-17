import { Injectable } from '@nestjs/common';
import * as nodemailer from 'nodemailer';

@Injectable()
export class MailService {
  private readonly transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST!,
    port: Number(process.env.SMTP_PORT || 587),
    secure: false,                 // для MailHog всегда false
    auth: undefined, 
    // auth: { user: process.env.SMTP_USER!, pass: process.env.SMTP_PASS! },
  });

  async send(to: string, subject: string, html: string) {
    if (process.env.MAIL_DISABLED === '1') {
      console.warn('[MAIL_DISABLED] would send:', { to, subject });
      return;
    }
    const from = process.env.MAIL_FROM || 'no-reply@example.com';
    await this.transporter.sendMail({ from, to, subject, html });
  }
}

