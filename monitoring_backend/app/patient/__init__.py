# app/patient/__init__.py

from flask import Blueprint

patient = Blueprint('patient', __name__)

from . import views
