#!/usr/bin/env -S uv run --no-project --with fastapi --with uvicorn --with pydantic-settings --with typer python

import json
import os

import pandas as pd
import uvicorn
from fastapi import FastAPI
from fastapi.responses import Response
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    data_path: str = "./"
    # fastapi ls /Data/home/xiaoyang/repos/qube/res
    # cat /Data/home/xiaoyang/repos/qube/res/*

    model_config = SettingsConfigDict(
        env_prefix="MY_SRV_",
        # extra="allow", # Does it allow extrasettings
    )

SETTINGS = Settings()


app = FastAPI()

@app.get("/")
def read_json():
    # Read all JSON files in data_path, combine into a dataframe, and return as CSV

    json_files = [f for f in os.listdir(SETTINGS.data_path) if f.endswith(".json")]
    data_list = []
    for filename in json_files:
        file_path = os.path.join(SETTINGS.data_path, filename)
        with open(file_path, "r") as f:
            content = json.load(f)
            data_list.append(content)
    if not data_list:
        return Response("No JSON data found", media_type="text/plain")
    df = pd.DataFrame(data_list)
    csv_data = df.to_csv(index=False)
    return Response(content=csv_data, media_type="text/csv")

if __name__ == "__main__":
    import typer

    def main(P: int = typer.Option(8000, "--port", "-p", help="Port number to run the server on")):
        uvicorn.run(app, host="0.0.0.0", port=P)

    typer.run(main)


