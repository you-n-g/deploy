#!/usr/bin/env python
"""
Quick review files content.
"""
from collections import defaultdict
from pathlib import Path
import pickle
from pprint import pprint

import gc
import fire
from tqdm.auto import tqdm
import numpy as np
import pandas as pd


# memory info about Data
# https://towardsdatascience.com/reducing-memory-usage-in-pandas-with-smaller-datatypes-b527635830af


# https://stackoverflow.com/a/57531404
def reduce_memory_usage(df):
    """ iterate through all the columns of a dataframe and modify the data type
        to reduce memory usage.
    """
    start_mem = df.memory_usage().sum() / 1024**2 # Unit: MB
    print('Memory usage of input dataframe: {:.2f} MB'.format(start_mem))

    for col in tqdm(df.columns):
        col_type = df[col].dtype
        # categorical data
        if col_type == object:
            df[col] = df[col].astype('category')
        # numerical data
        else:
            c_min = df[col].min()
            c_max = df[col].max()
            # integer
            if str(col_type)[:3] == 'int' or str(col_type)[:4] == 'uint':
                if c_min > np.iinfo(np.int8).min and c_max < np.iinfo(np.int8).max:
                    df[col] = df[col].astype(np.int8)
                elif c_min > np.iinfo(np.int16).min and c_max < np.iinfo(np.int16).max:
                    df[col] = df[col].astype(np.int16)
                elif c_min > np.iinfo(np.int32).min and c_max < np.iinfo(np.int32).max:
                    df[col] = df[col].astype(np.int32)
                elif c_min > np.iinfo(np.int64).min and c_max < np.iinfo(np.int64).max:
                    df[col] = df[col].astype(np.int64)
            # float
            else:
                if c_min > np.finfo(np.float16).min and c_max < np.finfo(np.float16).max:
                    df[col] = df[col].astype(np.float16)
                elif c_min > np.finfo(np.float32).min and c_max < np.finfo(np.float32).max:
                    df[col] = df[col].astype(np.float32)
                else:
                    df[col] = df[col].astype(np.float64)

    end_mem = df.memory_usage().sum() / 1024**2
    print('Memory usage after optimization: {:.2f} MB'.format(end_mem))
    print('Decreased by {:.1f}%'.format(100 * (start_mem - end_mem) / start_mem))
    return df



class ReadFile:
    def _auto_load(self, path):
        for f in [self._pkl, self._hdf, self._parquet]:
            try:
                return f(path)
            except Exception as e:
                print(f"{f.__name__} failed: {e}")

    def _pkl(self, path):
        with Path(path).open("rb") as f:
            return pickle.load(f)

    def _parquet(self, path):
        return pd.read_parquet(path)

    def _inspect(self, obj, e=False):
        if e:
            if isinstance(obj, defaultdict):
                # defaultdict does not work well with objexplore
                obj = dict(obj)
            try:
                __import__("objexplore").explore(obj)
            except ImportError:
                print("objexplore not installed")
        else:
            if isinstance(obj, pd.DataFrame):
                print(obj.head())
                print(f"{obj.shape=}")
            else:
                pprint(obj)

    def _hdf(self, path):
        """quick view"""
        for k in [None, "data"]:
            try:
                return pd.read_hdf(path, key=k)
            except KeyError:
                print(f"key={k} not found")

    def auto(self, path, e=False):
        obj = self._auto_load(path)
        self._inspect(obj, e)

    def pk(self, path, e=False):
        obj = self._pkl(path)
        self._inspect(obj, e)

    def df_conv(self, file):
        """
        Convert file form `pickle` to `.parquet`
        """
        p = Path(file)
        df = pd.read_pickle(p)
        df.to_parquet(p.with_suffix(".parquet"))

    def conv16p(self, path):

        def wrapper(method):
            def _f(df, path):
                getattr(df, method)(path)
            return _f

        p = Path(path)
        if p.suffix in {".pkl"}:
            rf = pd.read_pickle
            wf = wrapper("to_pickle")
        elif p.suffix in {".parquet"}:
            # TODO: parquet does not support half precision....
            rf = pd.read_parquet
            wf = wrapper("to_parquet")
        else:
            raise NotImplementedError(f"This type of input is not supported")
        wf(reduce_memory_usage(rf(p).head()), p.with_suffix(f".16p{p.suffix}"))



if __name__ == "__main__":
    fire.Fire(ReadFile)
