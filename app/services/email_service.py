import email.utils
import logging
import smtplib
import uuid
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional

import httpx
from fastapi import HTTPException, status

from app.core.config import settings

logger = logging.getLogger("kharcha.email")


class EmailDeliveryError(Exception):
    """Custom exception raised when email dispatch fails."""
    pass


class EmailService:
    """
    Production-ready, multi-provider email dispatch engine for KharchaAI.
    Supports:
    1. Gmail SMTP & Standard SMTP (TLS/SSL) with RFC 5322 headers (SPF/DKIM compatible).
    2. Resend API (HTTP REST) - Ideal for cloud deployments & ISP port-blocked networks.
    3. SendGrid API (HTTP REST).
    Guarantees strict delivery confirmation: never returns false success.
    """

    @staticmethod
    def mask_email(email: str) -> str:
        """Masks an email for safe, audit-compliant logging (e.g., u***r@domain.com)."""
        if not email or "@" not in email:
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
        Sends a real 6-digit verification code to the target email address.
        Raises HTTPException if delivery fails or if no provider is configured.
        Returns True ONLY when the email provider acknowledges acceptance.
        """
        normalized_email = to_email.strip().lower()
        masked_email = cls.mask_email(normalized_email)

        # Contextual copy
        if purpose == "password_reset":
            subject = "KharchaAI - Password Reset Verification Code"
            title = "Reset Your Password"
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

KharchaAI Security Team
Smart Financial Tracking & AI Wealth Management
"""

        # High-Fidelity Responsive HTML Template (KharchaAI Dark Emerald Theme)
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

        # -------------------------------------------------------------------
        # 1. Dispatch via Resend HTTP API (if configured)
        # -------------------------------------------------------------------
        if settings.RESEND_API_KEY:
            try:
                sender_email = settings.EMAILS_FROM_EMAIL or "onboarding@resend.dev"
                resend_payload = {
                    "from": f"{settings.EMAILS_FROM_NAME} <{sender_email}>",
                    "to": [normalized_email],
                    "subject": subject,
                    "html": html_body,
                    "text": text_body,
                }
                res = httpx.post(
                    "https://api.resend.com/emails",
                    headers={
                        "Authorization": f"Bearer {settings.RESEND_API_KEY}",
                        "Content-Type": "application/json"
                    },
                    json=resend_payload,
                    timeout=12.0
                )
                if res.status_code in (200, 201):
                    data = res.json()
                    logger.info(f"[EMAIL SERVICE] Resend API delivered OTP to {masked_email} (id: {data.get('id')})")
                    return True
                else:
                    error_detail = res.text
                    logger.error(f"[EMAIL SERVICE] Resend API error ({res.status_code}): {error_detail}")
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail=f"Email delivery via Resend failed: {error_detail}"
                    )
            except httpx.RequestError as exc:
                logger.error(f"[EMAIL SERVICE] Resend network error: {exc}")
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"Email delivery network error: {exc}"
                )

        # -------------------------------------------------------------------
        # 2. Dispatch via SendGrid API (if configured)
        # -------------------------------------------------------------------
        if settings.SENDGRID_API_KEY:
            try:
                sender_email = settings.EMAILS_FROM_EMAIL or "no-reply@kharcha.ai"
                sg_payload = {
                    "personalizations": [{"to": [{"email": normalized_email}]}],
                    "from": {"email": sender_email, "name": settings.EMAILS_FROM_NAME},
                    "subject": subject,
                    "content": [
                        {"type": "text/plain", "value": text_body},
                        {"type": "text/html", "value": html_body}
                    ]
                }
                res = httpx.post(
                    "https://api.sendgrid.com/v3/mail/send",
                    headers={
                        "Authorization": f"Bearer {settings.SENDGRID_API_KEY}",
                        "Content-Type": "application/json"
                    },
                    json=sg_payload,
                    timeout=12.0
                )
                if res.status_code in (200, 202):
                    logger.info(f"[EMAIL SERVICE] SendGrid delivered OTP to {masked_email}")
                    return True
                else:
                    logger.error(f"[EMAIL SERVICE] SendGrid error ({res.status_code}): {res.text}")
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail=f"Email delivery via SendGrid failed: {res.text}"
                    )
            except httpx.RequestError as exc:
                logger.error(f"[EMAIL SERVICE] SendGrid network error: {exc}")
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"Email delivery network error: {exc}"
                )

        # -------------------------------------------------------------------
        # 3. Dispatch via SMTP (Gmail, Outlook, Yahoo, or Custom SMTP)
        # -------------------------------------------------------------------
        smtp_user = settings.effective_smtp_email
        smtp_pwd = settings.effective_smtp_password
        smtp_host = settings.effective_smtp_server
        smtp_port = settings.SMTP_PORT

        # If SMTP is NOT configured or has placeholder values, do NOT attempt or show false success
        is_placeholder = (
            "your_sending_gmail" in smtp_user.lower()
            or "your_16_character" in smtp_pwd.lower()
            or "your_app_password" in smtp_pwd.lower()
        )
        if not smtp_user or not smtp_pwd or is_placeholder:
            logger.error(
                f"[EMAIL SERVICE] Email delivery failed: SMTP credentials are not configured or still contain placeholders in .env. "
                f"Attempted to send to {masked_email}."
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=(
                    "EMAIL_NOT_CONFIGURED: Gmail SMTP credentials in .env still contain placeholder values. "
                    "Please replace SMTP_EMAIL and SMTP_APP_PASSWORD with your actual Gmail and 16-character Google App Password."
                )
            )

        # Determine sending From address
        from_address = settings.EMAILS_FROM_EMAIL.strip() if settings.EMAILS_FROM_EMAIL else smtp_user

        # Build RFC 5322 compliant message with anti-spam headers
        msg_id_domain = smtp_user.split("@")[-1] if "@" in smtp_user else "kharcha.ai"
        message = MIMEMultipart("alternative")
        message["Subject"] = subject
        message["From"] = f"{settings.EMAILS_FROM_NAME} <{from_address}>"
        message["To"] = normalized_email
        message["Reply-To"] = from_address
        message["Date"] = email.utils.formatdate(localtime=True)
        message["Message-ID"] = f"<{uuid.uuid4()}@{msg_id_domain}>"
        message["X-Mailer"] = "KharchaAI-Security-Engine/1.0"
        message["Auto-Submitted"] = "auto-generated"
        message["X-Auto-Response-Suppress"] = "All"
        message["Precedence"] = "bulk"

        part1 = MIMEText(text_body, "plain", "utf-8")
        part2 = MIMEText(html_body, "html", "utf-8")
        message.attach(part1)
        message.attach(part2)

        try:
            if settings.SMTP_SSL:
                server = smtplib.SMTP_SSL(smtp_host, settings.SMTP_PORT, timeout=15)
            else:
                server = smtplib.SMTP(smtp_host, settings.SMTP_PORT, timeout=15)
                server.ehlo()
                if settings.SMTP_TLS:
                    server.starttls()
                    server.ehlo()

            # Authenticate with SMTP server
            try:
                server.login(smtp_user, smtp_pwd)
            except (smtplib.SMTPAuthenticationError, smtplib.SMTPServerDisconnected) as auth_err:
                logger.error(f"[EMAIL SERVICE] SMTP Authentication Failed for {smtp_user}: {auth_err}")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=(
                        "EMAIL_AUTH_FAILED: Gmail SMTP authentication failed (535 Bad Credentials). "
                        "Please verify that 2-Step Verification is enabled and use a valid 16-character Google App Password in .env."
                    )
                )

            # Send mail
            server.send_message(message)
            server.quit()

            logger.info(f"[EMAIL SERVICE] Real OTP email successfully delivered to {masked_email} via SMTP ({smtp_host})")
            return True

        except smtplib.SMTPAuthenticationError as auth_err:
            logger.error(f"[EMAIL SERVICE] SMTP Authentication Failed for {smtp_user}: {auth_err}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=(
                    "EMAIL_AUTH_FAILED: Gmail SMTP authentication failed. "
                    "Please verify your 16-character App Password."
                )
            )
        except smtplib.SMTPConnectError as conn_err:
            logger.error(f"[EMAIL SERVICE] SMTP Connection Failed to {smtp_host}:{settings.SMTP_PORT}: {conn_err}")
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"EMAIL_CONNECT_FAILED: Could not connect to mail server {smtp_host}:{settings.SMTP_PORT}."
            )
        except (smtplib.SMTPException, TimeoutError, OSError) as exc:
            logger.error(f"[EMAIL SERVICE] SMTP dispatch error to {masked_email}: {exc}")
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"EMAIL_DELIVERY_FAILED: Could not deliver verification email ({str(exc)})."
            )
