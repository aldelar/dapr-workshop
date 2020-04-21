FROM tiangolo/uvicorn-gunicorn-fastapi:python3.7-alpine3.8
# FastAPI app
COPY ./app /app
# python libs
COPY ./requirements.txt .
RUN pip install --upgrade pip
RUN pip install -r requirements.txt