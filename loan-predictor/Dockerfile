FROM tiangolo/uvicorn-gunicorn-fastapi:python3.7-alpine3.8
# FastAPI app
COPY ./app /app
# python libs
COPY ./requirements.txt .
RUN pip install --upgrade pip
RUN pip install -r requirements.txt
# Overides defaults of https://github.com/tiangolo/uvicorn-gunicorn-docker/blob/master/python3.7/gunicorn_conf.py
ENV PORT 808