# app/extensions.py

from flask_mail import Mail
from flask_cors import CORS
from flask_bootstrap import Bootstrap
from flask_sqlalchemy import SQLAlchemy
from flask_security import Security
from flask_login import LoginManager
from flask_migrate import Migrate
from flask_bcrypt import Bcrypt

bcrypt = Bcrypt()
bootstrap = Bootstrap()
db = SQLAlchemy()
cors = CORS()
mail = Mail()
login_manager = LoginManager()
security = Security()
migrate = Migrate()
