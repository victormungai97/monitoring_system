# app/admin/views.py

from flask import make_response, jsonify, request

from . import admin
from pictures import upload_file
from tokens import admin_only_route

from app import db
from app.models import User, user_roles, Role, PatientRelative, PatientCaregiver
from app.errors import system_logging
from app.models import user_datastore
from app.extras import validate_phone_number


@admin.route('/')
def index():
    return 'admin'


@admin.route('/register/', methods=['POST'])
@admin_only_route
def register():
    if request.method == 'POST':
        try:
            # Get sent data
            data, message, status, response_code = request.form.to_dict(), '', 0, 202

            # no data sent
            if not data:
                return make_response(jsonify({'message': 'Data is missing', 'status': -1})), response_code

            fullname, phone_number, id_number = data['official_names'], data['phone_number'], data['id_number']
            residency, gender = data.get('residency', 'Nairobi'), data.get('gender', '') or ''
            role, relative, caregiver = data['role'], data.get('relative', ''), data.get('caregiver', '')

            # Ensure the key details are not missing
            if not role:
                return make_response(jsonify({'message': 'Role is missing', 'status': 1})), response_code
            if not fullname:
                return make_response(jsonify({'message': 'Official names are missing', 'status': 1})), response_code
            if not phone_number:
                return make_response(jsonify({'message': 'Phone number is missing', 'status': 1})), response_code
            if not id_number:
                return make_response(jsonify({'message': "ID number is missing", 'status': 1})), response_code

            # Confirm role given is valid
            if user_datastore.find_role(role=role) is None:
                return make_response(jsonify({'message': 'Non-existent role', 'status': -3})), 401

            if role == 'patient':
                if not relative:
                    return jsonify({'message': 'At least 1 relative required', 'status': 1}), response_code
                if not User.query.filter(User.user_id == relative).first():
                    return jsonify({'message': 'Relative provided not registered'}), response_code
                if not caregiver:
                    return jsonify({'message': 'At least 1 caregiver required', 'status': 1}), response_code
                if not User.query.filter(User.user_id == caregiver).first():
                    return jsonify({'message': 'Caregiver provided not registered'}), response_code

            # Check format of phone number
            message, status = validate_phone_number(phone_number)
            if status:
                return make_response(jsonify({'message': message, 'status': 7})), 202
            parts = [x.strip() for x in message.split('.')]
            phone_number = parts[1].split(':')[-1].strip()

            # check if user is already registered
            if User.query.filter_by(phoneNumber=phone_number).first():
                return make_response(jsonify({'message': 'Phone Number already registered', 'status': 5})), 202

            # receive profile picture
            message, status = upload_file(request.files, fullname, file_type='image', tag="profile_picture")
            if status or type(message) == str:
                return jsonify({'message': message, "status": -4}), 401
            else:
                profile_picture = message['http_url']

            if role == 'caregiver' or role == 'admin':
                # receive ID picture
                message, status = upload_file(request.files, fullname, file_type='image', tag="identification_picture")
                if status or type(message) == str:
                    return jsonify({'message': message, "status": -4}), 401
                else:
                    identification_picture = message['http_url']
            else:
                identification_picture = ''

            # Create user with given role
            user_id = User.generate_user_id(role)
            try:
                user_datastore.create_user(
                    user_id=user_id, fullname=fullname, phoneNumber=phone_number,
                    profile_picture=profile_picture, identification_number=id_number, roles=[role],
                    identification_picture=identification_picture, gender=gender, residence=residency,
                )
                if role == 'patient':
                    db.session.add(PatientRelative(relative=relative, patient=user_id, tag='primary'))
                    db.session.add(PatientCaregiver(caregiver=caregiver, patient=user_id, tag='primary'))

                db.session.commit()
            except Exception as err:
                print(err)
                db.session.rollback()
                system_logging(msg=err, exception=True)
                return make_response(jsonify({'message': "Error saving user", 'status': 9})), 202

            user = User.query.filter(User.phoneNumber == phone_number).first()
            user.launch_task('send_account_confirmation_sms', 'Sending account confirmation OTP SMS', phone_number)

            return make_response(jsonify({'message': 'Successful user addition', 'status': status})), 200
        except Exception as err:
            print(err)
            system_logging(err, exception=True)
            message = "Error during user registration"
            return make_response(jsonify({'message': message, 'status': -2})), 401


@admin.route('/get/')
@admin_only_route
def get_users():
    _role = request.args.get('role', None)
    if not _role:
        return jsonify({'message': 'Specify class of fields to retrieve'})
    if type(_role) != str or (_role != 'all' and user_datastore.find_role(role=_role) is None):
        return jsonify({'message': 'Non-existent role'})
    if _role == 'all':
        return jsonify({'message': User.retrieve_users(User.query.all())})
    users = [User.retrieve_users(User.query.filter_by(user_id=role.user_id).all())[0] for role in
             db.session.query(user_roles).filter_by(role_id=Role.query.filter_by(name=_role).first().id).all()]
    return jsonify({'message': users})
