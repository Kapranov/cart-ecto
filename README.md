# Meet Ecto, The No-Compromise Database Wrapper For Concurrent Elixir Apps

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

## Installation and Configuration

For starters, let's create a new app with a supervisor using Mix. Mix is
a build tool that ships with Elixir that provides tasks for creating,
compiling, testing your application, managing its dependencies and much
more.

```bash
mix new ./ --app cart_ecto --sup
```

### 16 Feb 2019 by Oleg G.Kapranov

[1]: https://www.toptal.com/elixir/meet-ecto-database-wrapper-for-elixir
[2]: https://github.com/boriscy/cart
