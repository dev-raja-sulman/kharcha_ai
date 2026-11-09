import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional

from app.core.config import settings

logger = logging.getLogger("kharcha.email")


class EmailService:
    """
    Production-ready email dispatch service for KharchaAI.
    Supports secure TLS/SSL SMTP delivery to Gmail, Outlook, Yahoo, and custom providers.
    Provides responsive branded HTML templates and plain-text fallbacks.
    """

    @staticmethod
    def _mask_email(email: str) -> str:
        """Masks an email for safe, audit-compliant logging (e.g., u***r@domain.com)."""
        if "@" not in email:
            return "***"
        user_part, domain = email.split("@", 1)
        if len(user_part) <= 2:
            masked_user = f"{user_part[0]}***"
        else:
            masked_user = f"{user_part[0]}***{user_part[-1]}"
        return f"{masked_user}@{domain}"

    @classmethod
    def send_otp_email(
        cls,
        to_email: str,
        otp_code: str,
        purpose: str = "registration"
    ) -> bool:
        """
        Sends a secure 6-digit verification code to the target email address.
        """
        normalized_email = to_email.strip().lower()
        masked_email = cls._mask_email(normalized_email)

        # Subject and contextual copy
        if purpose == "password_reset":
            subject = "KharchaAI - Password Reset Verification Code"
            title = "Password Reset Request"
            lead_text = "We received a request to reset the password for your KharchaAI account. Please use the 6-digit verification code below to set a new password:"
            action_desc = "reset your password"
        else:
            subject = "KharchaAI - Verify Your Email Address"
            title = "Verify Your Email Address"
            lead_text = "Welcome to KharchaAI! Please enter the 6-digit verification code below to verify your email address and activate your AI financial assistant:"
            action_desc = "complete your registration"

        expiry_minutes = settings.OTP_EXPIRE_MINUTES

        # Plain Text Fallback
        text_body = f"""KharchaAI Security Notification

{title}

{lead_text}

VERIFICATION CODE: {otp_code}

This code will expire in {expiry_minutes} minutes.
For security reasons, never share this verification code with anyone.

If you did not request this code to {action_desc}, please ignore this email. Your account remains completely safe.

KharchaAI Team
Smart Financial Tracking & AI Wealth Management
"""

        # High-Fidelity Responsive HTML Email Template (KharchaAI Dark Emerald Theme)
        html_body = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{subject}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0b1120; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #f8fafc;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #0b1120; padding: 40px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" style="max-width: 540px; background-color: #0f172a; border-radius: 16px; border: 1px solid #1e293b; overflow: hidden; box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.5);">
          <!-- Header -->
          <tr>
            <td style="padding: 32px 32px 20px 32px; text-align: center; border-bottom: 1px solid #1e293b;">
              <div style="display: inline-block; width: 48px; height: 48px; line-height: 48px; border-radius: 12px; background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: #ffffff; font-size: 24px; font-weight: bold; text-align: center;">
                ₹
              </div>
              <h1 style="margin: 12px 0 0 0; color: #ffffff; font-size: 22px; font-weight: 700; letter-spacing: -0.5px;">
                Kharcha<span style="color: #10b981;">AI</span>
              </h1>
              <p style="margin: 4px 0 0 0; color: #64748b; font-size: 12px; text-transform: uppercase; letter-spacing: 1.5px; font-weight: 600;">
                Autonomous Wealth Engine
              </p>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding: 32px;">
              <h2 style="margin: 0 0 12px 0; color: #ffffff; font-size: 18px; font-weight: 600;">
                {title}
              </h2>
              <p style="margin: 0 0 24px 0; color: #94a3b8; font-size: 14px; line-height: 1.6;">
                {lead_text}
              </p>

              <!-- OTP Display Box -->
              <div style="background-color: #1e293b; border: 1px solid #334155; border-radius: 12px; padding: 24px 16px; text-align: center; margin: 24px 0;">
                <div style="color: #64748b; font-size: 11px; text-transform: uppercase; letter-spacing: 1.5px; margin-bottom: 8px; font-weight: 600;">
                  Security Verification Code
                </div>
                <div style="font-family: 'Courier New', Courier, monospace; font-size: 34px; font-weight: 800; letter-spacing: 10px; color: #10b981; padding-left: 10px;">
                  {otp_code}
                </div>
                <div style="color: #f59e0b; font-size: 12px; font-weight: 500; margin-top: 10px;">
                  ⏱️ Expires in {expiry_minutes} minutes
                </div>
              </div>

              <!-- Security Advisory -->
              <p style="margin: 20px 0 0 0; color: #64748b; font-size: 13px; line-height: 1.5;">
                • Never share this code with anyone. KharchaAI staff will never ask for your verification code.<br>
                • If you did not request this verification, someone may have entered your email by mistake. You can safely ignore this message.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #0a0f1d; padding: 20px 32px; border-top: 1px solid #1e293b; text-align: center;">
              <p style="margin: 0; color: #475569; font-size: 12px;">
                &copy; 2026 KharchaAI. All rights reserved. Enterprise-grade financial intelligence.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""

        # If SMTP_HOST is not configured, perform safe simulated delivery
        if not settings.SMTP_HOST:
            logger.info(
                f"[EMAIL SERVICE] Simulated email dispatch to {masked_email} "
                f"for purpose '{purpose}' (Valid for {expiry_minutes} min). SMTP_HOST not configured."
            )
            # In local dev environment, output helpful server hint without breaking
            return True

        # Build MIME Message
        message = MIMEMultipart("alternative")
        message["Subject"] = subject
        message["From"] = f"{settings.EMAILS_FROM_NAME} <{settings.EMAILS_FROM_EMAIL}>"
        message["To"] = normalized_email

        part1 = MIMEText(text_body, "plain", "utf-8")
        part2 = MIMEText(html_body, "html", "utf-8")
        message.attach(part1)
        message.attach(part2)

        # Dispatch via configured SMTP server
        try:
            if settings.SMTP_SSL:
                server = smtplib.SMTP_SSL(settings.SMTP_HOST, settings.SMTP_PORT, timeout=10)
            else:
                server = smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=10)
                if settings.SMTP_TLS:
                    server.starttls()

            if settings.SMTP_USER and settings.SMTP_PASSWORD:
                server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)

            server.send_message(message)
            server.quit()
            logger.info(f"[EMAIL SERVICE] Verification email successfully delivered to {masked_email}")
            return True
        except Exception as e:
            logger.warning(
                f"[EMAIL SERVICE] Live SMTP delivery to {masked_email} failed: {e}. "
                f"Proceeding with transaction to prevent user lockout."
            )
            return False
