FROM debian:jessie

# Should lock that down to a specific version !

MAINTAINER Tristan Salles

## the update is fine but very slow ... keep it separated so it doesn't
## get run again and break the cache. The later parts of this build
## may be sensitive to later versions being picked up in the install phase.

RUN apt-get update -y ;

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --fix-missing \
        bash-completion \
        build-essential

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --fix-missing \
        git \
        python \
        python-dev \
        python-pip \
        ruby-full \
        ssh \
        curl \
        rsync \
        vim \
        less \
        gfortran \
        cython \
        cmake \
        zip

## Compile petsc
RUN cd /usr/local && \
    git clone https://bitbucket.org/petsc/petsc petsc && \
    cd petsc && \
    export PETSC_VERSION=3.8.4 && \
    git checkout tags/v$PETSC_VERSION && \
    ./configure --CFLAGS='-O3' --CXXFLAGS='-O3' --FFLAGS='-O3' --with-debugging=no --download-openmpi=yes --download-hdf5=yes --download-fblaslapack=yes --download-metis=yes --download-parmetis=yes && \
    make PETSC_DIR=/usr/local/petsc PETSC_ARCH=arch-linux2-c-opt all

## These are for the full python - scipy stack

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libopenblas-dev \
    liblapack-dev \
    libscalapack-mpi-dev \
    libhdf5-serial-dev \
    petsc-dev \
    libhdf5-openmpi-dev \
    xauth \
    libnetcdf-dev \
    libfreetype6-dev \
    libpng12-dev \
    libtiff-dev \
    libxft-dev \
    xvfb \
    freeglut3 \
    freeglut3-dev \
    libgl1-mesa-dri \
    libgl1-mesa-glx \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    libfreetype6-dev \
    python-numpy \
    python-scipy \
    python-matplotlib \
    python-pandas \
    python-sympy \
    python-nose \
    pkg-config

# Better to build the latest versions than use the old apt-gotten ones
# I'm putting this here as it takes time and ought to be cached before the
# more ephemeral parts of this image.


# (proj4 is buggered up everywhere in apt-get ... so build a known-to-work version from source)
#
RUN cd /usr/local && \
    curl http://download.osgeo.org/proj/proj-4.9.3.tar.gz > proj-4.9.3.tar.gz && \
    tar -xzf proj-4.9.3.tar.gz && \
    cd proj-4.9.3 && \
    ./configure && \
    make all && \
    make install

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        python-gdal \
        python-pil  \
        python-h5py \
        libxml2-dev \
        python-lxml \
        libgeos-dev

## The recent netcdf4 / pythonlibrary stuff doesn't work properly with the default search paths etc
## here is a fix which builds the repo version. Hoping that pip install or apt-get install will work again soon

# RUN USE_SETUPCFG=0 HDF5_INCDIR=/usr/include/hdf5/serial HDF5_LIBDIR=/usr/lib/x86_64-linux-gnu/hdf5/serial pip install git+https://github.com/Unidata/netcdf4-python

RUN pip install --upgrade pip && \
    pip install matplotlib numpy scipy --upgrade && \
    pip install --upgrade pyproj && \
    pip install --upgrade netcdf4

#
# These ones are needed for cartopy / imaging / geometry stuff
#

RUN pip install \
              appdirs packaging \
              runipy \
              ipython

RUN pip install --no-binary :all: shapely

RUN pip install  \
            pyproj \
            obspy \
            seaborn \
            pandas \
            jupyter \
            https://github.com/ipython-contrib/jupyter_contrib_nbextensions/tarball/master \
            jupyter_nbextensions_configurator

RUN pip install --upgrade cartopy

RUN jupyter contrib nbextension install --system && \
    jupyter nbextensions_configurator enable --system

# Add Tini

EXPOSE 8888

RUN pip install cmocean \
          stripy \
          litho1pt0 \
          mpi4py

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends wget

## Compile petsc4py
RUN cd /usr/local && \
        wget https://bitbucket.org/petsc/petsc4py/downloads/petsc4py-3.8.1.tar.gz && \
        tar -xzf petsc4py-3.8.1.tar.gz && \
        cd petsc4py-3.8.1 && \
        export PETSC_DIR=/usr/local/petsc && \
        export PETSC_ARCH=arch-linux2-c-opt && \
        python setup.py install

RUN curl -L https://github.com/krallin/tini/releases/download/v0.6.0/tini > tini && \
      echo "d5ed732199c36a1189320e6c4859f0169e950692f451c03e7854243b95f4234b *tini" | sha256sum -c - && \
      mv tini /usr/local/bin/tini && \
      chmod +x /usr/local/bin/tini

RUN pip install pyevtk

# basemap needs compilation :((
# though maybe you could 'pip install' it after setting the GEOS_DIR
RUN wget http://downloads.sourceforge.net/project/matplotlib/matplotlib-toolkits/basemap-1.0.7/basemap-1.0.7.tar.gz && \
        tar -zxvf basemap-1.0.7.tar.gz && \
        cd basemap-1.0.7 && \
        cd geos-3.3.3 && \
        mkdir ~/install && \
        ./configure --prefix=/usr/ && \
        make && \
        make install && \
        export GEOS_DIR=/usr/ && \
        cd .. && \
        python setup.py build && \
        python setup.py install && \
        cd .. && \
        rm -rf basemap-1.0.7.tar.gz && \
        rm -rf basemap-1.0.7

## These break the current installation of lavavu so we simply remove them
RUN DEBIAN_FRONTEND=noninteractive apt-get remove -y --no-install-recommends \
          libavcodec-dev \
          libavformat-dev \
          libavutil-dev

RUN pip install lavavu

# script for xvfb-run.  all docker commands will effectively run under this via the entrypoint
RUN printf "#\041/bin/sh \n rm -f /tmp/.X99-lock && xvfb-run -s '-screen 0 1600x1200x16' \$@" >> /usr/local/bin/xvfbrun.sh && \
                          chmod +x /usr/local/bin/xvfbrun.sh

RUN mkdir /live && \
         mkdir /live/share

# Persistent / Shared space outside the container
VOLUME /live/share

# expose notebook port and server port
EXPOSE 8888 9999

ENV LD_LIBRARY_PATH=/live/share/paraLands

# note we use xvfb which to mimic the X display for lavavu
ENTRYPOINT ["/usr/local/bin/tini", "--", "xvfbrun.sh"]

WORKDIR /live

# launch notebook
CMD ["jupyter", "notebook", " --no-browser", "--allow-root", "--ip=0.0.0.0", "--NotebookApp.iopub_data_rate_limit=1.0e10"]
