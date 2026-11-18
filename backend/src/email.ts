export interface EmailSender {
  send(to: string, subject: string, body: string): Promise<void>;
}

export interface SentEmail {
  to: string;
  subject: string;
  body: string;
}

/** Masque une adresse pour les journaux : `karim@x.com` -> `k***@x.com`. */
export function maskEmail(email: string): string {
  const at = email.lastIndexOf('@');
  if (at < 1) return '***';
  return `${email[0]}***${email.slice(at)}`;
}

/**
 * Expéditeur de dev/test : garde le dernier message en mémoire, n'écrit jamais
 * le contenu (jeton) ni l'adresse en clair dans les journaux.
 */
export class LogEmailSender implements EmailSender {
  last: SentEmail | undefined;

  async send(to: string, subject: string, body: string): Promise<void> {
    this.last = { to, subject, body };
    console.log(`[email] message pour ${maskEmail(to)}`);
  }
}
