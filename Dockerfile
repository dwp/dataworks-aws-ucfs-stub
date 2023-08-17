FROM python:3.8-alpine

WORKDIR /tmp

COPY assume-role /
COPY ./requirements.txt /tmp
RUN pip install --no-cache-dir -r /tmp/requirements.txt