# app/__init__.py

import rq
import cv2
from redis import Redis
from flask import Flask, current_app, redirect, url_for, render_template, Response
from rq_scheduler import Scheduler
from datetime import datetime

from config import app_config
from extensions import *

# initialize app
app = Flask(__name__, instance_relative_config=True)


def create_app(config_name):
    """
    This is the method that initializes modules used in the app
    :param config_name: The key for the configuration to use
    :return: Flask app
    """
    global app
    if config_name not in app_config.keys():
        config_name = 'development'
    app.config.from_object(".".join(["config", app_config[config_name]]))

    db.init_app(app)
    cors.init_app(app)
    mail.init_app(app)
    bcrypt.init_app(app)
    login_manager.init_app(app)
    migrate.init_app(app, db)
    bootstrap.init_app(app)

    login_manager.login_message = "You must be logged in to access this page."

    from app import models, errors, views

    security.init_app(app, datastore=models.user_datastore)

    # enable logging
    errors.system_logging('Monitoring - A web based home monitoring system for assisted living')

    # these are blueprints, they help to organize the projects into smaller logical components based on eg user roles
    from .home import home as home_blueprint
    from .admin import admin as admin_blueprint
    from .patient import patient as patient_blueprint
    from .relative import relative as relative_blueprint
    from .caregiver import caregiver as medical_blueprint

    app.register_blueprint(home_blueprint, url_prefix='/home')
    app.register_blueprint(medical_blueprint, url_prefix='/caregiver')
    app.register_blueprint(admin_blueprint, url_prefix='/admin')
    app.register_blueprint(patient_blueprint, url_prefix='/patient')
    app.register_blueprint(relative_blueprint, url_prefix='/relative')

    # Initialize Redis and RQ
    app.redis = Redis.from_url(app.config['REDIS_URL'])
    # The queue where tasks are submitted
    queue_name = 'monitoring_tasks'
    app.task_queue = rq.Queue(queue_name, connection=app.redis)

    # Instantiate Scheduler for schedule queue
    schedule_name = "monitoring_scheduler"
    app.scheduler = Scheduler(queue_name=schedule_name, connection=app.redis)

    return app


# Executes before the first request is processed.
@app.before_first_request
def init_db():
    """
    Method creates and initializes the models used
    :return: None
    """
    from app import models, errors
    from .models import user_datastore
    from datetime import datetime

    try:
        # Create any database tables that don't exist yet.
        db.create_all()

        # Create the Roles "admin", "client" and "stylist" -- unless they already exist
        user_datastore.find_or_create_role(name='admin', description='Administrator')
        user_datastore.find_or_create_role(name='patient', description='Patient')
        user_datastore.find_or_create_role(name='caregiver', description='Caregiver')
        user_datastore.find_or_create_role(name='relative', description='Relative')

        # Add admin user
        if not models.User.query.filter_by(user_id='ad-0').first():
            user_datastore.create_user(
                user_id='ad-0', fullname='Monitoring System', phoneNumber=app.config['ADMIN_PHONE_NUMBER'],
                profile_picture=app.config['ADMIN_ICON'], identification_number='0', roles=['admin'],
                identification_picture='', residence=app.config['HEADQUARTERS'], is_confirmed=True,
                password=app.config['ADMIN_PASSWORD'],
            )

        try:
            # Commit any database changes; the User and Roles must exist before we can add a Role to the User
            db.session.commit()
        except Exception as err:
            errors.system_logging(err, exception=True)
            print(err)
            db.session.rollback()

        # Provide function to be queued as import string to overcome inconvenience of import it on the application side
        func_import_string = 'app.tasks.prune_database'
        # On server startup, schedule that expired blacklisted token are removed
        current_app.scheduler.enqueue_at(datetime.utcnow(), func_import_string)
        # Then run cleaning every day
        pruning_task = models.ScheduledTask.query.filter_by(name='prune_database', cancelled=False).first()
        if not pruning_task:
            job_id = current_app.scheduler.cron(
                "0 0 * * *",  # Cron string setting function to run daily at 12:00 AM (UTC) / 3:00 AM (EAT)
                func=func_import_string,  # Function to be queued
                repeat=None,  # Repeat this number of times (None means repeat forever)
                use_local_timezone=True,  # Interpret hours in the local timezone
            ).get_id()
            pruning_task = models.ScheduledTask(
                id=job_id,
                name='prune_database',
                interval=24 * 60 * 60,
                description='Cleaning database to remove old tokens and OTPs',
                cancelled=False
            )
            pruning_task.save()
    except Exception as ex:
        # Log any error that occurs
        errors.system_logging(ex, exception=True)
        print(ex)
