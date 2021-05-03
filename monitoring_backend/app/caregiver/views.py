# app/caregiver/views.py

from . import caregiver


@caregiver.route('/')
def index():
    return "caregiver"
