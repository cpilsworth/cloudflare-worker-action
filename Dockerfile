FROM r.j3ss.co/terraform:latest

LABEL "com.github.actions.name"="Cloudflare Worker"
LABEL "com.github.actions.description"="Deploy a worker to a cloudlfare zone"
LABEL "com.github.actions.icon"="cloud"
LABEL "com.github.actions.color"="#f58220"

RUN apk add --no-cache \
	git \
	make

COPY terraform /usr/src/terraform
COPY Makefile /usr/src
COPY deploy.sh /usr/local/bin/deploy

WORKDIR /usr/src

ENTRYPOINT ["deploy"]
