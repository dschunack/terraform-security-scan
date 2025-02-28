# pinned version of the Alpine-tagged 'go' image
#FROM alpine:3.15.0
FROM golang:1.21-alpine

# install requirements
RUN apk add --update --no-cache bash ca-certificates curl jq

COPY entrypoint.sh /entrypoint.sh
# set the default entrypoint -- when this container is run, use this command
ENTRYPOINT ["/entrypoint.sh"]
