import os
import shutil
import tempfile

import certifi
import yfinance as yf
from curl_cffi import requests as curl_requests
from fastapi import FastAPI, HTTPException

# 프로젝트 경로에 한글(문서)이 있으면 curl이 인증서 파일을 읽지 못하므로
# 인증서를 영문 경로(임시 폴더)로 복사해서 사용
CA_FILE = os.path.join(tempfile.gettempdir(), "cacert.pem")
shutil.copyfile(certifi.where(), CA_FILE)
session = curl_requests.Session(impersonate="chrome", verify=CA_FILE)

app = FastAPI()


@app.get("/")
def read_home():
    return {"hello": "world"}


@app.get("/samsung")
def get_samsung(period: str = "1mo"):
    """삼성전자(005930.KS) 주식 데이터를 JSON으로 반환"""
    df = yf.Ticker("005930.KS", session=session).history(period=period)
    if df.empty:
        raise HTTPException(status_code=404, detail="데이터를 가져오지 못했습니다.")

    data = [
        {
            "date": idx.strftime("%Y-%m-%d"),
            "open": round(row["Open"]),
            "high": round(row["High"]),
            "low": round(row["Low"]),
            "close": round(row["Close"]),
            "volume": int(row["Volume"]),
        }
        for idx, row in df.iterrows()
    ]
    return {"name": "삼성전자", "ticker": "005930.KS", "count": len(data), "data": data}
