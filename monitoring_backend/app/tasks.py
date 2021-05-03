# app/tasks.py

"""
This module contains functions that will be run in the background
"""

import sys
from datetime import datetime

from app import create_app
from app.models import User, OTP, BlacklistToken, PatientRelative, PatientCaregiver
from app.messaging import send_sms
from app.extras import get_config_name
from app.email import send_email

# Get a Flask application instance and application context
app = create_app(get_config_name())
app.app_context().push()


def send_account_confirmation_sms(phone_number):
    try:
        otp = User.generate_otp(phone_number)
        if otp:
            status = OTP(code=otp, user=phone_number, purpose='registration').save()
            if status:
                app.logger.exception('Unable to generate account confirmation OTP', exc_info=sys.exc_info())
            msg = f'Welcome to Monitoring System. Confirmation OTP is {otp}. Enter it & set password to confirm account'
            result = send_sms(msg, [phone_number], app, True)
            if result != 'Successful sending of SMS':
                app.logger.exception(result, exc_info=sys.exc_info())
        else:
            app.logger.exception('Unable to generate account confirmation OTP', exc_info=sys.exc_info())
    except BaseException as err:
        print(f'ERROR SENDING ACCOUNT CONFIRMATION SMS: {err}')
        app.logger.exception(f'Unhandled exception sending account confirmation SMS:\n{err}', exc_info=sys.exc_info())


def send_reset_password_sms(phone_number):
    try:
        otp = User.generate_otp(phone_number, purpose='reset_password')
        if otp:
            status = OTP(code=otp, user=phone_number, purpose='reset_password').save()
            if status:
                app.logger.exception('Unable to generate reset password OTP', exc_info=sys.exc_info())
            msg = f'Reset password request received. OTP is {otp}. Enter it & set new password to complete reset'
            result = send_sms(msg, [phone_number], app, True)
            if result != 'Successful sending of SMS':
                app.logger.exception(result, exc_info=sys.exc_info())
        else:
            app.logger.exception('Unable to generate reset password OTP', exc_info=sys.exc_info())
    except BaseException as err:
        print(f'ERROR SENDING RESET PASSWORD SMS: {err}')
        app.logger.exception(f'Unhandled exception sending reset password SMS:\n{err}', exc_info=sys.exc_info())


def send_alert_communication(patient, attachment=None):
    rs = PatientRelative.query.filter(PatientRelative.patient == patient).all()
    if rs:
        relatives = [User.query.filter(User.user_id == r.relative).first().email for r in rs]
        email = f'''
            Hi. You are registered as a role for relative. An alert has been raised with regards to him. {"Please open the attached file and t" if attachment else "T"}ake appropriate action.
    
    Regards,
    Monitoring System
            '''
        send_email(
            'MONITORING ALERT',
            sender=app.config['MAIL_USERNAME'],
            recipients=relatives,
            text_body=email,
            attachments=[attachment] if attachment else None,
            sync=True,
        )
        primary = [User.query.filter(User.user_id == u.relative).first().phoneNumber for u in
                   PatientRelative.query.filter_by(patient=patient, tag='primary').all()]
        send_sms(
            f'ALERT!! As the primary relative of {patient}, you\'re being alerted of an alarm raised with regards to him',
            phone_numbers=primary,
            flask_app=app,
            sync=True,
        )

    cs = PatientCaregiver.query.filter(PatientCaregiver.patient == patient).all()
    if cs:
        caregivers = [User.query.filter(User.user_id == c.caregiver).first().email for c in cs]
        email = f'''
                Hi. You are registered as a role for caregiver. An alert has been raised with regards to him. {"Please open the attached file and t" if attachment else "T"}ake appropriate action.

        Regards,
        Monitoring System
                '''
        secondary = [User.query.filter(User.user_id == x.caregiver).first().phoneNumber for x in
                     PatientCaregiver.query.filter_by(patient=patient, tag='primary').all()]
        send_sms(
            f'ALERT!! As the primary caregiver of {patient}, you\'re being alerted of an alarm raised with regards to him',
            phone_numbers=secondary,
            flask_app=app,
            sync=True,
        )
        send_email(
            'MONITORING ALERT',
            sender=app.config['MAIL_USERNAME'],
            recipients=caregivers,
            text_body=email,
            attachments=[attachment] if attachment else None,
            sync=True,
        )


def prune_database():
    """
    Delete tokens that have expired from the database.
    How (and if) you call this is entirely up you. You could expose it to an
    endpoint that only administrators could call, you could run it as a cron,
    set it up with flask cli, etc.
    For now, we shall run it via a scheduled task.
    This task shall run initially on server startup then daily at 3 AM East African Time.
    """
    # Get current time
    now = datetime.now()
    tokens = BlacklistToken.query.all()
    for token in tokens:
        if token.blacklisted_on < now:
            # Get the difference between now and time when token was blacklisted
            diff = now - token.blacklisted_on
            # if difference in days is more than 7 (> 1 week old tokens), delete
            if diff.days > 7:
                token.delete()
