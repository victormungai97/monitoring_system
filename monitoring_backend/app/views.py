# app/views.py

from flask import render_template, Response, redirect
from datetime import datetime
from app import app


@app.route("/")
def index():
    return redirect('http://0.0.0.0:5632/')

