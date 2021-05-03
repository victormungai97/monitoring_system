from flask import Flask,Response,render_template
import threading
import argparse
from imutils import build_montages
from datetime import datetime
import numpy as np
import imagezmq
import imutils
import cv2

# construct the argument parser and parse the arguments

Output_frame = None

# initialize the ImageHub object
imageHub = imagezmq.ImageHub()
# initialize the list of class labels MobileNet SSD was trained to
# detect, then generate a set of bounding box colors for each class
CLASSES = ["background","bottle","cat", "chair", "dog","person", "pottedplant","sofa", "tvmonitor"]
# load our serialized model from disk
print("[INFO] loading model...")

# initialize the consider set (class labels we care about and want
# to count), the object count dictionary, and the frame  dictionary
CONSIDER = set(["dog", "person"])
objCount = {obj: 0 for obj in CONSIDER}
frameDict = {}
# initialize the dictionary which will contain  information regarding
# when a device was last active, then store the last time the check
# was made was now
lastActive = {}
lastActiveCheck = datetime.now()
# stores the estimated number of Pis, active checking period, and
# calculates the duration seconds to wait before making a check to
# see if a device was active
ESTIMATED_NUM_PIS = 1
ACTIVE_CHECK_PERIOD = 1
ACTIVE_CHECK_SECONDS = ESTIMATED_NUM_PIS * ACTIVE_CHECK_PERIOD


print("[INFO] detecting: {}...".format(", ".join(obj for obj in CONSIDER)))


lock = threading.Lock()

app = Flask(__name__)

@app.route("/")
def index():
    return render_template("stream.html")

@app.route("/feed")
def feed():
    return Response(generate(),
                    mimetype="multipart/x-mixed-replace;boundary=frame")

def generate():
    global Output_frame,lock
    while True:
        if Output_frame is None:
            continue
        (flag,encodedImage)=cv2.imencode(".jpg",Output_frame)
        if not flag:
            continue
        yield(b'--frame\r\n'
              b'Content-Type: image/jpeg\r\n\r\n' + bytearray(encodedImage)+b'\r\n')


def recognition(lock, args):
    net = cv2.dnn.readNetFromCaffe(args["prototxt"], args["model"])

    # assign montage width and height so we can view all incoming frames
    # in a single "dashboard"
    mW = args["montageW"]
    mH = args["montageH"]

    while True:
        # receive RPi name and frame from the RPi and acknowledge
        # the receipt
        (ClientName, frame) = imageHub.recv_image()
        imageHub.send_reply(b'OK')
        # if a device is not in the last active dictionary then it means
        # that its a newly connected device
        if ClientName not in lastActive.keys():
            print("[INFO] receiving data from {}...".format(ClientName))
        # record the last active time for the device from which we just
        # received a frame
        lastActive[ClientName] = datetime.now()

    # resize the frame to have a maximum width of 400 pixels, then
        # grab the frame dimensions and construct a blob
        frame = imutils.resize(frame, width=400)
        (h, w) = frame.shape[:2]
        blob = cv2.dnn.blobFromImage(cv2.resize(frame, (300, 300)),0.007843, (300, 300), 127.5)
        # pass the blob through the network and obtain the detections and
        # predictions
        net.setInput(blob)
        detections = net.forward()
        # reset the object count for each object in the CONSIDER set
        objCount = {obj: 0 for obj in CONSIDER}

        for i in np.arange(0, detections.shape[2]):
            # extract the confidence (i.e., probability) associated with
            # the prediction
            confidence = detections[0, 0, i, 2]
            # filter out weak detections by ensuring the confidence is
            # greater than the minimum confidence
            if confidence > args["confidence"]:
                # extract the index of the class label from the
                # detections
                idx = int(detections[0, 0, i, 1])
                # check to see if the predicted class is in the set of
                # classes that need to be considered
                try:
                    if CLASSES[idx] in CONSIDER:
                        # increment the count of the particular object
                        # detected in the frame
                        objCount[CLASSES[idx]] += 1
                        # compute the (x, y)-coordinates of the bounding box
                        # for the object
                        box = detections[0, 0, i, 3:7] * np.array([w, h, w, h])
                        (startX, startY, endX, endY) = box.astype("int")
                        # draw the bounding box around the detected object on
                        # the frame
                        cv2.rectangle(frame, (startX, startY), (endX, endY),
                                      (255, 0, 0), 2)
                except:
                    pass

        # draw the sending device name on the frame
        cv2.putText(frame, ClientName, (10, 25),cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 2)
        # draw the object count on the frame
        label = ", ".join("{}: {}".format(obj, count) for (obj, count) in objCount.items())
        cv2.putText(frame, label, (10, h - 20),cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255,0), 2)
        # update the new frame in the frame dictionary
        frameDict[ClientName] = frame
        # build a montage using images in the frame dictionary
        montages = build_montages(frameDict.values(), (w, h), (mW, mH))
        # display the montage(s) on the screen
        for (i, montage) in enumerate(montages):
            with lock:
                global Output_frame
                Output_frame = montage.copy()



if __name__ == "__main__":
    
    args = {'prototxt': "prototxt.txt", 'model': "caffemodel", 'montageW': 1, 'montageH': 1, 'confidence': 0.8}

    t = threading.Thread(target=recognition,args=(lock,args))

    t.daemon= True
    t.start()

    app.run(debug=True,port=5632,host="0.0.0.0",threaded=True,use_reloader=False)
