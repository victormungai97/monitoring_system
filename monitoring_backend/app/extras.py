# app/extras.py

import os
import re
import pytz
import phonenumbers
from datetime import datetime
from phonenumbers import carrier


def get_config_name():
    """Get the environment running the app"""
    config_name = None
    try:
        # Here, we obtain environment variables from a settings file
        # Useful for running inside an IDE
        from settings import get_env_variable

        config_name = get_env_variable['FLASK_ENV']
    except (ImportError, Exception):
        # Here, we obtain environment variables directly from computer
        # Useful for running in a terminal
        try:
            config_name = os.getenv('FLASK_ENV')
        except BaseException as err:
            print(err)

    if not config_name:
        config_name = 'production'
    return config_name


def validate_phone_number(phone_number: str = ''):
    try:
        if not phone_number:
            return 'Missing phone number', -4
        if type(phone_number) != str:
            return "Unable to determine phone number", -4
        region = "KE"
        # Create a `PhoneNumber` object from a string representing a phone number
        # Specify country of origin of phone number.
        # This maybe unnecessary for numbers starting with '+' since they are globally unique.
        parsed_phone = phonenumbers.parse(phone_number, region)
        # Check whether it's a possible number (e.g. it has the right number of digits)
        if not phonenumbers.is_possible_number(parsed_phone):
            return "Possibly not a number. Check if e.g. number of digits is correct", -4
        # Check whether it's a valid number (e.g. it's in an assigned exchange)
        if not phonenumbers.is_valid_number_for_region(parsed_phone, region):
            return "Invalid phone number", -4
        # Format number as per international format code E164
        phone_number = phonenumbers.format_number(parsed_phone, phonenumbers.PhoneNumberFormat.E164)
        # Get the carrier of the phone number
        operator = carrier.name_for_number(parsed_phone, "en") if carrier.name_for_number(parsed_phone, "en") else ''
        return f"""Phone number valid. Phone: {phone_number}. Operator: {operator}""", 0
    except phonenumbers.phonenumberutil.NumberParseException as err:
        return f'{err}', -4
    except BaseException as ex:
        return f'{ex}', -4


def create_path(upload_folder="./uploads", tag="upload", media="images", username="unnamed"):
    """
    Function that creates the users' file directories using their registration numbers
    :param upload_folder: Parent folder for uploads
    :param tag: Specifies the category of the file eg upload and hence the specific folder file is to be saved in
    :param media: The media type of file eg images, videos, pdf etc
    :param username: The user's unique name
    :return: Path to the directories
    """
    if type(username) != str:
        return ""
    # split username if whitespace is found within it
    if re.findall(r'[\s]', username):
        details = username.split()
    else:
        details = username
    # create new path to folder for user's image(s)
    if type(details) == list:
        path = '/'.join([os.getcwd(), upload_folder, tag, media, '_'.join(details), ''])
    elif type(details) == str:
        path = '/'.join([os.getcwd(), upload_folder, tag, media, details, ''])
    else:
        path = '/'.join([os.getcwd(), upload_folder, tag, ''])
    # create the new folder
    if not os.path.isdir(path):
        os.makedirs(path)
    return path


def unique_files(directory, filename, basename, extension='pdf'):
    """
    check if file is in current directory. If so, rename it
    :param directory: Directory to save in
    :param filename: Name of file currently
    :param basename: Base name of file
    :param extension: Extension of file
    :return: New file name if current name exists
    """
    if not directory:
        return ""
    for root, dirs, files in os.walk(directory):
        for i in range(len(files)):
            files[i] = os.path.join(root, files[i])
        common_files = []
        if filename in files:
            for _file in files:
                if os.path.basename(_file).startswith(basename):
                    common_files.append(_file)
            if common_files:
                common_files.sort()
                filename = common_files[-1]
                start, end = tuple(filename.rsplit('_', 1))
                now = datetime.now(tz=pytz.timezone('Africa/Nairobi')).strftime("%Y%m%d%H%M%S%f")
                filename = "_".join([start, ".".join([now, extension])])
    return filename
