use Mix.Config

if Mix.env == :dev do

  config :mix_test_watch,
    clear: true

  config :cart_ecto,
    ecto_repos: [CartEcto.Repo]

  import_config "dev.secret.exs"
end

if Mix.env == :test do
  config :cart_ecto,
    ecto_repos: [CartEcto.Repo]

  import_config "test.secret.exs"
end

if Mix.env == :prod do
  import_config "prod.secret.exs"
end
