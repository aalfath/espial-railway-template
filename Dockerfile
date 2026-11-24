# Espial on Railway: official upstream image, pinned by version and digest.
# Release notes: https://github.com/jonschoning/espial/releases
FROM busybox:1.37.0-musl@sha256:f6a95d611e0a8780fabdb2aec43e31275b2720dfefa3e41b16835bfc42454478 AS busybox

FROM jonschoning/espial:0.0.42@sha256:52501164589ccb65c42ffb33c2f042a86042e3c1e3d9313f6560dc9c83b7901b

# The upstream image is distroless with a 6-applet BusyBox. Swap in a full static
# BusyBox so the start script (and `railway ssh`) have echo, grep, awk and friends.
COPY --from=busybox /bin/busybox /bin/busybox
RUN ["/bin/busybox", "--install", "-s", "/bin"]

COPY start.sh /app/start.sh
RUN ["/bin/busybox", "chmod", "755", "/app/start.sh"]

ENV PORT=3000 \
    HOST=*6 \
    SQLITE_DATABASE=/app/data/espial.sqlite3 \
    IP_FROM_HEADER=true \
    SSL_ONLY=true \
    ARCHIVE_BACKEND=disabled

WORKDIR /app
EXPOSE 3000
ENTRYPOINT []
CMD ["/bin/sh", "/app/start.sh"]
