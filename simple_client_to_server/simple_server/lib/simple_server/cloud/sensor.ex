defmodule SimpleServer.Cloud.Sensor do
  @moduledoc """
  A sensor installed on a client.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @fields [
    :serial_number,
    :name
  ]

  schema "sensors" do
    field(:serial_number, :string)
    field(:name, :string)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = event, attrs) do
    event
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> optimistic_lock(:offset)
  end

  def to_sink_event(sensor) do
    %Sink.Event{
      key: UUID.string_to_binary!(sensor.id),
      event_type_id: 1,
      offset: sensor.offset,
      timestamp: sensor.updated_at,
      event_data:
        :erlang.term_to_binary(%{serial_number: sensor.serial_number, name: sensor.name}),
      schema_version: 0
    }
  end
end
