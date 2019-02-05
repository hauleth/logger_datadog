# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger, :console, metadata: :all

config :logger, :datadog,
  api_token: "foo",
  tls: false,
  endpoint: "localhost"
