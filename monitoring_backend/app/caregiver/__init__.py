# app/caregiver/__init_.py

from flask import Blueprint

caregiver = Blueprint('caregiver', __name__)

from . import views
