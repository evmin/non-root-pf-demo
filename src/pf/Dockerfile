# syntax=docker/dockerfile:1
FROM docker.io/continuumio/miniconda3:latest

# gcc is for build psutil in MacOS
RUN apt-get update && apt-get install -y runit gcc

# ---------------------------------------------------------------
# Create a user with a specific UID and group with a specific GID
RUN groupadd -g 1001 pf && \
    useradd -u 1001 -g pf -m pf

COPY ./flow /home/pf/flow
COPY ./connections /home/pf/connections
COPY ./start.sh /home/pf
COPY ./runit /home/pf/runit

RUN chown -R pf:pf /home/pf
RUN chmod -R +x /home/pf/runit

EXPOSE 8080

# create conda environment
USER pf
WORKDIR /home/pf
RUN conda create -n promptflow-serve python=3.9.16 pip=23.0.1 -q -y && \
    conda run -n promptflow-serve \
    pip install -r /home/pf/flow/requirements.txt && \
    conda run -n promptflow-serve pip install promptflow && \
    conda run -n promptflow-serve pip install promptflow-tools && \
    conda run -n promptflow-serve pip install keyrings.alt && \
    conda run -n promptflow-serve pip install gunicorn==20.1.0 && \
    conda run -n promptflow-serve pip install 'uvicorn>=0.27.0,<1.0.0' && \
    conda run -n promptflow-serve pip cache purge && \
    conda clean -a -y

CMD ["bash", "/home/pf/start.sh"]
