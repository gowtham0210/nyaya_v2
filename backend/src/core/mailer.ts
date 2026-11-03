import { Inject, Injectable, Logger } from '@nestjs/common';
import nodemailer, { type Transporter } from 'nodemailer';
import { APP_CONFIG, type AppConfig } from './config.js';

export interface Mail {
  to: string;
  subject: string;
  text: string;
}

/**
 * Sends mail over SMTP. Without SMTP settings, development writes each mail
 * to the log (and keeps it in [outbox] for tests); production sends nothing
 * and [available] is false.
 */
@Injectable()
export class Mailer {
  private readonly logger = new Logger('Mail');
  private readonly transport?: Transporter;
  /** Mails "sent" without SMTP, newest last. Development and tests only. */
  readonly outbox: Mail[] = [];

  constructor(@Inject(APP_CONFIG) private readonly config: AppConfig) {
    const smtp = config.smtp;
    if (smtp)
      this.transport = nodemailer.createTransport({
        host: smtp.host,
        port: smtp.port,
        secure: smtp.port === 465,
        auth: smtp.user ? { user: smtp.user, pass: smtp.password } : undefined,
      });
  }

  get available() {
    return !!this.transport || !this.config.isProduction;
  }

  async send(mail: Mail): Promise<void> {
    if (this.transport) {
      await this.transport.sendMail({ from: this.config.smtp!.from, ...mail });
      return;
    }
    if (this.config.isProduction) throw new Error('SMTP is not set up');
    this.outbox.push(mail);
    this.logger.log(`To ${mail.to}: ${mail.subject}\n${mail.text}`);
  }
}
