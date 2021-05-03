# config.py

import os
import instance.config as cfg

try:
    # Here, we obtain environment variables from a settings file
    # Useful for running inside an IDE
    from settings import get_env_variable

    SECRET_KEY = get_env_variable['SECRET_KEY']
    ADMIN_PASSWORD = get_env_variable['ADMIN_PASSWORD']
    JWT_SECRET_KEY = get_env_variable['JWT_SECRET_KEY']
    CONFIG = get_env_variable['FLASK_ENV']
except (ImportError, Exception):
    # Here, we obtain environment variables directly from computer
    # Useful for running in a terminal
    SECRET_KEY = os.getenv('SECRET_KEY')
    ADMIN_PASSWORD = os.getenv('ADMIN_PASSWORD')
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY')
    CONFIG = os.getenv('FLASK_ENV')

CONFIG = CONFIG or 'production'
UPLOAD_FOLDER = "app/static/uploads"
REDIS_URL = cfg.REDIS_URL or 'redis://'


class Config(object):
    """Common configurations"""
    # Put any configurations common across all environments
    SQLALCHEMY_DATABASE_URI = cfg.DATABASE_URL or 'sqlite:///database.db'
    SESSION_COOKIE_NAME = "session"
    DEBUG = False
    TESTING = False
    CSRF_ENABLED = True
    SERVER_NAME = cfg.SERVER_NAME
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    ADMIN_PASSWORD = ADMIN_PASSWORD or "admin-password"
    SECRET_KEY = SECRET_KEY or "my-secret-key"
    JWT_SECRET_KEY = JWT_SECRET_KEY or 'jwt-secret-string'
    # Defines the complexity of the hashing algorithm
    BCRYPT_LOG_ROUNDS = cfg.BCRYPT_LOG_ROUNDS or 13
    # Set maximum file upload size
    MAX_CONTENT_LENGTH = 20 * 1024 * 1024 * 1024
    # Define path for upload folder
    UPLOAD_FOLDER = UPLOAD_FOLDER
    # Define path for logs folder
    LOG_FOLDER = "app/logs"
    # Define path for rooms folder
    ROOMS_FOLDER = "app/rooms"
    # specify the type of cache required, 'simple' should do
    CACHE_TYPE = 'simple'
    # used for email and phone confirmation
    EMAIL_CONFIRMATION_KEY = cfg.EMAIL_CONFIRMATION_KEY
    PHONE_CONFIRMATION_KEY = cfg.PHONE_CONFIRMATION_KEY
    SECURITY_PASSWORD_SALT = cfg.SECURITY_PASSWORD_SALT
    # use for password reset
    RESET_PASSWORD_KEY = cfg.RESET_PASSWORD_KEY
    # email server details to configure Flask to send email immediately after an error, with stack trace in email body
    MAIL_SERVER = cfg.MAIL_SERVER  # if not set, then emailing errors will be disabled
    MAIL_PORT = int(cfg.MAIL_PORT or 25)  # set to standard port 25 if not set
    # Transport Layer Security(TLS) with SMTP provides confidentiality and authentication for email traffic
    MAIL_USE_TLS = cfg.MAIL_USE_TLS or 1
    # mail server credentials, optional
    MAIL_USERNAME = cfg.MAIL_USERNAME
    MAIL_PASSWORD = cfg.MAIL_PASSWORD
    # admin account details
    HEADQUARTERS = cfg.HEADQUARTERS
    ADMIN_ICON = cfg.ADMIN_ICON
    ADMIN_PHONE_NUMBER = cfg.ADMIN_PHONE_NUMBER
    # list of the email addresses that will receive error reports
    ADMINS = cfg.ADMINS
    # Firebase Cloud Messaging keys
    FIREBASE_CLIENT_SERVER_KEY = cfg.FIREBASE_CLIENT_SERVER_KEY
    FIREBASE_STYLIST_SERVER_KEY = cfg.FIREBASE_STYLIST_SERVER_KEY
    # Africa's Talking Credentials
    AFRICA_TALKING_USERNAME = cfg.AFRICA_TALKING_USERNAME
    AFRICA_TALKING_KEY = cfg.AFRICA_TALKING_KEY
    # connection URL for the Redis service
    REDIS_URL = REDIS_URL


class DevelopmentConfig(Config):
    """Development configurations"""
    DEBUG = True
    BCRYPT_LOG_ROUNDS = 4  # to save on development time, let's reduce this
    SQLALCHEMY_ECHO = False  # allows SQLAlchemy to log errors
    # allows SQLAlchemy to track changes while running
    SQLALCHEMY_TRACK_MODIFICATIONS = True


class ProductionConfig(Config):
    """Production configurations"""
    SQLALCHEMY_ECHO = False
    SQLALCHEMY_TRACK_MODIFICATIONS = False


class TestingConfig(DevelopmentConfig):
    """Testing configurations"""

    TESTING = True
    # Give a testing database
    SQLALCHEMY_DATABASE_URI = cfg.TEST_DATABASE_URL
    SQLALCHEMY_ECHO = False


app_config = {
    'development': 'DevelopmentConfig',
    'production': 'ProductionConfig',
    'testing': 'TestingConfig',
}
