import sys
from app.core.config import settings
from app.services.email_service import EmailService

def main():
    print("=" * 50)
    print("KharchaAI Live Email Dispatch Diagnostic")
    print("=" * 50)
    print(f"SMTP_SERVER / HOST: {settings.effective_smtp_server}")
    print(f"SMTP_PORT:          {settings.SMTP_PORT}")
    print(f"SMTP_EMAIL / USER:  {EmailService.mask_email(settings.effective_smtp_email)}")
    print(f"SMTP_APP_PASSWORD:  {'Yes (Length: ' + str(len(settings.effective_smtp_password)) + ')' if settings.effective_smtp_password else 'NO (EMPTY)'}")
    print(f"EMAILS_FROM_EMAIL:  {settings.EMAILS_FROM_EMAIL or settings.effective_smtp_email or '(defaults to SMTP_USER)'}")
    print(f"RESEND_API_KEY:     {'Yes' if settings.RESEND_API_KEY else 'NO (EMPTY)'}")
    print("=" * 50)

    recipient = sys.argv[1] if len(sys.argv) > 1 else "rajasulman106@gmail.com"
    print(f"Attempting test dispatch to: {recipient} ...")
    try:
        success = EmailService.send_otp_email(
            to_email=recipient,
            otp_code="948172",
            purpose="registration"
        )
        print(f"RESULT: SUCCESS! Email delivered. return={success}")
    except Exception as exc:
        print(f"RESULT: FAILED! {type(exc).__name__}: {exc}")

if __name__ == "__main__":
    main()
