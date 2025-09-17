export declare class MailService {
    private readonly transporter;
    send(to: string, subject: string, html: string): Promise<void>;
}
