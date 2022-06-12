defmodule SimpleClient do
  @moduledoc false
  import Ecto.Query, only: [from: 2]
  alias SimpleClient.{AckLog, GroundEventLog, LastSensorReading}
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
        changeset = LastSensorReading.changeset(%LastSensorReading{name: name}, params)
        Ecto.Multi.insert(multi, :reading, changeset)

      existing ->
        # if a new sensor reading comes in, make sure we increment the offset
        changeset = LastSensorReading.changeset(existing, params)
        Ecto.Multi.update(multi, :reading, changeset, force: true)
    end
    |> Ecto.Multi.run(:event_log, fn _repo, %{reading: reading} ->
      reading
      |> LastSensorReading.to_sink()
      |> log_ground_event()
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{reading: result}} -> {:ok, result}
      {:error, _name, changeset, _} -> {:error, changeset}
    end
  end

  def queue_size do
    Repo.aggregate(gel_query(), :count)
  end

  def get_next_event() do
    query = from(q in gel_query(), limit: 1)

    # order by
    Repo.all(query)
    |> case do
      [] -> nil
      [event] -> GroundEventLog.to_sink_event(event)
    end
  end

  def ack_event({event_type_id, key, offset}) do
    case Repo.get_by(GroundEventLog, event_type_id: event_type_id, key: key, offset: offset) do
      nil -> {:error, :no_event}
      event -> %AckLog{id: event.id} |> Repo.insert()
    end
  end

  defp log_ground_event(sink_event) do
    ground_event_log = struct(GroundEventLog, Map.from_struct(sink_event))
    Repo.insert(ground_event_log)
  end

  defp gel_query do
    from(gel in GroundEventLog,
      left_join: al in AckLog,
      on: gel.id == al.id,
      where: is_nil(al.id),
      order_by: [asc: :id]
    )
  end
end
