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
    |> cast(attrs, [:quantity, :price, :item_id])
    |> validate_required([:quantity, :price, :item_id])
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
