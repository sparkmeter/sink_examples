defmodule SimpleServer.SinkEventStorage do
  import Ecto.Query, only: [from: 2]
  alias SimpleServer.Repo
  alias SimpleServer.Ground.GroundEventLog

  def get_current_events(client_id, client_instance_id) do
    query =
      from(e in GroundEventLog,
        where: e.client_id == ^client_id,
        where: e.instance_id == ^client_instance_id
      )

    query
    |> Repo.all()
    |> Enum.map(fn event ->
      {%Sink.Event{
         event_type_id: event.event_type_id,
         key: event.key,
         offset: event.offset,
         schema_version: event.schema_version,
         timestamp: event.event_timestamp,
         event_data: event.event_data
       }, DateTime.to_unix(event.ingested_at, :microsecond)}
    end)
  end

  def get_event(client_id, client_instance_id, {event_type_id, key}, offset) do
    GroundEventLog
    |> Repo.get_by(
      client_id: client_id,
      client_instance_id: client_instance_id,
      event_type_id: event_type_id,
      key: key,
      offset: offset
    )
    |> case do
      nil ->
        nil

      event ->
        {%Sink.Event{
           event_type_id: event.event_type_id,
           key: event.key,
           offset: event.offset,
           schema_version: event.schema_version,
           timestamp: event.event_timestamp,
           event_data: event.event_data
         }, DateTime.to_unix(event.ingested_at, :microsecond)}
    end
  end
end
