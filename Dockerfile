FROM fastplaz/ubuntu

LABEL maintainer="Luri Darmawan <luri@carik.id>"
LABEL description="Carik Bot Engine berbasis Object Pascal FastPlaz di lingkungan Docker"

WORKDIR /projects

# Dependencies untuk HEALTHCHECK dan injeksi config yang aman (jq)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

COPY files/run.sh /app/run.sh
RUN chmod +x /app/run.sh

# Persiapan direktori Carik
RUN mkdir -p /projects/carik
COPY carik-linux.tar.gz /projects/carik/
RUN cd /projects/carik && tar zxf carik-linux.tar.gz && rm -f carik-linux.tar.gz

# Tautan simbolik ke webroot Apache
RUN ln -sf /projects/carik /var/www/html/carik && \
    ln -sf /projects/carik /var/www/html/chatbot

# Salin konfigurasi bawaan dan kamus NLP
COPY config.json /projects/carik/config/config.json
COPY files/nlp/ /projects/carik/files/nlp/

# Pastikan permission direktori runtime (runtime chown ulang di run.sh untuk named volumes)
RUN mkdir -p /projects/carik/ztemp /projects/carik/data && \
    chmod -R 775 /projects/carik/ztemp /projects/carik/data && \
    chown -R www-data:www-data /projects/carik/ztemp /projects/carik/data 2>/dev/null || echo "[build] www-data belum tersedia, chown ditunda ke runtime"

ENV PORT=80

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:${PORT:-80}/carik/ || curl -f http://localhost/carik/ || exit 1

ENTRYPOINT ["/app/run.sh"]
