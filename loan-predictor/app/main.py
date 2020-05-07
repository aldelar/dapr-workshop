# ----------------------------------------------------
# Copyright (c) https://www.linkedin.com/in/agdelarue/
# ----------------------------------------------------

from fastapi import FastAPI
app = FastAPI()

import logging
import os
import requests
import json

# imports from Azure ML scoring.py
import pickle
import numpy as np
import pandas as pd
import azureml.train.automl
from sklearn.externals import joblib
from azureml.core.model import Model
from inference_schema.schema_decorators import input_schema, output_schema
from inference_schema.parameter_types.numpy_parameter_type import NumpyParameterType
from inference_schema.parameter_types.pandas_parameter_type import PandasParameterType

# DAPR_PORT
dapr_port = os.getenv("DAPR_HTTP_PORT", 3500)
# EXAMPLE: calling another service / actor
#dapr_url = f"http://localhost:{dapr_port}/v1.0/invoke/nodeapp/method/neworder"
# EXAMPLE: access secret store secret
#dapr_url = f"http://localhost:{dapr_port}/v1.0/secrets/{secret_store_name}/{secret_name}"

# load scoring model
model = joblib.load('model.pkl')
# scoring input/output format
input_sample = pd.DataFrame(data=[{'age': 24, 'job': 'technician', 'marital': 'single', 'education': 'university.degree', 'default': 'no', 'housing': 'no', 'loan': 'yes', 'contact': 'cellular', 'month': 'jul', 'day_of_week': 'wed', 'duration': 109, 'campaign': 3, 'pdays': 999, 'previous': 0, 'poutcome': 'nonexistent', 'emp.var.rate': 1.4, 'cons.price.idx': 93.918, 'cons.conf.idx': -42.7, 'euribor3m': 4.963, 'nr.employed': 5228.1}], columns=['age', 'job', 'marital', 'education', 'default', 'housing', 'loan', 'contact', 'month', 'day_of_week', 'duration', 'campaign', 'pdays', 'previous', 'poutcome', 'emp.var.rate', 'cons.price.idx', 'cons.conf.idx', 'euribor3m', 'nr.employed'])
output_sample = np.array([0])

# test app booted up properly
@app.get('/')
def hello():
    return input_sample.to_json()

# scoring API
@input_schema('data', PandasParameterType(input_sample))
@output_schema(NumpyParameterType(output_sample))
@app.post('/scores/')
def scores(data):
    try:
        result = model.predict(data)
        return json.dumps({"result": result.tolist()})
    except Exception as e:
        result = str(e)
        return json.dumps({"error": result})