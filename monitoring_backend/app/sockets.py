# app/sockets.py

"""
This module shall contain the web socket event handlers
"""

from flask import request
from flask_socketio import SocketIO, send

from app import app
from .errors import system_logging

REDIS_URL = app.config.get('REDIS_URL', 'redis://')
# Start SocketIO server, allow CORS and connect to a message queue eg Redis
socketIO = SocketIO(app, cors_allowed_origins="*", message_queue=REDIS_URL)


@socketIO.on('add message')
def add_message(data):
    from app.models import User, Message, Chat
    if not data:
        send('Message details not send')
    else:
        sender, recipient, chat_id, timestamp = data['sender'], data['recipient'], data['chat'], data['timestamp']
        if not sender or type(sender) is not str:
            send("Sender not provided")
        elif not recipient or type(recipient) is not str:
            send("Recipient not provided")
        elif not chat_id or type(chat_id) is not str:
            send("Chat not provided")
        elif not timestamp or type(timestamp) is not str:
            send("Message timestamp not provided")
        else:
            # Confirm sender
            sender = User.query.filter_by(username=sender).first()
            if not sender:
                send('Sender not registered')
                return
            # Confirm user
            recipient = User.query.filter_by(username=recipient).first()
            if not recipient:
                send('Recipient not registered')
                return
            from datetime import datetime
            timestamp = datetime.strptime(timestamp, "%A %b %d, %Y %I:%M %p")
            message = Message(
                sender_id=sender.email,
                recipient_id=recipient.email,
                chat_id=int(chat_id),
                body=data['content'] or '',
                timestamp=timestamp,
            )
            status = message.save()
            if status:
                send('Problem saving message')
            else:
                chats = Chat.query.filter_by(chat_id=chat_id).all()
                socketIO.emit('messages', {'message': Chat.retrieve_chats(chats=chats)[0]})


# noinspection PyUnresolvedReferences
@socketIO.on_error_default
def error_handler(err):
    """
    Decorator to define a default error handler for SocketIO events.
    This decorator can be applied to a function that acts as a default error handler for any namespaces
    that do not have a specific handler.
    """
    print(err)
    system_logging(msg=err, exception=True)
    socketIO.emit(request.event["message"], {'message': 'Error occurred. Please contact the administrator'})
