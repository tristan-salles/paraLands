FROM tristansalles/docker-core:latest

MAINTAINER Tristan Salles

## These are for the full python - scipy stack

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libscalapack-mpi-dev \
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
    curl

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
RUN DEBIAN_FRONTEND=noninteractive apt-get remove -y --no-install-recommends python-scipy
RUN pip install --upgrade pip && \
    pip install matplotlib numpy scipy --upgrade && \
    pip install --upgrade pyproj && \
    pip install --upgrade netcdf4

RUN pip install \
    appdirs packaging \
    runipy \
    ipython \
    cmocean \
    pyevtk

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

### Define Jupyter environment
RUN update-alternatives --set mpirun /usr/bin/mpirun.mpich

ENV TINI_VERSION v0.8.4
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/local/bin/tini
RUN chmod +x /usr/local/bin/tini

# expose notebook port and server port
EXPOSE 8888

ENV LD_LIBRARY_PATH=/fun/share/paraLands

ENTRYPOINT ["/usr/local/bin/tini", "--"]

RUN mkdir /fun/share
VOLUME /fun/share

WORKDIR  /fun

CMD jupyter notebook --ip=0.0.0.0 --no-browser \
    --NotebookApp.token='' --allow-root  --NotebookApp.iopub_data_rate_limit=1.0e10
