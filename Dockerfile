# Build image
FROM ubuntu:18.04 AS build
RUN apt-get update
RUN apt-get install -y build-essential git

# Should CUDA be enabled?
# ARG cuda=0
# Compile with support for Tensor Cores?
# ARG cuda_tc=0

# Get and compile darknet
WORKDIR /src
RUN git clone -n https://github.com/AlexeyAB/darknet.git
WORKDIR /src/darknet
RUN git checkout 4c315ea26b56c2bf20ebc240d94386c6e3cc83db
RUN sed -i -e "s!OPENMP=0!OPENMP=1!g" Makefile && \
    sed -i -e "s!AVX=0!AVX=1!g" Makefile && \
    sed -i -e "s!LIBSO=0!LIBSO=1!g" Makefile && \
    sed -i -e "s!GPU=0!GPU=0!g" Makefile && \
    sed -i -e "s!CUDNN=0!CUDNN=0!g" Makefile && \
    sed -i -e "s!CUDNN_HALF=0!CUDNN_HALF=0!g" Makefile && \
    make

# App image:
FROM ubuntu:18.04

# Bare-bones python install
RUN apt-get update && \
    apt-get install -y libgomp1 wget && \
    apt-get install -y --no-install-recommends python3-pip && \
    apt-get install -y python3-setuptools && \
    pip3 install --no-cache-dir wheel && \
    rm -rf /var/lib/apt/lists

# Get darknet from build image
WORKDIR /app
COPY --from=build /src/darknet/libdarknet.so .
COPY --from=build /src/darknet/build/darknet/x64/darknet.py .
COPY --from=build /src/darknet/cfg data/
COPY --from=build /src/darknet/data data/

# Install api
COPY requirements.txt .
COPY app.py .
COPY swagger.yaml .
RUN pip3 install --no-cache-dir -r requirements.txt

# Model to use (defaults to yolov9000):
ENV weights_file=yolo9000.weights
ENV config_file=data/yolo9000.cfg
ENV meta_file=data/combine9k.data

# Download trained weights for model:
RUN wget https://pjreddie.com/media/files/yolo9000.weights
EXPOSE 8080
CMD ["python3", "app.py"]