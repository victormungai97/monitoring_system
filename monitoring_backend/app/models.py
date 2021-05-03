# app/models.py

"""
This module contains tables for the database
"""

import rq
import sys
import pytz
import random
import string
from hashlib import md5
from datetime import datetime
from urllib.parse import urlparse

from flask import current_app, request
from flask_login import UserMixin
from sqlalchemy.schema import UniqueConstraint
from flask_security import SQLAlchemyUserDatastore, RoleMixin

from app import app, db, login_manager, bcrypt
from app.extras import validate_phone_number
from app.errors import system_logging


def time_now():
    """
    Here, we shall the current time in Kenya's timezone
    :return: The current datetime in Kenyan time
    """
    return datetime.now(tz=pytz.timezone('Africa/Nairobi'))


def save(field):
    """
    Method to save a field into the database
    If successful, the field is committed and success status code returned
    If unsuccessful, the field is rolled back and failure status code returned
    :param field: The record to be saved
    :return: Status code. 0 -> Success, 1 -> Failure
    """
    try:
        db.session.add(field)
        db.session.commit()
        return 0
    except Exception as err:
        print(err)
        system_logging(err, exception=True)
        db.session.rollback()
        return 1


def delete(field):
    """
    Method to delete a field from the database
    If successful, the field is committed and success status code returned
    If unsuccessful, the field is rolled back and failure status code returned
    :param field: The record to be saved
    :return: Status code. 0 -> Success, 1 -> Failure
    """
    try:
        db.session.delete(field)
        db.session.commit()
        return 0
    except Exception as err:
        print(err)
        system_logging(err, exception=True)
        db.session.rollback()
        return 1


# This table has the purpose of connecting the User and Role classes
# This is because there is a many-to-many relationship between User and Role
# as 1 user can have several roles e.g. user and admin
# and 1 role will have several users
# Hence, this table will have a foreign key pointing to each class hence fulfilling the many-to-many relationship
user_roles = db.Table(
    'user_roles',
    db.Column('id', db.Integer, primary_key=True, autoincrement=True),
    db.Column('user_id', db.Text, db.ForeignKey('users.User ID')),
    db.Column('role_id', db.Integer, db.ForeignKey('roles.id')),
)


class User(db.Model, UserMixin):
    """
    Create a User table.
    This will hold all users of the system
    """

    # Ensures table will be named in plural and not in singular
    # as is the name of the model
    __tablename__ = 'users'

    # Table fields
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    identification_number = db.Column('Identification Number', db.Text, nullable=True, index=True)
    fullname = db.Column('Full Name', db.Text, index=True, default='')
    email = db.Column('Email Address', db.Text, default='')
    phoneNumber = db.Column('Phone Number', db.String(20), unique=True, index=True, nullable=False)
    user_id = db.Column('User ID', db.Text, unique=True, index=True, nullable=False)
    residence = db.Column('Residence', db.String(300), default='Nairobi', index=True)
    password_hash = db.Column('Password', db.String(255), index=False, nullable=False, default='')
    profile_picture = db.Column('Profile Picture', db.String(500), unique=True)
    gender = db.Column('Gender', db.Text, default='Unspecified', index=True)
    identification_picture = db.Column('ID Picture', db.String(500), nullable=False, default='')
    creation_date = db.Column('Creation Date', db.DateTime, index=True, default=time_now())
    active = db.Column('Active', db.Boolean, index=True, default=True)
    suspended = db.Column('Suspended', db.Boolean, index=True, default=False)
    is_confirmed = db.Column('is_confirmed', db.Boolean, index=True, default=False)
    # create a secondary relationship between the user and roles through user_roles table
    # backref is the back reference to user from roles & will show the user info when we're looking at this role
    # lazy defines how the data will be loaded from the database;
    # in this case it will be loaded dynamically, which is ideal for managing large collections
    roles = db.relationship(
        'Role',
        secondary=user_roles,
        backref=db.backref('users', lazy='dynamic'),
    )
    # Relation between users and devices
    user_device = db.relationship(
        'UserDevice',
        primaryjoin='UserDevice.user == User.user_id',
        backref='user_device', lazy='dynamic',
    )
    # Relationship between users and otp codes
    otp = db.relationship(
        'OTP',
        primaryjoin='OTP.user == User.phoneNumber',
        backref='otp', lazy='dynamic',
    )
    # Relation between users and logins
    user_login = db.relationship(
        'UserLogin',
        primaryjoin='UserLogin.user == User.user_id',
        backref='user_login', lazy='dynamic',
    )
    # Relationship between users and tasks
    task = db.relationship(
        'Task',
        primaryjoin='Task.user_id == User.phoneNumber',
        backref='initiator', lazy='dynamic',
    )
    # Relationship between users and chat
    chat_relative = db.relationship(
        'Chat',
        primaryjoin='Chat.relative == User.user_id',
        backref='chat_relative', lazy='dynamic',
    )
    chat_patient = db.relationship(
        'Chat',
        primaryjoin='Chat.patient == User.user_id',
        backref='chat_patient', lazy='dynamic',
    )
    # Relationship between users and alerts
    alert = db.relationship(
        'Alert',
        primaryjoin='Alert.patient == User.user_id',
        backref='alert', lazy='dynamic',
    )
    # Relationship between users and request
    request_relative = db.relationship(
        'Request',
        primaryjoin='Request.caregiver == User.user_id',
        backref='request_relative', lazy='dynamic',
    )
    request_patient = db.relationship(
        'Request',
        primaryjoin='Request.patient == User.user_id',
        backref='request_patient', lazy='dynamic',
    )
    # Relationship between users and messages
    author = db.relationship(
        'Message',
        primaryjoin='Message.sender_id == User.user_id',
        backref='author', lazy='dynamic',
    )
    recipient = db.relationship(
        'Message',
        primaryjoin='Message.recipient_id == User.user_id',
        backref='recipient', lazy='dynamic',
    )
    # Map patients and relatives
    patient_relative1 = db.relationship(
        'PatientRelative',
        primaryjoin='PatientRelative.relative == User.user_id',
        backref='patient_relative1', lazy='dynamic',
    )
    patient_relative2 = db.relationship(
        'PatientRelative',
        primaryjoin='PatientRelative.patient == User.user_id',
        backref='patient_relative2', lazy='dynamic',
    )
    # Map patients and relatives
    patient_caregiver1 = db.relationship(
        'PatientCaregiver',
        primaryjoin='PatientCaregiver.caregiver == User.user_id',
        backref='patient_caregiver1', lazy='dynamic',
    )
    patient_caregiver2 = db.relationship(
        'PatientCaregiver',
        primaryjoin='PatientCaregiver.patient == User.user_id',
        backref='patient_caregiver2', lazy='dynamic',
    )

    @classmethod
    def generate_user_id(cls, role):
        role = role.lower()
        users = cls.query.filter(cls.user_id.like(f"%{role[:2]}%")).all()
        if not users:
            return f'{role[:2]}-0'
        uid = int(users[-1].user_id.split('-')[-1])
        return f'{role[:2]}-{uid + 1}'

    @staticmethod
    def generate_otp(phone_number, purpose='registration'):
        # Get random choices from ascii_letters and digits
        code = ''.join([random.choice(string.ascii_letters + string.digits) for _ in range(6)])
        # check if code is attached to user for stated purpose and has not been validated (is in use)
        otp = OTP.query.filter_by(code=code, purpose=purpose, user=phone_number).first()
        # if in use, generate recursively until we get a free code
        if otp:
            code = User.generate_otp(phone_number, purpose)
        return code

    @classmethod
    def request_password_reset(cls, data: dict = None):
        try:
            # no data sent
            if not data:
                return {'message': 'Data is missing', 'status': -2}, 401

            # get phone number
            phone_number = data.get('phone_number', None)
            if not phone_number:
                return {'message': 'Phone Number is missing', 'status': 1}, 202

            # Check format of phone number
            message, status = validate_phone_number(phone_number)
            if status:
                return {'message': message, 'status': 7}, 202
            parts = [x.strip() for x in message.split('.')]
            phone_number = parts[1].split(':')[-1].strip()

            user = cls.query.filter(cls.phoneNumber == phone_number).first()
            if user:
                # Log user out of all devices
                login_sessions = UserLogin.query.filter(UserLogin.user == user.user_id).all()
                if login_sessions:
                    for session in login_sessions:
                        session.logged_in = False
                        session.save()
                # Send SMS if user's status is okay
                if not app.testing and user.active and not user.suspended:
                    user.launch_task('send_reset_password_sms', 'Sending reset password OTP SMS', phone_number)
            return {'message': "Check your SMS for instructions to reset your password", "status": 0}, 200
        except Exception as err:
            print(err)
            system_logging(msg=err, exception=True)
            return {'message': 'Something went wrong. Please contact the administrator', 'status': -1}, 401

    @staticmethod
    def retrieve_users(users):
        _users = []
        base_url = f'{urlparse(request.url).scheme}://{urlparse(request.url).netloc}/'
        for user in users:
            if not user.profile_picture:
                digest = md5(user.user_id.lower().encode('utf-8')).hexdigest()
                profile_picture = f'https://www.gravatar.com/avatar/{digest}?d=identicon&s={500}'
            else:
                profile_picture = f'{base_url}{user.profile_picture}'
            if not user.identification_picture:
                identification_picture = ''
            else:
                identification_picture = f'{base_url}{user.identification_picture}'
            _users.append(
                {
                    'id': user.id,
                    'user_id': user.user_id,
                    'fullname': user.fullname,
                    'phone_number': user.phoneNumber,
                    'id_number': user.identification_number,
                    'id_picture': identification_picture,
                    'profile_picture': profile_picture,
                    'residence': user.residence,
                    'gender': user.gender,
                    'created_at': user.creation_date.strftime("%A %b %d, %Y %I:%M %p"),
                    'active': user.active,
                    'suspended': user.suspended,
                    'is_confirmed': user.is_confirmed,
                }
            )
        return _users

    def save(self):
        return save(self)

    def delete(self):
        return delete(self)

    @property
    def password(self):
        """
        Prevent password from being accessed
        """
        raise AttributeError('password is not a readable attribute.')

    @password.setter
    def password(self, password):
        """
        Set password to a hashed password
        """
        self.password_hash = bcrypt.generate_password_hash(password).decode('utf-8')

    def set_password(self, password):
        self.password_hash = bcrypt.generate_password_hash(password).decode('utf-8')

    def verify_password(self, password):
        """
        Check if hashed password matches actual password
        """
        return bcrypt.check_password_hash(self.password_hash, password)

    def add_notification(self, name, data):
        try:
            user = self.username
            progress = data['progress']
            print('Process: {} by {}. Progress: {}'.format(name, user, progress))
        except Exception as err:
            print(err)

    def launch_task(self, name, description, *args, **kwargs):
        """
        Submit task to RQ queue and add it to the database
        :param name: Task/function name as defined in app/tasks.py
        :param description: Friendly description of the task that can be presented to users
        :param args: Positional arguments to be passed to the task
        :param kwargs: Keyword arguments that will be passed to the task
        :return: The task itself
        """
        try:
            # Submit the job and add it to the queue
            rq_job = current_app.task_queue.enqueue('app.tasks.' + name, *args, **kwargs)
            # Create a corresponding Task object in database based on RQ-assigned task ID
            task = Task(id=rq_job.get_id(), name=name, description=description, user_id=self.phoneNumber)
            # Add the new task object to the session, but it does not issue a commit
            task.save()
            return task
        except BaseException as err:
            print(err)
            return None

    def get_tasks_in_progress(self):
        """Return the complete list of functions that are outstanding for the user"""
        tasks = Task.query.filter_by(user_id=self.phoneNumber, complete=False).all()
        if not tasks:
            return None
        return Task.retrieve_tasks(tasks)

    def get_task_in_progress(self, name):
        """
        Return a user's specific outstanding task.
        Prevent user from starting two or more tasks of the same type concurrently,
        Therefore, check if a previous task is currently running before launching a task
        """
        task = Task.query.filter_by(name=name, user_id=self.phoneNumber, complete=False).first()
        if not task:
            return None
        return Task.retrieve_tasks([task])[0]

    def __repr__(self):
        return '<User: {}>'.format(self.user_id)


# Set up user_loader
@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))


class Role(db.Model, RoleMixin):
    """
    Create a Role table
    """

    __tablename__ = 'roles'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column('Name', db.String(60), unique=True, index=True, nullable=False)
    description = db.Column('Description', db.String(255), default='')
    # Relation between users and logins
    device = db.relationship(
        'UserDevice',
        primaryjoin='UserDevice.role == Role.name',
        backref='device', lazy='dynamic',
    )

    def __repr__(self):
        return '<Role: {}>'.format(self.name)

    def __hash__(self):
        return hash(self.name)


class UserDevice(db.Model):
    """
    Create a User Device table
    It will hold the devices that a user uses to log in
    """

    __tablename__ = 'user_devices'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user = db.Column('User', db.Text, db.ForeignKey('users.User ID', ondelete='CASCADE', onupdate='CASCADE'), )
    platform = db.Column('Platform', db.String(60), nullable=False, default='')
    role = db.Column('Role', db.String(60), db.ForeignKey('roles.Name', ondelete='CASCADE', onupdate='CASCADE'), )
    firebase_token = db.Column('Firebase Token', db.Text, nullable=False, default='')
    primary_device = db.Column(db.Boolean, default=False, index=True)
    creation_date = db.Column('Creation Date', db.DateTime, index=True, default=time_now())

    def save(self):
        return save(self)

    def delete(self):
        return delete(self)

    def __repr__(self):
        return '<User Device: {}>'.format(self.firebase_token)


class UserLogin(db.Model):
    """
    Create a User Login table
    Will hold the user's login session
    """

    __tablename__ = 'user_logins'

    id = db.Column('ID', db.Integer, primary_key=True, autoincrement=True)
    user = db.Column(
        'User',
        db.Text,
        db.ForeignKey('users.User ID', ondelete='CASCADE', onupdate='CASCADE'),
        nullable=False,
    )
    device_id = db.Column('Device ID', db.Text, nullable=False, default='')
    logged_in = db.Column(db.Boolean, default=False, index=True)
    login_date = db.Column('Login Date', db.DateTime, index=True, default=time_now())

    __table_args__ = (UniqueConstraint(user, device_id), {})

    @staticmethod
    def retrieve_login_sessions(login_sessions):
        _login_sessions = []
        for login_session in login_sessions:
            _login_sessions.append(
                {
                    'ID': login_session.id,
                    'user': login_session.user,
                    'device_id': login_session.device_id,
                    'logged_in': login_session.logged_in,
                    'login_date': login_session.login_date,
                }
            )
        return _login_sessions

    def save(self):
        return save(self)

    def delete(self):
        return delete(self)

    def __repr__(self):
        return '<Login Session: {}>'.format(self.id)


class PatientRelative(db.Model):
    """
    Create a PatientRelative table
    This will map all patients to at least one relative
    """
    __tablename__ = 'patient_relatives'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    relative = db.Column(db.Text, db.ForeignKey('users.User ID', ondelete='CASCADE', onupdate='CASCADE'), )
    patient = db.Column(db.Text, db.ForeignKey('users.User ID', ondelete='CASCADE', onupdate='CASCADE'), )
    tag = db.Column(db.Text, default='')
    creation_date = db.Column('created_at', db.DateTime, default=time_now())

    @staticmethod
    def retrieve_patient_relatives(patient_relatives):
        _patient_relatives = []
        for patient_relative in patient_relatives:
            _patient_relatives.append(
                {
                    'id': patient_relative.id,
                    'patient': User.retrieve_users(User.query.filter_by(user_id=patient_relative.patient).all())[0],
                    'relative': User.retrieve_users(User.query.filter_by(user_id=patient_relative.relative).all())[0],
                    'created_at': patient_relative.creation_date.strftime("%A %b %d, %Y %I:%M %p"),
                }
            )
        return _patient_relatives

    def save(self):
        return save(self)

    def delete(self):
        return delete(self)

    def __repr__(self):
        return f'Patient: {self.patient}. Relative: {self.relative}'


class PatientCaregiver(db.Model):
    """
    Create a PatientCaregiver table
    This will map all patients to at least one caregiver
    """
    __tablename__ = 'patient_caregivers'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    caregiver = db.Column(db.Text, db.ForeignKey('users.User ID', ondelete='CASCADE', onupdate='CASCADE'), )
    patient = db.Column(db.Text, db.ForeignKey('users.User ID', ondelete='CASCADE', onupdate='CASCADE'), )
    tag = db.Column(db.Text, default='')
    creation_date = db.Column('created_at', db.DateTime, default=time_now())

    @staticmethod
    def retrieve_patient_relatives(patient_caregivers):
        _patient_caregivers = []
        for patient_caregiver in patient_caregivers:
            _patient_caregivers.append(
                {
                    'id': patient_caregiver.id,
                    'patient': User.retrieve_users(User.query.filter_by(user_id=patient_caregiver.patient).all())[0],
                    'caregiver': User.retrieve_users(User.query.filter_by(user_id=patient_caregiver.relative).all())[0],
                    'created_at': patient_caregiver.creation_date.strftime("%A %b %d, %Y %I:%M %p"),
                }
            )
        return _patient_caregivers

    def save(self):
        return save(self)

    def delete(self):
        return delete(self)

    def __repr__(self):
        return f'Patient: {self.patient}. Relative: {self.relative}'


class Alert(db.Model):
    """
    Create an Alert table to store all alerts
    """
    __tablename__ = 'alerts'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    patient = db.Column(db.Text, db.ForeignKey('users.User ID', ondelete='CASCADE', onupdate='CASCADE'), )
    creation_date = db.Column('Creation Date', db.DateTime, index=True, default=time_now(), )
    creator = db.Column('Creator', db.Text, default='System', index=True)

    @staticmethod
    def retrieve_alerts(alerts):
        _alerts = []
        for alert in alerts:
            _alerts.append(
                {
                    'patient': User.retrieve_users(User.query.filter(User.user_id == alert.patient).all())[0],
                    'initiator': alert.creator,
                    'id': alert.id,
                    'creation_date': alert.creation_date.strftime("%A %b %d, %Y %I:%M %p"),
                }
            )
        return _alerts

    def save(self):
        return save(self)

    def delete(self):
        return delete(self)

    def __repr__(self):
        return '<Alert {}>'.format(self.id)


class Request(db.Model):
    """
    Create an Alert table to store all alerts
    """
    __tablename__ = 'requests'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    caregiver = db.Column(db.Text, db.ForeignKey('users.User ID', ondelete='CASCADE', onupdate='CASCADE'), )
    patient = db.Column(db.Text, db.ForeignKey('users.User ID', ondelete='CASCADE', onupdate='CASCADE'), )
    creation_date = db.Column('Creation Date', db.DateTime, index=True, default=time_now(), )

    @staticmethod
    def retrieve_requests(requests):
        _requests = []
        for req in requests:
            _requests.append(
                {
                    'patient': User.retrieve_users(User.query.filter(User.user_id == req.patient).all())[0],
                    'caregiver': User.retrieve_users(User.query.filter(User.user_id == req.caregiver).all())[0],
                    'id': req.id,
                    'creation_date': req.creation_date.strftime("%A %b %d, %Y %I:%M %p"),
                }
            )
        return _requests

    def save(self):
        return save(self)

    def delete(self):
        return delete(self)

    def __repr__(self):
        return '<Request {}>'.format(self.id)


class Chat(db.Model):
    """
    Create a Chat table
    This will hold all the chat rooms for conversations between a stylist and client
    How chat rooms work is that, if it did not exist, a room is created with the booking's stylist & client
    If did exist, the existing chat room shall be enabled and the two parties allowed to communicate.
    Chat room communication can only be carried out when there is an active pending booking.
    Hence on cancellation and completion of a booking, a chat shall be disabled
    """

    __tablename__ = 'chats'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    chat_id = db.Column('Chat ID', db.Integer, index=True, nullable=False, unique=True)
    relative = db.Column(db.Text, db.ForeignKey('users.User ID', ondelete='CASCADE', onupdate='CASCADE'), )
    patient = db.Column(db.Text, db.ForeignKey('users.User ID', ondelete='CASCADE', onupdate='CASCADE'), )
    disabled = db.Column(db.Boolean, index=True, default=False)
    creation_date = db.Column('Creation Date', db.DateTime, index=True, default=time_now(), )
    # Relationship between chats and messages
    message = db.relationship(
        'Message',
        primaryjoin='Message.chat_id == Chat.chat_id',
        backref='message', lazy='dynamic',
    )

    @staticmethod
    def retrieve_chats(chats):
        _chats = []
        for chat in chats:
            messages = list(reversed(Message.query.filter(Message.chat_id == chat.chat_id).all()))
            _chats.append({
                'id': chat.chat_id,
                'relative': User.retrieve_users(User.query.filter(User.user_id == chat.relative).all())[0],
                'patient': User.retrieve_users(User.query.filter(User.user_id == chat.patient).all())[0],
                'disabled': chat.disabled,
                'messages': Message.retrieve_messages(messages),
            })
        return _chats

    def save(self):
        return save(self)

    def delete(self):
        return delete(self)

    def __repr__(self):
        return '<Chat {}>'.format(self.chat_id)


class Message(db.Model):
    """
    Create a Message table
    This will hold the communication(messages) between a client and stylist
    It should be used when the appointment datetime is due
    and the stylist/client need to locate each other or something like that.
    """

    __tablename__ = 'messages'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    sender_id = db.Column(db.Text, db.ForeignKey('users.User ID', ondelete='CASCADE', onupdate='CASCADE'))
    recipient_id = db.Column(db.Text, db.ForeignKey('users.User ID', ondelete='CASCADE', onupdate='CASCADE'), )
    chat_id = db.Column(db.Integer, db.ForeignKey('chats.Chat ID', ondelete='CASCADE', onupdate='CASCADE'), )
    body = db.Column(db.Text)
    starred = db.Column(db.Boolean, default=False, index=True)
    unread = db.Column(db.Boolean, default=True, index=True)
    timestamp = db.Column(db.DateTime, index=True, default=time_now(), )
    # message type: 0 -> text, 1 -> image, 2 -> video, 3 -> sticker
    type = db.Column(db.Integer, default=0, index=True)

    @staticmethod
    def retrieve_messages(messages):
        _messages = []
        base_url = f'{urlparse(request.url).scheme}://{urlparse(request.url).netloc}/'
        for message in messages:
            if message.type == 1 or message.type == 2:
                content = f'{base_url}{message.body}'
            else:
                content = message.body

            _messages.append({
                'id': message.id,
                'sender': User.retrieve_users(User.query.filter(User.user_id == message.sender_id).all())[0],
                'recipient': User.retrieve_users(User.query.filter(User.user_id == message.recipient_id).all())[0],
                'timestamp': message.timestamp.strftime("%A %b %d, %Y %I:%M %p"),
                'starred': message.starred,
                'unread': message.unread,
                'content': content,
                'type': message.type,
            })
        return _messages

    def save(self):
        return save(self)

    def delete(self):
        return delete(self)

    def __repr__(self):
        return '<Message {}>'.format(self.body)


class Task(db.Model):
    """
    Create a Task table
    It will be a database representation of a background task that runs after completion of a request
    """
    __tablename__ = 'tasks'

    # Primary key will be the job identifiers generated by RQ.
    id = db.Column(db.String(36), primary_key=True)
    name = db.Column(db.String(128), index=True)
    description = db.Column(db.String(128))
    user_id = db.Column(db.String(20), db.ForeignKey('users.Phone Number', ondelete='CASCADE', onupdate='CASCADE'), )
    # Flag to separate tasks that ended from those that are actively running
    complete = db.Column(db.Boolean, default=False)
    creation_date = db.Column('Creation Date', db.DateTime, index=True, default=time_now())

    def get_rq_job(self):
        """
        Helper method that loads the RQ Job instance, from a given task id,
        :return: The RQ Job instance or None in case of error
        """
        try:
            # Loads the Job instance from the data that exists in Redis about it
            rq_job = rq.job.Job.fetch(self.id, connection=current_app.redis)
        except BaseException as err:
            print(err)
            current_app.logger.exception(err, exc_info=sys.exc_info())
            return None
        return rq_job

    def get_progress(self):
        """
        Builds on top of get_rq_job().
        Assumptions:
            1. If the job id from the model does not exist in the RQ queue, that means that the job already finished and
                the data expired and was removed from the queue, so in that case the percentage returned is 100
            2. If the job exists, but there is no information associated with the meta attribute, then it is safe to
                assume that the job is scheduled to run, but did not get a chance to start yet,
                so in that situation, 0 is returned as progress
        :return: Progress percentage for the task
        """
        job = self.get_rq_job()
        return job.meta.get('progress', 0) if job is not None else 100

    @staticmethod
    def retrieve_tasks(tasks: list):
        _tasks = []
        for task in tasks:
            _tasks.append(
                {
                    'id': task.id,
                    'name': task.name,
                    'description': task.description,
                    'user': User.retrieve_users(User.query.filter(User.phoneNumber == task.user_id).all()),
                    'complete': task.complete,
                }
            )
        return _tasks

    def save(self):
        return save(self)

    def delete(self):
        return delete(self)

    def __repr__(self):
        return '<Task: {}>'.format(self.id)


class ScheduledTask(db.Model):
    """
    Create a Scheduled Task table
    All processes that are planned to be executed at a specified or periodically shall be stored here
    Interval shall be saved in seconds
    """
    __tablename__ = 'scheduled_tasks'

    id = db.Column(db.String(36), primary_key=True, nullable=False)
    name = db.Column(db.String(128), index=True)
    start = db.Column(db.DateTime, nullable=False, default=time_now())
    interval = db.Column(db.Integer, default=0)
    description = db.Column(db.Text)
    cancelled = db.Column(db.Boolean, default=False)

    @staticmethod
    def get_scheduled_task(task_id):
        try:
            # Loads the Job instance from the data that exists in Redis about it
            rq_job = rq.job.Job.fetch(task_id, connection=current_app.redis)
        except BaseException as err:
            print(err)
            current_app.logger.exception(err, exc_info=sys.exc_info())
            return None
        return rq_job

    def cancel_scheduled_task(self, job):
        """
        Given a job, check if it is in scheduler and cancel it if true
        :param job: RQ Job or Job ID
        :return: None
        """
        try:
            status = 0
            scheduler = current_app.scheduler
            if job and (type(job) == rq.job or type(job) == str) and job in scheduler:
                scheduler.cancel(job)
                self.cancelled = True
                status = self.save()
            return status
        except BaseException as err:
            print(err)
            current_app.logger.exception(err, exc_info=sys.exc_info())
            return 'Unable to cancel scheduled task'

    @staticmethod
    def retrieve_scheduled_tasks(tasks: list):
        _tasks = []
        for task in tasks:
            _tasks.append(
                {
                    'id': task.id,
                    'name': task.name,
                    'description': task.description,
                    'cancelled': task.cancelled,
                    'beginning': task.start.strftime("%A %b %d, %Y %I:%M %p"),
                    'interval': task.interval,
                }
            )
        return _tasks

    def save(self):
        return save(self)

    def delete(self):
        return delete(self)

    def __repr__(self):
        return '<Scheduled task: {}>'.format(self.id)


class OTP(db.Model):
    """
    Create OTP table
    We shall store all one time password used for confirming user accounts and password resets here
    """
    __tablename__ = 'otps'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    code = db.Column(db.String(500), nullable=False)
    user = db.Column(db.String(20), db.ForeignKey('users.Phone Number', ondelete='CASCADE', onupdate='CASCADE'), )
    is_validated = db.Column(db.Boolean, default=False)
    purpose = db.Column(db.Text, default='registration')
    generation_date = db.Column(db.DateTime, nullable=False, default=time_now())

    def save(self):
        return save(self)

    def delete(self):
        return delete(self)

    def __repr__(self):
        return '<One Time Password: {}>'.format(self.code)


class SMSMessageData(db.Model):
    """
    Create an SMS Message data table
    We shall record the response given to us from Africa's Talking after sending an SMS
    """

    __tablename__ = 'sms_responses'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    description = db.Column('Description', db.Text, nullable=False, default='')
    # Relationship between sms message data and recipients
    recipient = db.relationship(
        'SMSRecipientsData',
        primaryjoin='SMSRecipientsData.source == SMSMessageData.id',
        backref='recipients', lazy='dynamic',
    )

    @staticmethod
    def from_json(json: dict):
        if not json or type(json) != dict:
            return None
        sms = SMSMessageData(description=json.get('Message', ''))
        status = sms.save()
        if not status:
            return sms
        else:
            return None

    @staticmethod
    def retrieve_sms_responses(responses):
        _responses = []
        for response in responses:
            _responses.append(
                {
                    'ID': response.id,
                    'description': response.description,
                    'recipients': SMSRecipientsData.retrieve_recipients(
                        SMSRecipientsData.query.filter_by(source=response.recipient).all()
                    ),
                }
            )
        return _responses

    def save(self):
        return save(self)

    def delete(self):
        return delete(self)

    def __repr__(self):
        return '<SMSMessageData: {}>'.format(self.id)


class SMSRecipientsData(db.Model):
    __tablename__ = 'sms_recipients'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    cost = db.Column('Cost', db.Text, nullable=False, default='')
    statusCode = db.Column('Status Code', db.Integer, default=0)
    number = db.Column('Number', db.Text, nullable=False, default='')
    messageId = db.Column('Message ID', db.Text, unique=True, nullable=False)
    messageParts = db.Column('Message Parts', db.Integer, default=0)
    status = db.Column('Status', db.Text, nullable=False, default='')
    source = db.Column(db.Integer, db.ForeignKey('sms_responses.id', ondelete='CASCADE', onupdate='CASCADE'), )
    creation_date = db.Column('Creation Date', db.DateTime, index=True, default=time_now(), )

    @staticmethod
    def from_json(json: dict):
        if not json or type(json) != dict:
            return None
        recipient = SMSRecipientsData(
            cost=json.get('cost', 'KES 0'),
            messageId=json.get('messageId', ''),
            messageParts=json.get('messageParts', 0),
            number=json.get('number', ''),
            status=json.get('status', 'Success'),
            statusCode=json.get('statusCode', 0),
            source=json.get('source', 0),
        )
        status = recipient.save()
        if not status:
            return recipient
        else:
            return None

    @staticmethod
    def retrieve_recipients(recipients):
        _recipients = []
        for recipient in recipients:
            _recipients.append(
                {
                    'ID': recipient.id,
                    'cost': recipient.cost,
                    'statusCode': recipient.statusCode,
                    'number': recipient.number,
                    'messageId': recipient.messageId,
                    'messageParts': recipient.messageParts,
                    'status': recipient.status,
                    'creation_date': recipient.creation_date.strftime("%A %b %d, %Y %I:%M %p"),
                }
            )
        return _recipients

    def save(self):
        return save(self)

    def delete(self):
        return delete(self)

    def __repr__(self):
        return '<Recipient: {}>'.format(self.id)


class BlacklistToken(db.Model):
    """
    Create a BlacklistToken table
    This will store JWT tokens after they have been rendered invalid i.e 'blacklisted'
    """
    __tablename__ = 'blacklist_tokens'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    token = db.Column(db.String(500), unique=True, nullable=False)
    blacklisted_on = db.Column(db.DateTime, nullable=False, default=time_now())

    def __init__(self, token):
        self.token = token
        self.blacklisted_on = time_now()

    @classmethod
    def blacklist_tokens(cls, auth_token: str = '', refresh_token: str = ''):
        # mark the auth token as blacklisted
        if not auth_token:
            return 'Please provide authentication token for blacklisting', -1
        blacklist_token = cls(token=auth_token)
        status = blacklist_token.save()
        if status:
            return 'Error blacklisting authentication token', -2
        # mark the refresh token as blacklisted
        if not refresh_token:
            return 'Please provide refresh token for blacklisting', -3
        blacklist_token = cls(token=refresh_token)
        status = blacklist_token.save()
        if status:
            return 'Error blacklisting refresh token', -4
        return '', 0

    @classmethod
    def check_blacklist(cls, auth_token):
        # check whether auth token has been blacklisted
        res = cls.query.filter_by(token=str(auth_token)).first()
        if res:
            return True
        else:
            return False

    def save(self):
        return save(self)

    def delete(self):
        return delete(self)

    def __repr__(self):
        return '<Blacklisted Token: {}>'.format(self.token)


user_datastore = SQLAlchemyUserDatastore(db, User, Role)  # This variable connects Flask Security to Flask-SQLAlchemy
