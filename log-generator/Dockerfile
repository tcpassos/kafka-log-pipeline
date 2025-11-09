FROM alpine:3.18
RUN apk add --no-cache bash
COPY generator.sh /generator.sh
RUN chmod +x /generator.sh
CMD ["/generator.sh"]