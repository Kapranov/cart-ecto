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

### Building an Invoice with Inline Items

For our demo application, we will build a simple invoicing tool. For
changesets (models) we will have Invoice, Item and InvoiceItem.
InvoiceItem belongs to Invoice and Item. This diagram represents how
our models will be related to each other:

![schema](/schema.png "schema tables")

The diagram is pretty simple. We have a table `invoices` that has many
`invoice_items` where we store all the details and also a table `items`
that has many `invoice_items`. You can see that the type for `invoice_id`
and `item_id` in `invoice_items` table is UUID. We are using UUID
because it helps obfuscate the routes, in case you want to expose the
app over an API and makes it simpler to sync since you don't depend on a
sequential number. Now let's create the tables using Mix tasks.

### Ecto.Migration

![schema](/invoices.png "invoices table")

Migrations are files that are used to modify the database schema.
`Ecto.Migration` gives you a set of methods to create tables, add
indexes, create constraints, and other schema-related stuff. Migrations
really help keep the application in sync with the database. Let's create
a migration script for our first table:

```bash
mix ecto.gen.migration create_invoices
```

This will generate a file similar to
`priv/repo/migrations/20190216165320_create_invoices.exs`
where we will define our migration. Open the file generated and modify
its contents to be as follows:

```elixir
defmodule CartEcto.Repo.Migrations.CreateInvoices do
  use Ecto.Migration

  def change do
    create table(:invoices, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :customer, :text
      add :amount, :decimal, precision: 12, scale: 2
      add :balance, :decimal, precision: 12, scale: 2
      add :date, :date

      timestamps()
    end
end
```

Inside method `def change do` we define the schema that will generate
the SQL for the database.
`create table(:invoices, primary_key: false) do` will create the table
invoices. We have set `primary_key: false` but we will add an ID field
of type UUID, customer field of type text, date field of type date. The
`timestamps` method will generate the fields `inserted_at`, `updated_at`
that Ecto automatically fills with the time the record was inserted and
the time it was updated, respectively. Now go to the console and run the
migration: `mix ecto.migrate`

We have created the table `invoice`'s with all the defined fields. Let's
create the items table:

```bash
mix ecto.gen.migration create_items
```

Now edit the generated migration script:

```elixir
defmodule CartEcto.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :text
      add :price, :decimal, precision: 12, scale: 2

      timestamps()
    end
  end
end
```

The new thing here is the decimal field that allows numbers with 12
digits, 2 of which are for the decimal part of the number. Let's run
the migration again: `mix ecto.migrate`

Now we have created items table and finally let's create the
`invoice_items` table:

```bash
mix ecto.gen.migration create_invoice_items
```

Edit the migration:

```elixir
defmodule CartEcto.Repo.Migrations.CreateInvoiceItems do
  use Ecto.Migration

  def change do
    create table(:invoice_items, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :invoice_id, references(:invoices, type: :uuid, null: false)
      add :item_id, references(:items, type: :uuid, null: false)
      add :price, :decimal, precision: 12, scale: 2
      add :quantity, :decimal, precision: 12, scale: 2
      add :subtotal, :decimal, precision: 12, scale: 2

      timestamps()
    end

    create index(:invoice_items, [:invoice_id])
    create index(:invoice_items, [:item_id])
  end
end
```
As you can see, this migration has some new parts. The first thing you
will notice is `add :invoice_id, references(:invoices, type: :uuid, null: false)`
This creates the field `invoice_id` with a constraint in the database
that references the invoices table. We have the same pattern for
`item_id` field. Another thing that is different is the way we create
an index: `create index(:invoice_items, [:invoice_id])` creates the
`invoice_items_invoice_id_index`.

### Ecto.Schema and Ecto.Changeset

In Ecto, `Ecto.Model` has been deprecated in favor of using `Ecto.Schema`,
so we will call the modules schemas instead of models. Let's create the
changesets. We will start with the most simple changeset Item and create
the file `lib/cart_ecto/item.ex`:

```elixir
defmodule CartEcto.Item do
  use Ecto.Schema

  import Ecto.Changeset

  alias CartEcto.{Item}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "items" do
    field :name, :string
    field :price, :decimal, precision: 12, scale: 2

    timestamps()
  end

  def changeset(%Item{} = item, attrs) do
    item
    |> cast(attrs, [:name, :price])
    |> validate_required([:name, :price])
    |> validate_number(:price, greater_than_or_equal_to: Decimal.new(0))
  end
end
```

At the top, we inject code into the changeset using `use Ecto.Schema`.
We are also using `import Ecto.Changeset` to import functionality from
`Ecto.Changeset`. We could have specified which specific methods to
import, but let’s keep it simple. The `alias Cart.InvoiceItem` allows us
to write directly inside the changeset InvoiceItem, as you will see in a
moment.

The `@primary_key {:id, :binary_id, autogenerate: true}` specifies that
our primary key will be auto generated. Since we are using a UUID type,
we define the schema with `schema "items" do` and inside the block we
define each field and relationships. We defined name as string and price
as decimal, very similar to the migration. Next, the macro
`has_many :invoice_items, InvoiceItem`  indicates a relationship between
`Item` and `InvoiceItem`. Since by convention we named the field
`item_id` in the `invoice_items` table, we don’t need to configure the
foreign key. Finally the `timestamps` method will set the `inserted_at`
and `updated_at` fields.

### Ecto.Changeset

![schema](/changeset.png "changeset model")

The `def changeset(%Item{} = item, attrs) do` function receives an Elixir
struct with params which we will pipe through different functions.
`cast(attrs, [:name, :price])` casts the values into the correct type.
For instance, you can pass only strings in the params and those would be
converted to the correct type defined in the schema.
`validate_required([:name, :price])` validates that the name and price
fields are present,
`validate_number(:price, greater_than_or_equal_to: Decimal.new(0))`
validates that the number is greater than or equal to 0 or in this case
`Decimal.new(0)`.

That was a lot to take in, so let's look at this in the console with
examples so you can grasp the concepts better: `iex -S mix`

This will load the console. `-S mix` loads the current project into the
iex REPL.

```elixir
item = CartEcto.Item.changeset(%CartEcto.Item{}, %{name: "Paper", price: "2.5"})

#Ecto.Changeset<
  action: nil,
  changes: %{name: "Paper", price: #Decimal<2.5>},
  errors: [],
  data: #CartEcto.Item<>,
  valid?: true
>
```

This returns an `Ecto.Changeset` struct that is valid without errors.
Now let’s save it:

```elixir
item = CartEcto.Repo.insert!(item)
```

We don’t show the SQL for brevity. In this case, it returns the
`CartEcto.Item` struct with all the values set, You can see that
`inserted_at` and `updated_at` contain their timestamps and the
`id` field has a UUID value. Let's see some other cases:

```elixir
item2 = CartEcto.Item.changeset(%CartEcto.Item{price: Decimal.new(20)}, %{name: "Scissors"})
```
Now we have set the `Scissors` item item in a different way, setting the
price directly `%CartEcto.Item{price: Decimal.new(20)}`.

We need to set its correct type, unlike the first item where we just
passed a string as price. We could have passed a float and this would
have been cast into a decimal type. If we pass, for example
`%CartEcto.Item{price: 12.5}`, when you insert the item it would throw
an exception stating that the type doesn't match.

```elixir
invalid_item = CartEcto.Item.changeset(%CartEcto.Item{}, %{name: "Scissors", price: -1.5})
```

To terminate the console, press `Ctrl+C` twice. You can see that
validations are working and the price must be greater than or equal to
zero (0). As you can see, we have defined all the schema `Ecto.Schema`
which is the part related to how the structure of the module is defined
and the changeset `Ecto.Changeset` which is all validations and casting.

Let's continue and create the file `lib/cart_ecto/invoice_item.ex`:

```elixir
defmodule CartEcto.InvoiceItem do
  use Ecto.Schema

  import Ecto.Changeset

  alias CartEcto.InvoiceItem

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "invoice_items" do
    belongs_to :invoice, CartEcto.Invoice, type: :binary_id
    belongs_to :item, CartEcto.Item, type: :binary_id
    field :quantity, :decimal, precision: 12, scale: 2
    field :price, :decimal, precision: 12, scale: 2
    field :subtotal, :decimal, precision: 12, scale: 2

    timestamps()
  end

  @zero Decimal.new(0)

  @doc false
  def changeset(%InvoiceItem{} = invoice_item, attrs) do
    invoice_item
    |> cast(attrs, [:quantity, :price, :subtotal, :invoice_id, :item_id])
    |> validate_required([:quantity, :price, :subtotal, :invoice_id, :item_id])
    |> validate_number(:price, greater_than_or_equal_to: @zero)
    |> validate_number(:quantity, greater_than_or_equal_to: @zero)
    |> foreign_key_constraint(:invoice_id, message: "Select a valid invoice")
    |> foreign_key_constraint(:item_id, message: "Select a valid item")
    |> set_subtotal
  end

  @doc false
  def set_subtotal(cs) do
    case {(cs.changes[:price] || cs.invoice_item.price), (cs.changes[:quantity] || cs.invoice_item.quantity)} do
      {_price, nil} -> cs
      {nil, _quantity} -> cs
      {price, quantity} ->
        put_change(cs, :subtotal, Decimal.mult(price, quantity))
    end
  end
end
```
This changeset is bigger but you should already be familiar with most of
it. Here `belongs_to :invoice, CartEcto.Invoice, type: :binary_id`
defines the `belongs to` relationship with the `CartEcto.Invoice`
changeset that we will soon create. The next `belongs_to :item` creates
a relationship with the items table. We have defined
`@zero Decimal.new(0)`. In this case, `@zero` is like a constant that
can be accessed inside the module. The changeset function has new parts,
one of which is
`foreign_key_constraint(:invoice_id, message: "Select a valid invoice")`
This will allow an error message to be generated instead of generating
an exception when the constraint is not fulfilled. And finally, the
method `set_subtotal` will calculate the subtotal. We pass the changeset
and return a new changeset with the subtotal calculated if we have both
the price and quantity.

Now, let's create the `CartEcto.Invoice`. So create and edit the file
`lib/cart_ecto/invoice.ex` to contain the following:

```elixir
defmodule CartEcto.Invoice do
  use Ecto.Schema

  import Ecto.Changeset

  alias CartEcto.{Invoice, InvoiceItem, Repo}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "invoices" do
    field :customer, :string
    field :amount, :decimal, precision: 12, scale: 2
    field :balance, :decimal, precision: 12, scale: 2
    field :date, :utc_datetime
    has_many :invoice_items, InvoiceItem, on_delete: :delete_all

    timestamps()
  end

  def changeset(%Invoice{} = invoice, attrs) do
    invoice
    |> cast(attrs, [:customer, :amount, :balance, :date])
    |> validate_required([:customer, :date])
  end

  def create(params) do
    cs = changeset(%Invoice{}, params)
    |> validate_item_count(params)
    |> put_assoc(:invoice_items, get_items(params))

    if cs.valid? do
      Repo.insert(cs)
    else
      cs
    end
  end

  defp get_items(params) do
    items = params[:invoice_items] || params["invoice_items"]
    Enum.map(items, fn(item)-> InvoiceItem.changeset(%InvoiceItem{}, item) end)
  end

  defp validate_item_count(cs, params) do
    items = params[:invoice_items] || params["invoice_items"]

    if Enum.count(items) <= 0 do
      add_error(cs, :invoice_items, "Invalid number of items")
    else
      cs
    end
  end
end
```

`CartEcto.Invoice` changeset has some differences. The first one is
inside schemas: `has_many :invoice_items, InvoiceItem, on_delete: :delete_all`
means that when we delete an invoice, all the associated `invoice_items`
will be deleted. Keep in mind, though, that this is not a constraint
defined in the database.

Let's try the create method in the console to understand things better.
You might have created the items ("Paper", "Scissors") which we will be
using here:

```elixir
item_ids = Enum.map(CartEcto.Repo.all(Cart.Item), fn(item)-> item.id end)
{id1, id2} = {Enum.at(item_ids, 0), Enum.at(item_ids, 1)}
```

We fetched all items with `CartEcto.Repo.all` and with the `Enum.map`
function we just get the `item.id` of each item.

In the second line, we just assign  `id1` and `id2` with the first and
second `item_ids`, respectively:

```elixir
inv_items = [
  %{
    item_id: id1,
    price: 2.5,
    quantity: 2
  },
  %{
    item_id: id2,
    price: 20,
    quantity: 1
  }
]

{:ok, inv} = CartEcto.Invoice.create(
  %{
    customer: "James Brown",
    date: Ecto.Date.utc,
    invoice_items: inv_items
  }
)
```

The invoice has been created with its `invoice_items` and we can fetch
all the invoices now.

```elixir
alias CartEcto.{Repo, Invoice}
Repo.all(Invoice)
```

You can see it returns the `Invoice` but we would like to also see the
`invoice_items`:

```elixir
Repo.all(Invoice) |> Repo.preload(:invoice_items)
```

With the `Repo.preload` function, we can get the `invoice_items`. Note
that this can process queries concurrently. In my case the query looked
like this:

```elixir
Repo.get(Invoice, "5d573153-b3d6-46bc-a2c0-6681102dd3ab")
|> Repo.preload(:invoice_items)
```

#### 16 Feb 2019 by Oleg G.Kapranov

[1]: https://www.toptal.com/elixir/meet-ecto-database-wrapper-for-elixir
[2]: https://github.com/boriscy/cart
