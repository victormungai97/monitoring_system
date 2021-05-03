# app/home/views.py

from . import relative


@relative.route('/')
def index():
    return "relative"
