# app/home/views.py

import pytz
from datetime import datetime
from flask import request, make_response, jsonify

from . import home
from tokens import encode_auth_token, encode_refresh_token, jwt_refresh_token_required, login_token_required

from app.errors import system_logging
from app.extras import validate_phone_number
from app.models import BlacklistToken, User, UserDevice, UserLogin, OTP, Alert


@home.route('/')
def index():
    return "home"


@home.route('/login/', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        try:
            uid = request.headers.get("UniqueID")
            if not uid:
                return jsonify({'message': 'Device ID not provided', 'auth_token': None, 'refresh_token': None})

            platform, firebase_token = request.headers.get("Platform"), ''
            if platform and (platform == "android" or platform == "ios"):
                firebase_token = request.headers.get("FirebaseToken")

            data, auth_token, refresh_token = request.get_json(), None, None

            if not data:
                return jsonify({'message': "Data missing", 'auth_token': None, 'refresh_token': None})

            phone, password = data['phone_number'], data['password']

            if not phone:
                return jsonify({'message': 'Phone number not provided', 'auth_token': None, 'refresh_token': None})

            if not password:
                return jsonify({'message': 'Password not provided', 'auth_token': None, 'refresh_token': None})

            # Check format of phone number
            message, status = validate_phone_number(phone)
            if status:
                return jsonify({'message': message, 'auth_token': None, 'refresh_token': None})
            parts = [x.strip() for x in message.split('.')]
            phone_number = parts[1].split(':')[-1].strip()

            # Verify credentials
            user = User.query.filter_by(phoneNumber=phone_number).first()
            if not user:
                return jsonify({'message': 'User not registered', 'auth_token': None, 'refresh_token': None})

            # User must have confirmed account creation, else prompt user to confirm account
            if not user.is_confirmed:
                return jsonify({
                    'message': "Enter OTP code sent in SMS to confirm account",
                    'auth_token': None,
                    'refresh_token': None,
                })

            if not user.verify_password(password):
                return jsonify({'message': 'Invalid password', 'auth_token': None, 'refresh_token': None})

            # User must be active, else prompt user to activate account before logging in
            if not user.active:
                return jsonify(
                    {'message': 'Activate account before logging in', 'auth_token': None, 'refresh_token': None}
                )

            user_id = user.user_id

            # Get list of user's registered roles
            role_names = [role.name for role in user.roles]
            # Take first role, thus user can only have 1 role
            role = role_names[0]
            # Log user in and thus generate token
            if firebase_token:
                user_device = UserDevice.query.filter_by(user=user_id, platform=platform, role=role).first()
                if not user_device:
                    user_device = UserDevice(
                        user=user_id,
                        platform=platform,
                        firebase_token=firebase_token,
                        primary_device=True,
                        role=role,
                    )
                    user_device.save()
            login_session = UserLogin.query.filter_by(user=user_id, device_id=uid).first()
            if not login_session:
                # Create a user's login session for a particular device installation
                login_session = UserLogin(
                    user=user_id,
                    device_id=uid,
                    logged_in=True,
                    login_date=datetime.now(tz=pytz.timezone('Africa/Nairobi')),
                )
                status = login_session.save()
            else:
                # Update user's login session for particular device installation
                login_session.logged_in = True
                login_session.login_date = datetime.now(tz=pytz.timezone('Africa/Nairobi'))
                status = login_session.save()
            if status:
                return jsonify({'message': 'Error logging in user', 'auth_token': None, 'refresh_token': None})
            tokens = (encode_auth_token(user_id), encode_refresh_token(user_id))
            return jsonify(
                {'message': f'Success! ID {user_id}', 'auth_token': tokens[0], 'refresh_token': tokens[1], 'role': role}
            )
        except Exception as err:
            print(err)
            system_logging(err, exception=True)
            return jsonify({'message': "Error in login. Contact admin", 'auth_token': None, 'refresh_token': None}), 401


@home.route('/token/refresh/')
@jwt_refresh_token_required
def token_refresh():
    try:
        current_user = request.headers.get('UserID')
        return make_response(jsonify({'auth_token': encode_auth_token(current_user)}))
    except Exception as err:
        print(err)
        system_logging(err, exception=True)
        return make_response(jsonify({"error": "Error generating access token"})), 401


@home.route('/request_password_reset/', methods=['POST'])
def request_password_reset():
    try:
        response, code = User.request_password_reset(data=request.get_json())
        return make_response(jsonify(response)), code
    except Exception as err:
        print(err)
        system_logging(err, exception=True)
        return make_response(jsonify({"message": "Error requesting password reset"})), 401


@home.route('/raise_alert/', methods=['POST'])
def raise_alert():
    try:
        source = request.headers.get('Source', '')
        if not source:
            source = 'System'

        patient = request.headers.get('Patient', '')
        if not patient:
            system_logging('Patient not provided', exception=True)

        status = Alert(patient=patient, creator=source).save()
        if status:
            system_logging(f'Unable to raise alert raised by {source} for patient {patient}', exception=True)

        user = User.query.filter(User.user_id == patient).first()
        user.launch_task('send_alert_communication', 'Sending alert communication', patient)
        return jsonify({'message': 'done'})
    except Exception as err:
        print(err)
        system_logging(f"Error raising alert {err}", exception=True)
        return ''


@home.route('/verify_otp/', methods=['POST'])
def verify_otp():
    try:
        data = request.get_json()
        # no data sent
        if not data:
            return {'message': 'Data is missing', 'status': -2}, 401

        # get otp
        code = data.get('otp', None)
        if not code:
            return jsonify({'message': 'OTP code is missing'})

        # get phone number
        phone_number = data.get('phone_number', None)
        if not phone_number:
            return jsonify({'message': 'Phone Number is missing'})

        # get password
        password = data.get('password', None)
        if not password:
            return jsonify({'message': 'Password is missing'})

        # Check format of phone number
        message, status = validate_phone_number(phone_number)
        if status:
            return jsonify({'message': message})
        parts = [x.strip() for x in message.split('.')]
        phone_number = parts[1].split(':')[-1].strip()

        user = User.query.filter(User.phoneNumber == phone_number).first()
        if not user:
            return jsonify({'message': 'Phone number not registered'})

        if not OTP.query.filter(OTP.code == code).first():
            return jsonify({'message': 'OTP Code not recognized'})

        otp = OTP.query.filter(OTP.code == code, OTP.user == phone_number).first()
        if not otp:
            return jsonify({'message': 'OTP code not found under user'})
        if otp.is_validated:
            return jsonify({'message': 'OTP already validated'})
        otp.is_validated = True
        status = otp.save()
        if status:
            return jsonify({'message': f'Unable to complete {otp.purpose}'})

        user.is_confirmed = True
        user.set_password(password)
        status = user.save()
        if status:
            return jsonify({'message': 'Unable to set password'})
        return jsonify({'message': 'Success'})
    except Exception as err:
        print(err)
        system_logging(err, exception=True)
        return make_response(jsonify({'message': "Error verifying OTP"})), 401


@home.route('/logout/')
@login_token_required
@jwt_refresh_token_required
def logout():
    try:
        response_code = 202
        # Blacklist token
        auth_token = request.headers.get('Authorization').split(" ")[1]
        refresh_token = request.headers.get('Refresh').split(" ")[1]
        message, status = BlacklistToken.blacklist_tokens(auth_token, refresh_token)
        # Set response code for unsuccessful blacklisting
        if status:
            response_code = 401
        # log out after successful blacklisting
        else:
            # log user out
            username, uid = request.headers.get('UserID'), request.headers.get("UniqueID")
            login_session = UserLogin.query.filter(UserLogin.user == username, UserLogin.device_id == uid).first()
            login_session.logged_in = False
            status = login_session.save()
            if not status:
                message, response_code = 'Successful logging out', 200
            else:
                message, status = 'Cannot logout user', 2
        return make_response(jsonify({'status': status, 'message': message})), response_code
    except Exception as err:
        print(err)
        system_logging(err, exception=True)
        return make_response(jsonify({'message': "Error during logging out", 'status': -2})), 401
