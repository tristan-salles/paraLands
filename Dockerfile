FROM tristansalles/docker-core:latest

## =============================================================
## base - image ... whatever functionality you want to provide !
## This is my unix / python stuff (but it doesn't have underworld)
##
## This dockerfile builds an image from this content, and serves the
## sample web pages and notebooks at port 8080
##
## docker run -p 8181:8080 --name="docker-web-notebooks-test" -t lmoresi/lmoresi/docker-web-notebooks-module
## and then browse the docker VM ip address on port 8181 (for example)
##
## OR just use kitematic and click on the preview image
##
## =============================================================

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  petsc-dev \
  libhdf5-openmpi-dev \
  xauth

RUN pip install mkdocs mkdocs-bootswatch pymdown-extensions\
                stripy \
                litho1pt0 \
                mpi4py \
                petsc4py


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

#ADD run-jupyter.py run-jupyter.py

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
