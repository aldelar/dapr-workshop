FROM tiangolo/uvicorn-gunicorn-fastapi:python3.7

# libraries
RUN apt-get update
RUN apt-get -y upgrade
ENV TZ Etc/UTC
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install apt-utils python3.7 python3-pip
# Default to Python3
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.7 100
RUN update-alternatives --set python /usr/bin/python3.7
# Default to Pip3
RUN update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 100
RUN update-alternatives --set pip /usr/bin/pip3

#
RUN apt-get -y install cython python-numpy python-pandas python-psutil

# python libs
COPY ./requirements.txt .
RUN pip install --upgrade pip
RUN pip install -r requirements.txt

# FastAPI app
COPY ./app /app

# Overides defaults of https://github.com/tiangolo/uvicorn-gunicorn-docker/blob/master/python3.7/gunicorn_conf.py
ENV PORT 808