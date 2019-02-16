defmodule CartEcto.Item do
  use Ecto.Schema

  import Ecto.Changeset

  alias CartEcto.{InvoiceItem, Item}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "items" do
    field :name, :string
    field :price, :decimal, precision: 12, scale: 2
    has_many :invoice_items, InvoiceItem

    timestamps()
  end

  def changeset(%Item{} = item, attrs) do
    item
    |> cast(attrs, [:name, :price])
    |> validate_required([:name, :price])
    |> validate_number(:price, greater_than_or_equal_to: Decimal.new(0))
  end
end
