# ----------------------------------------------------
# Copyright (c) https://www.linkedin.com/in/agdelarue/
# ----------------------------------------------------

from fastapi import FastAPI
from pydantic import BaseModel
from typing import List
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

# scoring model
model = joblib.load('model.pkl')

# request model
class LoanRequest(BaseModel):
    age: List[int]
    job: List[str]
    marital: List[str]
    education: List[str]
    default: List[str]
    housing: List[str]
    loan: List[str]
    contact: List[str]
    month: List[str]
    day_of_week: List[str]
    duration: List[int]
    campaign: List[int]
    pdays: List[int]
    previous: List[int]
    poutcome: List[str]
    emp_var_rate: List[float]
    cons_price_idx: List[float]
    cons_conf_idx: List[float]
    euribor3m: List[float]
    nr_employed: List[float]

# scoring API
@app.post('/scores/')
def scores(loan_request: LoanRequest):
    try:
        logging.warning(f"LR:{loan_request}")
        data_dict = loan_request.__dict__
        # adjust keys for model inputs
        fix_key(data_dict, 'emp_var_rate', 'emp.var.rate')
        fix_key(data_dict, 'cons_price_idx', 'cons.price.idx')
        fix_key(data_dict, 'cons_conf_idx', 'cons.conf.idx')
        fix_key(data_dict, 'nr_employed', 'nr.employed')
        #
        logging.warning(f"DD:{data_dict}")
        data_df = pd.DataFrame.from_dict(data_dict)
        logging.warning(f"DF:{data_df}")
        result = model.predict(data_df)
        return json.dumps({"result": result.tolist()})
    except Exception as e:
        result = str(e)
        return json.dumps({"error": result})

# d: dictionary, k: key, new_k: new key
def fix_key(d, k, new_k):
    d[new_k] = d[k]
    del d[k]

# test app booted up properly
@app.get('/')
def hello():
    return "loan-predictor"