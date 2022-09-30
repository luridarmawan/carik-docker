FROM fastplaz/ubuntu

MAINTAINER Luri Darmawan <luri@carik.id>

WORKDIR /projects
COPY files/run.sh /app/
RUN chmod +x /app/run.sh

# update fastplaz
# RUN cd /projects/vendors/fastplaz/ && git pull origin development

# setup
RUN mkdir carik
COPY carik-linux.tar.gz carik/
RUN cd carik && tar zxf carik-linux.tar.gz
# RUN curl -o carik-linux.tar.gz https://github.com/luridarmawan/Carik/releases/download/v0.0.2020/carik-linux.tar.gz && tar zxf carik-linux.tar.gz
RUN ln -s /projects/carik/ /var/www/html/carik && ln -s /projects/carik/ /var/www/html/chatbot

# Copy your config file to container
COPY config.json /projects/carik/config/
COPY files/nlp/* /projects/carik/files/nlp/

# example: bypass change botName in config.json
# CMD ["./carik-loader", "--botName=yourBot"]
