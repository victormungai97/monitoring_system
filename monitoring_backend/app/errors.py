# app/errors.py

"""
This module will handles the errors that might arise from the system
It will contain custom functions that redirect user to custom URLs when various errors occur
and a function that logs the errors and informs the admin(s) when said errors occur
"""

import logging
import os
from rq import Queue
from rq.job import Job
import werkzeug.exceptions as ex
from flask import render_template_string
from rq.registry import FailedJobRegistry
from werkzeug.http import HTTP_STATUS_CODES
from logging.handlers import SMTPHandler, RotatingFileHandler

from app import app


class BandwidthExceeded(ex.HTTPException):
    """
    Create custom status code for error 509
    """
    code = 509
    description = 'The server is temporarily unable to service your request due to the site owner ' \
                  'reaching his/her bandwidth limit. Please try again later. '


ex.default_exceptions[509] = BandwidthExceeded
HTTP_STATUS_CODES[509] = 'Bandwidth Limit Exceeded'
abort = ex.Aborter()

# change format of log message
# here, we've set the timestamp, logging level, message, source file & line no where log entry originated
LOG_FORMAT = "%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]"


@app.errorhandler(404)
def page_not_found(error):
    errs = str(error).split(':')[-1].split('.')
    print(errs)
    return render_template_string(
        '''
        <html>
            <head>
                <title>Page not found</title>
            </head>
            <body>
                <b>This page does not exist</b>
            </body>
        </html>
        '''
    ), 404


def _email():
    """
    Let us email errors to the developers and administrators
    :return: None
    """
    # if app is running without debug mode
    if not app.debug:
        # allow sending logs by email only if mail server has been set
        if app.config.get('MAIL_SERVER'):
            auth = None
            # receive email server credentials, if any
            if app.config['MAIL_USERNAME'] or app.config['MAIL_PASSWORD']:
                auth = (app.config['MAIL_USERNAME'], app.config['MAIL_PASSWORD'])
            secure = None
            # set up secure email traffic transport
            if app.config['MAIL_USE_TLS']:
                secure = ()
            # SMTPHandler from logging enables sending logs to admins and tech support by email
            recipients = ['victormungai@gmail.com']
            mail_handler = SMTPHandler(
                mailhost=(app.config['MAIL_SERVER'], app.config['MAIL_PORT']),
                fromaddr='admin@' + (app.config['SERVER_NAME'] or 'nywelenyumbani.co.ke'),
                toaddrs=recipients,
                subject='Monitoring System Failure',
                credentials=auth,
                secure=secure,
            )
            # ensure only errors are reported
            mail_handler.setLevel(logging.ERROR)
            app.logger.addHandler(mail_handler)


def set_logger(filename):
    # save info, warnings, errors and critical messages in log file
    # limit size of log file to 10KB(10240 bytes) and keep last 30 log files as backup
    file_handler = RotatingFileHandler(filename, maxBytes=10240, backupCount=30)
    # set format
    file_handler.setFormatter(logging.Formatter(LOG_FORMAT))

    # setting logging level to INFO enables logging to cover everything except DEBUG
    file_handler.setLevel(logging.INFO)
    return file_handler


def system_logging(msg, exception=False, log_file='monitoring.log'):
    """
    This is a function that handles system error logging,
    from emailing errors to logging the errors in a file.
    The messages in log file will have as much information as possible.
    RotatingFileHandler rotates the logs, ensuring that the log files
    do not grow too large when the application runs for a long time.
    The server writes a line to the logs each time it starts.
    When this application runs on a production server, these log entries will tell you when the server was restarted.
    :param: logs_folder = The folder that will contain the log file
    """
    # Get and secure the log file
    from werkzeug.utils import secure_filename
    if not log_file or type(log_file) != str:
        log_file = 'monitoring.log'
    log_file = secure_filename(log_file)

    # if log folder does not exist, create it
    logs_folder = app.config.get("LOG_FOLDER", "./logs")
    if not os.path.isdir(logs_folder):
        os.makedirs(logs_folder)

    _email()

    app.logger.addHandler(set_logger(logs_folder + f'/{log_file}'))
    app.logger.setLevel(logging.INFO)
    if exception:
        app.logger.exception(msg)
    else:
        app.logger.info(msg)


def check_failed_rq_jobs(queue_name='monitoring_tasks', delete_job=False):
    """This function will print out jobs that failed to execute on RQ 's task queue"""
    queue = Queue(connection=app.redis, name=queue_name)
    registry = FailedJobRegistry(queue=queue)
    # This is how to remove a job from a registry
    for job_id in registry.get_job_ids():
        # Get job whose ID is given
        job = Job.fetch(job_id, connection=app.redis)
        # Print out the job's exception stacktrace
        system_logging(f'\n{job.__dict__["exc_info"]}\n------------------------------------------\n', True, 'redis.log')
        # Remove from registry and delete job
        registry.remove(job_id, delete_job=delete_job)
