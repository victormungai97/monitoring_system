# pictures.py

import re
import os
import sys
import imghdr
# import img2pdf
import subprocess
from ffmpy import FFmpeg
from datetime import datetime
# from imdirect import imdirect_open
from werkzeug.utils import secure_filename
from PIL import Image  # library for manipulating images

from app.errors import system_logging
from app.extras import unique_files, create_path, get_config_name
from config import UPLOAD_FOLDER

_IMAGE_ALLOWED_EXTENSIONS = tuple({'jpeg', 'jpg', 'png', 'gif'})
_VIDEO_ALLOWED_EXTENSIONS = tuple({'mp4', 'mkv', 'mpeg', 'webm', '3gp', 'mov', 'ogg', 'flv', 'ts', 'avi', 'wmv'})
_OTHER_ALLOWED_EXTENSIONS = tuple({'pdf'})
ALLOWED_EXTENSIONS = list(_IMAGE_ALLOWED_EXTENSIONS + _VIDEO_ALLOWED_EXTENSIONS + _OTHER_ALLOWED_EXTENSIONS)
EXTENSIONS_MAP = {"IMAGE_FILES": _IMAGE_ALLOWED_EXTENSIONS, "VIDEO_FILES": _VIDEO_ALLOWED_EXTENSIONS}


def allowed_file(filename):
    """
    Function checks whether file is allowed based on filename extension
    :param filename: File to be checked
    :return: Status of checking, either True(allowed) or False(disallowed)
    """
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


def request_files_to_contents(files, uploads: list, tag: str = 'upload', length: int = 0):
    # Initiate background process of uploading images
    if not uploads:
        return 'Possible Error! Upload list not provided'
    if type(uploads) != list:
        return 'Invalid uploads'
    if not files:
        return 'ERROR! Upload file(s) is missing'
    _files = []
    if not length or type(length) != int:
        length = len(uploads)
    for i in range(0, length):
        _file, position = files[f'{tag}-{i}'], i + 1
        # Get filename
        filename = _file.filename
        if not filename:
            return f"File {position}'s name is missing"
        # Ensure file is allowed
        if not allowed_file(filename):
            return f'File {position} is disallowed'
        # Get file contents
        stream = _file.read()
        if not stream:
            return f'File {position} is empty'
        # Get file size
        size = len(stream)
        # Get file type
        mime_type = _file.content_type.split(';')[0]
        # Ensure media file is of appropriate size
        if re.search('image', mime_type):
            if size > 25 * 1024 * 1024:  # MB
                return f'Image at {position} is too big'
        elif re.search('video', mime_type):
            if size > 500 * 1024 * 1024:  # MB
                return f'Video at {position} is too big'
        else:
            return f'File {position} is unsupported'
        _files.append((stream, secure_filename(filename)))
    return _files


def individual_request_file_content(multipart_files, tag, file_type, limit):
    if tag not in multipart_files:
        return "No {} part in the request".format(tag)

    _file = multipart_files[tag]
    if not _file or not _file.filename or type(_file.filename) != str:
        return 'No file provided'
    if _file:
        if not allowed_file(_file.filename):
            return "Disallowed file type"

        filename = str(secure_filename(_file.filename))
        # Get file contents
        stream = _file.read()
        if not stream:
            return 'File is empty'

        # Get file size and type
        size, mime_type = len(stream), _file.content_type.split(';')[0]
        # Ensure media file is of appropriate size
        if re.search(file_type, mime_type):
            if size > limit:
                return 'File is too big'

            return stream, secure_filename(filename)
        else:
            return 'File is unsupported'


def upload_file(multipart_files, username, file_type, tag="upload"):
    """
    Function to save an uploaded file to path.
    It shall receive a file uploaded from client along with its dict key in the request
    and save the file after some processing and compression
    :param file_type: Type of file
    :param tag: The key for the file object in the request.file dictionary
    :param multipart_files: Files sent as part of form-data
    :param username: Unique name of the user
    :return: URL of image or error message and corresponding status code
    """
    # expect the key for file to be a string
    if type(tag) != str:
        return "Invalid file key. Required string", -190
    # check if the post request has the file part whose key is 'tag'
    if tag not in multipart_files:
        return "No {} part in the request".format(tag), -191
    # get the file
    _file = multipart_files[tag]
    # check if filename is present
    if not _file or _file.filename == '':
        return 'No file selected for uploading', -192
    # check that file is present and is for the required type as defined by its extension
    if _file:
        if allowed_file(_file.filename):
            filename = str(secure_filename(_file.filename))
            return determine_file(username, file_type, _file, filename, tag=tag), 0
        else:
            return "Disallowed file type", -193


def validate_image(file):
    """
    Function takes a byte stream as an argument.
    It starts by reading 512 bytes from the stream, and then resetting the stream pointer back to enabling saving later.
    The first 512 bytes of the image data are going to be sufficient to identify the format of the image
    :param file: Byte stream from image file or image file itself as `FileStorage` object
    :return: Detected image format
    """
    from werkzeug.datastructures import FileStorage
    if type(file) == FileStorage:
        stream = file.stream
    elif type(file) == bytes:
        stream = file
    else:
        stream = None
    if not stream:
        return None
    # Read 512 bytes from stream
    header = stream.read(512)
    # Reset stream pointer back to allow save() to see entire stream
    stream.seek(0)
    # imghdr.what take filename as 1st argument and data stored in memory as 2nd argument with filename set to None
    # Result from function is detected image format
    _format = imghdr.what(None, header)
    #  If unknown image format is detected, then the return value is None
    if not _format:
        return None
    # If a format is detected, the name of the format is returned
    return _format if _format != 'jpeg' else 'jpg'


def check_file_size(filename: str, limit: int = 25, level: str = 'MB'):
    """
    Check file size
    :param filename: Path to file
    :param limit: Maximum allowed size of file
    :param level: The byte power to consider file size against
    :return: Result of check
    """
    if not limit:
        return 'No file limit given'
    if type(limit) != int:
        return 'Invalid file limit provided'
    # Get file statistics
    file_stats = os.stat(filename)
    # Then file size in bytes
    file_size = file_stats.st_size
    powers = {'KB': 1, 'MB': 2, 'GB': 3, 'TB': 4}
    # Compare file size against limit based on given base power
    return (file_size / (1024 ** powers.get(level, 1))) <= limit if level else file_size <= limit


def determine_file(username, file_type, file, filename, tag="upload"):
    """
    Function that saves and delegates the processing of uploaded file
    :param username: Unique name of the user
    :param file_type: Type of uploaded file
    :param filename: Name of the specific image file
    :param file: Uploaded file
    :param tag: Specifies the category of the file eg upload and hence the specific folder file is to be saved in
    :return: URL of the files
    """
    # get file extension
    ext = filename.rsplit('.', 1)[1].lower()
    # check if non-image sent under image file type
    if re.match("image", file_type) and ext not in EXTENSIONS_MAP["IMAGE_FILES"]:
        return 'Disallowed image file'
    # check if non-video sent under video file type
    if re.match("video", file_type) and ext not in EXTENSIONS_MAP["VIDEO_FILES"]:
        return 'Disallowed video file'

    if tag.find("-") != -1:
        tag = tag.split("-")[0]

    if tag == "certificate":
        media = "PDFs".lower()
    elif re.match("image", file_type):
        media = "images"
    elif re.match("video", file_type):
        media = "videos"
    elif re.match("pdf", file_type):
        media = "PDFs".lower()
    else:
        media = "others"
    path = create_path(upload_folder=UPLOAD_FOLDER, username=username, tag=tag, media=media)

    # extract file extension
    ext = filename.rsplit('.', 1)[-1]
    # get path of file with username as basename
    filename = os.path.join(path, "".join([username, "_", str(0), ".", ext]))
    # generate unique file name
    filename = unique_files(path, filename, username, ext)

    if type(file) == bytes:
        with open(filename, 'wb') as f:
            f.write(file)
        file_parts = secure_filename(filename).rsplit('.')
    else:
        # for video, get original file parts
        file_parts = secure_filename(file.filename).rsplit('.')
        # save file
        file.save(filename)
    basename, extension = file_parts[0], file_parts[-1]

    # process and save images
    if re.match("image", file_type):
        if tag == "certificate" or tag == "good_conduct":
            return convert_image_to_pdf(filename)
        else:
            return determine_picture(filename)
    # process and save videos
    if re.match("video", file_type):
        return determine_video(filename, basename, extension, user=username, tag=tag)

    # get last part of filename starting from static
    http_url = filename.rsplit('/', maxsplit=6)[1:]
    return {'http_url': '/'.join(http_url), 'local_url': filename, 'thumbnail': ''}


def determine_picture(filename):
    """
    Function that processes and saves images and returns their URLs
    :param filename: Name of the specific image file
    :return: URL of image
    """
    if not filename or type(filename) != str:
        return 'Invalid image filename'
    # Confirm that file exists
    if not os.path.isfile(filename):
        return 'Image file not found'
    # Confirm image is less than given limit
    check_res = check_file_size(filename, limit=5, level='MB')
    if not check_res:
        # Delete if it exceeds
        os.remove(filename)
        return 'Image file is too big. Deleted'
    if type(check_res) == str:
        return check_res
    # compress image
    compress_image(filename)

    # get last part of filename starting from static
    http_url = filename.rsplit('/', maxsplit=6)[1:]
    return {'http_url': '/'.join(http_url), 'local_url': filename, 'thumbnail': '', 'preview': ''}


def compress_image(filename):
    """
    Function to resize(compress) image to a given size
    :param filename: Image to resize
    :return: None
    """
    import piexif  # library for holding on to exif data eg orientation
    # open file to be compressed
    img = Image.open(filename)
    # load exif data
    try:
        exif_dict = piexif.load(img.info["exif"])
        exif_bytes = piexif.dump(exif_dict)
    except BaseException as err:
        print('Exif error: {}'.format(err))
        exif_bytes = None
    # compress the image accordingly. Thumbnail maintains aspect ratio and leaves small images as is
    img.thumbnail((500, 500), Image.ANTIALIAS)
    # save the downsized image
    if exif_bytes:
        img.save(filename, optimize=True, quality=100, exif=exif_bytes)
    else:
        img.save(filename, optimize=True, quality=100)


def determine_video(filename, basename, ext, user, tag):
    """
    Function that processes and saves videos and returns their URLs
    :param ext: Original video extension
    :param basename: Original basename for the video
    :param user: Person uploading the video
    :param filename: Name of the specific video file
    :param tag: Specifies the category of the file eg upload and hence the specific folder file is to be saved in
    :return: URL of video
    """
    if not filename or type(filename) != str:
        return 'Invalid video filename'
    # Confirm that file exists
    if not os.path.isfile(filename):
        return 'Video file not found'
    # Confirm image is less than given limit
    if not check_file_size(filename, limit=300, level='MB'):
        # Delete if it exceeds
        os.remove(filename)

    # check whether app is in debug mode
    debug = get_config_name() == 'development' or get_config_name() == 'testing'
    # check video duration
    duration = get_video_length(input_video=filename)
    if duration <= -1:
        return {'http_url': '/'.join(filename.rsplit('/', maxsplit=6)[1:]), 'local_url': filename, 'thumbnail': ''}

    # decide when to extract thumbnail by discarding first given number of seconds in input video
    scene = 0 if duration < 1 else 1

    # set thumbnail of video. It will be generated at given scene of video and -vframes is number of frames(1)
    thumb = basename + '_' + datetime.now().strftime('%d%m%y_%H%M%S%f') + '.jpg'
    thumbnail = create_path(UPLOAD_FOLDER, media="thumbnails", username=user, tag=tag) + thumb

    # set length of gif preview of video.
    gif_length = 5
    # If video is less than 6 seconds, the whole video shall be made a gif
    if duration <= gif_length:
        gif_command = ['ffmpeg', '-ss', '0', '-t', f'{duration}', '-i', filename, '-y']
    # If video is 6-9 seconds, skip first 5 seconds and create output based on difference
    elif (gif_length + 1) < duration <= ((gif_length * 2) - 1):
        gif_command = ['ffmpeg', '-ss', f'{gif_length}', '-t', f'{(duration - gif_length)}', '-i', filename, '-y']
    # If video greater than 9 seconds, skip first 5 seconds and create output of 5 seconds
    else:
        gif_command = ['ffmpeg', '-ss', f'{gif_length}', '-t', f'{gif_length}', '-i', filename, '-y']
    # Add other commands for scaling, filters etc required when generating a gif from video
    # See "https://superuser.com/questions/556029/how-do-i-convert-a-video-to-gif-using-ffmpeg-with-reasonable-quality"
    gif_command.extend(
        ['-vf', "fps=10,scale=160:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse", '-loop', '0']
    )
    # Create gif file name and directory if missing
    gif = basename + '_' + datetime.now().strftime('%d%m%y_%H%M%S%f') + '.gif'
    preview = create_path(UPLOAD_FOLDER, media="gifs", username=user, tag=tag) + gif
    gif_command.append(preview)
    # get file path
    path = filename.rsplit('/', 1)[0]
    # set encoder
    if debug:
        codec, crf = "libx264", 24
    else:
        codec, crf = "libx265", 30
    # set output filename
    filename2 = path + '/' + basename + '_' + datetime.now().strftime('%d%m%y_%H%M%S%f') + '.mp4'
    # convert if input is not mp4, set resolution to 480p and compress
    output_params = {
        # Generate processed video
        filename2: f"-y -vf scale=-2:480 -c:v {codec} -crf {crf} -c:a copy",
        # Generate thumbnail with width of maximum of 280 pixels and preserving aspect ratio
        thumbnail: f"-ss {scene} -vframes 1 -filter:v scale='min(280\\, iw):-1' -y",
    }
    # Process video
    ff = FFmpeg(executable='/usr/bin/ffmpeg', inputs={filename: None}, outputs=output_params)
    if debug:
        print(ff.cmd)
    ff.run()
    # Generate GIF preview using subprocess call
    from upgrade import run_terminal
    if debug:
        print(gif_command)
    run_terminal(gif_command)
    # Delete old file and save the new file
    os.remove(filename)
    filename = unique_files(path, filename.replace(ext, 'mp4'), basename, 'mp4')
    os.rename(filename2, filename)

    # get last part of filename starting from static
    http_url = filename.rsplit('/', maxsplit=6)[1:]
    thumbnail_url = thumbnail.rsplit('/', maxsplit=6)[1:]
    preview_url = preview.rsplit('/', maxsplit=6)[1:]
    return {
        'http_url': '/'.join(http_url),
        'local_url': filename,
        'thumbnail': '/'.join(thumbnail_url),
        'preview': '/'.join(preview_url)
    }


def get_video_length(input_video: str = ''):
    try:
        if not input_video:
            system_logging('Input filename not provided', exception=True)
            return -1

        commands = ['/usr/bin/ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of',
                    'default=noprint_wrappers=1:nokey=1', input_video]
        # check python version and run appropriate subprocess function
        if repr(sys.version_info[0]) + repr(sys.version_info[1]) >= '35':  # Python 3.5 and higher
            result = subprocess.run(commands, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        else:
            result = subprocess.call(commands, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        return float(result.stdout)
    except BaseException as err:
        print(err)
        system_logging(err, exception=True)
        return -1


def image_to_pdf(local_url: str = ''):
    pass
    # from fpdf import FPDF
    # image = Image.open(local_url)
    # width, height = image.size
    #
    # pdf = FPDF(unit='pt', format=[width, height], orientation='L')
    # pdf.add_page()
    # pdf.image(local_url, 0, 0, width, height)
    #
    # # get last part of filename starting from static
    # path = f'{local_url.split(".")[0]}.pdf'
    # # save file
    # pdf.output(path, 'F')
    # # Delete the image, hence only having the PDF
    # os.remove(local_url)
    # return {'http_url': '/'.join(path.rsplit('/', maxsplit=6)[1:])}


def convert_image_to_pdf(filename):
    """This function takes an image filename and converts the image to PDF"""
    pass
    # try:
    #     # Verify filename
    #     if not filename or type(filename) != str:
    #         return 'Invalid image filename'
    #     # Confirm that file exists
    #     if not os.path.isfile(filename):
    #         return 'Image file not found'
    #
    #     # Split the filename into the directory, basename and extension
    #     directory, name = tuple(filename.rsplit('/', 1))
    #     basename, extension = tuple(name.split('.'))
    #     # Open the image and if it is not RGB, convert the image to JPEG RGB
    #     im = Image.open(filename)
    #     filename2 = filename
    #     if im.mode != 'RGB':
    #         im = im.convert('RGB')
    #         filename2 = f'{directory}/{basename}.jpg'
    #         im.save(filename2, quality=95)
    #     im.close()
    #
    #     # If original image is modified to RGB, delete it and keep the new one
    #     if filename != filename2:
    #         os.remove(filename)
    #         filename = filename2
    #
    #     import io
    #     # Open the RGB image with imdirect library which performs automatic rotation of opened JPEG image
    #     image = imdirect_open(filename)
    #     output = io.BytesIO()
    #     image.save(output, format='JPEG')
    #     # Convert the image to PDF bytes and write it to a PDF file
    #     pdf_bytes = img2pdf.convert(output.getvalue())
    #     output = f"{directory}/{basename}.pdf"
    #     with open(output, "wb") as f:
    #         f.write(pdf_bytes)
    #     # Delete the image, hence only having the PDF
    #     os.remove(filename)
    #
    #     # get last part of filename starting from static
    #     return {'http_url': '/'.join(output.rsplit('/', maxsplit=6)[1:])}
    # except BaseException as err:
    #     print(err)
    #     system_logging(err, exception=True)
    #     try:
    #         res = determine_picture(filename)
    #         return res if type(res) == str else image_to_pdf(res['local_url'])['http_url'] if type(res) == dict else ''
    #     except BaseException as err:
    #         print(err)
    #         system_logging(err, exception=True)
    #         return "Unable to process certificate"


def get_concat_horizontal(image_list: list):
    """Concatenate list of images horizontally with the same height"""
    try:
        if image_list:
            # Get first image in list
            image1 = image_list.pop(0)
            # Loop through the rest of the files
            for image2 in image_list:
                # Create a background
                dst = Image.new('RGB', (image1.width + image2.width, image1.height))
                # Paste the images
                dst.paste(image1, (0, 0))
                dst.paste(image2, (image1.width, 0))
                image1 = dst
            return image1
    except BaseException as err:
        print(err)
        system_logging(f'Exception concatenating images\n{err}', exception=True)
    return None


def get_concat_vertical(image_list: list):
    """Concatenate list of images vertically with the same width"""
    try:
        if image_list:
            # Get first image in list
            image1 = image_list.pop(0)
            # Loop through the rest of the files
            for image2 in image_list:
                # Create a background
                dst = Image.new('RGB', (image1.width, image1.height + image2.height))
                # Paste the images
                dst.paste(image1, (0, 0))
                dst.paste(image2, (0, image1.height))
                image1 = dst
            return image1
    except BaseException as err:
        print(err)
        system_logging(f'Exception concatenating images\n{err}', exception=True)
    return None
