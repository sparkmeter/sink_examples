defmodule SimpleClient.OutgoingEventSubscription do
  @moduledoc """
  Events to be sent to the server
  """
  use Ecto.Schema
  import Ecto.Changeset

  @fields [:key, :event_type_id, :consumer_offset, :ack_at_row_id, :nack_at_row_id]
  @required_fields [:key, :event_type_id]

  @type t() :: %__MODULE__{}

  @primary_key false
  schema "outgoing_event_subscriptions" do
    field(:key, :binary, primary_key: true)
    field(:event_type_id, :integer, primary_key: true)
    field(:consumer_offset, :integer)
    field(:ack_at_row_id, :integer)
    field(:nack_at_row_id, :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = reading, attrs) do
    reading
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end
end
