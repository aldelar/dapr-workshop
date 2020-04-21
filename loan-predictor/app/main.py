# ----------------------------------------------------
# Copyright (c) https://www.linkedin.com/in/agdelarue/
# ----------------------------------------------------

from fastapi import FastAPI
app = FastAPI()

import logging
import os
import requests
import json

# DAPR_PORT
dapr_port = os.getenv("DAPR_HTTP_PORT", 3500)

# EXAMPLE: calling another service / actor
dapr_url = f"http://localhost:{dapr_port}/v1.0/invoke/nodeapp/method/neworder"

@app.get('/')
def hello():
    return "loan-predictor"

@app.get('/predict-loan/{l}')
def predict_loan(l: str):
    return { 'method': 'predict-loan', 'input:': l}

@app.get('/secrets/{secret_store_name}/{secret_name}')
def get_secret(secret_store_name: str, secret_name: str):
    dapr_url = f"http://localhost:{dapr_port}/v1.0/secrets/{secret_store_name}/{secret_name}"
    logging.warning(dapr_url)
    secret_value = json.loads(requests.get(dapr_url).text)[secret_name]
    return {
        'secret_store_name': secret_store_name,
        'secret_name': secret_name,
        'secret_value' : secret_value
        }