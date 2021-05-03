# run.py

# App uses Flask-SocketIO giving access to low latency bi-directional communications between the clients and the server
# When connecting to a message queue service eg Redis for external(background) processes,
# it's very likely the package that talks to the service will hang if the Python standard library is not monkey patched.
# It is recommended that you apply the monkey patching at the top of your main script, even above your imports
# Read more at the Flask-SocketIO docs: https://flask-socketio.readthedocs.io/en/latest/

import eventlet

eventlet.monkey_patch(select=True, socket=True)

from app import create_app
from app.extras import get_config_name

app = create_app(get_config_name())

if __name__ == '__main__':
    from app.sockets import *
    socketIO.run(app, debug=app.debug, host="0.0.0.0", port=8745)
