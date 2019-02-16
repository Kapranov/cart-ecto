## The No-Compromise Database Wrapper For Concurrent Elixir Apps

Ecto is a domain specific language for writing queries and interacting
with databases in the Elixir language.

Ecto is comprised of 4 main components:

* `Ecto.Repo`. Defines repositories that are wrappers around a data
  store. Using it, we can insert, create, delete, and query a repo. An
  adapter and credentials are required to communicate with the database.
* `Ecto.Schema`. Schemas are used to map any data source into an Elixir
  struct.
* `Ecto.Changeset`. Changesets provide a way for developers to filter
  and cast external parameters, as well as a mechanism to track and
  validate changes before they are applied to data.
* `Ecto.Query`. Provides a `DSL`-like `SQL` query for retrieving
  information from a repository. Queries in Ecto are secure, avoiding
  common problems like `SQL` Injection, while still being composable,
  allowing developers to build queries piece by piece instead of all at
  once.

### Installation and Configuration

For starters, let's create a new app with a supervisor using Mix. Mix is
a build tool that ships with Elixir that provides tasks for creating,
compiling, testing your application, managing its dependencies and much
more.

```bash
mix new ./ --app cart_ecto --sup
```

This will create a directory cart with the initial project files.

We are using the `--sup` option since we need a supervisor tree that
will keep the connection to the database. Next, we go to the `cart-ecto`
directory with `cd cart-ecto` and open the file `mix.exs` and replace
its contents:

```elixir
defmodule CartEcto.MixProject do
  use Mix.Project

  def project do
    [
      app: :cart_ecto,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: applications(Mix.env),
      mod: {CartEcto.Application, []}
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:ecto_sql, "~> 3.0"},
      {:ex_unit_notifier, "~> 0.1.4", only: :test},
      {:mix_test_watch, "~> 0.9.0"},
      {:postgrex, "~> 0.14.1"},
      {:remix, "~> 0.0.2", only: :dev}
    ]
  end

  defp applications(:dev), do: applications(:all) ++ [:remix]
  defp applications(_all), do: [:logger]
end
```

In `def application do` we have to add as applications `:postgrex`,
`:ecto` so these can be used inside our application. We also have to
add those as dependencies by adding in `defp deps do` postgrex (which
is the database adapter) and ecto. Once you have edited the file, run
in the console: `mix deps.get`

This will install all dependencies and create a file `mix.lock`. that
stores all dependencies and `sub-dependencies` of the installed packages
(similar to `Gemfile.lock` in bundler).

### Ecto.Repo

![schema](/models.png "schema model")

We will now look at how to define a repo in our application. We can have
more than one repo, meaning we can connect to more than one database. We
need to configure the database in the file `config/config.exs`:

```elixir
use Mix.Config

if Mix.env == :dev do
  config :mix_test_watch,
    clear: true

  import_config "dev.secret.exs"
end

if Mix.env == :test do
  import_config "test.secret.exs"
end

if Mix.env == :prod do
  import_config "prod.secret.exs"
end
```

We are just setting the minimum, so we can run the next command. With
the line `:cart_ecto, cart_repos: [CartEcto.Repo]` we are telling Ecto
which repos we are using. This is a cool feature since it allows us to
have many repos, i.e. we can connect to multiple databases.

Now run the following command: `mix ecto.gen.repo`

This command generates the repo. If you read the output, it tells you
to add a supervisor and repo in your app. Let's start with the
supervisor. We will edit `lib/cart_ecto.ex`:

```elixir
defmodule CartEcto.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {CartEcto.Repo, []}
    ]

    opts = [strategy: :one_for_one, name: CartEcto.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```
In this file, we are defining the supervisor `{CartEcto.Repo, []}`
and adding it to the children list (in Elixir,  lists are similar
to arrays). We define the children supervised with the strategy
`strategy: :one_for_one` which means that, if one of the supervised
processes fails, the supervisor will restart only that process into
its default state. If you look at `lib/cart_ecto/repo.ex` you will
see that this file has been already created, meaning we have a Repo
for our application.

```elixir
defmodule CartEcto.Repo do
  use Ecto.Repo,
    otp_app: :cart_ecto,
    adapter: Ecto.Adapters.Postgres
end
```
Now let's edit the configuration file `config/config.exs`:

```elixir
use Mix.Config

if Mix.env == :dev do

  config :mix_test_watch,
    clear: true

  config :cart_ecto,
    ecto_repos: [CartEcto.Repo]

  config :cart_ecto, CartEcto.Repo,
    database: "cart_dev",
    username: "your_login",
    password: "your_password",
    hostname: "localhost"
end

if Mix.env == :test do
  config :cart_ecto,
    ecto_repos: [CartEcto.Repo]

  config :cart_ecto, CartEcto.Repo,
    database: "cart_test",
    username: "your_login",
    password: "your_password",
    hostname: "localhost"
end

if Mix.env == :prod do
end
```

Having defined all configuration for our database we can now generate
it by running: `mix ecto.create`

This command creates the database and, with that, we have essentially
finished the configuration. We arenow ready to start coding, but let's
define the scope of our app first.

#### 16 Feb 2019 by Oleg G.Kapranov

[1]: https://www.toptal.com/elixir/meet-ecto-database-wrapper-for-elixir
[2]: https://github.com/boriscy/cart
