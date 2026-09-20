FROM fastplaz/ubuntu

LABEL maintainer="Luri Darmawan <luri@carik.id>"
LABEL description="Carik Bot Engine berbasis Object Pascal FastPlaz di lingkungan Docker"

WORKDIR /projects

# Salin berkas inisialisasi runtime
COPY files/run.sh /app/run.sh
RUN chmod +x /app/run.sh

# Persiapan direktori kerja Carik
RUN mkdir -p /projects/carik
COPY carik-linux.tar.gz /projects/carik/
RUN cd /projects/carik && tar zxf carik-linux.tar.gz && rm -f carik-linux.tar.gz

# Tautan simbolik ke webroot Apache
RUN ln -sf /projects/carik/ /var/www/html/carik && \
    ln -sf /projects/carik/ /var/www/html/chatbot

# Salin konfigurasi bawaan dan kamus NLP
COPY config.json /projects/carik/config/config.json
COPY files/nlp/* /projects/carik/files/nlp/

# Pastikan permission direktori runtime
RUN mkdir -p /projects/carik/ztemp /projects/carik/data /projects/carik/files && \
    chmod -R 775 /projects/carik/ztemp /projects/carik/data /projects/carik/files && \
    chown -R www-data:www-data /projects/carik/ztemp /projects/carik/data /projects/carik/files 2>/dev/null || true

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost/carik/ || exit 1

ENTRYPOINT ["/app/run.sh"]
