defmodule SimpleClient do
  @moduledoc false
  import Ecto.Query, only: [from: 2]
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
          ack_at_row_id: nil,
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

  def get_next_event() do
    OutgoingEventSubscription
    |> EventCursors.take("self", 1)
    |> List.last()
  end

  def ack_event({event_type_id, key, offset}, sequence_number) do
    {:ok, _} =
      OutgoingEventSubscription
      |> Repo.get_by(event_type_id: event_type_id, key: key)
      |> Ecto.Changeset.change(
        consumer_offset: offset,
        ack_at_row_id: sequence_number,
        nack_at_row_id: nil
      )
      |> Repo.update()

    :ok
  end

  def nack_event({event_type_id, key, _offset}, sequence_number) do
    from(sub in OutgoingEventSubscription,
      where:
        sub.event_type_id == ^event_type_id and sub.key == ^key and is_nil(sub.nack_at_row_id)
    )
    |> Repo.one()
    |> case do
      nil ->
        :ok

      sub ->
        {:ok, _} =
          sub
          |> Ecto.Changeset.change(nack_at_row_id: sequence_number)
          |> Repo.update()

        :ok
    end
  end

  defp log_ground_event(sink_event) do
    ground_event_log = struct(GroundEventLog, Map.from_struct(sink_event))
    Repo.insert(ground_event_log)
  end
end
