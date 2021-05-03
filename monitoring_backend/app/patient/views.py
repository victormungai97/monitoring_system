# app/patient/views.py

from . import patient


@patient.route('/')
def index():
    return 'patient'


@patient.route('/create_request/')
def create_request():
    pass
