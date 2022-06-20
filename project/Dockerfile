FROM python:alpine3.7
COPY . /app
WORKDIR /app
#RUN apt install python3-pip
RUN pip install -r requirements.txt
EXPOSE 5001
ENTRYPOINT [ "python" ]
CMD [ "demo.py" ]
