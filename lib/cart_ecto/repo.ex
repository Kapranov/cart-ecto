defmodule CartEcto.Repo do
  use Ecto.Repo,
    otp_app: :cart_ecto,
    adapter: Ecto.Adapters.Postgres
end
