defmodule SimpleClient do
  @moduledoc false
  alias SimpleClient.{OutgoingEventSubscription, GroundEventLog, LastSensorReading}
  alias SimpleClient.Repo

  @doc """
  Log sensor reading values for sensor identified by "name"

  This does two things:
  - it upserts a LastSensorReading record
  - it inserts a record into the GroundEventLog
  """
  def log_sensor_reading(name, params) do
    multi = Ecto.Multi.new()

    case Repo.get_by(LastSensorReading, name: name) do
      nil ->
        # todo: use an id instead of a name
        changeset = LastSensorReading.changeset(%LastSensorReading{name: name}, params)
        Ecto.Multi.insert(multi, :reading, changeset)

      existing ->
        # if a new sensor reading comes in, make sure we increment the offset
        changeset = LastSensorReading.changeset(existing, params)
        Ecto.Multi.update(multi, :reading, changeset, force: true)
    end
    |> Ecto.Multi.run(:event, fn _repo, %{reading: reading} ->
      reading
      |> LastSensorReading.to_sink()
      |> log_ground_event()
    end)
    |> Ecto.Multi.run(:subscription, fn repo, %{event: event} ->
      if event.offset > 1 do
        {:ok, nil}
      else
        # create the subscription
        repo.insert(%OutgoingEventSubscription{
          event_type_id: event.event_type_id,
          key: event.key,
          consumer_offset: 0,
          row_id: nil,
          nack_at_row_id: nil
        })
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{reading: result}} -> {:ok, result}
      {:error, _name, changeset, _} -> {:error, changeset}
    end
  end

  def queue_size do
    EventCursors.queue_size(OutgoingEventSubscription, "self")
  end

  def get_next_event() do
    nil
  end

  def ack_event({_event_type_id, _key, _offset}, _sequence_number) do
    :ok
  end

  defp log_ground_event(sink_event) do
    ground_event_log = struct(GroundEventLog, Map.from_struct(sink_event))
    Repo.insert(ground_event_log)
  end
end
