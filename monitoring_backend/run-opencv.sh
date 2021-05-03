#!/bin/bash
sudo apt -y update && sudo apt -y upgrade
sudo add-apt-repository "deb http://security.ubuntu.com/ubuntu xenial-security main"
sudo apt -y update
sudo apt install --upgrade -y build-essential cmake git pkg-config libgtk-3-dev \
    libavcodec-dev libavformat-dev libswscale-dev libv4l-dev \
    libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff-dev \
    gfortran openexr libatlas-base-dev python3-dev libtbb2 \
    libtbb-dev libdc1394-22-dev libopenexr-dev libjasper1 \
    libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev libjasper1 libjasper-dev
if [ ! -d opencv ]; then
  git clone https://github.com/opencv/opencv.git
fi
if [ ! -d opencv_contrib ]; then
  git clone https://github.com/opencv/opencv_contrib.git
fi
pip install --upgrade numpy
cd opencv
mkdir -p build && cd build
cmake -D CMAKE_BUILD_TYPE=RELEASE \
    -D CMAKE_INSTALL_PREFIX=/home/victor/Envs/monitoring_env \
    -D WITH_CUDA=OFF \
    -D INSTALL_C_EXAMPLES=ON \
    -D INSTALL_PYTHON_EXAMPLES=ON \
    -D OPENCV_GENERATE_PKGCONFIG=ON \
    -D OPENCV_EXTRA_MODULES_PATH=../../opencv_contrib/modules \
    -D OPENCV_ENABLE_NONFREE=ON \
    -D BUILD_EXAMPLES=ON ..
make -j8
make install
cd ../..
rm -rf opencv opencv_contrib
