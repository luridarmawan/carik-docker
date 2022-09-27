# Carik Bot Engine with Docker

Pull docker image with command
```
docker pull luri/carik-bot:latest
```

### Build

```
docker build . -t [yourDockerName]
```

### Running Chatbot Server

```
docker run -it -p 8080:80 luri/carik-bot
```

#### with composer
```bash
docker-compose up --build
```
