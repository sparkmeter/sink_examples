defmodule SimpleClient.LastSensorReading do
  @moduledoc """
  The last reading from a sensor.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @fields [
    :temperature,
    :humidity
  ]
  @required_fields @fields
  @event_type_id 1
  @schema_version 1

  @type t() :: %__MODULE__{}

  @primary_key {:name, :string, autogenerate: false}
  schema "last_sensor_readings" do
    field(:temperature, :integer)
    field(:humidity, :integer)
    field(:offset, :integer)

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = reading, attrs) do
    reading
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> optimistic_lock(:offset)
  end

  @doc """
  Take a SensorReading and encode/serialize it to a Sink.Event.
  """
  @spec to_sink(t()) :: Sink.Event.t()
  def to_sink(reading) do
    %Sink.Event{
      event_type_id: @event_type_id,
      key: reading.name,
      offset: reading.offset,
      schema_version: @schema_version,
      timestamp: DateTime.to_unix(reading.updated_at),
      # this could be done much more efficiently, but this is fine for an example
      event_data:
        :erlang.term_to_binary(%{
          temperature: reading.temperature,
          humidity: reading.humidity
        })
    }
  end
end
