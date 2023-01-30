defmodule SimpleServer.Cloud.SensorConfig do
  @moduledoc """
  Configuration settings for a sensor installed on a client.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias SimpleServer.Cloud.Sensor

  @fields [
    :on
  ]

  schema "sensor_configs" do
    belongs_to(:sensor, Sensor, type: :binary_id)
    field(:offset, :integer)
    field(:on, :boolean)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = sensor_config, attrs) do
    sensor_config
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> foreign_key_constraint(:sensor_id)
    |> optimistic_lock(:offset)
  end

  def to_sink_event(sensor_config) do
    %Sink.Event{
      key: UUID.string_to_binary!(sensor_config.id),
      event_type_id: 2,
      offset: sensor_config.offset,
      timestamp: sensor_config.updated_at,
      event_data: :erlang.term_to_binary(%{on: sensor_config.on}),
      schema_version: 0
    }
  end
end
