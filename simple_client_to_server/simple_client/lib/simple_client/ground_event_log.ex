defmodule SimpleClient.GroundEventLog do
  @moduledoc """
  A log of generated events that have been encoded into Sink format for transmission to server.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @fields [
    :key,
    :event_type_id,
    :offset,
    :timestamp,
    :schema_version,
    :event_data
  ]

  schema "ground_event_logs" do
    field(:key, :binary)
    field(:event_type_id, :integer)
    field(:offset, :integer)
    field(:timestamp, :integer)
    field(:schema_version, :integer)
    field(:event_data, :binary)
  end

  def changeset(%__MODULE__{} = event, attrs) do
    event
    |> cast(attrs, @fields)
    |> validate_required(@fields)
  end

  def to_sink_event(event) do
    struct(Sink.Event, Map.from_struct(event))
  end
end
