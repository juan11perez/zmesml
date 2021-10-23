#!/bin/bash
#
#
# Script to compile opencv with CUDA support.
#
#############################################################################################################################
#
# You need to prepare for compiling the opencv with CUDA support.
#
# You need to start with a clean docker image if you are going to recompile opencv.
# This can be done by switching to "Advanced View" and clicking "Force Update", 
# or remove the Docker image then reinstall it.
#
# Install the Unraid Nvidia drivers and be sure your graphics card can be seen in the
# Zoneminder Docker.  This will also be checked as part of the compile process.
# You will not get a working compile if your graphics card is not seen.  It may appear
# to compile properly but will not work.
#
# Download the cuDNN run time and dev packages for your GPU configuration.  You want the deb packages for Ubuntu 20.04.
# You wll need to have an account with Nvidia to download these packages.
# https://developer.nvidia.com/rdp/form/cudnn-download-survey
# Place them in the /config/opencv/ folder.
#
CUDNN_RUN=libcudnn8_8.1.1.33-1+cuda11.2_amd64.deb
CUDNN_DEV=libcudnn8-dev_8.1.1.33-1+cuda11.2_amd64.deb
#
# Download the cuda tools package.  You want the deb (local) package for Ubuntu 20.04.
# https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=x86_64&target_distro=Ubuntu&target_version=2004&target_type=deblocal
# Place the download in the /config/opencv/ folder.
#
CUDA_TOOL=cuda-repo-ubuntu2004-11-2-local_11.2.2-460.32.03-1_amd64.deb
CUDA_PIN=cuda-ubuntu2004.pin
CUDA_KEY=/var/cuda-repo-ubuntu2004-11-2-local/7fa2af80.pub
CUDA_VER=11.2
#
#
# Github URL for opencv zip file download.
# Current default is to pull the version 4.5.1 release.
#   Note: You shouldn't need to change these.
#
OPENCV_VER=4.5.3
OPENCV_URL=https://github.com/opencv/opencv/archive/$OPENCV_VER.zip
OPENCV_CONTRIB_URL=https://github.com/opencv/opencv_contrib/archive/$OPENCV_VER.zip
#
# You can run this script in a quiet mode so it will run without any user interaction.
#
# Once you are satisfied that the compile is working, run the following command:
#   echo "yes" > opencv_ok
# 
# The opencv.sh script will run when the Docker is updated so you won't have to do it manually.
#
#############################################################################################################################

QUIET_MODE=$1
if [[ $QUIET_MODE == 'quiet' ]]; then
	QUIET_MODE='yes'
	echo "Running in quiet mode."
	sleep 10
else
	QUIET_MODE='no'
fi

#
# Display warning.
#
if [ $QUIET_MODE != 'yes' ];then
	echo "##################################################################################"
	echo
	echo "This script will compile 'opencv' with GPU support."
	echo
	echo "WARNING:"
	echo "The compile process needs 15GB of disk (Docker image) free space, at least 4GB of"
	echo "memory, and will generate a huge Zoneminder Docker that is 10GB in size!  The apt"
	echo "update will be disabled so you won't get Linux updates.  Zoneminder will no"
	echo "longer update.  In order to get updates you will have to force update, or remove"
	echo "and re-install the Zoneminder Docker and then re-compile 'opencv'."
	echo
	echo "There are several stopping points to give you a chance to see if the process is"
	echo "progressing without errors."
	echo
	echo "The compile script can take an hour or more to complete!"
	echo "Press any key to continue, or ctrl-C to stop."
	echo
	echo "##################################################################################"
	read -n 1 -s
fi

#
# Remove log files.
#
rm -f /config/opencv/*.log

#
# Be sure we have enough disk space to compile opencv.
#
SPACE_AVAIL=`/bin/df / | /usr/bin/awk '{print $4}' | grep -v 'Available'`
if [[ $((SPACE_AVAIL/1000)) -lt 15360 ]];then
	if [ $QUIET_MODE != 'yes' ];then
		echo
		echo "Not enough disk space to compile opencv!"
		echo "Expand your Docker image to leave 15GB of free space."
		echo "Force update or remove and re-install Zoneminder to allow more space if your compile did not complete."
	fi
	logger "Not enough disk space to compile opencv!" -tEventServer
	exit
fi

#
# Check for enough memory to compile opencv.
#
MEM_AVAILABLE=`cat /proc/meminfo | grep MemAvailable | /usr/bin/awk '{print $2}'`
if [[ $((MEM_AVAILABLE/1000)) -lt 4096 ]];then
	if [ $QUIET_MODE != 'yes' ];then
		echo
		echo "Not enough memory available to compile opencv!"
		echo "You should have at least 4GB available."
		echo "Check that you have not over committed SHM."
		echo "You can also stop Zoneminder to free up memory while you compile."
		echo "  service zoneminder stop"
	fi
	logger "Not enough memory available to compile opencv!" -tEventServer
	exit
fi

#
# Remove face-recognition module
#
pip3 uninstall -y face-recognition

logger "Compiling opencv with GPU Support" -tEventServer

#
# Install cuda toolkit
#
logger "Installing cuda toolkit..." -tEventServer
cd ~
if [ -f  /config/opencv/$CUDA_PIN ]; then
	cp /config/opencv/$CUDA_PIN /etc/apt/preferences.d/cuda-repository-pin-600
else
	echo "Please download CUDA_PIN."
	logger "CUDA_PIN not downloaded!" -tEventServer
	exit
fi

if [ -f /config/opencv/$CUDA_TOOL ];then
	dpkg -i /config/opencv/$CUDA_TOOL
else
	echo "Please download CUDA_TOOL package."
	logger "CUDA_TOOL package not downloaded!" -tEventServer
	exit
fi

apt-key add $CUDA_KEY >/dev/null
apt-get update
apt-get -y upgrade -o Dpkg::Options::="--force-confold"
apt-get -y install cuda-toolkit-$CUDA_VER

echo "export PATH=/usr/local/cuda/bin:$PATH" >/etc/profile.d/cuda.sh
echo "export LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64:/usr/local/lib:$LD_LIBRARY_PATH" >> /etc/profile.d/cuda.sh
echo "export CUDADIR=/usr/local/cuda" >> /etc/profile.d/cuda.sh
echo "export CUDA_HOME=/usr/local/cuda" >> /etc/profile.d/cuda.sh
echo "/usr/local/cuda/lib64" > /etc/ld.so.conf.d/cuda.conf
ldconfig

# Get the paths imported in your curent system:
source /etc/profile.d/cuda.sh

# Install deps (you may not need all of these if you don't plan to install all the ML stuff I needed later)
# apt-get -y install build-essential cmake libjpeg-dev libpng-dev libtiff-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev libxvidcore-dev libx264-dev libgtk-3-dev libatlas-base-dev gfortran python3-dev pkg-config unzip ffmpeg qtbase5-dev  python3-dev python3-numpy libhdf5-dev libgtk-3-dev libdc1394-22 libdc1394-22-dev libjpeg-dev libtiff5-dev libtesseract-dev libavcodec-dev libavformat-dev libswscale-dev libxine2-dev libgstreamer-plugins-base1.0-0 libgstreamer-plugins-base1.0-dev libpng16-16 libpng-dev libv4l-dev libtbb-dev libmp3lame-dev libopencore-amrnb-dev libopencore-amrwb-dev libtheora-dev libvorbis-dev libxvidcore-dev v4l-utils libleptonica-dev

#
# check for expected install location
#
CUDADIR=/usr/local/cuda-$CUDA_VER
if [ ! -d "$CUDADIR" ]; then
	echo "Failed to install cuda toolkit!"
    logger "Failed to install cuda toolkit!" -tEventServer
    exit
elif [ ! -L "/usr/local/cuda" ]; then
    ln -s $CUDADIR /usr/local/cuda
fi

logger "Cuda toolkit installed" -tEventServer

#
# Ask user to check that the GPU is seen.
#
if [ -x /usr/bin/nvidia-smi ]; then
	/usr/bin/nvidia-smi >/config/opencv/nvidia-smi.log
	if [ $QUIET_MODE != 'yes' ];then
			echo "##################################################################################"
			echo
			cat /config/opencv/nvidia-smi.log
			echo "##################################################################################"
			echo "Verify your Nvidia GPU is seen and the driver is loaded."
			echo "If not, stop the script and fix the problem."
			echo "Press any key to continue, or ctrl-C to stop."
			read -n 1 -s
	fi
else
	echo "'nvidia-smi' not found!  Check that the Nvidia drivers are installed."
	logger "'nvidia-smi' not found!  Check that the Nvidia drivers are installed." -tEventServer
fi
#
# Install cuDNN run time and dev packages
#
logger "Installing cuDNN Package..." -tEventServer
#
if [ -f /config/opencv/$CUDNN_RUN ];then
	dpkg -i /config/opencv/$CUDNN_RUN
else
	echo "Please download CUDNN_RUN package."
	logger "CUDNN_RUN package not downloaded!" -tEventServer
	exit
fi
if [ -f /config/opencv/$CUDNN_DEV ];then
	dpkg -i /config/opencv/$CUDNN_DEV
else
	echo "Please download CUDNN_DEV package."
	logger "CUDNN_DEV package not downloaded!" -tEventServer
	exit
fi
logger "cuDNN Package installed" -tEventServer

#
# Compile opencv with cuda support
#
logger "Installing cuda support packages..." -tEventServer
apt-get -y install libjpeg-dev libpng-dev libtiff-dev libavcodec-dev libavformat-dev libswscale-dev
apt-get -y install libv4l-dev libxvidcore-dev libx264-dev libgtk-3-dev libatlas-base-dev gfortran
logger "Cuda support packages installed" -tEventServer

#
# Get opencv source
#
logger "Downloading opencv source..." -tEventServer
wget -q -O opencv.zip $OPENCV_URL
wget -q -O opencv_contrib.zip $OPENCV_CONTRIB_URL
unzip opencv.zip
unzip opencv_contrib.zip
mv $(ls -d opencv-*) opencv
mv opencv_contrib-$OPENCV_VER opencv_contrib
rm *.zip

cd ~/opencv
mkdir build
cd build
logger "Opencv source downloaded" -tEventServer

#
# Make opencv
#
logger "Compiling opencv..." -tEventServer

#
# Have user confirm that cuda and cudnn are enabled by the cmake.
#
cmake -D CMAKE_BUILD_TYPE=RELEASE \
	-D CMAKE_INSTALL_PREFIX=/usr/local \
	-D INSTALL_PYTHON_EXAMPLES=OFF \
	-D INSTALL_C_EXAMPLES=OFF \
	-D OPENCV_ENABLE_NONFREE=ON \
	-D WITH_CUDA=ON \
	-D WITH_CUDNN=ON \
	-D OPENCV_DNN_CUDA=ON \
	-D CUDA_ARCH_BIN=6.1 \
	-D CUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda-$CUDA_VER \
	-D ENABLE_FAST_MATH=1 \
	-D CUDA_FAST_MATH=1 \
	-D CUDA_GENERATION="Pascal" \
	-D WITH_CUBLAS=1 \
	-D OPENCV_EXTRA_MODULES_PATH=~/opencv_contrib/modules \
	-D HAVE_opencv_python3=ON \
	-D PYTHON_EXECUTABLE=/usr/bin/python3 \
	-D PYTHON2_EXECUTABLE=/usr/bin/python2 \
	-D BUILD_EXAMPLES=OFF .. >/config/opencv/cmake.log

if [ $QUIET_MODE != 'yes' ];then
	echo "######################################################################################"
	echo
	cat /config/opencv/cmake.log
	echo
	echo "######################################################################################"
	echo "Verify that CUDA and cuDNN are both enabled in the cmake output above."
	echo "Look for the lines with CUDA and cuDNN." 
	echo "You may have to scroll up the page to see them."
	echo "If those lines don't show 'YES', then stop the script and fix the problem."
	echo "Check that you have the correct versions of CUDA ond cuDNN for your GPU."
	echo "Press any key to continue, or ctrl-C to stop."
	read -n 1 -s
fi

make -j$(nproc)

logger "Installing opencv..." -tEventServer
make install
ldconfig

#
# Now reinstall face-recognition package to ensure it detects GPU.
#
pip3 install face-recognition

#
# Clean up/remove unnecessary packages
#
logger "Cleaning up..." -tEventServer

cd ~ ; rm -r opencv*

#
# Now reinstall dlib package to ensure it detects GPU; remove dlib module
#
pip3 uninstall -y dlib
#
cd /usr/local/cuda ; cp -r cuda-11.2/* . >/dev/null
cd ~/ ; git clone https://github.com/davisking/dlib.git ; cd dlib ; python3 setup.py install
ls /usr/local/cuda | grep -v "cuda-11.2" | xargs rm -r >/dev/null
cd ~ ; rm -r dlib*
#

# nvcc command activation
export PATH=/usr/local/cuda/cuda-$CUDA_VER/bin${PATH:+:${PATH}}$
export LD_LIBRARY_PATH=/usr/local/cuda/cuda-$CUDA_VER/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
# echo "export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}$"
# echo "export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

logger "Opencv compile completed" -tEventServer

if [ $QUIET_MODE != 'yes' ];then
	echo "Compile is complete."
	echo "Now check that the cv2 module in python is working."
	echo "Execute the following commands:"
	echo "  python3"
	echo "  import cv2"
	echo "  print(cv2.getBuildInformation())"
	echo "Now check that dlib is working with gpu."
	echo "Execute the following commands:"
	echo "  import dlib"
	echo "  dlib.DLIB_USE_CUDA"
	echo "  Ctrl-D to exit"
	echo
	echo "Verify that the import does not show errors."
	echo "If you don't see any errors, then you have successfully compiled opencv."
	echo
	echo "Once you are satisfied that the compile is working, run the following"
	echo "command:"
	echo "  echo "yes" > opencv_ok"
	echo
	echo "The opencv.sh script will run when the Docker is updated so you won't"
	echo "have to do it manually."
fi