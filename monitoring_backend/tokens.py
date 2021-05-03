# tokens.py

import datetime
import uuid
from functools import wraps
from time import time

import jwt
import pytz
from flask import request, make_response, jsonify
from itsdangerous import URLSafeTimedSerializer

from app import app
from app.errors import system_logging
from app.models import BlacklistToken, User, UserLogin, Role


def __token_authentication_helper(type_: str = 'auth'):
    from app.models import User
    # Get user credentials(user_id & token)
    if type_ == 'auth':
        resp = decode_view_auth_token()
    elif type_ == 'refresh':
        resp = decode_view_refresh_token()
    else:
        return 4, "Missing or invalid claim: type", 401
    # No token sent
    if not resp:
        return 2, 'Provide a valid authentication token', 401
    # There was an error validating token e.g missing user_id
    if not isinstance(resp, tuple):
        return 1, resp, 401
    # Confirm user
    user = User.query.filter_by(user_id=resp[0]).first()
    if not user:
        return 3, 'User not registered', 401
    return 0, user, 200


def patient_only_route(func):
    """This function is a decorator for endpoints that are accessible only by patients"""

    @wraps(func)
    def helper(*args, **kwargs):
        res = role_required(func)
        if type(res) == tuple:
            return res
        role = request.headers.get('Role')
        if role != 'patient':
            return make_response(jsonify({'message': 'Only patients can carry out this function', 'status': 7})), 401
        return func(*args, **kwargs)

    return helper


def caregiver_only_route(func):
    """This function is a decorator for endpoints that are accessible only by caregivers"""

    @wraps(func)
    def helper(*args, **kwargs):
        res = role_required(func)
        if type(res) == tuple:
            return res
        role = request.headers.get('Role')
        if role != 'caregiver':
            return make_response(jsonify({'message': 'Only caregivers can carry out this function', 'status': 7})), 401
        return func(*args, **kwargs)

    return helper


def relative_only_route(func):
    """This function is a decorator for endpoints that are accessible only by relatives"""

    @wraps(func)
    def helper(*args, **kwargs):
        res = role_required(func)
        if type(res) == tuple:
            return res
        role = request.headers.get('Role')
        if role != 'relative':
            return make_response(jsonify({'message': 'Only relatives can carry out this function', 'status': 7})), 401
        return func(*args, **kwargs)

    return helper


def admin_only_route(func):
    """This function is a decorator for endpoints that are accessible only to admin"""

    @wraps(func)
    def helper(*args, **kwargs):
        res = role_required(func)
        if type(res) == tuple:
            return res
        role = request.headers.get('Role')
        if role != 'admin':
            return make_response(jsonify({'message': 'This action can only be done by admins', 'status': 7})), 401
        return func(*args, **kwargs)

    return helper


def role_required(func):
    """This function is a decorator for endpoints that require user role to be provided"""

    @wraps(func)
    def helper(*args, **kwargs):
        res = login_token_required(func)
        if type(res) == tuple:
            return res
        role = request.headers.get('Role')
        if not role or type(role) != str or not Role.query.filter(Role.name == role).first():
            return make_response(jsonify({'message': 'No/invalid role provided', 'status': 6})), 401
        return func(*args, **kwargs)

    return helper


def login_token_required(func):
    """This function is a decorator for endpoints that require token authentication and logged in user"""

    @wraps(func)
    def helper(*args, **kwargs):
        status, message, response_code = __token_authentication_helper()
        if status:
            return make_response(jsonify({'status': status, 'message': message})), response_code
        user = message
        # retrieve device installation's unique identifier
        uid = request.headers.get("UniqueID")
        if not uid:
            return make_response(jsonify({'status': 3, 'message': 'Device ID not provided'})), 401
        # get login session
        login_session = UserLogin.query.filter(UserLogin.user == user.user_id, UserLogin.device_id == uid).first()
        if not login_session:
            return make_response(jsonify({'status': 4, 'message': 'Login session not found'})), 401
        # user must be logged in
        if not login_session.logged_in:
            return make_response(jsonify({'status': 5, 'message': 'User not logged in'})), 401
        return func(*args, **kwargs)

    return helper


def non_login_token_required(func):
    """This function is  decorator for endpoints that require token authentication but not necessarily logged in user"""

    @wraps(func)
    def helper(*args, **kwargs):
        status, message, response_code = __token_authentication_helper()
        if status:
            return make_response(jsonify({'status': status, 'message': message})), response_code
        return func(*args, **kwargs)

    return helper


def jwt_refresh_token_required(fn):
    """
    A decorator to protect a Flask endpoint.
    If you decorate an endpoint with this, it will ensure that the requester
    has a valid refresh token before allowing the endpoint to be called.
    """

    @wraps(fn)
    def wrapper(*args, **kwargs):
        status, message, response_code = __token_authentication_helper(type_='refresh')
        if status:
            return make_response(jsonify({'status': status, 'message': message})), response_code
        return fn(*args, **kwargs)

    return wrapper


def _encode_jwt_token(expiry: datetime, current_time: datetime, user_id, type_: str = 'auth'):
    """
    Generates the JWT tokens for authentication and refreshing
    :return:
    """
    payload = {
        # expiry time of the time if False/null, the JWT should never expire and the 'exp' claim is not set.
        'exp': expiry,
        # token issued at time of login
        'iat': current_time,
        # token not accepted before time of login
        'nbf': current_time,
        # this is subject of the token (the user whom it identifies)
        'sub': user_id,
        # JWT identifier
        'jti': str(uuid.uuid4()),
        # for CSRF in web forms
        'csrf': str(uuid.uuid4()),
        # type of token
        'type': type_
    }
    return jwt.encode(
        payload,
        app.config.get('JWT_SECRET_KEY'),
        algorithm='HS256',
    )


def encode_auth_token(user_id):
    """
    This function generates the authentication token to be used by user to request data from or add data to the system
    :param user_id: The ID of the user from User table.
    :return: Generated JWT token as string or error message
    """
    try:
        time_now = datetime.datetime.now(tz=pytz.timezone('Africa/Nairobi'))
        if app.config['TESTING']:
            # for testing, token expires 5 seconds after login
            expiry = time_now + datetime.timedelta(days=0, seconds=5)
        else:
            # token expires 15 minutes after login
            expiry = time_now + datetime.timedelta(days=0, minutes=15)
        return _encode_jwt_token(expiry=expiry, current_time=time_now, user_id=user_id, type_='auth')
    except Exception as err:
        print(err)
        system_logging(err, exception=True)
        return "Error generating token."


def encode_refresh_token(user_id):
    """
    This function generates the (utf-8) refresh token to reissue new auth token after expiration of previous token
    :param user_id: The ID of the user from User table.
    :return: Generated JWT token as string or error message
    """
    try:
        time_now = datetime.datetime.now(tz=pytz.timezone('Africa/Nairobi'))
        expiry = time_now + datetime.timedelta(days=30)
        return _encode_jwt_token(expiry=expiry, current_time=time_now, user_id=user_id, type_='refresh')
    except Exception as err:
        print(err)
        system_logging(err, exception=True)
        return "Error generating token."


def _decode_token(token, user_id, type_: str = 'auth'):
    """
    Decodes the token received
    :param token: The token to be decoded
    :param user_id: Unique name of user
    :return: integer|string
    """
    try:
        # First check if token has already been blacklisted
        is_blacklisted_token = BlacklistToken.check_blacklist(token)
        # If blacklisted, notify user to re-login
        if is_blacklisted_token:
            return "Token blacklisted. Please log in again"
        else:
            # Decode the valid token
            payload = jwt.decode(token, app.config.get('JWT_SECRET_KEY'), algorithms=["HS256"])
            # Check if token provided really belongs to the currently logged in user whose user_id has been given
            if user_id != payload['sub']:
                return 'Incorrect user'
            # Ensure that the token has correct access level eg type_ = 'refresh' for refreshing
            if type_ != payload['type']:
                return 'Incorrect access level'
            if payload['type'] not in ('refresh', 'auth'):
                raise JWTDecodeError("Missing or invalid claim: type")
            # Return user identified by token
            return payload['sub'], 0
    #  Token is used after it’s expired (time specified in the payload’s exp field has expired)
    except jwt.ExpiredSignatureError:
        return 'Signature expired. Please log in again.'
    #  Token supplied is not correct or malformed
    except jwt.InvalidTokenError:
        return 'Invalid token. Please log in again.'
    except Exception as err:
        print('DECODE ERROR {}'.format(repr(err)))
        system_logging(err, exception=True)
        return 'Error decoding token'


def decode_auth_token(auth_token, user_id):
    """
    Decodes the auth token
    :param auth_token: The token to be decoded
    :param user_id: Unique name of user
    :return: integer|string
    """
    try:
        return _decode_token(token=auth_token, user_id=user_id, type_='auth')
    except Exception as err:
        print('DECODE ERROR {}'.format(repr(err)))
        system_logging(err, exception=True)
        return 'Error decoding token'


def decode_view_auth_token():
    auth_header, auth_token = request.headers.get('Authorization'), ''
    if auth_header:
        # check if bearer token is malformed, usually when the frontend is adding token to header before requests
        try:
            auth_token = auth_header.split(" ")[1]
        except IndexError:
            return 'Bearer token malformed'
    if not auth_token:
        return None
    # Get unique user_id
    user_id = request.headers.get('UserID', None)
    if not user_id:
        return 'User Name missing'
    return decode_auth_token(auth_token, user_id)


def decode_refresh_token(auth_token, user_id):
    """
    Decodes the refresh token
    :param auth_token: The token to be decoded
    :param user_id: Unique name of user
    :return: integer|string
    """
    try:
        return _decode_token(token=auth_token, user_id=user_id, type_='refresh')
    except Exception as err:
        print('DECODE ERROR {}'.format(repr(err)))
        system_logging(err, exception=True)
        return 'Error decoding token'


def decode_view_refresh_token():
    refresh_header, refresh_token = request.headers.get('Refresh', None), ''
    if refresh_header:
        # check if bearer token is malformed, usually when the frontend is adding token to header before requests
        try:
            refresh_token = refresh_header.split(" ")[1]
        except IndexError:
            return 'Bearer token malformed'
    if not refresh_token:
        return None
    # Get unique user_id
    user_id = request.headers.get('UserID', None)
    if not user_id:
        return 'User Name missing'
    return decode_refresh_token(refresh_token, user_id)


def get_reset_password_token(user_id, expires_in=600):
    """Generate the reset password token. It shall be valid for 10 minutes (600 seconds)"""
    return jwt.encode(
        {'reset_password': user_id, 'exp': time() + expires_in},
        app.config['RESET_PASSWORD_KEY'],
        algorithm='HS256'
    )


def verify_reset_password_token(token):
    """Verify the reset password token then returns the User instance if correct or None if error"""
    try:
        user_id = jwt.decode(token, app.config['RESET_PASSWORD_KEY'], algorithms=["HS256"])['reset_password']
    except BaseException as err:
        system_logging(err, exception=True)
        return None
    return User.query.filter_by(user_id=user_id).first()


def get_confirm_account_token(user_id, expires_in=(7 * 24 * 60 * 60)):
    """Generate the user account confirmation token. It shall be valid for 7 days"""
    return jwt.encode(
        {'confirm_account': user_id, 'exp': time() + expires_in},
        app.config['ADMIN_PASSWORD'],
        algorithm='HS256'
    )


def verify_confirm_account_token(token):
    """Verify the user account confirmation token then returns the User instance if correct or None if error"""
    try:
        user_id = jwt.decode(token, app.config['ADMIN_PASSWORD'], algorithms=["HS256"])['confirm_account']
    except BaseException as err:
        system_logging(err, exception=True)
        return None
    return User.query.filter_by(user_id=user_id).first()


def generate_email_confirmation_token(email):
    """Generate email confirmation token using the email address obtained during user registration."""
    serializer = URLSafeTimedSerializer(app.config['EMAIL_CONFIRMATION_KEY'])
    return serializer.dumps(email, salt=app.config['SECURITY_PASSWORD_SALT'])


def generate_phone_confirmation_token(phone_number):
    """Generate email confirmation token using the email address obtained during user registration."""
    serializer = URLSafeTimedSerializer(app.config['PHONE_CONFIRMATION_KEY'])
    return serializer.dumps(phone_number, salt=app.config['SECURITY_PASSWORD_SALT'])


def verify_confirmation_token(token, expiration_time=86400, communication_end='email'):
    """Confirm the token to return the email. Default expiration time is 24 hours (86400 seconds)"""
    if not communication_end or type(communication_end) != str:
        communication_end = 'email'
    serializer = URLSafeTimedSerializer(app.config[f'{communication_end.upper()}_CONFIRMATION_KEY'])
    try:
        result = serializer.loads(
            token,
            salt=app.config['SECURITY_PASSWORD_SALT'],
            max_age=expiration_time
        )
    except BaseException as err:
        system_logging(err, exception=True)
        return None
    return result


class JWTDecodeError(Exception):
    """
    An error decoding a JWT
    """
    pass
