# app/home/__init_.py

from flask import Blueprint

relative = Blueprint('relative', __name__)

from . import views
