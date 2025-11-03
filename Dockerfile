FROM hexpm/elixir:1.18.4-erlang-27.3.4.4-debian-bookworm-20251020 as build

RUN apt-get update -y && apt-get install -y --no-install-recommends \
      build-essential git curl \
  && rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=prod
WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config ./config
RUN mix deps.get --only prod && mix deps.compile

COPY lib ./lib
COPY priv ./priv

# if you don’t have assets, this will no-op
RUN mix assets.deploy || true
RUN mix compile

RUN mix release

# --- runtime image ---
FROM debian:bookworm-slim

# ncurses on Debian = libncurses6 (and sometimes libtinfo6)
RUN apt-get update -y && apt-get install -y --no-install-recommends \
      openssl \
      libstdc++6 \
      libncurses6 \
      libtinfo6 \
      ca-certificates \
  && update-ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/_build/prod/rel/mail_sense ./

ENV HOME=/app
# EXPOSE 8080   # uncomment if you rely on Docker port metadata
CMD ["/app/bin/mail_sense", "start"]
