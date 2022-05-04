FROM ubuntu:jammy
RUN apt-get update -y
RUN apt-get install git gh make parallel jq -y

RUN git clone https://github.com/JosiahSiegel/git-secrets.git
WORKDIR "/git-secrets"
RUN make install
COPY lib/* /
COPY config/* /
RUN mv /exclusions.txt /.gitallowed
RUN ["chmod", "+x", "/patterns.sh"]

ENTRYPOINT ["bash", "/scan.sh"]
