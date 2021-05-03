# app/messaging.py

import sys
import africastalking

from app import app
from app.models import SMSMessageData, SMSRecipientsData


def send_sms(sms_message: str = '', phone_numbers: list = None, flask_app=None, sync=False):
    result = ''
    try:
        if not sms_message or type(sms_message) != str:
            result = 'SMS Message not provided'
        if not phone_numbers or type(phone_numbers) != list:
            result = 'List of phone numbers to receive SMS not provided'
        username = app.config.get('AFRICA_TALKING_USERNAME')
        api_key = app.config.get('AFRICA_TALKING_KEY')
        # Authenticate app with Africa's Talking servers
        africastalking.initialize(username, api_key)
        # Add SMS service
        sms = africastalking.SMS

        # send out SMS to array of phone numbers and receive response
        response = sms.send(sms_message, phone_numbers)
        if flask_app and not sync:
            with flask_app.app_context():
                result = save_sms_response(response)
        else:
            result = save_sms_response(response)
    except BaseException as err:
        print(err)
        app.logger.exception('Unhandled exception', exc_info=sys.exc_info())
        result = f"Unhandled exception: {err}"
    finally:
        if sync:
            return result
        else:
            print(f'Messaging result: {result}')


def save_sms_response(response: dict):
    sms_message_data = response['SMSMessageData']
    message_data = SMSMessageData.from_json(sms_message_data)
    if message_data:
        recipients = sms_message_data['Recipients']
        for recipient in recipients:
            recipient['source'] = message_data.id
            resp = SMSRecipientsData.from_json(recipient)
            if not resp:
                return 'Unable to save sms recipients response'
        return 'Successful sending of SMS'
    else:
        return 'Unable to save sms response'
