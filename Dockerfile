FROM ubuntu:20.10

# File Author / Maintainer MAINTAINER
MAINTAINER Natacha Beck <natabeck@gmail.com>

RUN apt-get update

RUN apt-get install -y vim   \
                       git   \
                       wget  \
                       tar   \
                       unzip \ 
                       openjdk-8-jre-headless

# Install Anaconda
RUN wget https://repo.anaconda.com/archive/Anaconda2-5.1.0-Linux-x86_64.sh; bash Anaconda2-5.1.0-Linux-x86_64.sh -b -p /anaconda
RUN rm -rf Anaconda2-5.1.0-Linux-x86_64.sh
ENV PATH="/anaconda/bin:${PATH}"

# Install pyspark
RUN pip install --upgrade pip 
RUN pip install pyspark

# Install PRSoS
RUN git clone https://github.com/MeaneyLab/PRSoS.git
RUN cd PRSoS; pip install -r requirements.txt

# Install plink
RUN mkdir /plink; cd /plink; wget http://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20200921.zip; unzip plink_linux_x86_64_20200921.zip
ENV PATH="/plink:${PATH}"

# Install ePRS
RUN mkdir /ePRS
COPY ePRS_script/run_ePRS_5HTT.sh /ePRS/run_ePRS_5HTT.sh
ENV PATH="/ePRS:${PATH}"
COPY fix_data /ePRS/fix_data 
