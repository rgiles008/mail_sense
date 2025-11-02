FROM hexpm/elixir:1.18.4-erlang-27.3.4.4-debian-bookworm-20251020 as build


RUN apt-get update -y && apt-get install -y build-essential git curl


ENV MIX_ENV=prod
WORKDIR /app


RUN mix local.hex --force && mix local.rebar --force


COPY mix.exs mix.lock ./
COPY config ./config
RUN mix deps.get --only prod && mix deps.compile


COPY lib ./lib
COPY priv ./priv
RUN mix assets.deploy || true
RUN mix compile


RUN mkdir -p /app/_build/prod/rel
RUN mix release


FROM debian:bookworm-slim
RUN apt-get update -y && apt-get install -y openssl ncurses-libs libstdc++6 ca-certificates && update-ca-certificates
WORKDIR /app
COPY --from=build /app/_build/prod/rel/mailgpt ./
ENV HOME=/app
CMD ["/app/bin/mailgpt", "start"]
